-- Port of ascii-sharks (World + AsciiRenderer) to native Neovim Lua
local M = {}

local TAU = math.pi * 2
local SHARK_NODES = 20

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function rand(lo, hi)
  return lo + math.random() * (hi - lo)
end

local function smoothstep(e0, e1, x)
  local t = clamp((x - e0) / (e1 - e0), 0, 1)
  return t * t * (3 - 2 * t)
end

local function angleDiff(a, b)
  local d = (b - a) % TAU
  if d > math.pi then d = d - TAU end
  if d < -math.pi then d = d + TAU end
  return d
end

local bit = bit or require("bit")
local bxor, band, rshift, lshift = bit.bxor, bit.band, bit.rshift, bit.lshift

local function imul32(a, b)
  local ah = band(rshift(a, 16), 0xffff)
  local al = band(a, 0xffff)
  local bh = band(rshift(b, 16), 0xffff)
  local bl = band(b, 0xffff)
  return bit.tobit(al * bl + lshift(band(ah * bl + al * bh, 0xffff), 16))
end

local function hash3(x, y, z)
  local h = bxor(
    imul32(math.floor(x), 374761393),
    bxor(imul32(math.floor(y), 668265263), imul32(math.floor(z), 1442695041))
  )
  h = imul32(bxor(h, rshift(h, 13)), 1274126177)
  h = bxor(h, rshift(h, 16))
  if h < 0 then
    h = h + 4294967296
  end
  return h / 4294967296
end

local function inTriangle(px, py, ax, ay, bx, by, cx, cy)
  local d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by)
  local d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy)
  local d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
  local neg = d1 < 0 or d2 < 0 or d3 < 0
  local pos = d1 > 0 or d2 > 0 or d3 > 0
  return not (neg and pos)
end

local function classicHalfWidth(s)
  if s < 0.13 then
    return 0.09 * (math.sin(((s / 0.13) * math.pi) / 2) ^ 0.95)
  end
  if s < 0.3 then
    return 0.09 + 0.016 * smoothstep(0.13, 0.3, s)
  end
  if s < 0.84 then
    return 0.019 + 0.087 * ((1 - (s - 0.3) / 0.54) ^ 1.25)
  end
  local k = (s - 0.84) / 0.16
  return 0.019 * (1 - k) + 0.012 * math.sin(k * math.pi)
end

local SHAPES = {
  classic = {
    halfWidth = classicHalfWidth,
    pectoral = { 0.15, 0.43, 0.55, 0.26 },
    falcate = true,
    pelvic = { 0.57, 0.65, 0.69, 0.085 },
    caudal = 0.085,
    dorsal = { 0.33, 0.47 },
    secondDorsal = { 0.71, 0.76 },
    eye = { 0.1, 0.14 },
    gills = { 0.19, 0.29 },
    tint = "slate",
  },
  hammerhead = {
    halfWidth = function(s)
      if s < 0.06 then return 0.045 end
      if s < 0.3 then return 0.045 + 0.061 * smoothstep(0.06, 0.3, s) end
      return classicHalfWidth(s) * 0.92
    end,
    head = { span = 0.17, sweep = 0.035, depth = 0.09, notch = 0 },
    pectoral = { 0.17, 0.4, 0.5, 0.22 },
    falcate = true,
    pelvic = { 0.56, 0.63, 0.67, 0.075 },
    caudal = 0.11,
    dorsal = { 0.28, 0.44 },
    secondDorsal = { 0.7, 0.74 },
    eye = nil,
    gills = { 0.16, 0.26 },
    tint = "slate",
  },
  greathammer = {
    halfWidth = function(s)
      if s < 0.05 then return 0.04 end
      if s < 0.3 then return 0.04 + 0.07 * smoothstep(0.05, 0.3, s) end
      return classicHalfWidth(s) * 0.95
    end,
    head = { span = 0.21, sweep = 0.006, depth = 0.085, notch = 0.014 },
    pectoral = { 0.16, 0.38, 0.49, 0.24 },
    falcate = true,
    pelvic = { 0.55, 0.62, 0.67, 0.085 },
    caudal = 0.13,
    dorsal = { 0.24, 0.45 },
    secondDorsal = { 0.68, 0.74 },
    eye = nil,
    gills = { 0.15, 0.25 },
    tint = "slate",
  },
  zebra = {
    halfWidth = function(s)
      if s < 0.1 then return 0.075 * (math.sin(((s / 0.1) * math.pi) / 2) ^ 0.7) end
      if s < 0.28 then return 0.075 + 0.025 * smoothstep(0.1, 0.28, s) end
      if s < 0.55 then return 0.022 + 0.078 * ((1 - (s - 0.28) / 0.27) ^ 1.1) end
      local k = (s - 0.55) / 0.45
      return 0.022 * (1 - k * k) + 0.012 * math.sin(k * math.pi)
    end,
    pectoral = { 0.12, 0.3, 0.36, 0.19 },
    falcate = false,
    pelvic = { 0.42, 0.48, 0.51, 0.065 },
    caudal = 0,
    dorsal = { 0.36, 0.44 },
    secondDorsal = { 0.49, 0.53 },
    eye = { 0.06, 0.09 },
    gills = { 0.13, 0.2 },
    tint = "warm",
  },
  tiger = {
    halfWidth = function(s)
      if s < 0.13 then return 0.1 * (math.sin(((s / 0.13) * math.pi) / 2) ^ 0.45) end
      if s < 0.3 then return 0.1 + 0.014 * smoothstep(0.13, 0.3, s) end
      if s < 0.84 then return 0.019 + 0.095 * ((1 - (s - 0.3) / 0.54) ^ 1.2) end
      local k = (s - 0.84) / 0.16
      return 0.019 * (1 - k) + 0.012 * math.sin(k * math.pi)
    end,
    pectoral = { 0.15, 0.42, 0.53, 0.25 },
    falcate = true,
    pelvic = { 0.57, 0.65, 0.69, 0.085 },
    caudal = 0.095,
    dorsal = { 0.33, 0.46 },
    secondDorsal = { 0.71, 0.75 },
    eye = { 0.08, 0.12 },
    gills = { 0.19, 0.28 },
    tint = "warm",
  },
  dragon = {
    is_dragon = true,
    halfWidth = function(s)
      -- Proportioned for an ultra-long (2.2x) 56-node serpentine body:
      -- Sculpted dragon snout -> flared jaw/cheeks -> slender neck -> long sinuous body -> flame tail fan
      if s < 0.015 then return 0.012 + 0.008 * math.sin((s / 0.015) * math.pi) end
      if s < 0.038 then return 0.014 + 0.016 * math.sin(((s - 0.015) / 0.023) * math.pi) end
      if s < 0.065 then return 0.015 + 0.004 * smoothstep(0.038, 0.065, s) end
      if s < 0.90 then
        local body_t = (s - 0.065) / 0.835
        return 0.0065 + 0.0135 * ((1 - body_t) ^ 0.82) * (1 + 0.10 * math.sin(body_t * math.pi))
      end
      -- Ornate leaf-shaped flame tail plume
      local k = (s - 0.90) / 0.10
      return 0.0065 * (1 - k) + 0.018 * math.sin(k * math.pi)
    end,
    pectoral = { 0.15, 0.185, 0.205, 0.058 },
    falcate = false,
    pelvic = { 0.56, 0.595, 0.615, 0.054 },
    caudal = 0,
    dorsal = { 0.045, 0.95 },
    secondDorsal = { 0.95, 0.99 },
    eye = { 0.016, 0.028 },
    gills = { 0.04, 0.06 },
    tint = "dragon_gold",
  },
  leviathan = {
    is_dragon = true,
    halfWidth = function(s)
      if s < 0.015 then return 0.013 + 0.009 * math.sin((s / 0.015) * math.pi) end
      if s < 0.038 then return 0.015 + 0.017 * math.sin(((s - 0.015) / 0.023) * math.pi) end
      if s < 0.065 then return 0.016 + 0.004 * smoothstep(0.038, 0.065, s) end
      if s < 0.90 then
        local body_t = (s - 0.065) / 0.835
        return 0.0070 + 0.0145 * ((1 - body_t) ^ 0.82) * (1 + 0.10 * math.sin(body_t * math.pi))
      end
      local k = (s - 0.90) / 0.10
      return 0.0070 * (1 - k) + 0.020 * math.sin(k * math.pi)
    end,
    pectoral = { 0.15, 0.185, 0.205, 0.062 },
    falcate = false,
    pelvic = { 0.56, 0.595, 0.615, 0.058 },
    caudal = 0,
    dorsal = { 0.045, 0.95 },
    secondDorsal = { 0.95, 0.99 },
    eye = { 0.016, 0.028 },
    gills = { 0.04, 0.06 },
    tint = "dragon_jade",
  },
}

local SKIN_RAMP = { ":", ";", "t", "%", "S", "X", "8", "#", "@" }
local FIN_GLYPHS = { "%", ";", "t", "S", ":" }
local RIDGE_GLYPHS = { "@", "8", "%" }
local MARK_GLYPHS = { "#", "%", "@" }
local EDGE_HEAVY = { ":", ";" }
local EDGE_LIGHT = { ".", "'", ",", "`" }
local EMBER_GLYPHS = { "*", "•", "+", "·" }
local MIST_GLYPHS = { "░", "▒", "~", "·" }

local FLAG_BODY = 1
local FLAG_EDGE = 2
local FLAG_FIN = 3
local FLAG_RIDGE = 4
local FLAG_EYE = 5
local FLAG_MARK = 6

local ns = vim.api.nvim_create_namespace("ascii_sharks")

local function int_to_rgb(c, fallback)
  if not c or c < 0 then
    return fallback[1], fallback[2], fallback[3]
  end
  return band(rshift(c, 16), 0xff), band(rshift(c, 8), 0xff), band(c, 0xff)
end

local function rgb_to_hex(r, g, b)
  return string.format("#%02x%02x%02x", clamp(math.floor(r), 0, 255), clamp(math.floor(g), 0, 255), clamp(math.floor(b), 0, 255))
end

local function mix_rgb(c1, c2, t)
  return {
    c1[1] + (c2[1] - c1[1]) * t,
    c1[2] + (c2[2] - c1[2]) * t,
    c1[3] + (c2[3] - c1[3]) * t,
  }
end

local function get_hl_rgb(name, attr, fallback)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok and hl and hl[attr] then
    return { int_to_rgb(hl[attr], fallback) }
  end
  return fallback
end

local function setup_highlights()
  -- Pull colors directly from the active Neovim colorscheme (e.g. Gruvbox)
  local bg_rgb = get_hl_rgb("Normal", "bg", { 29, 32, 33 })
  local fg_rgb = get_hl_rgb("Normal", "fg", { 235, 219, 178 })
  local comment_rgb = get_hl_rgb("Comment", "fg", { 146, 131, 116 })
  local special_rgb = get_hl_rgb("Special", "fg", { 254, 128, 25 })
  local func_rgb = get_hl_rgb("Function", "fg", { 184, 187, 38 })
  local const_rgb = get_hl_rgb("Constant", "fg", { 211, 134, 155 })
  local type_rgb = get_hl_rgb("Type", "fg", { 250, 189, 47 })
  local str_rgb = get_hl_rgb("String", "fg", { 184, 187, 38 })
  local diag_info = get_hl_rgb("DiagnosticInfo", "fg", { 131, 165, 152 })
  local diag_warn = get_hl_rgb("DiagnosticWarn", "fg", { 250, 189, 47 })
  local diag_err = get_hl_rgb("DiagnosticError", "fg", { 251, 73, 52 })
  local card_bg_rgb = mix_rgb(bg_rgb, fg_rgb, 0.06)

  local bg_hex = rgb_to_hex(bg_rgb[1], bg_rgb[2], bg_rgb[3])
  local fg_hex = rgb_to_hex(fg_rgb[1], fg_rgb[2], fg_rgb[3])
  local card_bg_hex = rgb_to_hex(card_bg_rgb[1], card_bg_rgb[2], card_bg_rgb[3])

  vim.api.nvim_set_hl(0, "SharkBg", { bg = bg_hex, fg = rgb_to_hex( unpack(mix_rgb(bg_rgb, comment_rgb, 0.25)) ) })
  vim.api.nvim_set_hl(0, "SharkWakeDim", { bg = bg_hex, fg = rgb_to_hex( unpack(mix_rgb(bg_rgb, diag_info, 0.45)) ) })
  vim.api.nvim_set_hl(0, "SharkWakeBright", { bg = bg_hex, fg = rgb_to_hex( unpack(diag_info) ), bold = true })

  vim.api.nvim_set_hl(0, "SharkMistDim", { bg = bg_hex, fg = rgb_to_hex( unpack(mix_rgb(bg_rgb, comment_rgb, 0.32)) ) })
  vim.api.nvim_set_hl(0, "SharkMistBright", { bg = bg_hex, fg = rgb_to_hex( unpack(mix_rgb(bg_rgb, comment_rgb, 0.58)) ) })
  vim.api.nvim_set_hl(0, "SharkEmberDim", { bg = bg_hex, fg = rgb_to_hex( unpack(mix_rgb(bg_rgb, diag_err, 0.65)) ) })
  vim.api.nvim_set_hl(0, "SharkEmberMid", { bg = bg_hex, fg = rgb_to_hex( unpack(special_rgb) ), bold = true })
  vim.api.nvim_set_hl(0, "SharkEmberBright", { bg = bg_hex, fg = rgb_to_hex( unpack(type_rgb) ), bold = true })

  vim.api.nvim_set_hl(0, "SharkFishDim", { bg = bg_hex, fg = rgb_to_hex( unpack(mix_rgb(bg_rgb, comment_rgb, 0.65)) ) })
  vim.api.nvim_set_hl(0, "SharkFishMid", { bg = bg_hex, fg = rgb_to_hex( unpack(comment_rgb) ) })
  vim.api.nvim_set_hl(0, "SharkFishBright", { bg = bg_hex, fg = fg_hex, bold = true })

  vim.api.nvim_set_hl(0, "SharkEdgeDim", { bg = bg_hex, fg = rgb_to_hex( unpack(mix_rgb(bg_rgb, comment_rgb, 0.55)) ) })
  vim.api.nvim_set_hl(0, "SharkEdgeBright", { bg = bg_hex, fg = rgb_to_hex( unpack(mix_rgb(comment_rgb, fg_rgb, 0.35)) ) })

  -- Separate skin palettes for Sharks (slate, warm) vs Dragons (dragon_gold, dragon_jade, dragon_crimson)
  local tints = {
    slate = mix_rgb(fg_rgb, diag_info, 0.35),
    warm = mix_rgb(fg_rgb, type_rgb, 0.35),
    dragon_gold = mix_rgb(fg_rgb, special_rgb, 0.65),
    dragon_jade = mix_rgb(fg_rgb, str_rgb, 0.65),
    dragon_crimson = mix_rgb(fg_rgb, diag_err, 0.65),
  }
  for name, target_rgb in pairs(tints) do
    for lvl = 1, 8 do
      local t = 0.14 + ((lvl - 1) / 7) * 0.64
      local cell_bg = mix_rgb(bg_rgb, target_rgb, t)
      local cell_fg = lvl > 4 and bg_rgb or mix_rgb(bg_rgb, fg_rgb, 0.12)
      vim.api.nvim_set_hl(0, "SharkSkin_" .. name .. "_" .. lvl, {
        bg = rgb_to_hex(cell_bg[1], cell_bg[2], cell_bg[3]),
        fg = rgb_to_hex(cell_fg[1], cell_fg[2], cell_fg[3]),
        bold = true,
      })
    end
  end

  -- Original Shark-specific ridge, eye, and marking colors
  local shark_ridge_bg = mix_rgb(bg_rgb, fg_rgb, 0.85)
  local shark_mark_bg = mix_rgb(bg_rgb, comment_rgb, 0.22)
  local shark_mark_fg = mix_rgb(bg_rgb, fg_rgb, 0.65)
  vim.api.nvim_set_hl(0, "SharkRidge", { bg = rgb_to_hex( unpack(shark_ridge_bg) ), fg = bg_hex, bold = true })
  vim.api.nvim_set_hl(0, "SharkEye", { bg = bg_hex, fg = fg_hex, bold = true })
  vim.api.nvim_set_hl(0, "SharkMark", { bg = rgb_to_hex( unpack(shark_mark_bg) ), fg = rgb_to_hex( unpack(shark_mark_fg) ), bold = true })

  -- Dedicated Dragon-specific ridge (horns/claws/crest), fiery eye, and shimmering scale lattice colors
  local dragon_ridge_bg = mix_rgb(bg_rgb, type_rgb, 0.85)
  local dragon_mark_bg = mix_rgb(bg_rgb, special_rgb, 0.32)
  local dragon_mark_fg = mix_rgb(bg_rgb, type_rgb, 0.82)
  vim.api.nvim_set_hl(0, "DragonRidge", { bg = rgb_to_hex( unpack(dragon_ridge_bg) ), fg = bg_hex, bold = true })
  vim.api.nvim_set_hl(0, "DragonEye", { bg = rgb_to_hex( unpack(diag_err) ), fg = fg_hex, bold = true })
  vim.api.nvim_set_hl(0, "DragonMark", { bg = rgb_to_hex( unpack(dragon_mark_bg) ), fg = rgb_to_hex( unpack(dragon_mark_fg) ), bold = true })

  local theme_accents = {
    special_rgb,
    diag_err,
    const_rgb,
    diag_info,
    func_rgb,
    str_rgb,
    diag_warn,
    fg_rgb,
  }
  local mid_skin_bg = rgb_to_hex( unpack(mix_rgb(bg_rgb, fg_rgb, 0.32)) )
  for i, col_rgb in ipairs(theme_accents) do
    vim.api.nvim_set_hl(0, "SharkAccent_" .. i, {
      bg = mid_skin_bg,
      fg = rgb_to_hex(col_rgb[1], col_rgb[2], col_rgb[3]),
      bold = true,
    })
  end

  -- Meteorite Shower / Bolide Fireball Storm highlights
  vim.api.nvim_set_hl(0, "MeteorStarDim", { bg = bg_hex, fg = rgb_to_hex(unpack(mix_rgb(bg_rgb, comment_rgb, 0.35))) })
  vim.api.nvim_set_hl(0, "MeteorStarMid", { bg = bg_hex, fg = rgb_to_hex(unpack(mix_rgb(bg_rgb, fg_rgb, 0.55))) })
  vim.api.nvim_set_hl(0, "MeteorStarBright", { bg = bg_hex, fg = fg_hex, bold = true })

  local meteor_palettes = {
    inferno = {
      core = fg_rgb,
      hot = type_rgb,
      fire = special_rgb,
      ember = diag_err,
      ion = diag_info,
    },
    cobalt = {
      core = fg_rgb,
      hot = diag_info,
      fire = const_rgb,
      ember = type_rgb,
      ion = str_rgb,
    },
    emerald = {
      core = fg_rgb,
      hot = func_rgb,
      fire = str_rgb,
      ember = diag_info,
      ion = type_rgb,
    },
  }
  for mname, mpal in pairs(meteor_palettes) do
    vim.api.nvim_set_hl(0, "MeteorCoreHot_" .. mname, {
      bg = rgb_to_hex(unpack(mpal.core)),
      fg = bg_hex,
      bold = true,
    })
    vim.api.nvim_set_hl(0, "MeteorCrustBright_" .. mname, {
      bg = rgb_to_hex(unpack(mix_rgb(bg_rgb, mpal.hot, 0.82))),
      fg = bg_hex,
      bold = true,
    })
    vim.api.nvim_set_hl(0, "MeteorCrustMid_" .. mname, {
      bg = rgb_to_hex(unpack(mix_rgb(bg_rgb, mpal.fire, 0.52))),
      fg = rgb_to_hex(unpack(mpal.hot)),
      bold = true,
    })
    vim.api.nvim_set_hl(0, "MeteorRockDark_" .. mname, {
      bg = rgb_to_hex(unpack(mix_rgb(bg_rgb, comment_rgb, 0.30))),
      fg = rgb_to_hex(unpack(mix_rgb(comment_rgb, mpal.fire, 0.45))),
      bold = true,
    })
    vim.api.nvim_set_hl(0, "MeteorShock_" .. mname, {
      bg = bg_hex,
      fg = rgb_to_hex(unpack(mpal.core)),
      bold = true,
    })
    vim.api.nvim_set_hl(0, "MeteorTrailHot_" .. mname, {
      bg = bg_hex,
      fg = rgb_to_hex(unpack(mpal.hot)),
      bold = true,
    })
    vim.api.nvim_set_hl(0, "MeteorTrailFire_" .. mname, {
      bg = bg_hex,
      fg = rgb_to_hex(unpack(mpal.fire)),
      bold = true,
    })
    vim.api.nvim_set_hl(0, "MeteorTrailEmber_" .. mname, {
      bg = bg_hex,
      fg = rgb_to_hex(unpack( mix_rgb(bg_rgb, mpal.ember, 0.72) )),
    })
    vim.api.nvim_set_hl(0, "MeteorSmoke_" .. mname, {
      bg = bg_hex,
      fg = rgb_to_hex(unpack( mix_rgb(bg_rgb, comment_rgb, 0.42) )),
    })
    vim.api.nvim_set_hl(0, "MeteorIon_" .. mname, {
      bg = bg_hex,
      fg = rgb_to_hex(unpack(mpal.ion)),
      bold = true,
    })
    vim.api.nvim_set_hl(0, "MeteorIonDim_" .. mname, {
      bg = bg_hex,
      fg = rgb_to_hex(unpack(mix_rgb(bg_rgb, mpal.ion, 0.52))),
    })
  end

  vim.api.nvim_set_hl(0, "SharkHeader", { bg = bg_hex, fg = rgb_to_hex( unpack(type_rgb) ), bold = true })
  vim.api.nvim_set_hl(0, "SharkDate", { bg = bg_hex, fg = rgb_to_hex( unpack(diag_info) ), bold = true })
  vim.api.nvim_set_hl(0, "SharkKey", { bg = card_bg_hex, fg = rgb_to_hex( unpack(special_rgb) ), bold = true })
  vim.api.nvim_set_hl(0, "SharkSubtitle", { bg = card_bg_hex, fg = rgb_to_hex( unpack(func_rgb) ) })
  vim.api.nvim_set_hl(0, "SharkDesc", { bg = card_bg_hex, fg = fg_hex })
  vim.api.nvim_set_hl(0, "SharkBoxBorder", { bg = card_bg_hex, fg = rgb_to_hex( unpack(mix_rgb(bg_rgb, comment_rgb, 0.7)) ) })
  vim.api.nvim_set_hl(0, "SharkFooter", { bg = bg_hex, fg = rgb_to_hex( unpack(const_rgb) ), italic = true })
end

-- Single very long dragon in Dragon mode (with 3 color/style variants on `s`),
-- classic shark school in Sharks mode, and 3 Meteorite Shower presets in Meteor mode.
local DRAGON_NODES = 56

local SCENE_PRESETS = {
  meteor = {
    {
      name = "Perseid Fireball Storm",
      palette = "inferno",
      -- Originating from above-left, streaking diagonally down-right (\)
      dir_x = 0.78,
      dir_y = 0.62,
      max_meteors = 16,
      spawn_rate = 0.22,
      bolide_chance = 0.26,
    },
    {
      name = "Cobalt Ion Shower",
      palette = "cobalt",
      -- Originating from above-left at a steeper angle
      dir_x = 0.70,
      dir_y = 0.71,
      max_meteors = 20,
      spawn_rate = 0.17,
      bolide_chance = 0.22,
    },
    {
      name = "Emerald Chondrite Rain",
      palette = "emerald",
      -- Coming from above, slanting toward the bottom-left (/)
      dir_x = -0.74,
      dir_y = 0.67,
      max_meteors = 17,
      spawn_rate = 0.20,
      bolide_chance = 0.28,
    },
  },
  dragon = {
    {
      { kind = "dragon", size = 1.0, tint = "dragon_gold" },
    },
    {
      { kind = "leviathan", size = 1.0, tint = "dragon_jade" },
    },
    {
      { kind = "dragon", size = 1.0, tint = "dragon_crimson" },
    },
  },
  sharks = {
    {
      { kind = "greathammer", size = 1.0 },
      { kind = "zebra", size = 0.78 },
      { kind = "hammerhead", size = 0.86 },
      { kind = "classic", size = 0.74 },
    },
    {
      { kind = "classic", size = 1.0 },
      { kind = "tiger", size = 0.88 },
      { kind = "greathammer", size = 0.82 },
      { kind = "zebra", size = 0.72 },
    },
  },
}

local step_sim

local function spawn_meteor(sim, met, prewarm)
  local W, H = sim.W, sim.H
  local preset = met.preset
  local base_angle = math.atan2(preset.dir_y, preset.dir_x) + rand(-0.08, 0.08)
  local dx = math.cos(base_angle)
  local dy = math.sin(base_angle)

  -- Choose meteoroid class:
  -- 1 = fast shooting-star streak, 2 = medium burning fireball, 3 = massive tumbling bolide
  local roll = math.random()
  local mkind
  local radius, speed, max_hist
  if roll < preset.bolide_chance then
    mkind = "bolide"
    radius = rand(18, 26)
    speed = rand(210, 290)
    max_hist = 28
  elseif roll < 0.68 then
    mkind = "fireball"
    radius = rand(10, 15)
    speed = rand(300, 420)
    max_hist = 22
  else
    mkind = "streak"
    radius = 5
    speed = rand(460, 640)
    max_hist = 16
  end

  local x, y
  if prewarm then
    x = rand(-W * 0.15, W * 0.95)
    y = rand(-H * 0.15, H * 0.85)
  else
    -- Spawn along the top sky or upper-left (or upper-right if dir_x < 0) so the entire screen is covered
    if dx >= 0 then
      if math.random() < 0.62 then
        x = rand(-W * 0.25, W * 0.75)
        y = rand(-45, -10)
      else
        x = rand(-45, -10)
        y = rand(-20, H * 0.65)
      end
    else
      if math.random() < 0.62 then
        x = rand(W * 0.25, W * 1.25)
        y = rand(-45, -10)
      else
        x = rand(W + 10, W + 45)
        y = rand(-20, H * 0.65)
      end
    end
  end

  table.insert(met.meteors, {
    id = math.random(1, 100000),
    kind = mkind,
    x = x,
    y = y,
    vx = dx * speed,
    vy = dy * speed,
    speed = speed,
    radius = radius,
    rot = rand(0, TAU),
    rot_speed = rand(-3.8, 3.8),
    seed = rand(0, 100),
    fragmented = false,
    burst_y = H * rand(0.32, 0.72),
    can_fragment = (mkind == "bolide" and math.random() < 0.55),
    history = { { x = x, y = y } },
    max_hist = max_hist,
  })
end

local function step_meteor(sim, dt)
  local met = sim.meteor
  if not met then return end
  local W, H = sim.W, sim.H
  local preset = met.preset

  -- 1. Spawn new meteorites continuously
  met.spawn_timer = met.spawn_timer - dt
  if met.spawn_timer <= 0 and #met.meteors < preset.max_meteors then
    met.spawn_timer = preset.spawn_rate * rand(0.6, 1.35)
    spawn_meteor(sim, met, false)
  end

  -- 2. Advance active meteorites, record plasma trails, shed ablation sparks, and trigger airbursts
  for i = #met.meteors, 1, -1 do
    local m = met.meteors[i]
    m.x = m.x + m.vx * dt
    m.y = m.y + m.vy * dt
    m.rot = m.rot + m.rot_speed * dt

    table.insert(m.history, 1, { x = m.x, y = m.y })
    while #m.history > m.max_hist do
      table.remove(m.history)
    end

    -- Shed glowing ablation sparks & smoky wake particles from fireballs and bolides
    if m.kind ~= "streak" and #met.sparks < 160 and math.random() < (m.kind == "bolide" and 0.85 or 0.50) then
      local perp_x = -m.vy / m.speed
      local perp_y = m.vx / m.speed
      local side = (math.random() < 0.5 and 1 or -1) * rand(15, 55)
      table.insert(met.sparks, {
        x = m.x - (m.vx / m.speed) * (m.radius * 0.6) + perp_x * rand(-m.radius * 0.5, m.radius * 0.5),
        y = m.y - (m.vy / m.speed) * (m.radius * 0.6) + perp_y * rand(-m.radius * 0.5, m.radius * 0.5),
        vx = m.vx * 0.25 + perp_x * side,
        vy = m.vy * 0.25 + perp_y * side,
        life = 1.0,
        decay = rand(1.1, 2.2),
        glyph = (math.random() < 0.45) and "*" or "•",
      })
    end

    -- Atmospheric Airburst Fragmentation for massive bolides!
    if m.can_fragment and not m.fragmented and m.y >= m.burst_y and m.x > W * 0.12 and m.x < W * 0.88 then
      m.fragmented = true
      m.radius = m.radius * 0.68
      -- Expanding airburst flash ring
      table.insert(met.bursts, {
        x = m.x,
        y = m.y,
        r = 8,
        max_r = rand(48, 76),
        alpha = 1.0,
      })
      -- Burst of glowing sparks
      for _ = 1, 14 do
        local ang = rand(0, TAU)
        local spd = rand(30, 110)
        table.insert(met.sparks, {
          x = m.x,
          y = m.y,
          vx = m.vx * 0.35 + math.cos(ang) * spd,
          vy = m.vy * 0.35 + math.sin(ang) * spd,
          life = 1.0,
          decay = rand(1.2, 2.4),
          glyph = "*",
        })
      end
      -- Split off 2 smaller burning fireball fragments
      local base_ang = math.atan2(m.vy, m.vx)
      for f = -1, 1, 2 do
        local fang = base_ang + f * rand(0.14, 0.26)
        local fspd = m.speed * rand(0.95, 1.18)
        table.insert(met.meteors, {
          id = math.random(1, 100000),
          kind = "fireball",
          x = m.x,
          y = m.y,
          vx = math.cos(fang) * fspd,
          vy = math.sin(fang) * fspd,
          speed = fspd,
          radius = rand(9, 13),
          rot = rand(0, TAU),
          rot_speed = rand(-4, 4),
          seed = rand(0, 100),
          fragmented = true,
          burst_y = H * 2,
          can_fragment = false,
          history = { { x = m.x, y = m.y } },
          max_hist = 18,
        })
      end
    end

    -- Despawn once completely past the bottom/side of the screen
    if m.y > H + 180 or m.x > W + 220 or m.x < -220 then
      table.remove(met.meteors, i)
    end
  end

  -- 3. Step drifting ablation sparks & smoke embers
  for i = #met.sparks, 1, -1 do
    local sp = met.sparks[i]
    sp.vx = sp.vx * 0.94
    sp.vy = sp.vy * 0.94 + 12 * dt
    sp.x = sp.x + sp.vx * dt
    sp.y = sp.y + sp.vy * dt
    sp.life = sp.life - sp.decay * dt
    if sp.life <= 0 then
      table.remove(met.sparks, i)
    end
  end

  -- 4. Step airburst shockwave rings
  for i = #met.bursts, 1, -1 do
    local b = met.bursts[i]
    b.r = b.r + 145 * dt
    b.alpha = 1.0 - (b.r / b.max_r)
    if b.r >= b.max_r or b.alpha <= 0.05 then
      table.remove(met.bursts, i)
    end
  end
end

local function create_sim(cols, rows, preset_idx, scene_mode)
  scene_mode = scene_mode or "meteor"
  if scene_mode == "solar" or scene_mode == "synapse" then scene_mode = "meteor" end
  local cw, ch = 10, 15
  local W = cols * cw
  local H = rows * ch
  local minSide = math.min(W, H)

  if scene_mode == "meteor" then
    local presets = SCENE_PRESETS.meteor
    local preset = presets[((preset_idx - 1) % #presets) + 1]

    -- Deep-space twinkling starfield
    local stars = {}
    local star_count = clamp(math.floor((cols * rows) / 28), 65, 160)
    local star_glyphs = { "·", ".", "·", "+", "✦" }
    for i = 1, star_count do
      table.insert(stars, {
        u = math.random(),
        v = math.random(),
        glyph = star_glyphs[(i % #star_glyphs) + 1],
        phase = rand(0, TAU),
        speed = rand(1.2, 3.8),
        bright = (i % 7 == 0),
      })
    end

    local sim = {
      scene = "meteor",
      cols = cols,
      rows = rows,
      cw = cw,
      ch = ch,
      W = W,
      H = H,
      time = 0,
      sharks = {},
      fish = {},
      wake = {},
      meteor = {
        preset = preset,
        stars = stars,
        meteors = {},
        sparks = {},
        bursts = {},
        spawn_timer = 0.05,
      },
    }

    -- Pre-populate and advance 35 steps so meteorites and burning trails are already streaking across the sky on Frame 1
    for _ = 1, 8 do
      spawn_meteor(sim, sim.meteor, true)
    end
    for _ = 1, 35 do
      step_sim(sim, 0.045)
    end
    return sim
  end

  local is_dragon = (scene_mode == "dragon")
  local baseLength = is_dragon and clamp(minSide * 1.65, 680, 1150) or clamp(minSide * 0.46, 160, 380)
  local mode_presets = SCENE_PRESETS[scene_mode] or SCENE_PRESETS.dragon
  local specs = mode_presets[((preset_idx - 1) % #mode_presets) + 1]

  local sharks = {}
  for i, spec in ipairs(specs) do
    local num_nodes = is_dragon and DRAGON_NODES or SHARK_NODES
    local length = baseLength * spec.size
    local orbitRadius = minSide * (is_dragon and 0.36 or rand(0.28, 0.40))
    local a = ((i - 1) / #specs) * TAU + rand(-0.2, 0.2)
    local orbitDir = (i % 2 == 1) and 1 or -1
    local x = W / 2 + math.cos(a) * orbitRadius * (W / math.max(1, minSide)) * 0.85
    local y = H / 2 + math.sin(a) * orbitRadius
    local heading = a + (orbitDir * math.pi) / 2
    local nodes = {}
    local seg = length / (num_nodes - 1)
    for n = 0, num_nodes - 1 do
      nodes[n * 2 + 1] = x - math.cos(heading) * seg * n
      nodes[n * 2 + 2] = y - math.sin(heading) * seg * n
    end
    table.insert(sharks, {
      id = i,
      kind = spec.kind,
      tint = spec.tint,
      num_nodes = num_nodes,
      length = length,
      nodes = nodes,
      history = is_dragon and { { x = x, y = y } } or nil,
      heading = heading,
      speed = is_dragon and 82 or 34,
      phase = rand(0, TAU),
      turn = 0,
      wander = 0,
      orbitDir = orbitDir,
      orbitRadius = orbitRadius,
      depth = spec.size,
    })
  end
  table.sort(sharks, function(a, b) return a.length < b.length end)

  local fish = {}
  local num_particles = clamp(math.floor((cols * rows) / (is_dragon and 28 or 38)), 50, 140)
  for i = 1, num_particles do
    if is_dragon then
      -- Mix of drifting mist clouds (kind=1) and rising glowing embers (kind=2)
      local pkind = (i % 3 == 0) and 2 or 1
      table.insert(fish, {
        x = rand(0, W),
        y = rand(0, H),
        vx = pkind == 1 and rand(8, 20) or rand(-12, 12),
        vy = pkind == 1 and rand(-2, 2) or rand(-28, -12),
        alarm = rand(0, 1),
        depth = rand(0.4, 1.0),
        pkind = pkind,
      })
    else
      local dir = (math.random() < 0.5 and 0 or math.pi) + rand(-0.4, 0.4)
      local spd = rand(28, 46)
      table.insert(fish, {
        x = rand(W * 0.08, W * 0.92),
        y = rand(H * 0.08, H * 0.92),
        vx = math.cos(dir) * spd,
        vy = math.sin(dir) * spd,
        alarm = 0,
        depth = rand(0.55, 1.0),
        pkind = 0,
      })
    end
  end

  local sim = {
    scene = scene_mode,
    cols = cols,
    rows = rows,
    cw = cw,
    ch = ch,
    W = W,
    H = H,
    time = 0,
    sharks = sharks,
    fish = fish,
    wake = {},
  }

  -- Pre-advance dragon simulation so its 56-node body starts already coiled
  -- along the exact multi-curve historical trajectory of its head.
  if is_dragon then
    for _ = 1, 180 do
      step_sim(sim, 0.05)
    end
  end

  return sim
end

step_sim = function(sim, dt)
  sim.time = sim.time + dt
  if sim.scene == "meteor" then
    step_meteor(sim, dt)
    return
  end
  local W, H = sim.W, sim.H
  local minSide = math.min(W, H)
  local cxW, cyW = W / 2, H / 2
  local is_dragon = (sim.scene == "dragon")

  -- Decay wake / trailing embers
  for k, v in pairs(sim.wake) do
    local nv = v * (is_dragon and 0.91 or 0.88)
    if nv < 0.08 then
      sim.wake[k] = nil
    else
      sim.wake[k] = nv
    end
  end

  -- Step background particles (mist + embers in dragon mode, boid fish in sharks mode)
  for _, f in ipairs(sim.fish) do
    if is_dragon then
      if f.pkind == 2 then
        -- Rising fire embers swirling in the dragon's draft
        f.vx = f.vx + math.sin(sim.time * 2.5 + f.y * 0.03) * 18 * dt
        f.x = (f.x + f.vx * dt) % W
        f.y = (f.y + f.vy * dt) % H
        f.alarm = 0.5 + 0.5 * math.sin(sim.time * 7 + f.x * 0.1)
      else
        -- Drifting mist wisps
        f.x = (f.x + f.vx * dt) % W
        f.y = (f.y + math.sin(sim.time * 0.6 + f.x * 0.01) * 3 * dt) % H
      end
    else
      local ax, ay = 0, 0
      local fear = 0
      for _, sh in ipairs(sim.sharks) do
        local nx, ny = sh.nodes[1], sh.nodes[2]
        local dx = f.x - nx
        local dy = f.y - ny
        local d = math.sqrt(dx * dx + dy * dy)
        local fearR = sh.length * 0.55 + 50
        if d < fearR and d > 1e-3 then
          local w = (1 - d / fearR) ^ 2
          ax = ax + (dx / d) * 950 * w
          ay = ay + (dy / d) * 950 * w
          fear = math.max(fear, w)
        end
      end
      f.alarm = math.max(f.alarm * 0.94, fear)
      local m = 36
      if f.x < m then ax = ax + (m - f.x) * 6 elseif f.x > W - m then ax = ax - (f.x - (W - m)) * 6 end
      if f.y < m then ay = ay + (m - f.y) * 6 elseif f.y > H - m then ay = ay - (f.y - (H - m)) * 6 end
      ay = ay - f.vy * 0.8 * (1 - 0.6 * f.alarm)
      f.vx = f.vx + (ax + rand(-25, 25)) * dt
      f.vy = f.vy + (ay + rand(-20, 20)) * dt
      local spd = math.sqrt(f.vx * f.vx + f.vy * f.vy)
      local maxSpd = 42 * (1 + 1.5 * f.alarm)
      if spd > maxSpd then
        f.vx = f.vx * (maxSpd / spd)
        f.vy = f.vy * (maxSpd / spd)
      elseif spd < 20 and spd > 1e-3 then
        f.vx = f.vx * (20 / spd)
        f.vy = f.vy * (20 / spd)
      end
      f.x = (f.x + f.vx * dt) % W
      f.y = clamp(f.y + f.vy * dt, 10, H - 10)
    end
  end

  -- Step creatures (dragon or sharks)
  for _, sh in ipairs(sim.sharks) do
    local L = sh.length
    local num_nodes = sh.num_nodes or SHARK_NODES
    local nodes = sh.nodes
    local hx, hy = nodes[1], nodes[2]

    if is_dragon then
      -- Serpentine dragon steering:
      -- The head steers along sweeping alternating S-curves around the screen,
      -- and the entire 56-node body strictly traces the exact historical path of the head!
      local rx = (hx - cxW) / math.max(1, W / minSide)
      local ry = hy - cyW
      local r = math.sqrt(rx * rx + ry * ry)
      if r < 1 then r = 1 end
      local radius = sh.orbitRadius * (1 + 0.18 * math.sin(sim.time * 0.25))
      local radial = clamp((radius - r) / radius, -1, 1)

      -- Base orbital tangent + radial pull
      local ox = (-ry / r) * sh.orbitDir + (rx / r) * radial * 0.90
      local oy = (rx / r) * sh.orbitDir + (ry / r) * radial * 0.90
      local orbit_angle = math.atan2(oy, ox)

      -- Add continuous alternating S-curve weaving to the head's trajectory
      -- so the path itself contains deep curves in alternating directions
      local weave = 0.88 * math.sin(sim.time * 1.35) + 0.42 * math.cos(sim.time * 0.55)
      local target_angle = orbit_angle + weave
      local dx = math.cos(target_angle)
      local dy = math.sin(target_angle)

      -- Keep center menu box clear
      local ex = (hx - cxW) / (W * 0.23)
      local ey = (hy - cyW) / (H * 0.20)
      local e2 = ex * ex + ey * ey
      if e2 < 1 and e2 > 1e-5 then
        local e = math.sqrt(e2)
        local w = (1 - e) * 2.6
        dx = dx + (ex / e) * w
        dy = dy + (ey / e) * w
      end

      -- Soft screen boundary return
      local marginX = W * 0.08
      local marginY = H * 0.08
      local over = math.max(marginX - hx, hx - (W - marginX), marginY - hy, hy - (H - marginY))
      if over > 0 then
        local w = clamp(over / (minSide * 0.22), 0, 1) * 3.5
        local toX = cxW - hx
        local toY = cyW - hy
        local d = math.sqrt(toX * toX + toY * toY)
        if d > 1e-3 then
          dx = dx + (toX / d) * w
          dy = dy + (toY / d) * w
        end
      end

      local desired = math.atan2(dy, dx)
      local maxTurn = 2.4 * dt
      local turned = clamp(angleDiff(sh.heading, desired), -maxTurn, maxTurn)
      sh.heading = sh.heading + turned
      sh.turn = sh.turn + (turned / dt - sh.turn) * math.min(1, dt * 4)

      local cruise = 84 + L * 0.015
      sh.speed = sh.speed + (cruise - sh.speed) * math.min(1, dt * 2.0)
      sh.phase = sh.phase + dt * 2.0

      hx = hx + math.cos(sh.heading) * sh.speed * dt
      hy = hy + math.sin(sh.heading) * sh.speed * dt
      nodes[1] = hx
      nodes[2] = hy

      -- Prepend new head position to breadcrumb history and place every spine node
      -- at exact arc-length intervals along the head's historical path!
      local hist = sh.history
      table.insert(hist, 1, { x = hx, y = hy })

      local seg = L / (num_nodes - 1)
      local h_idx = 1
      local acc_dist = 0
      for k = 1, num_nodes - 1 do
        local target_dist = k * seg
        while h_idx < #hist do
          local p1 = hist[h_idx]
          local p2 = hist[h_idx + 1]
          local sdx = p2.x - p1.x
          local sdy = p2.y - p1.y
          local d = math.sqrt(sdx * sdx + sdy * sdy)
          if acc_dist + d >= target_dist then
            local t = (d > 1e-5) and ((target_dist - acc_dist) / d) or 0
            nodes[k * 2 + 1] = p1.x + sdx * t
            nodes[k * 2 + 2] = p1.y + sdy * t
            break
          else
            acc_dist = acc_dist + d
            h_idx = h_idx + 1
          end
        end
        if h_idx >= #hist then
          local last = hist[#hist]
          nodes[k * 2 + 1] = last.x
          nodes[k * 2 + 2] = last.y
        end
      end

      -- Trim history tail beyond the dragon's body length
      for trim = #hist, h_idx + 4, -1 do
        hist[trim] = nil
      end
    else
      -- Original Shark physics
      local dx = math.cos(sh.heading)
      local dy = math.sin(sh.heading)

      sh.wander = clamp(sh.wander + (math.random() - 0.5) * dt * 3.0, -1.2, 1.2)
      dx = dx + math.cos(sh.heading + sh.wander) * 0.45
      dy = dy + math.sin(sh.heading + sh.wander) * 0.45

      local rx = (hx - cxW) / math.max(1, W / minSide)
      local ry = hy - cyW
      local r = math.sqrt(rx * rx + ry * ry)
      if r < 1 then r = 1 end
      local radius = sh.orbitRadius * (1 + 0.15 * math.sin(sim.time * 0.22 + sh.id))
      local radial = clamp((radius - r) / radius, -1, 1)
      dx = dx + ((-ry / r) * sh.orbitDir + (rx / r) * radial * 0.95) * 0.72
      dy = dy + ((rx / r) * sh.orbitDir + (ry / r) * radial * 0.95) * 0.72

      -- Keep center menu box clear
      local ex = (hx - cxW) / (W * 0.24)
      local ey = (hy - cyW) / (H * 0.20)
      local e2 = ex * ex + ey * ey
      if e2 < 1 and e2 > 1e-5 then
        local e = math.sqrt(e2)
        local w = (1 - e) * 2.4
        dx = dx + (ex / e) * w
        dy = dy + (ey / e) * w
      end

      -- Soft screen boundary return
      local over = math.max(-hx, hx - W, -hy, hy - H)
      if over > -L * 0.05 then
        local w = clamp((over + L * 0.05) / (L * 0.35), 0, 1) * 3.8
        local toX = cxW - hx
        local toY = cyW - hy
        local d = math.sqrt(toX * toX + toY * toY)
        if d > 1e-3 then
          dx = dx + (toX / d) * w
          dy = dy + (toY / d) * w
        end
      end

      -- Separation between sharks
      for _, other in ipairs(sim.sharks) do
        if other ~= sh then
          local ox = hx - other.nodes[1]
          local oy = hy - other.nodes[2]
          local d = math.sqrt(ox * ox + oy * oy)
          local range = (L + other.length) * 0.35
          if d < range and d > 1e-3 then
            local w = (1 - d / range) * 2.2
            dx = dx + (ox / d) * w
            dy = dy + (oy / d) * w
          end
        end
      end

      local desired = math.atan2(dy, dx)
      local maxTurn = 1.15 * dt
      local turned = clamp(angleDiff(sh.heading, desired), -maxTurn, maxTurn)
      sh.heading = sh.heading + turned
      sh.turn = sh.turn + (turned / dt - sh.turn) * math.min(1, dt * 3)

      local cruise = 34 + L * 0.045
      sh.speed = sh.speed + (cruise - sh.speed) * math.min(1, dt * 1.5)
      sh.phase = sh.phase + dt * (2.2 + sh.speed / 20)

      nodes[1] = nodes[1] + math.cos(sh.heading) * sh.speed * dt
      nodes[2] = nodes[2] + math.sin(sh.heading) * sh.speed * dt

      local seg = L / (num_nodes - 1)
      local maxBend = 0.16
      local prevAngle = sh.heading + math.pi
      for k = 1, num_nodes - 1 do
        local px = nodes[(k - 1) * 2 + 1]
        local py = nodes[(k - 1) * 2 + 2]
        local angle = math.atan2(nodes[k * 2 + 2] - py, nodes[k * 2 + 1] - px)
        angle = prevAngle + clamp(angleDiff(prevAngle, angle), -maxBend, maxBend)
        nodes[k * 2 + 1] = px + math.cos(angle) * seg
        nodes[k * 2 + 2] = py + math.sin(angle) * seg
        prevAngle = angle
      end
    end

    -- Deposit wake / trailing dragon embers
    for k = num_nodes - 5, num_nodes - 1 do
      local wc = math.floor(nodes[k * 2 + 1] / sim.cw)
      local wr = math.floor(nodes[k * 2 + 2] / sim.ch)
      if wc >= 0 and wc < sim.cols and wr >= 0 and wr < sim.rows then
        local idx = wr * sim.cols + wc
        sim.wake[idx] = math.min(1.0, (sim.wake[idx] or 0) + 0.55)
      end
    end
  end
end

local function sample_shark(px, py, L, spine, arc, arcTotal, shape, finTipLeft, finTipRight, sharkId, sim_time, num_nodes)
  num_nodes = num_nodes or SHARK_NODES
  local best = 1e12
  local bestS = 0
  local bestSign = 1
  local bestNx = 0
  local bestNy = 0

  for k = 0, num_nodes - 2 do
    local ax = spine[k * 2 + 1]
    local ay = spine[k * 2 + 2]
    local sx = spine[(k + 1) * 2 + 1] - ax
    local sy = spine[(k + 1) * 2 + 2] - ay
    local len2 = sx * sx + sy * sy
    if len2 < 1e-6 then len2 = 1 end
    local u = clamp(((px - ax) * sx + (py - ay) * sy) / len2, 0, 1)
    local qx = ax + sx * u
    local qy = ay + sy * u
    local dx = px - qx
    local dy = py - qy
    local d2 = dx * dx + dy * dy
    if d2 < best then
      best = d2
      local len = math.sqrt(len2)
      bestS = (arc[k + 1] + u * len) / arcTotal
      bestSign = (sx * (py - ay) - sy * (px - ax) >= 0) and 1 or -1
      bestNx = (-sy / len) * bestSign
      bestNy = (sx / len) * bestSign
    end
  end

  local a = Math_sqrt and Math_sqrt(best) or math.sqrt(best)
  local s = bestS
  local u = s * L
  local w = shape.halfWidth(s) * L

  -- Dragon-specific anatomy: flowing whiskers, swept-back horns, and 4 clawed limbs
  if shape.is_dragon then
    -- 1. Flowing dragon whiskers streaming backward from the snout
    if s >= 0.006 and s <= 0.075 and a > w and a <= L * 0.072 then
      local rel_a = (a - w) / (L * 0.058)
      local whisker_s = 0.011 + 0.042 * (rel_a ^ 1.3) + 0.005 * math.sin((sim_time or 0) * 4.0 + rel_a * 4.5)
      if math.abs(s - whisker_s) < 0.0045 then
        return true, FLAG_RIDGE, 1.0, s, a * bestSign, a
      end
    end

    -- 2. Swept-back branching dragon horns / antlers from behind the brow
    if s >= 0.025 and s <= 0.085 and a > w * 0.75 and a <= L * 0.058 then
      local horn_t = (s - 0.025) / 0.058
      local horn_a = w * 0.8 + horn_t * (L * 0.044)
      local branch_a = w * 0.8 + horn_t * (L * 0.026)
      if math.abs(a - horn_a) < L * 0.0052 or (horn_t > 0.45 and math.abs(a - branch_a) < L * 0.0042) then
        return true, FLAG_RIDGE, 0.95, s, a * bestSign, a
      end
    end
  end

  local head = shape.head
  if head and u < L * (head.sweep + head.depth + head.notch) then
    local span = L * head.span
    local r = a / span
    local front = L * head.sweep * r * r + L * head.notch * math.max(0, 1 - r / 0.14)
    local depth = L * head.depth * (1 - 0.2 * (r ^ 4))
    if r <= 1 and u >= front and u <= front + depth then
      local flag = r > 0.84 and FLAG_EYE or FLAG_BODY
      local shade = r > 0.84 and 0 or (0.62 - 0.2 * r + (u < front + L * 0.012 and 0.1 or 0))
      return true, flag, shade, s, a * bestSign, a
    end
  end

  if a <= w then
    local across = a / math.max(1e-3, w)
    local facing = (bestNx * -0.6 + bestNy * -0.8) * across
    local shade = 0.58 - across * across * 0.42 + facing * 0.26
    local flag = FLAG_BODY
    if shape.is_dragon then
      -- Serrated flame dorsal crest along the dragon's spine
      local spike = math.sin(s * 180)
      if s > 0.035 and s < 0.96 and across < (0.24 + 0.12 * math.max(0, spike)) then
        flag = FLAG_RIDGE
        shade = 1
      elseif shape.eye and s > shape.eye[1] and s < shape.eye[2] and across > 0.52 then
        flag = FLAG_EYE
        shade = 0
      elseif s > 0.04 and s < 0.89 then
        -- Overlapping dragon scale lattice
        local scale_pat = math.sin(s * 220) * math.cos((a * bestSign / L) * 210)
        if scale_pat > 0.52 then
          flag = FLAG_MARK
          shade = math.min(1, shade + 0.22)
        end
      end
    elseif s > shape.dorsal[1] and s < shape.dorsal[2] and across < 0.3 then
      flag = FLAG_RIDGE
      shade = 1
    elseif s > shape.secondDorsal[1] and s < shape.secondDorsal[2] and across < 0.4 then
      shade = math.max(shade, 0.82)
    elseif shape.eye and s > shape.eye[1] and s < shape.eye[2] and across > 0.6 then
      flag = FLAG_EYE
      shade = 0
    elseif s > shape.gills[1] and s < shape.gills[2] and across > 0.58 then
      if math.floor(((s - shape.gills[1]) / (shape.gills[2] - shape.gills[1])) * 5) % 2 == 0 then
        shade = shade * 0.45
      end
    elseif s < 0.05 then
      shade = math.max(shade, 0.7)
    elseif shape == SHAPES.zebra and s > 0.07 then
      local gu = (s * L) / (L * 0.06)
      local gv = (a * bestSign) / (L * 0.045)
      local cu, cv = math.floor(gu), math.floor(gv)
      local jx = hash3(cu, cv, sharkId) * 0.5 + 0.25
      local jy = hash3(cu, cv, sharkId + 11) * 0.5 + 0.25
      if (gu - cu - jx) ^ 2 + (gv - cv - jy) ^ 2 < 0.08 then
        flag = FLAG_MARK
      end
    end
    return true, flag, shade, s, a * bestSign, a
  end

  local tip = bestSign > 0 and finTipRight or finTipLeft
  local p0, p1, p2 = shape.pectoral[1], shape.pectoral[2], shape.pectoral[3]
  if inTriangle(u, a, L * p0, 0, L * p1, 0, L * p2, tip)
    and not (shape.falcate and inTriangle(u, a, L * p1, 0, L * (p1 + (p2 - p1) * 0.33), tip * 0.55, L * p2, tip))
  then
    -- If dragon, add bright claw tips at the outer edge of the front limbs
    local is_claw = shape.is_dragon and (a > tip * 0.74)
    return true, is_claw and FLAG_RIDGE or FLAG_FIN, 0.38 + 0.22 * (1 - clamp(a / math.max(1, tip), 0, 1)), s, a * bestSign, a
  end

  local v0, v1, v2, vr = shape.pelvic[1], shape.pelvic[2], shape.pelvic[3], shape.pelvic[4]
  if inTriangle(u, a, L * v0, 0, L * v1, 0, L * v2, L * vr)
    or (shape.caudal > 0 and inTriangle(u, a, L * v0, 0, L * 0.95, 0, L, L * shape.caudal))
  then
    local is_claw = shape.is_dragon and (a > L * vr * 0.74)
    return true, is_claw and FLAG_RIDGE or FLAG_FIN, 0.36, s, a * bestSign, a
  end

  return false, 0, 0, s, a * bestSign, a
end

local WEEK_HEADERS = {
  Sunday = {
    "███████╗██╗   ██╗███╗   ██╗██████╗  █████╗ ██╗   ██╗",
    "██╔════╝██║   ██║████╗  ██║██╔══██╗██╔══██╗╚██╗ ██╔╝",
    "███████╗██║   ██║██╔██╗ ██║██║  ██║███████║ ╚████╔╝ ",
    "╚════██║██║   ██║██║╚██╗██║██║  ██║██╔══██║  ╚██╔╝  ",
    "███████║╚██████╔╝██║ ╚████║██████╔╝██║  ██║   ██║   ",
    "╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝   ╚═╝   ",
  },
  Monday = {
    "███╗   ███╗ ██████╗ ███╗   ██╗██████╗  █████╗ ██╗   ██╗",
    "████╗ ████║██╔═══██╗████╗  ██║██╔══██╗██╔══██╗╚██╗ ██╔╝",
    "██╔████╔██║██║   ██║██╔██╗ ██║██║  ██║███████║ ╚████╔╝ ",
    "██║╚██╔╝██║██║   ██║██║╚██╗██║██║  ██║██╔══██║  ╚██╔╝  ",
    "██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██████╔╝██║  ██║   ██║   ",
    "╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝   ╚═╝   ",
  },
  Tuesday = {
    "████████╗██╗   ██╗███████╗███████╗██████╗  █████╗ ██╗   ██╗",
    "╚══██╔══╝██║   ██║██╔════╝██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝",
    "   ██║   ██║   ██║█████╗  ███████╗██║  ██║███████║ ╚████╔╝ ",
    "   ██║   ██║   ██║██╔══╝  ╚════██║██║  ██║██╔══██║  ╚██╔╝  ",
    "   ██║   ╚██████╔╝███████╗███████║██████╔╝██║  ██║   ██║   ",
    "   ╚═╝    ╚═════╝ ╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═╝   ╚═╝   ",
  },
  Wednesday = {
    "██╗    ██╗███████╗██████╗ ███╗   ██╗███████╗███████╗██████╗  █████╗ ██╗   ██╗",
    "██║    ██║██╔════╝██╔══██╗████╗  ██║██╔════╝██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝",
    "██║ █╗ ██║█████╗  ██║  ██║██╔██╗ ██║█████╗  ███████╗██║  ██║███████║ ╚████╔╝ ",
    "██║███╗██║██╔══╝  ██║  ██║██║╚██╗██║██╔══╝  ╚════██║██║  ██║██╔══██║  ╚██╔╝  ",
    "╚███╔███╔╝███████╗██████╔╝██║ ╚████║███████╗███████║██████╔╝██║  ██║   ██║   ",
    " ╚══╝╚══╝ ╚══════╝╚═════╝ ╚═╝  ╚═══╝╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═╝   ╚═╝   ",
  },
  Thursday = {
    "████████╗██╗  ██╗██╗   ██╗██████╗ ███████╗██████╗  █████╗ ██╗   ██╗",
    "╚══██╔══╝██║  ██║██║   ██║██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝",
    "   ██║   ███████║██║   ██║██████╔╝███████╗██║  ██║███████║ ╚████╔╝ ",
    "   ██║   ██╔══██║██║   ██║██╔══██╗╚════██║██║  ██║██╔══██║  ╚██╔╝  ",
    "   ██║   ██║  ██║╚██████╔╝██║  ██║███████║██████╔╝██║  ██║   ██║   ",
    "   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═════╝ ╚═╝  ╚═╝   ╚═╝   ",
  },
  Friday = {
    "███████╗██████╗ ██╗██████╗  █████╗ ██╗   ██╗",
    "██╔════╝██╔══██╗██║██╔══██╗██╔══██╗╚██╗ ██╔╝",
    "█████╗  ██████╔╝██║██║  ██║███████║ ╚████╔╝ ",
    "██╔══╝  ██╔══██╗██║██║  ██║██╔══██║  ╚██╔╝  ",
    "██║     ██║  ██║██║██████╔╝██║  ██║   ██║   ",
    "╚═╝     ╚═╝  ╚═╝╚═╝╚═════╝ ╚═╝  ╚═╝   ╚═╝   ",
  },
  Saturday = {
    "███████╗ █████╗ ████████╗██╗   ██╗██████╗ ██████╗  █████╗ ██╗   ██╗",
    "██╔════╝██╔══██╗╚══██╔══╝██║   ██║██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝",
    "███████╗███████║   ██║   ██║   ██║██████╔╝██║  ██║███████║ ╚████╔╝ ",
    "╚════██║██╔══██║   ██║   ██║   ██║██╔══██╗██║  ██║██╔══██║  ╚██╔╝  ",
    "███████║██║  ██║   ██║   ╚██████╔╝██║  ██║██████╔╝██║  ██║   ██║   ",
    "╚══════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝   ╚═╝   ",
  },
}

local DAYS_OF_WEEK = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

local MENU_ITEMS = {
  { key = "f", icon = "󰈞 ", desc = "Find Files", cmd = "Telescope find_files" },
  { key = "g", icon = "󰱼 ", desc = "Live Grep", cmd = "Telescope live_grep" },
  { key = "r", icon = "󰋚 ", desc = "Recent Files", cmd = "Telescope oldfiles" },
  { key = "e", icon = "󰈔 ", desc = "New File", cmd = "enew" },
  { key = "a", icon = "🐉 ", desc = "Switch Animation", cmd = "SWITCH_SCENE" },
  { key = "s", icon = "󰈺 ", desc = "Switch Variant", cmd = "SHARK_PRESET" },
  { key = "l", icon = "󰒲 ", desc = "Lazy Plugins", cmd = "Lazy" },
  { key = "q", icon = "󰅚 ", desc = "Quit Neovim", cmd = "qa" },
}

local SCENE_CYCLE = {
  meteor = "dragon",
  dragon = "sharks",
  sharks = "meteor",
}

local function render_meteor(sim, grid_char, grid_hl)
  local met = sim.meteor
  if not met then return end
  local cols, rows, cw, ch = sim.cols, sim.rows, sim.cw, sim.ch
  local pal = met.preset.palette

  local hl_core_hot = "MeteorCoreHot_" .. pal
  local hl_crust_bright = "MeteorCrustBright_" .. pal
  local hl_crust_mid = "MeteorCrustMid_" .. pal
  local hl_rock_dark = "MeteorRockDark_" .. pal
  local hl_shock = "MeteorShock_" .. pal
  local hl_trail_hot = "MeteorTrailHot_" .. pal
  local hl_trail_fire = "MeteorTrailFire_" .. pal
  local hl_trail_ember = "MeteorTrailEmber_" .. pal
  local hl_smoke = "MeteorSmoke_" .. pal
  local hl_ion = "MeteorIon_" .. pal
  local hl_ion_dim = "MeteorIonDim_" .. pal

  local function put(c, r, glyph, hl)
    if c >= 0 and c < cols and r >= 0 and r < rows then
      local idx = r * cols + c
      grid_char[idx] = glyph
      grid_hl[idx] = hl
    end
  end

  -- 1. Deep-Space Twinkling Starfield
  for _, st in ipairs(met.stars) do
    local tw = math.sin(sim.time * st.speed + st.phase)
    if tw > -0.45 then
      local c = math.floor(st.u * cols)
      local r = math.floor(st.v * rows)
      local hl = (st.bright and tw > 0.45) and "MeteorStarBright" or (tw > 0.15 and "MeteorStarMid" or "MeteorStarDim")
      put(c, r, st.glyph, hl)
    end
  end

  -- Sort meteors back-to-front by radius so large foreground bolides draw over background streaks
  local order = {}
  for i = 1, #met.meteors do
    order[i] = met.meteors[i]
  end
  table.sort(order, function(a, b) return a.radius < b.radius end)

  -- 2. Render Multi-Stage Ion, Plasma, Fire, and Atmospheric Smoke Trails
  for _, m in ipairs(order) do
    local hist = m.history
    local n_hist = #hist
    local spd = math.max(1, math.sqrt(m.vx * m.vx + m.vy * m.vy))
    local ux, uy = m.vx / spd, m.vy / spd
    -- Perpendicular vector for wide turbulent bolide wakes
    local px, py = -uy, ux
    local diag_glyph = (ux * uy >= 0) and "\\" or "/"

    if m.kind == "streak" then
      -- Upper-atmosphere shooting star: razor-sharp diagonal ionized streak + glowing head
      for h = n_hist - 1, 1, -1 do
        local p1 = hist[h]
        local p2 = hist[h + 1]
        local frac = h / math.max(1, n_hist - 1)
        local sub = 3
        for s = 0, sub - 1 do
          local t = s / sub
          local sx = p1.x + (p2.x - p1.x) * t
          local sy = p1.y + (p2.y - p1.y) * t
          local g = frac < 0.35 and diag_glyph or (frac < 0.70 and ":" or "·")
          local hl = frac < 0.45 and hl_ion or hl_ion_dim
          put(math.floor(sx / cw), math.floor(sy / ch), g, hl)
        end
      end
      local hc = math.floor(m.x / cw)
      local hr = math.floor(m.y / ch)
      put(hc, hr, "✦", hl_core_hot)
    else
      -- Fireball or Bolide: wide multi-stage plasma/fire/ember/smoke wake
      local is_bolide = (m.kind == "bolide")
      local base_w = is_bolide and (m.radius * 0.72) or (m.radius * 0.58)

      for h = n_hist - 1, 1, -1 do
        local p1 = hist[h]
        local p2 = hist[h + 1]
        local frac = (h - 1) / math.max(1, n_hist - 1)
        local sub = 3
        for s = sub - 1, 0, -1 do
          local t = s / sub
          local f = clamp(frac + (t / math.max(1, n_hist - 1)), 0, 1)
          local cx = p1.x + (p2.x - p1.x) * t
          local cy = p1.y + (p2.y - p1.y) * t
          -- Turbulent billowing width that narrows near the head, swells in mid-wake, and tapers in smoke
          local taper = (1.0 - f * 0.65)
          local half_w = base_w * taper
          local w_steps = math.max(1, math.floor(half_w / 3.2))

          for wi = -w_steps, w_steps do
            local w_frac = math.abs(wi) / math.max(1, w_steps)
            local turb = math.sin(h * 1.4 + wi * 2.1 - sim.time * 9.0) * (3.5 * f)
            local wx = cx + px * (wi * 3.2 + turb)
            local wy = cy + py * (wi * 3.2 + turb)
            local heat = (1.0 - f) * (1.0 - w_frac * 0.55)

            local glyph, hl
            if heat > 0.74 then
              glyph = heat > 0.86 and "#" or "*"
              hl = hl_trail_hot
            elseif heat > 0.48 then
              glyph = heat > 0.60 and "*" or "•"
              hl = hl_trail_fire
            elseif heat > 0.24 then
              glyph = heat > 0.35 and "•" or ":"
              hl = hl_trail_ember
            else
              glyph = (h + wi) % 2 == 0 and ":" or "·"
              hl = hl_smoke
            end
            put(math.floor(wx / cw), math.floor(wy / ch), glyph, hl)
          end
        end
      end
    end
  end

  -- 3. Drifting Ablation Sparks & Mid-Air Bolide Fragmentation Airbursts
  for _, sp in ipairs(met.sparks) do
    local c = math.floor(sp.x / cw)
    local r = math.floor(sp.y / ch)
    local glyph = sp.life > 0.65 and "*" or (sp.life > 0.35 and "•" or "·")
    local hl = sp.life > 0.70 and hl_trail_hot or (sp.life > 0.38 and hl_trail_fire or hl_trail_ember)
    put(c, r, glyph, hl)
  end

  for _, b in ipairs(met.bursts) do
    local ring_pts = 28
    local b_hl = b.alpha > 0.55 and hl_shock or (b.alpha > 0.30 and hl_trail_fire or hl_trail_ember)
    local b_glyph = b.alpha > 0.60 and "*" or (b.alpha > 0.30 and ":" or "·")
    for k = 0, ring_pts - 1 do
      local a = (k / ring_pts) * TAU
      local rx = b.x + math.cos(a) * b.r
      local ry = b.y + math.sin(a) * b.r * 0.88
      put(math.floor(rx / cw), math.floor(ry / ch), b_glyph, b_hl)
    end
  end

  -- 4. Multi-Cell Tumbling Craggy Meteorite & Bolide Heads + Atmospheric Bow-Shock
  for _, m in ipairs(order) do
    if m.kind ~= "streak" then
      local rad = m.radius
      local reach = rad * 1.55 + 8
      local c0 = math.max(0, math.floor((m.x - reach) / cw))
      local c1 = math.min(cols - 1, math.floor((m.x + reach) / cw))
      local r0 = math.max(0, math.floor((m.y - reach) / ch))
      local r1 = math.min(rows - 1, math.floor((m.y + reach) / ch))

      local spd = math.max(1, math.sqrt(m.vx * m.vx + m.vy * m.vy))
      local ux, uy = m.vx / spd, m.vy / spd

      for r = r0, r1 do
        for c = c0, c1 do
          local px = (c + 0.5) * cw
          local py = (r + 0.5) * ch
          local dx = px - m.x
          local dy = (py - m.y) * 0.96
          local d = math.sqrt(dx * dx + dy * dy)

          -- Irregular craggy asteroid silhouette rotating by m.rot
          local ang = math.atan2(dy, dx)
          local local_ang = ang - m.rot
          local crag = 1.0
            + 0.16 * math.sin(local_ang * 3 + m.seed)
            + 0.12 * math.cos(local_ang * 5 - m.seed * 1.7)
            + 0.07 * math.sin(local_ang * 7 + m.seed * 0.6)
          local eff_r = rad * crag
          local r_norm = d / math.max(1, eff_r)

          -- Windward directional alignment (dot product with velocity vector)
          local wind_dot = (dx * ux + dy * uy) / math.max(1, d)

          if r_norm <= 1.0 then
            -- Inside the tumbling craggy meteorite body:
            -- Windward leading edge & inner core are superheated; leeward backside shows dark chondrite crust
            local crater = math.sin((dx * math.cos(m.rot) - dy * math.sin(m.rot)) * 0.28 + m.seed)
              * math.cos((dx * math.sin(m.rot) + dy * math.cos(m.rot)) * 0.28 - m.seed)
            local ram_heat = (1.0 - r_norm * 0.55) + wind_dot * 0.48 + crater * 0.18

            if ram_heat > 0.88 or (wind_dot > 0.45 and r_norm > 0.62) then
              put(c, r, ram_heat > 1.05 and "@" or "#", hl_core_hot)
            elseif ram_heat > 0.54 then
              put(c, r, ram_heat > 0.70 and "#" or "8", hl_crust_bright)
            elseif ram_heat > 0.22 then
              put(c, r, crater > 0.1 and "%" or "*", hl_crust_mid)
            else
              put(c, r, crater > 0 and "=" or ":", hl_rock_dark)
            end
          elseif r_norm <= 1.38 and wind_dot > 0.38 then
            -- Glowing parabolic Atmospheric Ram-Pressure Bow-Shock ahead of the meteorite
            local shock_glyph = wind_dot > 0.72 and ((ux * uy >= 0) and "/" or "\\") or ":"
            put(c, r, shock_glyph, hl_shock)
          end
        end
      end
    end
  end
end

local function render_frame(buf, sim)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local cols, rows, cw, ch = sim.cols, sim.rows, sim.cw, sim.ch
  local is_dragon = (sim.scene == "dragon")
  local is_meteor = (sim.scene == "meteor")
  local grid_char = {}
  local grid_hl = {}

  if is_meteor then
    render_meteor(sim, grid_char, grid_hl)
  else
    -- 1. Wake dots / Trailing Dragon Embers
    for idx, w in pairs(sim.wake) do
      if is_dragon then
        grid_char[idx] = w > 0.65 and "*" or (w > 0.35 and "•" or "·")
        grid_hl[idx] = w > 0.65 and "SharkEmberBright" or (w > 0.35 and "SharkEmberMid" or "SharkEmberDim")
      else
        grid_char[idx] = "·"
        grid_hl[idx] = w > 0.45 and "SharkWakeBright" or "SharkWakeDim"
      end
    end

    -- 2. Background Particles (Mist Clouds & Embers in Dragon mode, Fish schools in Sharks mode)
    for _, f in ipairs(sim.fish) do
      local c = math.floor(f.x / cw)
      local r = math.floor(f.y / ch)
      if c >= 0 and c < cols and r >= 0 and r < rows then
        local idx = r * cols + c
        if is_dragon then
          if f.pkind == 2 then
            -- Rising glowing fire ember
            local e_idx = clamp(math.floor(f.alarm * #EMBER_GLYPHS) + 1, 1, #EMBER_GLYPHS)
            grid_char[idx] = EMBER_GLYPHS[e_idx]
            grid_hl[idx] = f.alarm > 0.7 and "SharkEmberBright" or (f.alarm > 0.4 and "SharkEmberMid" or "SharkEmberDim")
          else
            -- Drifting mist cloud wisp (3-cell horizontal wisp)
            local m_hl = f.depth > 0.72 and "SharkMistBright" or "SharkMistDim"
            grid_char[idx] = MIST_GLYPHS[3]
            grid_hl[idx] = m_hl
            if c + 1 < cols then
              grid_char[idx + 1] = "~"
              grid_hl[idx + 1] = "SharkMistDim"
            end
          end
        else
          grid_char[idx] = "-"
          grid_hl[idx] = f.alarm > 0.35 and "SharkFishBright" or (f.depth > 0.78 and "SharkFishMid" or "SharkFishDim")
        end
      end
    end

    -- 3. Creatures (Dragon or Sharks)
    local spine = {}
    local arc = {}
    for _, sh in ipairs(sim.sharks) do
      local L = sh.length
      local num_nodes = sh.num_nodes or SHARK_NODES
      local n = sh.nodes
      local swim = clamp(sh.speed / 60, 0.4, 1.4)
      local shape = SHAPES[sh.kind]
      local skin_tint = sh.tint or shape.tint

      for k = 0, num_nodes - 1 do
        if shape.is_dragon then
          -- No lateral fish wiggling! The dragon's spine strictly follows the head's past trajectory.
          spine[k * 2 + 1] = n[k * 2 + 1]
          spine[k * 2 + 2] = n[k * 2 + 2]
        else
          local s = k / (num_nodes - 1)
          local a = math.max(0, k - 1)
          local b = math.min(num_nodes - 1, k + 1)
          local tx = n[a * 2 + 1] - n[b * 2 + 1]
          local ty = n[a * 2 + 2] - n[b * 2 + 2]
          local tl = math.sqrt(tx * tx + ty * ty)
          if tl < 1e-6 then tl = 1 end
          tx, ty = tx / tl, ty / tl
          local off = L * 0.05 * (0.1 + 0.9 * (s ^ 1.8)) * swim * math.sin(sh.phase - s * 5.2)
          spine[k * 2 + 1] = n[k * 2 + 1] - ty * off
          spine[k * 2 + 2] = n[k * 2 + 2] + tx * off
        end
      end

      arc[1] = 0
      for k = 1, num_nodes - 1 do
        local dx = spine[k * 2 + 1] - spine[(k - 1) * 2 + 1]
        local dy = spine[k * 2 + 2] - spine[(k - 1) * 2 + 2]
        arc[k + 1] = arc[k] + math.sqrt(dx * dx + dy * dy)
      end
      local arcTotal = math.max(1, arc[num_nodes])

      local bank = clamp(sh.turn * 0.45, -0.35, 0.35)
      local flex = 1 + 0.06 * math.sin(sh.phase * 0.5)
      local reachFin = shape.pectoral[4]
      local finTipRight = L * reachFin * flex * (1 - bank)
      local finTipLeft = L * reachFin * flex * (1 + bank)

      local minX, minY, maxX, maxY = 1e9, 1e9, -1e9, -1e9
      for k = 0, num_nodes - 1 do
        local sx, sy = spine[k * 2 + 1], spine[k * 2 + 2]
        if sx < minX then minX = sx end
        if sx > maxX then maxX = sx end
        if sy < minY then minY = sy end
        if sy > maxY then maxY = sy end
      end

      local reach = shape.is_dragon and (L * 0.14) or (L * 0.36)
      local c0 = math.max(0, math.floor((minX - reach) / cw))
      local c1 = math.min(cols - 1, math.floor((maxX + reach) / cw))
      local r0 = math.max(0, math.floor((minY - reach) / ch))
      local r1 = math.min(rows - 1, math.floor((maxY + reach) / ch))
      local skipBeyond = reach + 18

      for r = r0, r1 do
        for c = c0, c1 do
          local x = c * cw + cw * 0.5
          local y = r * ch + ch * 0.5
          local hit, flag, shade, s, v, dist =
            sample_shark(x, y, L, spine, arc, arcTotal, shape, finTipLeft, finTipRight, sh.id, sim.time, num_nodes)
          if not hit and dist <= skipBeyond then
            -- Sub-cell edge check for soft silhouette
            local edge_hits = 0
            if sample_shark(c * cw + cw * 0.25, r * ch + ch * 0.3, L, spine, arc, arcTotal, shape, finTipLeft, finTipRight, sh.id, sim.time, num_nodes) then
              edge_hits = edge_hits + 1
            end
            if sample_shark(c * cw + cw * 0.75, r * ch + ch * 0.7, L, spine, arc, arcTotal, shape, finTipLeft, finTipRight, sh.id, sim.time, num_nodes) then
              edge_hits = edge_hits + 1
            end
            if edge_hits > 0 then
              local idx = r * cols + c
              local key = math.floor(hash3(math.floor(s * 52), math.floor(v / (cw * 0.9)), sh.id) * 10000)
              local set = edge_hits == 2 and EDGE_HEAVY or EDGE_LIGHT
              grid_char[idx] = set[(key % #set) + 1]
              grid_hl[idx] = edge_hits == 2 and "SharkEdgeBright" or "SharkEdgeDim"
            end
          elseif hit then
            local idx = r * cols + c
            local key = math.floor(hash3(math.floor(s * 52), math.floor(v / (cw * 0.9)), sh.id) * 100000)
            local tick = math.floor(sim.time * 2.4 + (key % 97) / 19)
            local roll = hash3(key, tick, 7)

            local glyph
            local hl
            if flag == FLAG_RIDGE then
              glyph = RIDGE_GLYPHS[(key % #RIDGE_GLYPHS) + 1]
              hl = shape.is_dragon and "DragonRidge" or "SharkRidge"
            elseif flag == FLAG_EYE then
              glyph = shape.is_dragon and "@" or "o"
              hl = shape.is_dragon and "DragonEye" or "SharkEye"
            elseif flag == FLAG_MARK then
              glyph = MARK_GLYPHS[(key % #MARK_GLYPHS) + 1]
              hl = shape.is_dragon and "DragonMark" or "SharkMark"
            elseif flag == FLAG_FIN then
              glyph = FIN_GLYPHS[(key % #FIN_GLYPHS) + 1]
              local lvl = clamp(math.floor((0.25 + shade * 0.65) * 8) + 1, 1, 8)
              hl = "SharkSkin_" .. skin_tint .. "_" .. lvl
            else
              local ramp_idx = clamp(math.floor((1 - shade) * (#SKIN_RAMP - 0.01)) + 1, 1, #SKIN_RAMP)
              glyph = SKIN_RAMP[ramp_idx]
              if roll < (shape.is_dragon and 0.12 or 0.085) then
                hl = "SharkAccent_" .. ((key % 8) + 1)
              else
                local lvl = clamp(math.floor(clamp(shade, 0, 1) * 7.99) + 1, 1, 8)
                hl = "SharkSkin_" .. skin_tint .. "_" .. lvl
              end
            end
            grid_char[idx] = glyph
            grid_hl[idx] = hl
          end
        end
      end
    end
  end

  -- Build lines & highlight spans
  local lines = {}
  local row_spans = {}
  local center_r = math.floor(rows / 2)
  local box_w = 36
  local box_left = math.max(0, math.floor((cols - box_w) / 2))

  for r = 0, rows - 1 do
    local chars = {}
    local spans = {}
    local run_hl = nil
    local run_start_byte = 0
    local byte_pos = 0

    for c = 0, cols - 1 do
      local idx = r * cols + c
      local ch_str = grid_char[idx] or " "
      local hl = grid_hl[idx]

      chars[c + 1] = ch_str
      local ch_len = #ch_str
      if hl ~= run_hl then
        if run_hl then
          table.insert(spans, { run_hl, run_start_byte, byte_pos })
        end
        run_hl = hl
        run_start_byte = byte_pos
      end
      byte_pos = byte_pos + ch_len
    end
    if run_hl then
      table.insert(spans, { run_hl, run_start_byte, byte_pos })
    end

    lines[r + 1] = table.concat(chars)
    row_spans[r + 1] = spans
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for r = 1, rows do
    for _, sp in ipairs(row_spans[r]) do
      pcall(vim.api.nvim_buf_add_highlight, buf, ns, sp[1], r - 1, sp[2], sp[3])
    end
  end

  -- Overlay the dashboard week_header (ASCII day of the week + live date/time) & shortcut box
  local day_name = DAYS_OF_WEEK[os.date("*t").wday] or "Monday"
  local header_lines = WEEK_HEADERS[day_name]
  local total_ui_height = #header_lines + 2 + #MENU_ITEMS + 4
  local start_row = math.max(1, center_r - math.floor(total_ui_height / 2))

  if cols > box_w + 4 and rows > total_ui_height then
    local cur_row = start_row

    -- 1. ASCII Day-of-the-Week Banner
    for _, hline in ipairs(header_lines) do
      local hwidth = vim.fn.strdisplaywidth(hline)
      local hcol = math.max(0, math.floor((cols - hwidth) / 2))
      if cur_row < rows then
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, cur_row, 0, {
          virt_text = { { hline, "SharkHeader" } },
          virt_text_win_col = hcol,
          priority = 200,
        })
      end
      cur_row = cur_row + 1
    end

    -- 2. Live Date & Time line (just like dashboard-nvim week_header)
    local date_str = "  " .. os.date("%Y-%m-%d    %H:%M:%S")
    local date_col = math.max(0, math.floor((cols - vim.fn.strdisplaywidth(date_str)) / 2))
    if cur_row < rows then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, cur_row, 0, {
        virt_text = { { date_str, "SharkDate" } },
        virt_text_win_col = date_col,
        priority = 200,
      })
    end
    cur_row = cur_row + 2

    -- 3. Shortcuts Card
    local inner_w = 30
    local hbar = string.rep("─", inner_w)
    local overlay_rows = {
      { { "  ┌" .. hbar .. "┐  ", "SharkBoxBorder" } },
    }
    for _, item in ipairs(MENU_ITEMS) do
      local key_str = "[" .. item.key .. "]"
      local icon_str = "  " .. item.icon
      local used = 2 + vim.fn.strdisplaywidth(key_str) + vim.fn.strdisplaywidth(icon_str) + vim.fn.strdisplaywidth(item.desc) + 1
      local pad = string.rep(" ", math.max(0, inner_w - used))
      table.insert(overlay_rows, {
        { "  │  ", "SharkBoxBorder" },
        { key_str, "SharkKey" },
        { icon_str, "SharkSubtitle" },
        { item.desc .. pad, "SharkDesc" },
        { " │  ", "SharkBoxBorder" },
      })
    end
    table.insert(overlay_rows, { { "  └" .. hbar .. "┘  ", "SharkBoxBorder" } })

    for _, chunks in ipairs(overlay_rows) do
      if cur_row < rows then
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, cur_row, 0, {
          virt_text = chunks,
          virt_text_win_col = box_left,
          priority = 200,
        })
      end
      cur_row = cur_row + 1
    end

    -- 4. Footer
    cur_row = cur_row + 1
    local scene_label
    if is_meteor then
      local vname = (sim.meteor and sim.meteor.preset and sim.meteor.preset.name) or "Perseid Fireball Storm"
      scene_label = "☄️ Meteorite Shower (" .. vname .. ")"
    elseif is_dragon then
      scene_label = "🐉 Dragon & Embers"
    else
      scene_label = "🦈 Sharks & Ocean"
    end
    local footer_str = "⚡ Happy coding with Neovim  •  " .. scene_label
    local footer_col = math.max(0, math.floor((cols - vim.fn.strdisplaywidth(footer_str)) / 2))
    if cur_row < rows then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, cur_row, 0, {
        virt_text = { { footer_str, "SharkFooter" } },
        virt_text_win_col = footer_col,
        priority = 200,
      })
    end
  end

  -- Flush redraw immediately even when typing in Command mode (:)
  if vim.fn.mode():match("^[cr]") and vim.api.nvim__redraw then
    pcall(vim.api.nvim__redraw, { buf = buf, valid = true })
  end
end

function M.start(initial_scene)
  setup_highlights()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "alpha"

  local win = vim.api.nvim_get_current_win()
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false
  vim.wo[win].winhl = "Normal:SharkBg,EndOfBuffer:SharkBg"

  local scene_mode = initial_scene or "meteor"
  local preset_idx = 1
  local cols = math.max(40, vim.api.nvim_win_get_width(win))
  local rows = math.max(15, vim.api.nvim_win_get_height(win))
  local sim = create_sim(cols, rows, preset_idx, scene_mode)

  local uv = vim.uv or vim.loop
  local timer = uv.new_timer()

  local function stop_timer()
    if timer then
      timer:stop()
      if not timer:is_closing() then
        timer:close()
      end
      timer = nil
    end
  end

  -- Map dashboard shortcut keys (keep animating while floating pickers like Telescope/Lazy are open)
  for _, item in ipairs(MENU_ITEMS) do
    vim.keymap.set("n", item.key, function()
      if item.cmd == "SWITCH_SCENE" then
        scene_mode = SCENE_CYCLE[scene_mode] or "meteor"
        preset_idx = 1
        sim = create_sim(sim.cols, sim.rows, preset_idx, scene_mode)
        return
      end
      if item.cmd == "SHARK_PRESET" then
        preset_idx = preset_idx + 1
        sim = create_sim(sim.cols, sim.rows, preset_idx, scene_mode)
        return
      end
      if item.cmd == "enew" or item.cmd == "qa" then
        stop_timer()
      end
      vim.cmd(item.cmd)
    end, { buffer = buf, nowait = true, silent = true, desc = item.desc })
  end

  -- Only stop when the startup buffer itself is wiped/hidden (not when moving focus to Neo-tree or floats)
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufHidden", "BufDelete" }, {
    buffer = buf,
    once = true,
    callback = stop_timer,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    buffer = buf,
    callback = function()
      setup_highlights()
    end,
  })

  render_frame(buf, sim)

  timer:start(0, 45, vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      stop_timer()
      return
    end
    local wins = vim.fn.win_findbuf(buf)
    if #wins == 0 then
      stop_timer()
      return
    end
    local cur_win = wins[1]
    local new_cols = math.max(40, vim.api.nvim_win_get_width(cur_win))
    local new_rows = math.max(15, vim.api.nvim_win_get_height(cur_win))
    if new_cols ~= sim.cols or new_rows ~= sim.rows then
      sim.cols = new_cols
      sim.rows = new_rows
      sim.W = new_cols * sim.cw
      sim.H = new_rows * sim.ch
    end
    step_sim(sim, 0.045)
    render_frame(buf, sim)
  end))
end

return M

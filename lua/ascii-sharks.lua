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
}

local SKIN_RAMP = { ":", ";", "t", "%", "S", "X", "8", "#", "@" }
local FIN_GLYPHS = { "%", ";", "t", "S", ":" }
local RIDGE_GLYPHS = { "@", "8", "%" }
local MARK_GLYPHS = { "#", "%", "@" }
local EDGE_HEAVY = { ":", ";" }
local EDGE_LIGHT = { ".", "'", ",", "`" }

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

  vim.api.nvim_set_hl(0, "SharkFishDim", { bg = bg_hex, fg = rgb_to_hex( unpack(mix_rgb(bg_rgb, comment_rgb, 0.65)) ) })
  vim.api.nvim_set_hl(0, "SharkFishMid", { bg = bg_hex, fg = rgb_to_hex( unpack(comment_rgb) ) })
  vim.api.nvim_set_hl(0, "SharkFishBright", { bg = bg_hex, fg = fg_hex, bold = true })

  vim.api.nvim_set_hl(0, "SharkEdgeDim", { bg = bg_hex, fg = rgb_to_hex( unpack(mix_rgb(bg_rgb, comment_rgb, 0.55)) ) })
  vim.api.nvim_set_hl(0, "SharkEdgeBright", { bg = bg_hex, fg = rgb_to_hex( unpack(mix_rgb(comment_rgb, fg_rgb, 0.35)) ) })

  -- 8 shading levels blended between theme background, theme accents, and theme foreground
  local slate_target = mix_rgb(fg_rgb, diag_info, 0.35)
  local warm_target = mix_rgb(fg_rgb, type_rgb, 0.35)
  local tints = {
    slate = slate_target,
    warm = warm_target,
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

  local ridge_bg = mix_rgb(bg_rgb, fg_rgb, 0.85)
  local mark_bg = mix_rgb(bg_rgb, comment_rgb, 0.22)
  local mark_fg = mix_rgb(bg_rgb, comment_rgb, 0.65)
  vim.api.nvim_set_hl(0, "SharkRidge", { bg = rgb_to_hex( unpack(ridge_bg) ), fg = bg_hex, bold = true })
  vim.api.nvim_set_hl(0, "SharkEye", { bg = bg_hex, fg = fg_hex, bold = true })
  vim.api.nvim_set_hl(0, "SharkMark", { bg = rgb_to_hex( unpack(mark_bg) ), fg = rgb_to_hex( unpack(mark_fg) ), bold = true })

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

  vim.api.nvim_set_hl(0, "SharkHeader", { bg = bg_hex, fg = rgb_to_hex( unpack(type_rgb) ), bold = true })
  vim.api.nvim_set_hl(0, "SharkDate", { bg = bg_hex, fg = rgb_to_hex( unpack(diag_info) ), bold = true })
  vim.api.nvim_set_hl(0, "SharkKey", { bg = card_bg_hex, fg = rgb_to_hex( unpack(special_rgb) ), bold = true })
  vim.api.nvim_set_hl(0, "SharkSubtitle", { bg = card_bg_hex, fg = rgb_to_hex( unpack(func_rgb) ) })
  vim.api.nvim_set_hl(0, "SharkDesc", { bg = card_bg_hex, fg = fg_hex })
  vim.api.nvim_set_hl(0, "SharkBoxBorder", { bg = card_bg_hex, fg = rgb_to_hex( unpack(mix_rgb(bg_rgb, comment_rgb, 0.7)) ) })
  vim.api.nvim_set_hl(0, "SharkFooter", { bg = bg_hex, fg = rgb_to_hex( unpack(const_rgb) ), italic = true })
end

local PRESETS = {
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
}

local function create_sim(cols, rows, preset_idx)
  local cw, ch = 10, 15
  local W = cols * cw
  local H = rows * ch
  local minSide = math.min(W, H)
  local baseLength = clamp(minSide * 0.46, 160, 380)
  local specs = PRESETS[preset_idx or 1]

  local sharks = {}
  for i, spec in ipairs(specs) do
    local length = baseLength * spec.size
    local orbitRadius = minSide * rand(0.28, 0.40)
    local a = ((i - 1) / #specs) * TAU + rand(-0.3, 0.3)
    local orbitDir = (i % 2 == 1) and 1 or -1
    local x = W / 2 + math.cos(a) * orbitRadius * (W / math.max(1, minSide)) * 0.85
    local y = H / 2 + math.sin(a) * orbitRadius
    local heading = a + (orbitDir * math.pi) / 2
    local nodes = {}
    local seg = length / (SHARK_NODES - 1)
    for n = 0, SHARK_NODES - 1 do
      nodes[n * 2 + 1] = x - math.cos(heading) * seg * n
      nodes[n * 2 + 2] = y - math.sin(heading) * seg * n
    end
    table.insert(sharks, {
      id = i,
      kind = spec.kind,
      length = length,
      nodes = nodes,
      heading = heading,
      speed = 34,
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
  local num_fish = clamp(math.floor((cols * rows) / 38), 45, 110)
  for _ = 1, num_fish do
    local dir = (math.random() < 0.5 and 0 or math.pi) + rand(-0.4, 0.4)
    local spd = rand(28, 46)
    table.insert(fish, {
      x = rand(W * 0.08, W * 0.92),
      y = rand(H * 0.08, H * 0.92),
      vx = math.cos(dir) * spd,
      vy = math.sin(dir) * spd,
      alarm = 0,
      depth = rand(0.55, 1.0),
    })
  end

  return {
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
end

local function step_sim(sim, dt)
  sim.time = sim.time + dt
  local W, H = sim.W, sim.H
  local minSide = math.min(W, H)
  local cxW, cyW = W / 2, H / 2

  -- Decay wake
  for k, v in pairs(sim.wake) do
    local nv = v * 0.88
    if nv < 0.08 then
      sim.wake[k] = nil
    else
      sim.wake[k] = nv
    end
  end

  -- Step fish
  for _, f in ipairs(sim.fish) do
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

  -- Step sharks
  for _, sh in ipairs(sim.sharks) do
    local L = sh.length
    local nodes = sh.nodes
    local hx, hy = nodes[1], nodes[2]
    local dx = math.cos(sh.heading)
    local dy = math.sin(sh.heading)

    sh.wander = clamp(sh.wander + (math.random() - 0.5) * dt * 3.0, -1.1, 1.1)
    dx = dx + math.cos(sh.heading + sh.wander) * 0.45
    dy = dy + math.sin(sh.heading + sh.wander) * 0.45

    local rx = (hx - cxW) / math.max(1, W / minSide)
    local ry = hy - cyW
    local r = math.sqrt(rx * rx + ry * ry)
    if r < 1 then r = 1 end
    local radius = sh.orbitRadius * (1 + 0.15 * math.sin(sim.time * 0.15 + sh.id))
    local radial = clamp((radius - r) / radius, -1, 1)
    dx = dx + ((-ry / r) * sh.orbitDir + (rx / r) * radial * 0.9) * 0.65
    dy = dy + ((rx / r) * sh.orbitDir + (ry / r) * radial * 0.9) * 0.65

    -- Keep center menu box mostly clear
    local ex = (hx - cxW) / (W * 0.24)
    local ey = (hy - cyW) / (H * 0.20)
    local e2 = ex * ex + ey * ey
    if e2 < 1 and e2 > 1e-5 then
      local e = math.sqrt(e2)
      local w = (1 - e) * 2.2
      dx = dx + (ex / e) * w
      dy = dy + (ey / e) * w
    end

    -- Soft screen boundary return
    local over = math.max(-hx, hx - W, -hy, hy - H)
    if over > -L * 0.05 then
      local w = clamp((over + L * 0.05) / (L * 0.35), 0, 1) * 3.5
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
        local range = (L + other.length) * 0.42
        if d < range and d > 1e-3 then
          local w = (1 - d / range) * 2.5
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
    sh.phase = sh.phase + dt * (2.2 + sh.speed / 22)

    nodes[1] = nodes[1] + math.cos(sh.heading) * sh.speed * dt
    nodes[2] = nodes[2] + math.sin(sh.heading) * sh.speed * dt

    local seg = L / (SHARK_NODES - 1)
    local maxBend = 0.16
    local prevAngle = sh.heading + math.pi
    for k = 1, SHARK_NODES - 1 do
      local px = nodes[(k - 1) * 2 + 1]
      local py = nodes[(k - 1) * 2 + 2]
      local angle = math.atan2(nodes[k * 2 + 2] - py, nodes[k * 2 + 1] - px)
      angle = prevAngle + clamp(angleDiff(prevAngle, angle), -maxBend, maxBend)
      nodes[k * 2 + 1] = px + math.cos(angle) * seg
      nodes[k * 2 + 2] = py + math.sin(angle) * seg
      prevAngle = angle
    end

    -- Deposit wake behind tail
    for k = SHARK_NODES - 4, SHARK_NODES - 1 do
      local wc = math.floor(nodes[k * 2 + 1] / sim.cw)
      local wr = math.floor(nodes[k * 2 + 2] / sim.ch)
      if wc >= 0 and wc < sim.cols and wr >= 0 and wr < sim.rows then
        local idx = wr * sim.cols + wc
        sim.wake[idx] = math.min(1.0, (sim.wake[idx] or 0) + 0.45)
      end
    end
  end
end

local function sample_shark(px, py, L, spine, arc, arcTotal, shape, finTipLeft, finTipRight, sharkId)
  local best = 1e12
  local bestS = 0
  local bestSign = 1
  local bestNx = 0
  local bestNy = 0

  for k = 0, SHARK_NODES - 2 do
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

  local a = math.sqrt(best)
  local s = bestS
  local u = s * L
  local w = shape.halfWidth(s) * L

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
    if s > shape.dorsal[1] and s < shape.dorsal[2] and across < 0.3 then
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
    return true, FLAG_FIN, 0.38 + 0.22 * (1 - clamp(a / math.max(1, tip), 0, 1)), s, a * bestSign, a
  end

  local v0, v1, v2, vr = shape.pelvic[1], shape.pelvic[2], shape.pelvic[3], shape.pelvic[4]
  if inTriangle(u, a, L * v0, 0, L * v1, 0, L * v2, L * vr)
    or (shape.caudal > 0 and inTriangle(u, a, L * 0.86, 0, L * 0.95, 0, L, L * shape.caudal))
  then
    return true, FLAG_FIN, 0.36, s, a * bestSign, a
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
  { key = "s", icon = "󰈺 ", desc = "Switch Sharks", cmd = "SHARK_PRESET" },
  { key = "l", icon = "󰒲 ", desc = "Lazy Plugins", cmd = "Lazy" },
  { key = "q", icon = "󰅚 ", desc = "Quit Neovim", cmd = "qa" },
}

local function render_frame(buf, sim)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local cols, rows, cw, ch = sim.cols, sim.rows, sim.cw, sim.ch
  local grid_char = {}
  local grid_hl = {}

  -- 1. Wake dots
  for idx, w in pairs(sim.wake) do
    grid_char[idx] = "·"
    grid_hl[idx] = w > 0.45 and "SharkWakeBright" or "SharkWakeDim"
  end

  -- 2. Fish schools
  for _, f in ipairs(sim.fish) do
    local c = math.floor(f.x / cw)
    local r = math.floor(f.y / ch)
    if c >= 0 and c < cols and r >= 0 and r < rows then
      local idx = r * cols + c
      grid_char[idx] = "-"
      grid_hl[idx] = f.alarm > 0.35 and "SharkFishBright" or (f.depth > 0.78 and "SharkFishMid" or "SharkFishDim")
    end
  end

  -- 3. Sharks
  local spine = {}
  local arc = {}
  for _, sh in ipairs(sim.sharks) do
    local L = sh.length
    local n = sh.nodes
    local swim = clamp(sh.speed / 60, 0.4, 1.4)
    local shape = SHAPES[sh.kind]

    for k = 0, SHARK_NODES - 1 do
      local s = k / (SHARK_NODES - 1)
      local a = math.max(0, k - 1)
      local b = math.min(SHARK_NODES - 1, k + 1)
      local tx = n[a * 2 + 1] - n[b * 2 + 1]
      local ty = n[a * 2 + 2] - n[b * 2 + 2]
      local tl = math.sqrt(tx * tx + ty * ty)
      if tl < 1e-6 then tl = 1 end
      tx, ty = tx / tl, ty / tl
      local amp = L * 0.05 * (0.1 + 0.9 * (s ^ 1.8)) * swim
      local off = amp * math.sin(sh.phase - s * 5.2)
      spine[k * 2 + 1] = n[k * 2 + 1] - ty * off
      spine[k * 2 + 2] = n[k * 2 + 2] + tx * off
    end

    arc[1] = 0
    for k = 1, SHARK_NODES - 1 do
      local dx = spine[k * 2 + 1] - spine[(k - 1) * 2 + 1]
      local dy = spine[k * 2 + 2] - spine[(k - 1) * 2 + 2]
      arc[k + 1] = arc[k] + math.sqrt(dx * dx + dy * dy)
    end
    local arcTotal = math.max(1, arc[SHARK_NODES])

    local bank = clamp(sh.turn * 0.45, -0.35, 0.35)
    local flex = 1 + 0.06 * math.sin(sh.phase * 0.5)
    local reachFin = shape.pectoral[4]
    local finTipRight = L * reachFin * flex * (1 - bank)
    local finTipLeft = L * reachFin * flex * (1 + bank)

    local minX, minY, maxX, maxY = 1e9, 1e9, -1e9, -1e9
    for k = 0, SHARK_NODES - 1 do
      local sx, sy = spine[k * 2 + 1], spine[k * 2 + 2]
      if sx < minX then minX = sx end
      if sx > maxX then maxX = sx end
      if sy < minY then minY = sy end
      if sy > maxY then maxY = sy end
    end

    local reach = L * 0.36
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
          sample_shark(x, y, L, spine, arc, arcTotal, shape, finTipLeft, finTipRight, sh.id)
        if not hit and dist <= skipBeyond then
          -- Sub-cell edge check for soft silhouette
          local edge_hits = 0
          if sample_shark(c * cw + cw * 0.25, r * ch + ch * 0.3, L, spine, arc, arcTotal, shape, finTipLeft, finTipRight, sh.id) then
            edge_hits = edge_hits + 1
          end
          if sample_shark(c * cw + cw * 0.75, r * ch + ch * 0.7, L, spine, arc, arcTotal, shape, finTipLeft, finTipRight, sh.id) then
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
            hl = "SharkRidge"
          elseif flag == FLAG_EYE then
            glyph = "o"
            hl = "SharkEye"
          elseif flag == FLAG_MARK then
            glyph = MARK_GLYPHS[(key % #MARK_GLYPHS) + 1]
            hl = "SharkMark"
          elseif flag == FLAG_FIN then
            glyph = FIN_GLYPHS[(key % #FIN_GLYPHS) + 1]
            local lvl = clamp(math.floor((0.25 + shade * 0.65) * 8) + 1, 1, 8)
            hl = "SharkSkin_" .. shape.tint .. "_" .. lvl
          else
            local ramp_idx = clamp(math.floor((1 - shade) * (#SKIN_RAMP - 0.01)) + 1, 1, #SKIN_RAMP)
            glyph = SKIN_RAMP[ramp_idx]
            if roll < 0.085 then
              hl = "SharkAccent_" .. ((key % 8) + 1)
            else
              local lvl = clamp(math.floor(clamp(shade, 0, 1) * 7.99) + 1, 1, 8)
              hl = "SharkSkin_" .. shape.tint .. "_" .. lvl
            end
          end
          grid_char[idx] = glyph
          grid_hl[idx] = hl
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
    local footer_str = "⚡ Happy coding with Neovim"
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

function M.start()
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

  local preset_idx = 1
  local cols = math.max(40, vim.api.nvim_win_get_width(win))
  local rows = math.max(15, vim.api.nvim_win_get_height(win))
  local sim = create_sim(cols, rows, preset_idx)

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
      if item.cmd == "SHARK_PRESET" then
        preset_idx = (preset_idx % #PRESETS) + 1
        sim = create_sim(sim.cols, sim.rows, preset_idx)
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

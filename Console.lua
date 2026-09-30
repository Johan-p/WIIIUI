-- spec 0001 §Module split "Console.lua": art frames -- left (minimap/
-- portrait art), middle (grid art, extensions), right (inventory, chat
-- area). BuildRight now covers the inventory-art pair (rightPart_middle/
-- rightPart_left), the shared background, the lid and the chat-area top/
-- middle/bottom pieces; the 6 extension filler textures are a later
-- iteration of the same slice. The extension1/2/3 overlays on the left
-- frame stay out of scope (slice 04's own deferral, unchanged).
local _, WIIIUI = ...

WIIIUI.Console = WIIIUI.Console or {}

-- Declared art (spec 0006 slice 10). Each region's art is an ordered piece
-- table; BuildArt below creates, sizes, textures and anchors every piece on
-- every Layout call. Field conventions:
--   key    parent[key] holds the texture (the Customizer's Console.<region>.<key>)
--   layer  draw layer passed to CreateTexture
--   geo    name of the region's geometry result in `geos` (Theme.*Geometry)
--   w, h   number, or a field name of geos[geo]
--   tex    {folder, file} (Theme.TexturePath) | literal path | fn(theme)
--   point, rel  anchor points on the piece and on its target
--   to     "$parent" | "UIParent" | sibling key on the same parent | fn() -> region
--   x, y   offset: number, or a field name of geos[geo]; nil is 0
-- Order is creation order and the Customizer's registry order.
local LEFT_PIECES = {
  { key = "minimapTexture", layer = "ARTWORK", geo = "minimap", w = "frameSize", h = "frameSize",
    tex = { "minimap_portrait", "minimap" }, point = "BOTTOM", to = "$parent", rel = "BOTTOM" },
  { key = "portraitTexture", layer = "BORDER", geo = "portrait", w = "size", h = "size",
    tex = { "minimap_portrait", "portrait" }, point = "BOTTOMLEFT", to = "minimapTexture", rel = "BOTTOMRIGHT",
    x = "anchorOffsetX", y = "anchorOffsetY" },
  { key = "extensionBackgroundTexture", layer = "BACKGROUND", geo = "extensionBackground", w = "width", h = "height",
    tex = "Interface\\Addons\\WIIIUI\\art\\other\\black_background", point = "BOTTOMLEFT", to = "portraitTexture",
    rel = "BOTTOMRIGHT", x = "offsetX", y = "offsetY" },
}

local function gridTile(key, layer, to, offsetField)
  return { key = key, layer = layer, geo = "grid", w = "size", h = "size", tex = { "actionbar", "actionslots_grid" },
    point = to and "BOTTOMLEFT" or "BOTTOM", to = to or "$parent", rel = to and "BOTTOMRIGHT" or "BOTTOM", x = offsetField }
end

local GRID_PIECES = {
  gridTile("tile1", "BACKGROUND"),
  gridTile("tile2", "BORDER", "tile1", "slot2OffsetX"),
  gridTile("tile3", "ARTWORK", "tile2", "slot3OffsetX"),
  gridTile("tile4", "OVERLAY", "tile3", "slot4OffsetX"),
}

local function gridTile4()
  local grid = WIIIUI.Console.grid

  return grid and grid.tile4
end

local RIGHT_PIECES = {
  { key = "rightPartMiddle", layer = "OVERLAY", geo = "rightPart", w = "middleWidth", h = "middleHeight",
    tex = { "inventory", "inventory" }, point = "BOTTOMLEFT", to = gridTile4, rel = "BOTTOMRIGHT",
    x = "middleOffsetX", y = "middleOffsetY" },
  { key = "rightPartLeft", layer = "ARTWORK", geo = "rightPart", w = "leftWidth", h = "leftHeight",
    tex = { "inventory", "no_inventory" }, point = "BOTTOMRIGHT", to = "rightPartMiddle", rel = "BOTTOMLEFT",
    x = "leftOffsetX", y = "leftOffsetY" },
  { key = "lid", layer = "BORDER", geo = "lid", w = "size", h = "size",
    tex = { "bottom right", "right_part_lid" }, point = "BOTTOMLEFT", to = "rightPartMiddle", rel = "BOTTOMLEFT",
    x = "offsetX", y = "offsetY" },
  { key = "chatTop", layer = "BORDER", geo = "chat", w = "topWidth", h = "topHeight",
    tex = { "bottom right", "BottomRight_Top" }, point = "BOTTOMLEFT", to = "UIParent", rel = "BOTTOMRIGHT",
    x = "topOffsetX", y = "topOffsetY" },
  { key = "chatMiddle", layer = "BORDER", geo = "chat", w = "middleWidth", h = "middleHeight",
    tex = { "bottom right", "BottomRight_Middle" }, point = "BOTTOMLEFT", to = "UIParent", rel = "BOTTOMRIGHT",
    x = "middleOffsetX", y = "middleOffsetY" },
  { key = "chatBottom", layer = "BORDER", geo = "chat", w = "bottomWidth", h = "bottomHeight",
    tex = { "bottom right", "BottomRight_Bottom" }, point = "BOTTOMLEFT", to = "UIParent", rel = "BOTTOMRIGHT",
    x = "bottomOffsetX", y = "bottomOffsetY" },
}

-- The 3 filler pairs: pair 1 hangs off rightPartMiddle's right edge, pairs 2
-- and 3 off the previous pair's bottom piece.
for i = 1, 3 do
  local layer = (i == 1) and "BORDER" or "ARTWORK"
  local to, rel = "rightPartMiddle", "BOTTOMRIGHT"

  if i > 1 then
    to, rel = "fillerBottom" .. (i - 1), "BOTTOMLEFT"
  end

  RIGHT_PIECES[#RIGHT_PIECES + 1] = { key = "fillerTop" .. i, layer = layer, geo = "filler", w = "topWidth", h = "topHeight",
    tex = { "bottom right", "BottomRightFillerTop" }, point = "BOTTOMLEFT", to = to, rel = rel,
    x = "top" .. i .. "OffsetX", y = "top" .. i .. "OffsetY" }
  RIGHT_PIECES[#RIGHT_PIECES + 1] = { key = "fillerBottom" .. i, layer = layer, geo = "filler", w = "bottomWidth", h = "bottomHeight",
    tex = { "bottom right", "BottomRightFillerBottom" }, point = "BOTTOMLEFT", to = to, rel = rel,
    x = "bottom" .. i .. "OffsetX", y = "bottom" .. i .. "OffsetY" }
end

WIIIUI.Console.ART = { left = LEFT_PIECES, grid = GRID_PIECES, right = RIGHT_PIECES }

local function pieceValue(field, geometry)
  if type(field) == "string" then
    return geometry[field]
  end

  return field or 0
end

local function pieceTarget(piece, parent)
  local to = piece.to

  if to == "$parent" then
    return parent
  elseif to == "UIParent" then
    return UIParent
  elseif type(to) == "function" then
    return to()
  end

  return parent[to]
end

local function pieceTexture(piece, theme)
  local tex = piece.tex

  if type(tex) == "table" then
    return WIIIUI.Theme.TexturePath(theme, tex[1], tex[2])
  elseif type(tex) == "function" then
    return tex(theme)
  end

  return tex
end

-- Get-or-create, size, texture, and anchor every piece, on every call: a piece
-- moved since the last build (a customizer revert, a stale anchor) returns to
-- its declared point.
local function BuildArt(parent, pieces, geos, theme)
  for _, piece in ipairs(pieces) do
    local geometry = geos[piece.geo]
    local texture = parent[piece.key]

    if not texture then
      texture = parent:CreateTexture(nil, piece.layer)
      parent[piece.key] = texture
    end

    texture:SetSize(pieceValue(piece.w, geometry), pieceValue(piece.h, geometry))
    texture:SetTexture(pieceTexture(piece, theme))
    local target = pieceTarget(piece, parent)

    -- A nil target would silently anchor to the parent; an ordering mistake
    -- in a piece table must fail loudly inside Layout's xpcall instead.
    assert(target, "Console art: no anchor target for " .. piece.key)
    texture:ClearAllPoints()
    texture:SetPoint(piece.point, target, piece.rel, pieceValue(piece.x, geometry), pieceValue(piece.y, geometry))
  end
end

-- Anchor companions: the client refuses to anchor a protected frame (the
-- portrait's secure button, the LibActionButton buttons, and any frame they
-- anchor to, which is implicitly protected) to a region -- "Cannot anchor
-- protected frames to regions" (in-game error, Forever 1.60.1). The art here
-- is all textures, so each texture a protected frame needs gets an invisible
-- companion Frame that mirrors the texture's own points and size; protected
-- frames anchor to the companion instead. The companion is derived from the
-- texture's live state (GetPoint/GetSize), never from a second copy of the
-- geometry, so the on-screen result is the texture's rect by construction and
-- customizer overrides carry over through SyncAnchors. A companion's own
-- anchors only ever name frames (other companions or real frames).
local anchorFrames = {}
local anchorRegions = {}

local function isRegion(object)
  local objectType = object.GetObjectType and object:GetObjectType()

  return objectType == "Texture" or objectType == "FontString"
end

local function companionOf(region)
  local frame = anchorFrames[region]

  if not frame then
    frame = CreateFrame("Frame", nil, region:GetParent())
    anchorFrames[region] = frame
    anchorRegions[#anchorRegions + 1] = region
  end

  return frame
end

local function collectPoints(frame)
  local points = {}

  for i = 1, frame:GetNumPoints() do
    points[i] = { frame:GetPoint(i) }
  end

  return points
end

local function applyPoints(frame, points)
  for _, p in ipairs(points) do
    frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
  end
end

-- Mirrors `region` onto its (already cleared) companion. The parent follows
-- the texture's own: the customizer can re-parent a texture, and the rect only
-- matches while both share a scale. Raises on the first failing SetPoint.
local function fillCompanion(region)
  local frame = companionOf(region)
  local parent = region:GetParent()

  if frame:GetParent() ~= parent then
    frame:SetParent(parent)
  end

  frame:SetSize(region:GetSize())

  for i = 1, region:GetNumPoints() do
    local point, relativeTo, relativePoint, x, y = region:GetPoint(i)

    if relativeTo and isRegion(relativeTo) then
      relativeTo = companionOf(relativeTo)
    end

    frame:SetPoint(point, relativeTo or parent, relativePoint, x, y)
  end
end

-- Re-mirrors every companion. Two passes: every companion is cleared first, so
-- no companion's anchor to another can produce a transient cycle while the
-- others still hold old points. A companion whose mirror fails gets its prior
-- points back (never left empty) and the first failure is returned as
-- `false, message` -- the customizer turns that into a rollback of the
-- offending entry. A companion created mid-loop (a target of a mirrored
-- anchor) is appended and reached by the same loop; it has no prior points.
-- Called at the end of each Build*, after the customizer's Apply, and after
-- each customizer revert.
function WIIIUI.Console.SyncAnchors()
  local prior = {}

  for i, region in ipairs(anchorRegions) do
    local frame = anchorFrames[region]

    prior[i] = collectPoints(frame)
    frame:ClearAllPoints()
  end

  local firstError
  local i = 1

  while anchorRegions[i] do
    local ok, err = pcall(fillCompanion, anchorRegions[i])

    if not ok then
      local frame = anchorFrames[anchorRegions[i]]

      firstError = firstError or err
      frame:ClearAllPoints()
      pcall(applyPoints, frame, prior[i] or {})
    end

    i = i + 1
  end

  return firstError == nil, firstError
end

-- The Frame protected code anchors to in place of `region` (a texture). A new
-- companion is mirrored immediately; an existing one is kept current by
-- SyncAnchors (each Build* and the customizer), so this stays a plain lookup.
function WIIIUI.Console.AnchorFrame(region)
  local existing = anchorFrames[region]

  if existing then
    return existing
  end

  local frame = companionOf(region)

  pcall(fillCompanion, region)

  return frame
end

-- Default anchor of the left console: flush with the bottom-left screen edge
-- (vanilla AlignUI and the ADDON_LOADED pass, e17c352 WIIIUI.lua:3818, 4853:
-- leftFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
-- minimapFrame:GetWidth()/2 - 1, 0)). minimapFrame's width is uiScale, so the
-- offset is derived from Theme.MinimapGeometry on every call, never cached.
-- `shift` moves it for the centering modes (applyLayoutModes).
local function defaultLeftOffsetX(uiScale)
  return WIIIUI.Theme.MinimapGeometry(uiScale).frameSize / 2 - 1
end

local function anchorLeft(left, uiScale, shift)
  left:ClearAllPoints()
  left:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", defaultLeftOffsetX(uiScale) + (shift or 0), 0)
end

-- Vanilla WIIIUI_leftpart (e17c352 WIIIUI.xml:2091-2097): the virtual
-- WIIIUI_Frame template it inherits anchors BOTTOM to its parent (UIParent);
-- AlignUI overrides that with the flush-left anchor above.
function WIIIUI.Console.BuildLeft()
  local left = WIIIUI.Console.left

  if not left then
    left = CreateFrame("Frame", nil, UIParent)
    -- Vanilla's WIIIUI_Frame template sized every console root 1x1
    -- (e17c352 WIIIUI.xml:8). A single anchor with no size leaves the rect
    -- invalid on modern clients and nothing anchored through it renders
    -- (API_ScriptRegion_IsRectValid, warcraft.wiki.gg).
    left:SetSize(1, 1)
    anchorLeft(left, WIIIUI.LayoutUnits())
    WIIIUI.Layers.Apply(left, "console.left")
    WIIIUI.Console.left = left
  end

  local uiScale = WIIIUI.LayoutUnits()

  -- Vanilla anchors these chain minimap -> portrait -> extension background
  -- (e17c352 WIIIUI.lua:1810, 1939, 2801); the extension background is the
  -- shared black_background texture, not a per-theme one.
  BuildArt(left, LEFT_PIECES, {
    minimap = WIIIUI.Theme.MinimapGeometry(uiScale),
    portrait = WIIIUI.Theme.PortraitGeometry(uiScale),
    extensionBackground = WIIIUI.Theme.ExtensionBackgroundGeometry(uiScale),
  }, wc3UI_Options.theme)

  WIIIUI.Console.SyncAnchors()
end

-- Vanilla WIIIUI_actionslotGrid (e17c352 WIIIUI.xml:3045-3113): its own
-- top-level frame -- inherits the virtual WIIIUI_Frame template (parent
-- UIParent), not a texture layer on WIIIUI_leftpart like the minimap/
-- portrait/extension-background art above. AlignActionBarUIGrid (e17c352
-- WIIIUI.lua:2695-2718) overrides the XML's static BOTTOM anchor at
-- runtime: the frame anchors BOTTOMLEFT to extensionBackground's
-- BOTTOMLEFT. The 4 tiles are same-themed, same-sized texture children in
-- ascending layers (BACKGROUND/BORDER/ARTWORK/OVERLAY, XML lines
-- 3056/3071/3086/3101); tile 1 keeps the XML's own static BOTTOM anchor to
-- the grid frame (that function never re-anchors it, only sizes it,
-- e17c352 WIIIUI.lua:2704-2705); tiles 2-4 chain BOTTOMLEFT to the
-- previous tile's BOTTOMRIGHT.
function WIIIUI.Console.BuildGrid()
  local grid = WIIIUI.Console.grid

  if not grid then
    grid = CreateFrame("Frame", nil, UIParent)
    WIIIUI.Layers.Apply(grid, "console.grid")
    WIIIUI.Console.grid = grid
  end

  local theme = wc3UI_Options.theme
  local uiScale = WIIIUI.LayoutUnits()
  local geometry = WIIIUI.Theme.GridGeometry(uiScale)
  local left = WIIIUI.Console.left
  local extensionBackgroundTexture = left and left.extensionBackgroundTexture

  grid:SetSize(geometry.size, geometry.size)
  grid:ClearAllPoints()
  -- The grid is implicitly protected (the secure grid buttons anchor to it),
  -- so it anchors to the extension texture's companion Frame, not the texture.
  grid:SetPoint(
    "BOTTOMLEFT",
    extensionBackgroundTexture and WIIIUI.Console.AnchorFrame(extensionBackgroundTexture),
    "BOTTOMLEFT",
    geometry.originOffsetX,
    geometry.originOffsetY
  )

  BuildArt(grid, GRID_PIECES, { grid = geometry }, theme)

  -- hideGride (vanilla AlignActionBarUIGrid, e17c352 WIIIUI.lua:2724-2738)
  -- hid actionSlotGridMain, the frame carrying only the four tile textures.
  -- The action buttons are children of Buttons.lua's header, not of the grid,
  -- so they stay. Vanilla's nightelf branch re-parented the ext1-3 overlays
  -- off the grid so the hide would not take them along; those overlays are
  -- not ported, so there is nothing to re-parent. The key keeps upstream's
  -- typo for save compatibility. Runs inside Layout, i.e. out of combat.
  if wc3UI_Options.hideGride then
    grid:Hide()
  else
    grid:Show()
  end

  WIIIUI.Console.SyncAnchors()
end

-- Vanilla WIIIUI_rightpart (e17c352 WIIIUI.xml:3120-3127): its own top-level
-- frame, XML-anchored BOTTOM but overridden every AlignRightPart call
-- (e17c352 WIIIUI.lua:3430) with rightFrame:SetPoint("BOTTOMRIGHT", UIParent,
-- "BOTTOMRIGHT", 0, 0) -- a constant anchor, so it's set once on creation
-- like the left frame's, not re-applied every Layout() call.
--
-- rightPart_middle/rightPart_left are vanilla Wc3_UI_right_middle (e17c352
-- WIIIUI.xml:3147, nested in WIIIUI_rightpart) and Wc3_UI_right_left
-- (e17c352 WIIIUI.xml:2195, nested in WIIIUI_leftpart instead -- a quirk of
-- vanilla's own XML, not load-bearing since a texture's SetPoint relativeTo
-- works across parents regardless of who created it). Both are built here as
-- children of this frame instead of split across left/right, so the whole
-- "right region" (this pair, the still-to-come lid/chat-area pieces and
-- fillers) lives behind one WIIIUI.Console.right table for slice 05 to
-- Hide()/Show().
--
-- Per-theme x-offset fraction for the ultraWide/centerSlim/centerSlimNoInv
-- chat-top re-anchor in applyLayoutModes below (vanilla AlignUltraWide,
-- e17c352 WIIIUI.lua:4674-4679): nightelf and undead override the default
-- fraction; every other theme name (including unknown ones) falls
-- through to the default, matching vanilla's own if/elseif/else chain.
-- Table lookup follows Theme.lua's RIGHT_LID_SHIFT_WIDTH_THEMES-style
-- per-theme table convention.
local ULTRA_WIDE_CHAT_TOP_OFFSET_X_THEMES = {
  nightelf = -0.9,
  undead = -0.734615,
}
local ULTRA_WIDE_CHAT_TOP_OFFSET_X_DEFAULT = -0.725833

-- Per-theme fixed (non-uiScale-scaled) x-offset for the chat-middle texture
-- in the same block (e17c352 WIIIUI.lua:4688-4689): nightelf only; every
-- other theme uses the uiScale-scaled default (-uiScale*0.0625).
local ULTRA_WIDE_CHAT_MIDDLE_OFFSET_X_NIGHTELF = -37

-- The one place the three layout flags are read (spec 0006 slice 10).
-- Vanilla AlignUltraWide checks centerSlim first with an elseif, so
-- centerSlim wins over centerSlimNoInv, which wins over ultraWide.
function WIIIUI.Console.LayoutMode()
  if wc3UI_Options.centerSlim then
    return "centerSlim"
  elseif wc3UI_Options.centerSlimNoInv then
    return "centerSlimNoInv"
  elseif wc3UI_Options.ultraWide then
    return "ultraWide"
  end

  return "normal"
end

-- Layout modes: centerSlim/centerSlimNoInv/ultraWide (vanilla
-- AlignUltraWide, e17c352 WIIIUI.lua:4640-4694, 4815). Reads the pieces
-- BuildRight already built on `right` (BuildArt's
-- parent[key] convention) and re-derives their visibility/anchor from
-- wc3UI_Options every call, since WIIIUI.Layout() has no done-flag -- the
-- false/default path of every branch below has to explicitly restore the
-- non-mode state, not just apply the mode.
--
-- Vanilla checks centerSlim first with an elseif, so centerSlimNoInv only
-- applies when centerSlim is also false -- replicated here so centerSlim's
-- per-piece hiding wins when both flags are set.
local function applyLayoutModes(right, left, rawTheme, uiScale, backgroundGeometry)
  local theme = WIIIUI.Theme.ResolveThemeName(rawTheme)
  local mode = WIIIUI.Console.LayoutMode()
  local lid = right.lid
  local chatTop = right.chatTop
  local chatMiddle = right.chatMiddle
  local chatBottom = right.chatBottom
  local fillerTop1, fillerBottom1 = right.fillerTop1, right.fillerBottom1
  local fillerTop2, fillerBottom2 = right.fillerTop2, right.fillerBottom2
  local fillerTop3, fillerBottom3 = right.fillerTop3, right.fillerBottom3

  -- centerSlim (vanilla AlignUltraWide's centerSlim branch, e17c352
  -- WIIIUI.lua:4640-4652) hides the lid/chat-area/filler pieces
  -- while keeping rightPartMiddle/rightPartLeft (inventory art) visible.
  -- Vanilla's nightelf-only decorative left-frame texture in the same
  -- branch is a deferred cosmetic detail, out of this list's scope.
  local slimPieces = {
    lid, chatTop, chatMiddle, chatBottom,
    fillerTop1, fillerBottom1, fillerTop2, fillerBottom2, fillerTop3, fillerBottom3,
  }

  if mode == "centerSlim" then
    for i = 1, #slimPieces do
      slimPieces[i]:Hide()
    end
  else
    for i = 1, #slimPieces do
      slimPieces[i]:Show()
    end
  end

  -- centerSlimNoInv (vanilla AlignUltraWide's centerSlimNoInv branch,
  -- e17c352 WIIIUI.lua:4653-4663) hides the whole right frame, which
  -- cascades to rightPartMiddle/rightPartLeft and everything else anchored
  -- under it -- unlike centerSlim above, which hides only the individual
  -- pieces and keeps the inventory art shown.
  if mode == "centerSlimNoInv" then
    right:Hide()
  else
    right:Show()
  end

  -- ultraWide/centerSlim/centerSlimNoInv horizontal centering (vanilla
  -- AlignUltraWide's tail, e17c352 WIIIUI.lua:4666-4694, 4815). chatTop/
  -- chatMiddle/chatBottom always reference rightPartLeft here (they
  -- already got their normal default anchor unconditionally in BuildRight,
  -- so the false branch below needs no extra code to revert them) -- only
  -- the *centering reference edge* selected just below varies per mode, and
  -- only the `left` frame's own anchor (reset by anchorLeft, not by BuildArt,
  -- which re-anchors the textures on every Layout) needs an explicit revert
  -- in the false branch. The action-slot-button
  -- repositioning/resize inside vanilla's other two elseif branches
  -- (e17c352 WIIIUI.lua:4697-4762) still doesn't exist until slice D and
  -- stays deferred.
  if mode ~= "normal" then
    local topOffsetX = uiScale * (ULTRA_WIDE_CHAT_TOP_OFFSET_X_THEMES[theme] or ULTRA_WIDE_CHAT_TOP_OFFSET_X_DEFAULT)
    local topOffsetY = -uiScale * 0.03846153

    -- Vanilla anchored these to the chat-area background's TOPRIGHT/
    -- BOTTOMRIGHT (e17c352 WIIIUI.lua:4680-4691). The background texture is
    -- gone (feature 0001 fix5: Blizzard's chat has its own background
    -- option), so the same corners are reached from rightPartLeft's
    -- BOTTOMRIGHT: the background sat at (offsetX, offsetY) from it with
    -- (width, height).
    local cornerX = backgroundGeometry.offsetX + backgroundGeometry.width
    local cornerTopY = backgroundGeometry.offsetY + backgroundGeometry.height
    local cornerBottomY = backgroundGeometry.offsetY
    local rightPartLeft = right.rightPartLeft

    chatTop:ClearAllPoints()
    chatTop:SetPoint("BOTTOMLEFT", rightPartLeft, "BOTTOMRIGHT", cornerX + topOffsetX, cornerTopY + topOffsetY)

    chatBottom:ClearAllPoints()
    chatBottom:SetPoint("BOTTOMLEFT", rightPartLeft, "BOTTOMRIGHT", cornerX - uiScale * 0.725833, cornerBottomY)

    local middleOffsetX = (theme == "nightelf") and ULTRA_WIDE_CHAT_MIDDLE_OFFSET_X_NIGHTELF or (-uiScale * 0.0625)

    chatMiddle:ClearAllPoints()
    chatMiddle:SetPoint("BOTTOMLEFT", rightPartLeft, "BOTTOMRIGHT", cornerX + middleOffsetX, cornerBottomY)

    -- vanilla minimapFrame:SetPoint (e17c352 WIIIUI.lua:4815) moves Wc3_UI_
    -- minimap directly; here the whole `left` console frame moves instead,
    -- since minimapTexture/portraitTexture/extensionBackgroundTexture/grid
    -- all chain their anchors from `left` -- moving the parent frame
    -- carries the same visual result without re-anchoring each child.
    if left then
      -- rightPartMiddle/rightPartLeft's resolved right
      -- edge chains all the way back through grid/extensionBackgroundTexture/
      -- portraitTexture/minimapTexture to `left` itself (BuildLeft/BuildGrid/
      -- BuildRight's own anchor graph). Measuring the reference edge against
      -- `left`'s prior (possibly already re-centered) position feeds this
      -- call's own output back into the next call's input and drifts off
      -- true center (security-specialist finding, slice 05 gate). Resetting
      -- `left` to its known default anchor before measuring makes the whole
      -- graph re-resolve relative to that fixed baseline first -- WoW
      -- resolves GetLeft/GetRight synchronously after SetPoint, no frame
      -- delay needed -- so the measured span depends only on fixed geometry,
      -- never on a previous call's result.
      anchorLeft(left, uiScale)

      -- Reference edge per mode -- vanilla picks a different frame
      -- depending which piece is actually visible (e17c352 WIIIUI.lua:
      -- 4666-4762): the chat-area background's right edge when neither
      -- center mode is on (the Wc3_UI_bottom_right_middle:IsVisible()
      -- branch, line 4667) -- rightPartLeft's right edge plus the
      -- background's offset and width, since the texture no longer exists;
      -- rightPartLeft when centerSlimNoInv (WIIIUI_rightpart:IsVisible()==
      -- nil, line 4703), +18 for nightelf (line 4711); rightPart_middle when
      -- centerSlim (WIIIUI_rightpartBackground:IsVisible()==nil, line 4815)
      -- -- vanilla checks centerSlim before centerSlimNoInv with an elseif,
      -- so centerSlim's reference wins when both flags are set, matching the
      -- Hide/Show precedence above. Vanilla's own resize of rightPart_middle
      -- under centerSlim (lines 4738-4762) stays deferred (real-action-
      -- button territory, slice D); this only selects which frame's edge is
      -- read, at its current (un-resized) width.
      local referenceFrame = right.rightPartLeft
      local referenceExtra = backgroundGeometry.offsetX + backgroundGeometry.width

      if mode == "centerSlim" then
        referenceFrame = right.rightPartMiddle
        referenceExtra = 0
      elseif mode == "centerSlimNoInv" then
        referenceExtra = 0
      end

      local referenceEdge = referenceFrame and referenceFrame:GetRight()

      if referenceEdge then
        referenceEdge = referenceEdge + referenceExtra
      end

      if referenceEdge and mode == "centerSlimNoInv" and theme == "nightelf" then
        referenceEdge = referenceEdge + 18
      end

      -- Vanilla moves the minimap texture itself and measures nothing on
      -- leftFrame (e17c352 WIIIUI.lua:4815): it lands the texture's left edge
      -- at (UIParent right - reference right)/2. The texture is `left`'s
      -- child here, so measure the texture's current left edge (at the
      -- default anchor just set) and shift `left` by the difference.
      -- `left` is 1x1 and the texture is centred on it, so measuring `left`
      -- itself would miss frameSize/2.
      local minimapTexture = left.minimapTexture
      local textureLeft = minimapTexture and minimapTexture:GetLeft()
      local uiParentRight = UIParent:GetRight()

      -- GetRight()/GetLeft() can return nil before a region's rect resolves
      -- (security-specialist finding, slice 05 gate) -- skip the re-centre
      -- and leave `left` at the default anchor just set above rather than
      -- computing arithmetic on nil.
      if referenceEdge and textureLeft and uiParentRight then
        anchorLeft(left, uiScale, (uiParentRight - referenceEdge) / 2 - textureLeft)
      end
    end
  elseif left then
    anchorLeft(left, uiScale)
  end
end

function WIIIUI.Console.BuildRight()
  local right = WIIIUI.Console.right

  if not right then
    right = CreateFrame("Frame", nil, UIParent)
    -- 1x1 like left: an unsized root's rect is invalid (see BuildLeft).
    right:SetSize(1, 1)
    right:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    -- Everything on this frame is art (textures), and it includes the opaque
    -- chat-area background. Vanilla raised chat to DIALOG above a HIGH frame
    -- (e17c352 WIIIUI.xml:3120); here chat is an Edit Mode system placed by
    -- the layout string and stays at its own LOW strata (R4), so the art
    -- goes below LOW and chat draws over all of it (feature 0001 fix3, D2).
    -- Interactive pieces (extras, portrait, cogwheel) are not children of
    -- this frame.
    WIIIUI.Layers.Apply(right, "console.right")
    WIIIUI.Console.right = right
  end

  local theme = wc3UI_Options.theme
  local uiScale = WIIIUI.LayoutUnits()
  local geometry = WIIIUI.Theme.RightPartGeometry(uiScale, theme)
  -- Vanilla WIIIUI_rightpartBackground (e17c352 WIIIUI.xml:3131) was an
  -- opaque black texture behind the chat; it is not drawn any more (feature
  -- 0001 fix5: Blizzard's chat frame has its own background option). Its
  -- geometry survives as the reference the ultra-wide chat textures and the
  -- centering measure from (applyLayoutModes). rightPartWidth defaults to
  -- uiScale*2.2 when unset (e17c352 WIIIUI.lua:4545-4546) and is excluded
  -- from DEFAULTS (Core.lua), so its type is guarded here.
  local rawRightPartWidth = wc3UI_Options.rightPartWidth
  local rightPartWidth = (type(rawRightPartWidth) == "number") and rawRightPartWidth or (uiScale * 2.2)
  local backgroundGeometry = WIIIUI.Theme.RightPartBackgroundGeometry(
    uiScale,
    rightPartWidth,
    wc3UI_Options.moveChatAreaUp
  )

  BuildArt(right, RIGHT_PIECES, {
    rightPart = geometry,
    lid = WIIIUI.Theme.RightLidGeometry(uiScale, theme, wc3UI_Options.moveChatAreaUp),
    chat = WIIIUI.Theme.ChatAreaGeometry(uiScale, theme, wc3UI_Options.moveChatAreaUp),
    filler = WIIIUI.Theme.RightFillerGeometry(uiScale, wc3UI_Options.moveChatAreaUp),
  }, theme)

  -- Layout modes (centerSlim/centerSlimNoInv/ultraWide): applyLayoutModes,
  -- defined above, re-derives visibility/anchors from wc3UI_Options every
  -- call -- see its own comments for the vanilla citations per mode.
  applyLayoutModes(right, WIIIUI.Console.left, theme, uiScale, backgroundGeometry)

  WIIIUI.Console.SyncAnchors()
end

WIIIUI.RegisterBuild("Console.BuildLeft", WIIIUI.Console.BuildLeft)
WIIIUI.RegisterBuild("Console.BuildGrid", WIIIUI.Console.BuildGrid, { after = { "Console.BuildLeft" } })
WIIIUI.RegisterBuild("Console.BuildRight", WIIIUI.Console.BuildRight, { after = { "Console.BuildGrid" } })

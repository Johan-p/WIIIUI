-- spec 0001 §Module split "Console.lua": art frames -- left (minimap/
-- portrait art), middle (grid art, extensions), right (inventory, chat
-- area). BuildRight now covers the inventory-art pair (rightPart_middle/
-- rightPart_left), the shared background, the lid and the chat-area top/
-- middle/bottom pieces; the 6 extension filler textures are a later
-- iteration of the same slice. The extension1/2/3 overlays on the left
-- frame stay out of scope (slice 04's own deferral, unchanged).
local _, WIIIUI = ...

WIIIUI.Console = WIIIUI.Console or {}

-- Shared create-if-missing-and-cache-on-parent step for the per-region art
-- textures below; callers still own SetSize/SetTexture/ClearAllPoints/
-- SetPoint since those differ per texture. isNew tells a caller that only
-- sets its anchor once (tile1, minimapTexture) when to do so.
local function getOrCreateTexture(parent, cacheKey, layer)
  local texture = parent[cacheKey]
  local isNew = not texture

  if isNew then
    texture = parent:CreateTexture(nil, layer)
    parent[cacheKey] = texture
  end

  return texture, isNew
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

-- Vanilla WIIIUI_leftpart (e17c352 WIIIUI.xml:2091-2097): the virtual
-- WIIIUI_Frame template it inherits anchors BOTTOM to its parent (UIParent)
-- at offset 0,0.
function WIIIUI.Console.BuildLeft()
  local left = WIIIUI.Console.left

  if not left then
    left = CreateFrame("Frame", nil, UIParent)
    -- Vanilla's WIIIUI_Frame template sized every console root 1x1
    -- (e17c352 WIIIUI.xml:8). A single anchor with no size leaves the rect
    -- invalid on modern clients and nothing anchored through it renders
    -- (API_ScriptRegion_IsRectValid, warcraft.wiki.gg).
    left:SetSize(1, 1)
    left:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
    -- Vanilla WIIIUI_leftpart is framestrata="LOW" (e17c352 WIIIUI.xml:5,
    -- the virtual WIIIUI_Frame template's default) -- below the grid and
    -- right consoles in the stack. API_Frame_GetFrameStrata,
    -- warcraft.wiki.gg.
    left:SetFrameStrata("LOW")
    WIIIUI.Console.left = left
  end

  local theme = wc3UI_Options.theme
  local uiScale = wc3UI_Options.uiScale
  local geometry = WIIIUI.Theme.MinimapGeometry(uiScale)

  -- Vanilla Wc3_UI_minimap (e17c352 WIIIUI.xml:2114-2126, Layer
  -- level="ARTWORK"): anchored BOTTOM to its parent's BOTTOM at offset 0,0.
  -- Sized square by AlignMinimap's minimapFrame:SetWidth/SetHeight(uiScale)
  -- (e17c352 WIIIUI.lua:1810-1811) -- Theme.lua's MinimapGeometry.frameSize.
  local minimapTexture, minimapIsNew = getOrCreateTexture(left, "minimapTexture", "ARTWORK")

  if minimapIsNew then
    minimapTexture:SetPoint("BOTTOM", left, "BOTTOM", 0, 0)
  end

  minimapTexture:SetSize(geometry.frameSize, geometry.frameSize)
  minimapTexture:SetTexture(WIIIUI.Theme.TexturePath(theme, "minimap_portrait", "minimap"))

  -- Vanilla Wc3_UI_portrait (e17c352 WIIIUI.xml:2132, Layer level="BORDER"),
  -- same WIIIUI_leftpart frame as the minimap texture. AlignPortrait
  -- (e17c352 WIIIUI.lua:1939-1943) overrides the XML's static anchor at
  -- runtime with portraitFrame:SetPoint("BOTTOMLEFT", minimapFrame,
  -- "BOTTOMRIGHT", 0, 0) -- minimapFrame there is Wc3_UI_minimap itself
  -- (InitiateFrameNames, e17c352 WIIIUI.lua:4564), i.e. minimapTexture here.
  local portraitGeometry = WIIIUI.Theme.PortraitGeometry(uiScale)
  local portraitTexture = getOrCreateTexture(left, "portraitTexture", "BORDER")

  portraitTexture:SetSize(portraitGeometry.size, portraitGeometry.size)
  portraitTexture:SetTexture(WIIIUI.Theme.TexturePath(theme, "minimap_portrait", "portrait"))
  portraitTexture:ClearAllPoints()
  portraitTexture:SetPoint(
    "BOTTOMLEFT",
    minimapTexture,
    "BOTTOMRIGHT",
    portraitGeometry.anchorOffsetX,
    portraitGeometry.anchorOffsetY
  )

  -- Vanilla Wc3_UI_extensionBackground (e17c352 WIIIUI.xml:2035, Layer
  -- level="BACKGROUND"): shared (not per-theme) texture, literal path from
  -- the same XML line, unlike Theme.TexturePath's per-theme paths.
  -- AlignMiddleExtension's tail (e17c352 WIIIUI.lua:2801-2804) overrides the
  -- XML's static anchor at runtime with extensionBackground:SetPoint(
  -- "BOTTOMLEFT", "Wc3_UI_portrait", "BOTTOMRIGHT", uiScale*-0.18, 0).
  local extensionBackgroundGeometry = WIIIUI.Theme.ExtensionBackgroundGeometry(uiScale)
  local extensionBackgroundTexture = getOrCreateTexture(left, "extensionBackgroundTexture", "BACKGROUND")

  extensionBackgroundTexture:SetSize(extensionBackgroundGeometry.width, extensionBackgroundGeometry.height)
  extensionBackgroundTexture:SetTexture("Interface\\Addons\\WIIIUI\\art\\other\\black_background")
  extensionBackgroundTexture:ClearAllPoints()
  extensionBackgroundTexture:SetPoint(
    "BOTTOMLEFT",
    portraitTexture,
    "BOTTOMRIGHT",
    extensionBackgroundGeometry.offsetX,
    extensionBackgroundGeometry.offsetY
  )

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
    -- Vanilla WIIIUI_actionslotGrid is framestrata="MEDIUM" (e17c352
    -- WIIIUI.xml:3045) -- above the left console, below the right console.
    -- API_Frame_GetFrameStrata, warcraft.wiki.gg.
    grid:SetFrameStrata("MEDIUM")
    WIIIUI.Console.grid = grid
  end

  local theme = wc3UI_Options.theme
  local uiScale = wc3UI_Options.uiScale
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

  local tilePath = WIIIUI.Theme.TexturePath(theme, "actionbar", "actionslots_grid")

  local tile1, tile1IsNew = getOrCreateTexture(grid, "tile1", "BACKGROUND")

  if tile1IsNew then
    tile1:SetPoint("BOTTOM", grid, "BOTTOM", 0, 0)
  end

  tile1:SetSize(geometry.size, geometry.size)
  tile1:SetTexture(tilePath)

  local tile2 = getOrCreateTexture(grid, "tile2", "BORDER")

  tile2:SetSize(geometry.size, geometry.size)
  tile2:SetTexture(tilePath)
  tile2:ClearAllPoints()
  tile2:SetPoint("BOTTOMLEFT", tile1, "BOTTOMRIGHT", geometry.slot2OffsetX, 0)

  local tile3 = getOrCreateTexture(grid, "tile3", "ARTWORK")

  tile3:SetSize(geometry.size, geometry.size)
  tile3:SetTexture(tilePath)
  tile3:ClearAllPoints()
  tile3:SetPoint("BOTTOMLEFT", tile2, "BOTTOMRIGHT", geometry.slot3OffsetX, 0)

  local tile4 = getOrCreateTexture(grid, "tile4", "OVERLAY")

  tile4:SetSize(geometry.size, geometry.size)
  tile4:SetTexture(tilePath)
  tile4:ClearAllPoints()
  tile4:SetPoint("BOTTOMLEFT", tile3, "BOTTOMRIGHT", geometry.slot4OffsetX, 0)

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
-- fraction; every other theme name (including unknown/custom ones) falls
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

-- Layout modes: centerSlim/centerSlimNoInv/ultraWide (vanilla
-- AlignUltraWide, e17c352 WIIIUI.lua:4640-4694, 4815). Reads the pieces
-- BuildRight already cached on `right` (getOrCreateTexture's
-- parent[cacheKey] convention) and re-derives their visibility/anchor from
-- wc3UI_Options every call, since WIIIUI.Layout() has no done-flag -- the
-- false/default path of every branch below has to explicitly restore the
-- non-mode state, not just apply the mode.
--
-- Vanilla checks centerSlim first with an elseif, so centerSlimNoInv only
-- applies when centerSlim is also false -- replicated here so centerSlim's
-- per-piece hiding wins when both flags are set.
local function applyLayoutModes(right, left, theme, uiScale)
  local rightPartBackground = right.rightPartBackground
  local lid = right.lid
  local chatTop = right.chatTop
  local chatMiddle = right.chatMiddle
  local chatBottom = right.chatBottom
  local fillerTop1, fillerBottom1 = right.fillerTop1, right.fillerBottom1
  local fillerTop2, fillerBottom2 = right.fillerTop2, right.fillerBottom2
  local fillerTop3, fillerBottom3 = right.fillerTop3, right.fillerBottom3

  -- centerSlim (vanilla AlignUltraWide's centerSlim branch, e17c352
  -- WIIIUI.lua:4640-4652) hides the background/lid/chat-area/filler pieces
  -- while keeping rightPartMiddle/rightPartLeft (inventory art) visible.
  -- Vanilla's nightelf-only decorative left-frame texture in the same
  -- branch is a deferred cosmetic detail, out of this list's scope.
  local slimPieces = {
    rightPartBackground, lid, chatTop, chatMiddle, chatBottom,
    fillerTop1, fillerBottom1, fillerTop2, fillerBottom2, fillerTop3, fillerBottom3,
  }

  if wc3UI_Options.centerSlim then
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
  if wc3UI_Options.centerSlimNoInv and not wc3UI_Options.centerSlim then
    right:Hide()
  else
    right:Show()
  end

  -- ultraWide/centerSlim/centerSlimNoInv horizontal centering (vanilla
  -- AlignUltraWide's tail, e17c352 WIIIUI.lua:4666-4694, 4815). chatTop/
  -- chatMiddle/chatBottom always reference rightPartBackground here (they
  -- already got their normal default anchor unconditionally in BuildRight,
  -- so the false branch below needs no extra code to revert them) -- only
  -- the *centering reference edge* selected just below varies per mode, and
  -- only `left`'s anchor (set once by BuildLeft at creation) needs an
  -- explicit revert in the false branch. The action-slot-button
  -- repositioning/resize inside vanilla's other two elseif branches
  -- (e17c352 WIIIUI.lua:4697-4762) still doesn't exist until slice D and
  -- stays deferred.
  if wc3UI_Options.ultraWide or wc3UI_Options.centerSlim or wc3UI_Options.centerSlimNoInv then
    local topOffsetX = uiScale * (ULTRA_WIDE_CHAT_TOP_OFFSET_X_THEMES[theme] or ULTRA_WIDE_CHAT_TOP_OFFSET_X_DEFAULT)
    local topOffsetY = -uiScale * 0.03846153

    chatTop:ClearAllPoints()
    chatTop:SetPoint("BOTTOMLEFT", rightPartBackground, "TOPRIGHT", topOffsetX, topOffsetY)

    chatBottom:ClearAllPoints()
    chatBottom:SetPoint("BOTTOMLEFT", rightPartBackground, "BOTTOMRIGHT", -uiScale * 0.725833, 0)

    local middleOffsetX = (theme == "nightelf") and ULTRA_WIDE_CHAT_MIDDLE_OFFSET_X_NIGHTELF or (-uiScale * 0.0625)

    chatMiddle:ClearAllPoints()
    chatMiddle:SetPoint("BOTTOMLEFT", rightPartBackground, "BOTTOMRIGHT", middleOffsetX, 0)

    -- vanilla minimapFrame:SetPoint (e17c352 WIIIUI.lua:4815) moves Wc3_UI_
    -- minimap directly; here the whole `left` console frame moves instead,
    -- since minimapTexture/portraitTexture/extensionBackgroundTexture/grid
    -- all chain their anchors from `left` -- moving the parent frame
    -- carries the same visual result without re-anchoring each child.
    if left then
      -- rightPartBackground/rightPartMiddle/rightPartLeft's resolved right
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
      left:ClearAllPoints()
      left:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)

      -- Reference edge per mode -- vanilla picks a different frame
      -- depending which piece is actually visible (e17c352 WIIIUI.lua:
      -- 4666-4762): rightPartBackground when neither center mode is on (the
      -- Wc3_UI_bottom_right_middle:IsVisible() branch, line 4667);
      -- rightPartLeft when centerSlimNoInv (WIIIUI_rightpart:IsVisible()==
      -- nil, line 4703), +18 for nightelf (line 4711); rightPart_middle when
      -- centerSlim (WIIIUI_rightpartBackground:IsVisible()==nil, line 4815)
      -- -- vanilla checks centerSlim before centerSlimNoInv with an elseif,
      -- so centerSlim's reference wins when both flags are set, matching the
      -- Hide/Show precedence above. Vanilla's own resize of rightPart_middle
      -- under centerSlim (lines 4738-4762) stays deferred (real-action-
      -- button territory, slice D); this only selects which frame's edge is
      -- read, at its current (un-resized) width.
      local referenceFrame = rightPartBackground

      if wc3UI_Options.centerSlim then
        referenceFrame = right.rightPartMiddle
      elseif wc3UI_Options.centerSlimNoInv then
        referenceFrame = right.rightPartLeft
      end

      local referenceEdge = referenceFrame and referenceFrame:GetRight()

      if referenceEdge and wc3UI_Options.centerSlimNoInv and not wc3UI_Options.centerSlim and theme == "nightelf" then
        referenceEdge = referenceEdge + 18
      end

      local leftEdge = left:GetLeft()
      local uiParentRight = UIParent:GetRight()

      -- GetRight()/GetLeft() can return nil before a region's rect resolves
      -- (security-specialist finding, slice 05 gate) -- skip the re-centre
      -- and leave `left` at the default anchor just set above rather than
      -- computing arithmetic on nil.
      if referenceEdge and leftEdge and uiParentRight then
        local span = referenceEdge - leftEdge

        left:ClearAllPoints()
        left:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (uiParentRight - span) / 2, 0)
      end
    end
  elseif left then
    left:ClearAllPoints()
    left:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
  end
end

function WIIIUI.Console.BuildRight()
  local right = WIIIUI.Console.right

  if not right then
    right = CreateFrame("Frame", nil, UIParent)
    -- 1x1 like left: an unsized root's rect is invalid (see BuildLeft).
    right:SetSize(1, 1)
    right:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    -- Vanilla WIIIUI_rightpart is framestrata="HIGH" (e17c352
    -- WIIIUI.xml:3120) -- the inventory/lid/chat-area console draws above
    -- the grid, which draws above the left console. API_Frame_
    -- GetFrameStrata, warcraft.wiki.gg.
    right:SetFrameStrata("HIGH")
    WIIIUI.Console.right = right
  end

  local theme = wc3UI_Options.theme
  local uiScale = wc3UI_Options.uiScale
  local geometry = WIIIUI.Theme.RightPartGeometry(uiScale, theme)
  local grid = WIIIUI.Console.grid
  local tile4 = grid and grid.tile4

  -- Vanilla Wc3_UI_right_middle (e17c352 WIIIUI.xml:3147, Layer
  -- level="OVERLAY"). AlignRightPart (e17c352 WIIIUI.lua:3438-3455) overrides
  -- the XML's static BOTTOM anchor at runtime, anchoring BOTTOMLEFT to
  -- actionSlotGrid_4's (this module's grid.tile4) BOTTOMRIGHT.
  local rightPartMiddle = getOrCreateTexture(right, "rightPartMiddle", "OVERLAY")

  rightPartMiddle:SetSize(geometry.middleWidth, geometry.middleHeight)
  rightPartMiddle:SetTexture(WIIIUI.Theme.TexturePath(theme, "inventory", "inventory"))
  rightPartMiddle:ClearAllPoints()
  rightPartMiddle:SetPoint("BOTTOMLEFT", tile4, "BOTTOMRIGHT", geometry.middleOffsetX, geometry.middleOffsetY)

  -- Vanilla Wc3_UI_right_left (e17c352 WIIIUI.xml:2195, Layer
  -- level="ARTWORK"). AlignRightPart (e17c352 WIIIUI.lua:3442-3455) overrides
  -- the XML's static BOTTOM anchor at runtime, anchoring BOTTOMRIGHT to
  -- rightPart_middle's BOTTOMLEFT.
  local rightPartLeft = getOrCreateTexture(right, "rightPartLeft", "ARTWORK")

  rightPartLeft:SetSize(geometry.leftWidth, geometry.leftHeight)
  rightPartLeft:SetTexture(WIIIUI.Theme.TexturePath(theme, "inventory", "no_inventory"))
  rightPartLeft:ClearAllPoints()
  rightPartLeft:SetPoint("BOTTOMRIGHT", rightPartMiddle, "BOTTOMLEFT", geometry.leftOffsetX, geometry.leftOffsetY)

  -- Vanilla WIIIUI_rightpartBackground (e17c352 WIIIUI.xml:3131, Layer
  -- level="BACKGROUND", nested in WIIIUI_rightpart), a shared (not
  -- per-theme) texture -- literal path, same convention as the left frame's
  -- extension-background. AlignRightPart (e17c352 WIIIUI.lua:3495-3497)
  -- overrides the XML's static CENTER anchor/0x0 size at runtime.
  -- rightPartWidth defaults to uiScale*2.2 when unset (e17c352
  -- WIIIUI.lua:4545-4546's backfill-only-when-nil semantics); read here
  -- rather than via Config.lua, which doesn't exist yet (slice 04B).
  -- rightPartWidth is deliberately excluded from DEFAULTS (Core.lua), so
  -- MergeDefaults never resets a wrong-typed value from a hand-edited or
  -- corrupted SavedVariables file -- guard the type here instead of letting
  -- a non-number flow into rightPartBackground:SetSize below.
  local rawRightPartWidth = wc3UI_Options.rightPartWidth
  local rightPartWidth = (type(rawRightPartWidth) == "number") and rawRightPartWidth or (uiScale * 2.2)
  local backgroundGeometry = WIIIUI.Theme.RightPartBackgroundGeometry(
    uiScale,
    rightPartWidth,
    wc3UI_Options.moveChatAreaUp
  )
  local rightPartBackground = getOrCreateTexture(right, "rightPartBackground", "BACKGROUND")

  rightPartBackground:SetSize(backgroundGeometry.width, backgroundGeometry.height)
  rightPartBackground:SetTexture("Interface\\Addons\\WIIIUI\\art\\other\\black_background")
  rightPartBackground:ClearAllPoints()
  rightPartBackground:SetPoint(
    "BOTTOMLEFT",
    rightPartLeft,
    "BOTTOMRIGHT",
    backgroundGeometry.offsetX,
    backgroundGeometry.offsetY
  )

  -- Vanilla Wc3_UI_right_lid (e17c352 WIIIUI.xml:3164, Layer
  -- level="BORDER"). AlignRightPart (e17c352 WIIIUI.lua:3490-3493) overrides
  -- the XML's static BOTTOM anchor at runtime, anchoring BOTTOMLEFT to
  -- rightPartMiddle's BOTTOMLEFT. Cached as right.lid so slice 05 can
  -- Hide()/Show() it.
  local lidGeometry = WIIIUI.Theme.RightLidGeometry(uiScale, theme, wc3UI_Options.moveChatAreaUp)
  local lid = getOrCreateTexture(right, "lid", "BORDER")

  lid:SetSize(lidGeometry.size, lidGeometry.size)
  lid:SetTexture(WIIIUI.Theme.TexturePath(theme, "bottom right", "right_part_lid"))
  lid:ClearAllPoints()
  lid:SetPoint("BOTTOMLEFT", rightPartMiddle, "BOTTOMLEFT", lidGeometry.offsetX, lidGeometry.offsetY)

  -- Vanilla Wc3_UI_bottom_right_top/middle/bottom (e17c352 WIIIUI.xml:3179/
  -- 3193/3207, Layer level="BORDER"). AlignRightPart's "Increase the size
  -- of the lower right area (chat area)" block (e17c352 WIIIUI.lua:3457-
  -- 3483) overrides the XML's static BOTTOM anchors at runtime, anchoring
  -- all three BOTTOMLEFT to UIParent's own BOTTOMRIGHT corner, not a WIIIUI
  -- frame. Cached as right.chatTop/chatMiddle/chatBottom so slice 05 can
  -- Hide()/Show() them.
  local chatAreaGeometry = WIIIUI.Theme.ChatAreaGeometry(uiScale, theme, wc3UI_Options.moveChatAreaUp)

  local chatTop = getOrCreateTexture(right, "chatTop", "BORDER")

  chatTop:SetSize(chatAreaGeometry.topWidth, chatAreaGeometry.topHeight)
  chatTop:SetTexture(WIIIUI.Theme.TexturePath(theme, "bottom right", "BottomRight_Top"))
  chatTop:ClearAllPoints()
  chatTop:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMRIGHT", chatAreaGeometry.topOffsetX, chatAreaGeometry.topOffsetY)

  local chatMiddle = getOrCreateTexture(right, "chatMiddle", "BORDER")

  chatMiddle:SetSize(chatAreaGeometry.middleWidth, chatAreaGeometry.middleHeight)
  chatMiddle:SetTexture(WIIIUI.Theme.TexturePath(theme, "bottom right", "BottomRight_Middle"))
  chatMiddle:ClearAllPoints()
  chatMiddle:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMRIGHT", chatAreaGeometry.middleOffsetX, chatAreaGeometry.middleOffsetY)

  local chatBottom = getOrCreateTexture(right, "chatBottom", "BORDER")

  chatBottom:SetSize(chatAreaGeometry.bottomWidth, chatAreaGeometry.bottomHeight)
  chatBottom:SetTexture(WIIIUI.Theme.TexturePath(theme, "bottom right", "BottomRight_Bottom"))
  chatBottom:ClearAllPoints()
  chatBottom:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMRIGHT", chatAreaGeometry.bottomOffsetX, chatAreaGeometry.bottomOffsetY)

  -- Vanilla Wc3_UI_right_right_extendedFillerTop_1/Bottom_1 (e17c352
  -- WIIIUI.xml:3220-3243, Layer level="BORDER"). AlignRightPart (e17c352
  -- WIIIUI.lua:3507-3514) overrides the XML's static BOTTOM anchor at
  -- runtime, anchoring both BOTTOMLEFT to rightPartMiddle's BOTTOMRIGHT.
  -- Cached as right.fillerTop1/fillerBottom1 so slice 05 can Hide()/Show()
  -- them; the uiScale-threshold Show/Hide quirks and the undead-only
  -- re-aligner (e17c352 WIIIUI.lua:3515-3560, 3562+) are this slice's
  -- documented deferral, not built here.
  local fillerGeometry = WIIIUI.Theme.RightFillerGeometry(uiScale, wc3UI_Options.moveChatAreaUp)
  local fillerTopPath = WIIIUI.Theme.TexturePath(theme, "bottom right", "BottomRightFillerTop")
  local fillerBottomPath = WIIIUI.Theme.TexturePath(theme, "bottom right", "BottomRightFillerBottom")

  local fillerTop1 = getOrCreateTexture(right, "fillerTop1", "BORDER")

  fillerTop1:SetSize(fillerGeometry.topWidth, fillerGeometry.topHeight)
  fillerTop1:SetTexture(fillerTopPath)
  fillerTop1:ClearAllPoints()
  fillerTop1:SetPoint("BOTTOMLEFT", rightPartMiddle, "BOTTOMRIGHT", fillerGeometry.top1OffsetX, fillerGeometry.top1OffsetY)

  local fillerBottom1 = getOrCreateTexture(right, "fillerBottom1", "BORDER")

  fillerBottom1:SetSize(fillerGeometry.bottomWidth, fillerGeometry.bottomHeight)
  fillerBottom1:SetTexture(fillerBottomPath)
  fillerBottom1:ClearAllPoints()
  fillerBottom1:SetPoint("BOTTOMLEFT", rightPartMiddle, "BOTTOMRIGHT", fillerGeometry.bottom1OffsetX, fillerGeometry.bottom1OffsetY)

  -- Vanilla Wc3_UI_right_right_extendedFillerTop_2/Bottom_2 (e17c352
  -- WIIIUI.xml:3251-3273, Layer level="ARTWORK"). AlignRightPart (e17c352
  -- WIIIUI.lua:3526-3534) overrides the XML's static BOTTOM anchor at
  -- runtime, anchoring both BOTTOMLEFT to fillerBottom1's own BOTTOMLEFT.
  local fillerTop2 = getOrCreateTexture(right, "fillerTop2", "ARTWORK")

  fillerTop2:SetSize(fillerGeometry.topWidth, fillerGeometry.topHeight)
  fillerTop2:SetTexture(fillerTopPath)
  fillerTop2:ClearAllPoints()
  fillerTop2:SetPoint("BOTTOMLEFT", fillerBottom1, "BOTTOMLEFT", fillerGeometry.top2OffsetX, fillerGeometry.top2OffsetY)

  local fillerBottom2 = getOrCreateTexture(right, "fillerBottom2", "ARTWORK")

  fillerBottom2:SetSize(fillerGeometry.bottomWidth, fillerGeometry.bottomHeight)
  fillerBottom2:SetTexture(fillerBottomPath)
  fillerBottom2:ClearAllPoints()
  fillerBottom2:SetPoint("BOTTOMLEFT", fillerBottom1, "BOTTOMLEFT", fillerGeometry.bottom2OffsetX, fillerGeometry.bottom2OffsetY)

  -- Vanilla Wc3_UI_right_right_extendedFillerTop_3/Bottom_3 (e17c352
  -- WIIIUI.xml:3280-3302, Layer level="ARTWORK"). AlignRightPart (e17c352
  -- WIIIUI.lua:3543-3550) overrides the XML's static BOTTOM anchor at
  -- runtime, anchoring both BOTTOMLEFT to fillerBottom2's own BOTTOMLEFT.
  local fillerTop3 = getOrCreateTexture(right, "fillerTop3", "ARTWORK")

  fillerTop3:SetSize(fillerGeometry.topWidth, fillerGeometry.topHeight)
  fillerTop3:SetTexture(fillerTopPath)
  fillerTop3:ClearAllPoints()
  fillerTop3:SetPoint("BOTTOMLEFT", fillerBottom2, "BOTTOMLEFT", fillerGeometry.top3OffsetX, fillerGeometry.top3OffsetY)

  local fillerBottom3 = getOrCreateTexture(right, "fillerBottom3", "ARTWORK")

  fillerBottom3:SetSize(fillerGeometry.bottomWidth, fillerGeometry.bottomHeight)
  fillerBottom3:SetTexture(fillerBottomPath)
  fillerBottom3:ClearAllPoints()
  fillerBottom3:SetPoint("BOTTOMLEFT", fillerBottom2, "BOTTOMLEFT", fillerGeometry.bottom3OffsetX, fillerGeometry.bottom3OffsetY)

  -- Layout modes (centerSlim/centerSlimNoInv/ultraWide): applyLayoutModes,
  -- defined above, re-derives visibility/anchors from wc3UI_Options every
  -- call -- see its own comments for the vanilla citations per mode.
  applyLayoutModes(right, WIIIUI.Console.left, theme, uiScale)

  WIIIUI.Console.SyncAnchors()
end

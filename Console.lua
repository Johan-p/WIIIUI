-- spec 0001 §Module split "Console.lua": art frames -- left (minimap/
-- portrait art), middle (grid art, extensions), right (inventory, chat
-- area). This iteration adds the right frame's inventory-art pair
-- (rightPart_middle/rightPart_left, slice 04B's tracer bullet); the lid,
-- chat-area top/middle/bottom pieces and the 6 extension filler textures
-- are later iterations of the same slice. The extension1/2/3 overlays on
-- the left frame stay out of scope (slice 04's own deferral, unchanged).
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

-- Vanilla WIIIUI_leftpart (e17c352 WIIIUI.xml:2091-2097): the virtual
-- WIIIUI_Frame template it inherits anchors BOTTOM to its parent (UIParent)
-- at offset 0,0.
function WIIIUI.Console.BuildLeft()
  local left = WIIIUI.Console.left

  if not left then
    left = CreateFrame("Frame", nil, UIParent)
    left:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
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
    WIIIUI.Console.grid = grid
  end

  local theme = wc3UI_Options.theme
  local uiScale = wc3UI_Options.uiScale
  local geometry = WIIIUI.Theme.GridGeometry(uiScale)
  local left = WIIIUI.Console.left
  local extensionBackgroundTexture = left and left.extensionBackgroundTexture

  grid:SetSize(geometry.size, geometry.size)
  grid:ClearAllPoints()
  grid:SetPoint(
    "BOTTOMLEFT",
    extensionBackgroundTexture,
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
function WIIIUI.Console.BuildRight()
  local right = WIIIUI.Console.right

  if not right then
    right = CreateFrame("Frame", nil, UIParent)
    right:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
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
end

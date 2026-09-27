-- spec 0001 §Module split "Console.lua": art frames -- left (minimap/
-- portrait art), middle (grid art, extensions), right (inventory, chat
-- area). This iteration adds the action-slot grid frame and its 4 tile
-- textures; the extension1/2/3 overlays and the right frame have no
-- sanctioned Theme.lua geometry yet and stay out of scope for this slice.
local _, WIIIUI = ...

WIIIUI.Console = WIIIUI.Console or {}

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
  local minimapTexture = left.minimapTexture

  if not minimapTexture then
    minimapTexture = left:CreateTexture(nil, "ARTWORK")
    minimapTexture:SetPoint("BOTTOM", left, "BOTTOM", 0, 0)
    left.minimapTexture = minimapTexture
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
  local portraitTexture = left.portraitTexture

  if not portraitTexture then
    portraitTexture = left:CreateTexture(nil, "BORDER")
    left.portraitTexture = portraitTexture
  end

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
  local extensionBackgroundTexture = left.extensionBackgroundTexture

  if not extensionBackgroundTexture then
    extensionBackgroundTexture = left:CreateTexture(nil, "BACKGROUND")
    left.extensionBackgroundTexture = extensionBackgroundTexture
  end

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

  local tile1 = grid.tile1

  if not tile1 then
    tile1 = grid:CreateTexture(nil, "BACKGROUND")
    tile1:SetPoint("BOTTOM", grid, "BOTTOM", 0, 0)
    grid.tile1 = tile1
  end

  tile1:SetSize(geometry.size, geometry.size)
  tile1:SetTexture(tilePath)

  local tile2 = grid.tile2

  if not tile2 then
    tile2 = grid:CreateTexture(nil, "BORDER")
    grid.tile2 = tile2
  end

  tile2:SetSize(geometry.size, geometry.size)
  tile2:SetTexture(tilePath)
  tile2:ClearAllPoints()
  tile2:SetPoint("BOTTOMLEFT", tile1, "BOTTOMRIGHT", geometry.slot2OffsetX, 0)

  local tile3 = grid.tile3

  if not tile3 then
    tile3 = grid:CreateTexture(nil, "ARTWORK")
    grid.tile3 = tile3
  end

  tile3:SetSize(geometry.size, geometry.size)
  tile3:SetTexture(tilePath)
  tile3:ClearAllPoints()
  tile3:SetPoint("BOTTOMLEFT", tile2, "BOTTOMRIGHT", geometry.slot3OffsetX, 0)

  local tile4 = grid.tile4

  if not tile4 then
    tile4 = grid:CreateTexture(nil, "OVERLAY")
    grid.tile4 = tile4
  end

  tile4:SetSize(geometry.size, geometry.size)
  tile4:SetTexture(tilePath)
  tile4:ClearAllPoints()
  tile4:SetPoint("BOTTOMLEFT", tile3, "BOTTOMRIGHT", geometry.slot4OffsetX, 0)
end

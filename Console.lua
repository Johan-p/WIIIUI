-- spec 0001 §Module split "Console.lua": art frames -- left (minimap/
-- portrait art), middle (grid art, extensions), right (inventory, chat
-- area). This iteration extends the left frame with the portrait texture
-- and the shared (non-themed) extension-background texture; the middle
-- grid and right frame follow in later iterations.
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

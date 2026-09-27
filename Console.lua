-- spec 0001 §Module split "Console.lua": art frames -- left (minimap/
-- portrait art), middle (grid art, extensions), right (inventory, chat
-- area). This iteration builds only the left frame and its minimap texture,
-- the tracer bullet WIIIUI.Layout() (Core.lua) hangs region Build* functions
-- off; middle/right and the portrait texture follow in later iterations.
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
end

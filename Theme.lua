-- spec 0001 §Module split "Theme.lua": theme->path resolution, replacing
-- vanilla WIIIUI.lua's ChangeTheme (e17c352, theme fallback + SetTexture
-- path concatenation).
local _, WIIIUI = ...

WIIIUI.Theme = {}

local KNOWN_THEMES = {
  human = true,
  orc = true,
  undead = true,
  nightelf = true,
  custom1 = true,
  custom2 = true,
  custom3 = true,
  custom4 = true,
  custom5 = true,
  custom6 = true,
  custom7 = true,
  custom8 = true,
}

function WIIIUI.Theme.ResolveThemeName(theme)
  if KNOWN_THEMES[theme] then
    return theme
  end
  return "orc"
end

function WIIIUI.Theme.TexturePath(theme, folder, file)
  local resolved = WIIIUI.Theme.ResolveThemeName(theme)
  return "Interface\\Addons\\WIIIUI\\art\\" .. resolved .. "\\" .. folder .. "\\" .. file
end

-- Vanilla AlignMinimap (e17c352 WIIIUI.lua ~1807-1826): minimapFrame is uiScale
-- square; Minimap itself is 0.55 of that, offset from the frame center. Only
-- the unconditional math is ported here; theme/uiScale-threshold branches
-- (e.g. the mail-icon extraAlign stepping) are out of scope for this slice.
function WIIIUI.Theme.MinimapGeometry(uiScale)
  return {
    frameSize = uiScale,
    minimapSize = uiScale * 0.55,
    minimapOffsetX = uiScale * -0.189,
    minimapOffsetY = uiScale * -0.20,
    trackingOffsetX = uiScale * 0.14,
    trackingOffsetY = uiScale * -0.34,
  }
end

-- Vanilla AlignPortrait (e17c352 WIIIUI.lua ~1939-1954): portraitFrame is
-- uiScale square, anchored BOTTOMLEFT of minimapFrame's BOTTOMRIGHT with no
-- offset.
function WIIIUI.Theme.PortraitGeometry(uiScale)
  return {
    size = uiScale,
    anchorOffsetX = 0,
    anchorOffsetY = 0,
  }
end

-- Vanilla AlignActionBarUIGrid (e17c352 WIIIUI.lua ~2695-2739): the grid
-- frame is uiScale*0.91851 square, anchored BOTTOMLEFT of extensionBackground.
-- Slots 2-4 chain BOTTOMLEFT-to-BOTTOMRIGHT off the previous slot. Only the
-- unconditional numbers are ported here; the hideGride/nightelf
-- parent-swapping in that function is frame visibility/parenting, out of
-- scope until the grid frames themselves are built.
function WIIIUI.Theme.GridGeometry(uiScale)
  return {
    size = uiScale * 0.91851,
    originOffsetX = uiScale * 0.2 - uiScale * 0.01666666667,
    originOffsetY = 1,
    slot2OffsetX = uiScale * -0.4518,
    slot3OffsetX = uiScale * -0.4518,
    slot4OffsetX = uiScale * -0.6115 + 2,
  }
end

-- Vanilla AlignMiddleExtension's extensionBackground block (e17c352
-- WIIIUI.lua ~2795-2799, the tail of that function): extensionBackground is
-- uiScale*2.1 wide, uiScale*0.5 tall, anchored BOTTOMLEFT of the portrait's
-- BOTTOMRIGHT. The ext1/ext2/ext3 branchy positioning above it stays out of
-- scope for this slice.
function WIIIUI.Theme.ExtensionBackgroundGeometry(uiScale)
  return {
    width = uiScale * 2.1,
    height = uiScale * 0.5,
    offsetX = uiScale * -0.18,
    offsetY = 0,
  }
end

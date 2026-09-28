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

-- Vanilla AlignRightPart, the rightPart_middle/rightPart_left block
-- (e17c352 WIIIUI.lua:3438-3456): rightPart_middle is (uiScale +
-- uiScale*0.01851) wide, uiScale tall, anchored BOTTOMLEFT to
-- actionSlotGrid_4's BOTTOMRIGHT. rightPart_left is uiScale/2 wide, uiScale
-- tall, anchored BOTTOMRIGHT to rightPart_middle's BOTTOMLEFT at
-- rightPart_left:GetWidth()/2 (i.e. uiScale/4) + uiScale*0.1. Per-theme
-- pixel nudges (human -2/-2, orc -1/-1, undead -1/-0, confirmed at
-- WIIIUI.lua:3446-3456) subtract from both offsets; nightelf has no branch
-- in vanilla and any other theme name resolves like TexturePath does (bogus
-- -> orc), so both fall through to the orc/default nudge via
-- ResolveThemeName.
local RIGHT_PART_NUDGES = {
  human = { middle = 2, left = 2 },
  orc = { middle = 1, left = 1 },
  undead = { middle = 1, left = 0 },
}

-- Vanilla AlignRightPart, the WIIIUI_rightpartBackground block (e17c352
-- WIIIUI.lua:3495-3497): width is the caller-resolved rightPartWidth
-- (uiScale*2.2 derived default when unset, e17c352 WIIIUI.lua:4545-4546 --
-- resolved by the caller, not here, since the derivation reads
-- wc3UI_Options directly and this function stays a pure uiScale/theme-free
-- calculation like the other *Geometry functions); height is
-- uiScale*0.5578 + moveChatAreaUp; anchored BOTTOMLEFT to rightPart_left's
-- BOTTOMRIGHT at a constant offset of 3,0 (not per-theme, not uiScale-scaled).
function WIIIUI.Theme.RightPartBackgroundGeometry(uiScale, rightPartWidth, moveChatAreaUp)
  return {
    width = rightPartWidth,
    height = uiScale * 0.5578 + moveChatAreaUp,
    offsetX = 3,
    offsetY = 0,
  }
end

-- Vanilla AlignRightPart, the lid block (e17c352 WIIIUI.lua:3485-3493):
-- Wc3_UI_right_lid is uiScale square, anchored BOTTOMLEFT to
-- rightPart_middle's BOTTOMLEFT at offset (uiScale*0.2833333333 -
-- shiftWidth, uiScale*-0.3166 + moveChatAreaUp). shiftWidth subtracts from
-- the x offset for undead only (e17c352 WIIIUI.lua:3486-3488); no branch
-- for any other theme.
local RIGHT_LID_SHIFT_WIDTH_THEMES = {
  undead = true,
}

function WIIIUI.Theme.RightLidGeometry(uiScale, theme, moveChatAreaUp)
  local resolved = WIIIUI.Theme.ResolveThemeName(theme)
  local shiftWidth = RIGHT_LID_SHIFT_WIDTH_THEMES[resolved] and uiScale * 0.0185185 or 0

  return {
    size = uiScale,
    offsetX = uiScale * 0.2833333333 - shiftWidth,
    offsetY = uiScale * -0.3166 + moveChatAreaUp,
  }
end

-- Vanilla AlignRightPart, the "Increase the size of the lower right area
-- (chat area)" block (e17c352 WIIIUI.lua:3457-3483): Wc3_UI_bottom_right_
-- top/middle/bottom all anchor BOTTOMLEFT to UIParent's own BOTTOMRIGHT
-- corner (not a WIIIUI frame). Top and bottom are theme-independent.
-- Middle's height carries a human/undead extraHeight term
-- (uiScale*0.022222, e17c352 WIIIUI.lua:3464-3468); the trailing
-- +uiScale*0.0208333 term (e17c352 WIIIUI.lua:3472) is dropped only for
-- human (e17c352 WIIIUI.lua:3476-3478), kept for every other theme.
local CHAT_AREA_EXTRA_HEIGHT_THEMES = {
  human = true,
  undead = true,
}

function WIIIUI.Theme.ChatAreaGeometry(uiScale, theme, moveChatAreaUp)
  local resolved = WIIIUI.Theme.ResolveThemeName(theme)
  local extraHeight = CHAT_AREA_EXTRA_HEIGHT_THEMES[resolved] and uiScale * 0.022222 or 0
  local middleHeight = uiScale - uiScale * 0.5 + moveChatAreaUp + extraHeight

  if resolved ~= "human" then
    middleHeight = middleHeight + uiScale * 0.0208333
  end

  return {
    topWidth = uiScale,
    topHeight = uiScale / 4,
    topOffsetX = uiScale * -0.7259,
    topOffsetY = uiScale * 0.5208 + moveChatAreaUp,
    middleWidth = uiScale / 16,
    middleHeight = middleHeight,
    middleOffsetX = uiScale * -0.0625,
    middleOffsetY = 0,
    bottomWidth = uiScale,
    bottomHeight = uiScale / 8,
    bottomOffsetX = uiScale * -0.7259,
    bottomOffsetY = 0,
  }
end

-- Vanilla AlignRightPart, the extension-filler block (e17c352
-- WIIIUI.lua:3496-3550): the 6 filler textures anchor off rightPart_middle
-- (top1/bottom1) then chain off each other's bottom piece (top2/bottom2 off
-- bottom1, top3/bottom3 off bottom2). alignExtraHorizontal
-- (e17c352 WIIIUI.lua:3496-3505) is unconditional uiScale-threshold position
-- math (not a Show/Hide quirk), so it's in scope for "base position": 0
-- below 250, -3 from 250-259, -6 above 259. The Show/Hide toggles guarding
-- filler visibility (e17c352 WIIIUI.lua:3515-3560) and the undead-only
-- re-aligner (e17c352 WIIIUI.lua:3562+) that resizes/repositions these same
-- textures per exact uiScale value are this slice's documented deferral, not
-- built here.
function WIIIUI.Theme.RightFillerGeometry(uiScale, moveChatAreaUp)
  local alignExtraHorizontal = 0

  if uiScale >= 250 and uiScale <= 259 then
    alignExtraHorizontal = -3
  elseif uiScale > 259 then
    alignExtraHorizontal = -6
  end

  return {
    topWidth = uiScale / 2,
    topHeight = uiScale / 4,
    bottomWidth = uiScale / 2,
    bottomHeight = uiScale / 16,

    top1OffsetX = uiScale * -0.09 + alignExtraHorizontal,
    top1OffsetY = uiScale * 0.5206 + moveChatAreaUp,
    bottom1OffsetX = uiScale * -0.03703,
    bottom1OffsetY = 0,

    top2OffsetX = uiScale * 0.2291 + alignExtraHorizontal,
    top2OffsetY = uiScale * 0.5206 + moveChatAreaUp,
    bottom2OffsetX = uiScale * 0.2768,
    bottom2OffsetY = 0,

    top3OffsetX = uiScale * 0.2291 + alignExtraHorizontal,
    top3OffsetY = uiScale * 0.5206 + moveChatAreaUp,
    bottom3OffsetX = uiScale * 0.2768,
    bottom3OffsetY = 0,
  }
end

-- Vanilla AlignHealthMana (e17c352 WIIIUI.lua:1987-1992, 2009-2014): both
-- bars anchor BOTTOMLEFT to minimapFrame's BOTTOMRIGHT (minimapFrame there
-- is Wc3_UI_minimap itself, per Console.lua's BuildLeft's own citation of
-- this same vanilla naming quirk -- the minimap texture, not the left
-- console frame) at uiScale*-0.147, <Y>;
-- width uiScale*0.27, height uiScale*0.03. Y is uiScale*0.07 for the health
-- bar (slot 1) and uiScale*0.02 for the power bar (slot 2) -- a
-- uiScale*0.05 step down per slot, derived from those two known offsets so
-- slotIndex generalizes to a later inserted bar (0002's druid "form" bar,
-- spec 0004 §Phase-boundary) without a new hardcoded constant per bar.
function WIIIUI.Theme.BarGeometry(uiScale, slotIndex)
  return {
    width = uiScale * 0.27,
    height = uiScale * 0.03,
    offsetX = uiScale * -0.147,
    offsetY = uiScale * 0.07 - (slotIndex - 1) * uiScale * 0.05,
  }
end

-- Vanilla AlignActionBars (e17c352 WIIIUI.lua:2639-2667): button size and
-- horizontal spacing within a row. row2/row3 stack the multi-bar rows above
-- the bottom row by one button height plus a fixed uiScale-scaled gap each
-- (e17c352 WIIIUI.lua:2660, 2665: extraY = actionButton:GetHeight() +
-- uiScale*0.0667, then + actionButton:GetHeight() + uiScale*0.04444);
-- actionButton:GetHeight() there equals size, so the port computes both
-- purely from uiScale rather than reading a built button's height back.
-- The per-index pixel nudges vanilla applies at buttons 7/10/12
-- (WIIIUI.lua:2560-2574, mostly commented out in vanilla itself) are a
-- documented deferral, same convention as Console.lua's filler-nudge notes.
function WIIIUI.Theme.ActionButtonGeometry(uiScale)
  local size = uiScale * 0.11111

  return {
    size = size,
    spacing = uiScale * 0.159259,
    row2OffsetY = size + uiScale * 0.0667,
    row3OffsetY = size + uiScale * 0.0667 + size + uiScale * 0.04444,
  }
end

-- Vanilla AlignZoneText (e17c352 WIIIUI.lua:1878-1889): ZoneTextPos 1/2 pick
-- the Y offset (BOTTOM-anchored to Minimap, e17c352 WIIIUI.lua:1830, 1883,
-- 1885); 3 hides the button outright. Blizzard.lua's BuildZoneText reads
-- this and existence-checks the frame itself (spec 0001 §1.6 "depend on the
-- spike").
function WIIIUI.Theme.ZoneTextGeometry(uiScale, pos)
  if pos == 3 then
    return { hidden = true }
  end

  local offsetY = 1

  if pos == 2 then
    offsetY = uiScale * 0.5
  end

  return { hidden = false, offsetY = offsetY }
end

-- Vanilla AlignMinimap's mail block (e17c352 WIIIUI.lua:1834-1837): only the
-- unconditional (non-theme-conditional) offsets -- the human/orc
-- uiScale-threshold extraAlign fine-tune (e17c352 WIIIUI.lua:1839-1858) is a
-- documented deferral, same convention as RightFillerGeometry's above.
function WIIIUI.Theme.MailIndicatorGeometry(uiScale)
  return {
    offsetX = uiScale * -0.0054,
    offsetY = uiScale * 0.18,
    iconSize = uiScale * 0.085 - 3,
  }
end

function WIIIUI.Theme.RightPartGeometry(uiScale, theme)
  local nudge = RIGHT_PART_NUDGES[WIIIUI.Theme.ResolveThemeName(theme)] or { middle = 0, left = 0 }
  local leftWidth = uiScale / 2

  return {
    middleWidth = uiScale + uiScale * 0.01851,
    middleHeight = uiScale,
    middleOffsetX = uiScale * -0.2479 - nudge.middle,
    middleOffsetY = -1,
    leftWidth = leftWidth,
    leftHeight = uiScale,
    leftOffsetX = leftWidth / 2 + uiScale * 0.1 - nudge.left,
    leftOffsetY = 0,
  }
end

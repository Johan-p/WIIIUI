-- spec 0001 §A.3-A.4, §Settings schema: WIIIUI namespace + defaults merge.
local _, WIIIUI = ...
_G.WIIIUI = WIIIUI

-- spec 0001 §Settings schema: full key set from CLAUDE.md -> Domain model,
-- plus EnableCustomize/edit_theme_settings (added to DEFAULTS) and the
-- "Set in Edit Mode" keys (kept, no control renders them). rightPartWidth
-- is intentionally absent: its default is derived from uiScale at read time.
WIIIUI.DEFAULTS = {
  theme = "orc",
  uiScale = 240,
  moveChatAreaUp = 10,
  hpWarning = 25,
  xpRestedXpColor = { 0, 0, 1, 0.5 },
  weaponIconSelected1 = 16,
  weaponIconSelected2 = "none",
  weaponIconSelected3 = "none",
  portraitScale = 0,
  PortraitAlignmentX = 100,
  PortraitAlignmentY = 100,
  shapeshiftAuraPos = 2,
  castbarAlignmentOption = 190,
  HealthPercent = false,
  PowerPercent = false,
  MultiBarRightHorizontal = false,
  MultiBarLeftHorizontal = false,
  chatInputAbove = false,
  hideGride = false,
  HideChatArrows = false,
  StopAnimation = false,
  hideMicroButtons = true,
  hideBagsAboveChatFrame = true,
  buffTopRight = true,
  ZoneTextPos = 1,
  ultraWide = false,
  centerSlim = false,
  centerSlimNoInv = false,
  EnableCustomize = false,
  edit_theme_settings = {},
}

-- Clamp ranges applied on load (spec 0001 §Settings schema); castbarAlignmentOption
-- is kept but unused, so it has no clamp.
local CLAMPS = {
  hpWarning = { 1, 99 },
  uiScale = { 240, 270 },
  moveChatAreaUp = { 0, 150 },
  portraitScale = { 0, 35 },
  PortraitAlignmentX = { 0, 200 },
  PortraitAlignmentY = { 0, 200 },
}

local function deepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for k, v in pairs(value) do
    copy[k] = deepCopy(v)
  end
  return copy
end

local function clamp(value, low, high)
  if value < low then
    return low
  elseif value > high then
    return high
  end
  return value
end

function WIIIUI.MergeDefaults(saved)
  local merged = {}

  -- Unknown keys are kept as-is.
  for key, value in pairs(saved or {}) do
    merged[key] = value
  end

  -- Missing keys are added; a wrong-type key is reset to the default.
  -- Table defaults are deep-copied so callers never share DEFAULTS' tables.
  for key, value in pairs(WIIIUI.DEFAULTS) do
    local current = merged[key]
    if current == nil or type(current) ~= type(value) then
      merged[key] = deepCopy(value)
    end
  end

  for key, range in pairs(CLAMPS) do
    merged[key] = clamp(merged[key], range[1], range[2])
  end

  return merged
end

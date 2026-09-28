-- spec 0001 §Module split "Bars.lua": health/power bars + text, power
-- colour by UnitPowerType token (C1). Vanilla AlignHealthMana (e17c352
-- WIIIUI.lua:1980-2059) reused Blizzard's PlayerFrameHealthBar/
-- PlayerFrameManaBar, reparented to UIParent; PlayerFrame is now retired
-- (R2, Core.lua's WIIIUI.Retire), which hides its children too, so this
-- slice builds WIIIUI's own StatusBar frames at the same position/size
-- instead. % text, the HP gradient and the low-HP pulse are secret-value
-- guarded and land in slice 09 (this slice's own Notes); text stays the raw
-- "cur / max" concatenation, which CLAUDE.md's secret-value rules allow
-- unguarded (concatenation, SetValue and SetMinMaxValues are all sanctioned
-- secret-tolerant operations).
local _, WIIIUI = ...

WIIIUI.Bars = WIIIUI.Bars or {}

-- WIIIUI ships no bar art of its own (vanilla borrowed Blizzard's own
-- PlayerFrameHealthBar/PlayerFrameManaBar texture, which is gone once
-- PlayerFrame is retired). WHITE8X8 is the universal Blizzard texture the
-- maintainer's DruidHUD project already validated in-game on Forever for
-- exactly this purpose (sister project, same Forever/retail standards,
-- CLAUDE.md status header).
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"

-- Vanilla never sets a static health-bar colour in AlignHealthMana itself
-- (Blizzard's own texture supplied it); the dynamic HP gradient
-- (HPBarDamageGradiant, e17c352 WIIIUI.lua:3975-4003) is secret-guarded and
-- deferred to slice 09 per this slice's own Notes. This is a static
-- placeholder until that lands.
local HEALTH_BAR_DEFAULT_COLOR_R, HEALTH_BAR_DEFAULT_COLOR_G, HEALTH_BAR_DEFAULT_COLOR_B = 0, 1, 0

-- Vanilla AlignHealthMana (e17c352 WIIIUI.lua:1999, 2018): health text at
-- font size 10, power text at 9, same theme font as the rest of the console
-- (CLAUDE.md "the look is the specification").
local FONT_PATH = "Interface\\Addons\\WIIIUI\\art\\other\\fonts\\blq55.TTF"
local FONT_SIZES = { health = 10, power = 9 }

-- spec 0004 §Phase-boundary "0002 druid resource bar": "(1) Bars.lua builds
-- bars from a list { "health", "power" } with a slotIndex." 0002 inserts
-- "form" between them; kept as an ordered list (not two hardcoded blocks)
-- so that insertion only touches this line, not BuildBars' body.
local BAR_DEFS = { "health", "power" }

local function updateHealth()
  local bar = WIIIUI.Bars.health
  if not bar then
    return
  end

  bar:SetMinMaxValues(0, UnitHealthMax("player"))
  bar:SetValue(UnitHealth("player"))

  if bar.text then
    bar.text:SetText(UnitHealth("player") .. " / " .. UnitHealthMax("player"))
  end
end

local function updatePower()
  local bar = WIIIUI.Bars.power
  if not bar then
    return
  end

  bar:SetMinMaxValues(0, UnitPowerMax("player"))
  bar:SetValue(UnitPower("player"))

  if bar.text then
    bar.text:SetText(UnitPower("player") .. " / " .. UnitPowerMax("player"))
  end

  -- spec 0001 §Event -> widget wiring: "colour by UnitPowerType token
  -- (vanilla colours)". PowerBarColor is Blizzard's own table
  -- (Blizzard_UnitFrame/Mainline/PowerBarColorUtil.lua on the forever
  -- branch) -- its MANA/RAGE/ENERGY entries (r=0,g=0,b=1 / r=1,g=0,b=0 /
  -- r=1,g=1,b=0) are exactly vanilla's ResetPowerBarColor (e17c352
  -- WIIIUI.lua:3862-3873), and it covers every other power type too without
  -- inventing new colours. Existence-checked: PowerBarColor is a Blizzard
  -- global, not guaranteed by the test stub.
  local _, token = UnitPowerType("player")
  local color = PowerBarColor and PowerBarColor[token]

  if color then
    bar:SetStatusBarColor(color.r, color.g, color.b, 1)
  end
end

-- Vanilla AlignHealthMana (e17c352 WIIIUI.lua:1987-1992, 2009-2014): both
-- bars anchor to minimapFrame (the minimap art texture, WIIIUI.Console.left.
-- minimapTexture -- see BuildLeft's own citation of this same vanilla
-- naming quirk). Console.BuildLeft/BuildGrid/BuildRight already ran earlier
-- in this same WIIIUI.Layout() call (Core.lua's canonical module order), so
-- the minimap texture exists by the time this runs.
function WIIIUI.Bars.BuildBars()
  local uiScale = wc3UI_Options.uiScale
  local left = WIIIUI.Console.left
  local minimapTexture = left and left.minimapTexture

  for slotIndex, key in ipairs(BAR_DEFS) do
    local bar = WIIIUI.Bars[key]

    if not bar then
      bar = CreateFrame("StatusBar", nil, UIParent)
      bar:SetStatusBarTexture(BAR_TEXTURE)
      bar.text = bar:CreateFontString(nil, "OVERLAY")
      bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
      bar.text:SetFont(FONT_PATH, FONT_SIZES[key], "")
      WIIIUI.Bars[key] = bar
    end

    local geometry = WIIIUI.Theme.BarGeometry(uiScale, slotIndex)

    bar:SetFrameStrata("LOW")
    bar:SetSize(geometry.width, geometry.height)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", minimapTexture, "BOTTOMRIGHT", geometry.offsetX, geometry.offsetY)
  end

  WIIIUI.Bars.health:SetStatusBarColor(
    HEALTH_BAR_DEFAULT_COLOR_R,
    HEALTH_BAR_DEFAULT_COLOR_G,
    HEALTH_BAR_DEFAULT_COLOR_B,
    1
  )

  updateHealth()
  updatePower()
end

-- spec 0001 §Event -> widget wiring, all via RegisterUnitEvent(event,
-- "player") (WIIIUI.On's unit form). Registered once at file scope, like
-- Core.lua's own ADDON_LOADED/PLAYER_LOGIN/UI_SCALE_CHANGED handlers --
-- BuildBars() itself stays idempotent and event-free, matching Console.lua's
-- Build* convention.
WIIIUI.On("UNIT_HEALTH", updateHealth, "player")
WIIIUI.On("UNIT_MAXHEALTH", updateHealth, "player")
WIIIUI.On("UNIT_POWER_UPDATE", updatePower, "player")
WIIIUI.On("UNIT_MAXPOWER", updatePower, "player")
WIIIUI.On("UNIT_DISPLAYPOWER", updatePower, "player")

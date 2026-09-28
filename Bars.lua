-- spec 0001 §Module split "Bars.lua": health/power bars + text, power
-- colour by UnitPowerType token (C1), plus §1.2's secret-safe % text, HP
-- gradient and low-HP pulse. Vanilla AlignHealthMana (e17c352
-- WIIIUI.lua:1980-2059) reused Blizzard's PlayerFrameHealthBar/
-- PlayerFrameManaBar, reparented to UIParent; PlayerFrame is now retired
-- (R2, Core.lua's WIIIUI.Retire), which hides its children too, so this
-- file builds WIIIUI's own StatusBar frames at the same position/size
-- instead. The raw "cur / max" text (default) is CLAUDE.md's own sanctioned
-- unguarded route (concatenation, SetValue and SetMinMaxValues are all
-- secret-tolerant); % text, the gradient and the pulse go through
-- WIIIUI.Safe (Core.lua) since they touch UnitHealthPercent/
-- UnitPowerPercent's SecretReturns results.
local _, WIIIUI = ...

WIIIUI.Bars = WIIIUI.Bars or {}

-- WIIIUI ships no bar art of its own (vanilla borrowed Blizzard's own
-- PlayerFrameHealthBar/PlayerFrameManaBar texture, which is gone once
-- PlayerFrame is retired). WHITE8X8 is the universal Blizzard texture the
-- maintainer's DruidHUD project already validated in-game on Forever for
-- exactly this purpose (sister project, same Forever/retail standards,
-- CLAUDE.md status header).
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"

-- Vanilla LowHPWarning (e17c352 WIIIUI.lua:3875-3939): the low-HP flash
-- lives on PortraitBackground, ported forward here per spec 0001's
-- architecture note ("Bars.lua ... low-HP pulse ... Every secret-value
-- guard lives here"). white_background.tga already ships in art/other/
-- (the same file vanilla toggled between white_background/black_background
-- -- this port uses SetVertexColor for the fixed red tint instead, spec
-- 0001 §1.2, so only one of the two files is needed).
local LOW_HP_TEXTURE = "Interface\\Addons\\WIIIUI\\art\\other\\white_background"
local LOW_HP_OVERLAY_WIDTH_FRACTION = 0.35
local LOW_HP_OVERLAY_HEIGHT_FRACTION = 0.35
local LOW_HP_OVERLAY_HEIGHT_PAD = 20
local LOW_HP_PULSE_DURATION = 1

-- Vanilla never sets a static health-bar colour in AlignHealthMana itself
-- (Blizzard's own texture supplied it). This is the fallback colour the bar
-- keeps whenever the secret-guarded HP gradient (below) fails to build or
-- apply -- vanilla HPBarDamageGradiant's own 100%-health colour (e17c352
-- WIIIUI.lua:3975-4003: g=1 at healthPercent=1).
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

-- spec 0001 §1.2: "Health % text (HealthPercent) ... fs:SetFormattedText(
-- '%.0f%%', UnitHealthPercent('player', true, CurveConstants.ScaleTo100))
-- inside pcall ... Fallback: falls back to cur / max text." The guard seam
-- is WIIIUI.Safe (Core.lua); CurveConstants.ScaleTo100 is Blizzard's own
-- pre-built curve (Blizzard_SharedXMLBase/CurveConstants.lua), not one
-- WIIIUI builds.
local function setHealthText(bar)
  if wc3UI_Options.HealthPercent then
    local ok = WIIIUI.Safe(function()
      bar.text:SetFormattedText("%.0f%%", UnitHealthPercent("player", true, CurveConstants.ScaleTo100))
    end)
    if ok then
      return
    end
  end

  bar.text:SetText(UnitHealth("player") .. " / " .. UnitHealthMax("player"))
end

-- spec 0001 §1.2: "Power % text (PowerPercent) ... Same with
-- UnitPowerPercent('player', nil, false, CurveConstants.ScaleTo100)."
local function setPowerText(bar)
  if wc3UI_Options.PowerPercent then
    local ok = WIIIUI.Safe(function()
      bar.text:SetFormattedText("%.0f%%", UnitPowerPercent("player", nil, false, CurveConstants.ScaleTo100))
    end)
    if ok then
      return
    end
  end

  bar.text:SetText(UnitPower("player") .. " / " .. UnitPowerMax("player"))
end

-- spec 0001 §1.2: "HP gradient ... One ColorCurve built at login: 0 -> red,
-- 0.5 -> yellow, 1 -> green (the vanilla r,g formula sampled at 0/0.5/1,
-- linear)." Vanilla HPBarDamageGradiant (e17c352 WIIIUI.lua:3975-4003):
-- healthPercent<0.5 -> r=1,g=2*healthPercent,b=0 (0%=red, 50%=yellow);
-- else -> r=2*(1-healthPercent),g=1,b=0 (50%=yellow, 100%=green) -- exactly
-- the three sampled points below. Built lazily (not at file/module load)
-- and cached, so a missing C_CurveUtil/AddPoint/CreateColor API (spec 0001
-- §1.2's own "Unverified" list) degrades this one feature via WIIIUI.Safe
-- instead of erroring Bars.lua's whole load. ScriptObject_ColorCurveObject
-- (warcraft.wiki.gg): "AddPoint takes an x and y value; ... the y should be
-- a ColorMixin structure", built via CreateColor(r,g,b) (SharedXML/
-- Color.lua via FrameXML/Util.lua).
-- healthColorCurveFailed*/fingerprint cache a build failure (missing
-- C_CurveUtil/CreateColor) so a known-failing build isn't retried on every
-- UNIT_HEALTH/UNIT_MAXHEALTH event -- but only while the reason it failed
-- hasn't changed. The fingerprint is a cheap existence check of the two
-- globals the build needs, taken *before* attempting the build; a failure
-- is skipped only when a later call's fingerprint still matches the one
-- recorded at failure time, so a build that starts succeeding again (the
-- globals reappear) still gets retried on the very next call, per spec
-- 0001 §1.2's own degrade-and-recover expectation for this route.
local function healthCurveFingerprint()
  return C_CurveUtil ~= nil and CreateColor ~= nil
end

local healthColorCurve, healthColorCurveFailed, healthColorCurveFailedFingerprint

local function getHealthColorCurve()
  if healthColorCurve then
    return healthColorCurve
  end

  local fingerprint = healthCurveFingerprint()

  if healthColorCurveFailed and healthColorCurveFailedFingerprint == fingerprint then
    return nil
  end

  local ok, curve = WIIIUI.Safe(function()
    local c = C_CurveUtil.CreateColorCurve()
    c:AddPoint(0, CreateColor(1, 0, 0))
    c:AddPoint(0.5, CreateColor(1, 1, 0))
    c:AddPoint(1, CreateColor(0, 1, 0))
    return c
  end)

  if ok then
    healthColorCurve = curve
    healthColorCurveFailed = false
  else
    healthColorCurveFailed = true
    healthColorCurveFailedFingerprint = fingerprint
  end

  return healthColorCurve
end

-- spec 0001 §1.2: "local c = UnitHealthPercent('player', true, curve) ->
-- bar:GetStatusBarTexture():SetVertexColor(c:GetRGB()) in pcall." Leaves
-- the bar's own static SetStatusBarColor (BuildBars) untouched on failure
-- -- that's the "Static vanilla green" fallback the spec's own table names.
local function updateHealthGradient(bar)
  local curve = getHealthColorCurve()
  if not curve then
    return
  end

  WIIIUI.Safe(function()
    local color = UnitHealthPercent("player", true, curve)
    bar:GetStatusBarTexture():SetVertexColor(color:GetRGB())
  end)
end

-- spec 0001 §1.2: "Low-HP pulse ... overlay is a frame holding the red
-- portrait-background texture. Its child texture runs a looping
-- AnimationGroup Alpha 0<->1 (1 s each way, the vanilla timing)." Anchored
-- to left.portraitTexture (not WIIIUI.Portrait.button/model) because
-- Bars.lua's BuildBars runs before Portrait.lua's BuildPortrait in
-- WIIIUI.Layout() (WIIIUI.toc load order) -- the portrait art texture is
-- already built by Console.BuildLeft by the time this runs, matching how
-- Portrait.lua itself anchors its own button to the same texture. Building
-- the animation is plain non-secret widget setup (no unit value involved),
-- so unlike the curve/SetAlpha calls below it isn't wrapped in WIIIUI.Safe.
local function buildLowHpOverlay(anchor, uiScale)
  local overlay = WIIIUI.Bars.lowHpOverlay

  if not overlay then
    overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetFrameStrata("LOW")

    local texture = overlay:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(overlay)
    texture:SetTexture(LOW_HP_TEXTURE)
    texture:SetVertexColor(1, 0, 0, 1)

    -- "Its child texture runs a looping AnimationGroup Alpha 0<->1" --
    -- BOUNCE plays the single 0->1 animation forward then backward each
    -- cycle, giving the 1s-each-way ping-pong with one animation instead
    -- of two (warcraft.wiki.gg API_AnimationGroup_SetLooping).
    local animGroup = texture:CreateAnimationGroup()
    local pulse = animGroup:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0)
    pulse:SetToAlpha(1)
    pulse:SetDuration(LOW_HP_PULSE_DURATION)
    animGroup:SetLooping("BOUNCE")
    animGroup:Play()

    overlay.texture = texture
    overlay.animGroup = animGroup
    WIIIUI.Bars.lowHpOverlay = overlay
  end

  overlay:ClearAllPoints()
  if anchor then
    overlay:SetPoint("CENTER", anchor, "CENTER", 0, 0)
  end
  overlay:SetSize(
    uiScale * LOW_HP_OVERLAY_WIDTH_FRACTION,
    uiScale * LOW_HP_OVERLAY_HEIGHT_FRACTION + LOW_HP_OVERLAY_HEIGHT_PAD
  )

  return overlay
end

-- spec 0001 §1.2: "A Step curve with points (0,1), (hpWarning/100,1),
-- (hpWarning/100+0.0001,0), (1,0) ... The curve is rebuilt when hpWarning
-- changes." Cached alongside the threshold it was built for (not just
-- built once at login) so this file alone -- without a Config.lua hook --
-- notices a changed wc3UI_Options.hpWarning on the next health event.
-- lowHpCurveFailed*/fingerprint cache a build failure (missing
-- Enum.LuaCurveType/C_CurveUtil) against the threshold *and* the
-- prerequisite-existence fingerprint it failed at (same reasoning as
-- healthCurveFingerprint above), so a known-failing build isn't retried on
-- every health event, but still recovers on the next event once the
-- missing piece reappears, without waiting for hpWarning to change.
local function lowHpCurveFingerprint()
  return C_CurveUtil ~= nil and Enum ~= nil and Enum.LuaCurveType ~= nil
end

local lowHpCurve, lowHpCurveThreshold
local lowHpCurveFailed, lowHpCurveFailedThreshold, lowHpCurveFailedFingerprint

local function getLowHpCurve()
  local threshold = wc3UI_Options.hpWarning

  if lowHpCurve and lowHpCurveThreshold == threshold then
    return lowHpCurve
  end

  local fingerprint = lowHpCurveFingerprint()

  if
    lowHpCurveFailed
    and lowHpCurveFailedThreshold == threshold
    and lowHpCurveFailedFingerprint == fingerprint
  then
    return nil
  end

  local ok, curve = WIIIUI.Safe(function()
    local cutoff = threshold / 100
    local c = C_CurveUtil.CreateCurve()
    c:SetType(Enum.LuaCurveType.Step)
    c:AddPoint(0, 1)
    c:AddPoint(cutoff, 1)
    c:AddPoint(cutoff + 0.0001, 0)
    c:AddPoint(1, 0)
    return c
  end)

  if ok then
    lowHpCurve = curve
    lowHpCurveThreshold = threshold
    lowHpCurveFailed = false
  else
    lowHpCurve = nil
    lowHpCurveThreshold = nil
    lowHpCurveFailed = true
    lowHpCurveFailedThreshold = threshold
    lowHpCurveFailedFingerprint = fingerprint
  end

  return lowHpCurve
end

-- spec 0001 §1.2: "overlay:SetAlpha(UnitHealthPercent('player', true,
-- stepCurve)) ... Effective alpha = parent (secret 0/1) x child (animated),
-- so there is no comparison, no arithmetic and no OnUpdate." Never calls
-- Show/Hide based on the secret result itself -- only WIIIUI.Safe's own ok
-- flag (a plain boolean, not a unit value) drives the one degrade action.
local function updateLowHpPulse()
  local overlay = WIIIUI.Bars.lowHpOverlay
  if not overlay then
    return
  end

  local curve = getLowHpCurve()
  if not curve then
    overlay:Hide()
    return
  end

  local ok = WIIIUI.Safe(function()
    overlay:SetAlpha(UnitHealthPercent("player", true, curve))
  end)

  if ok then
    overlay:Show()
  else
    overlay:Hide()
  end
end

local function updateHealth()
  local bar = WIIIUI.Bars.health
  if not bar then
    return
  end

  bar:SetMinMaxValues(0, UnitHealthMax("player"))
  bar:SetValue(UnitHealth("player"))

  if bar.text then
    setHealthText(bar)
  end

  updateHealthGradient(bar)
  updateLowHpPulse()
end

local function updatePower()
  local bar = WIIIUI.Bars.power
  if not bar then
    return
  end

  bar:SetMinMaxValues(0, UnitPowerMax("player"))
  bar:SetValue(UnitPower("player"))

  if bar.text then
    setPowerText(bar)
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

      -- CLAUDE.md "Tech stack quirks": "FontString:SetFont returns success
      -- on Forever; the pattern stays: set the font object, then SetFont,
      -- then confirm with GetFont(), fall back to a Blizzard font object."
      -- GameFontHighlightSmall (FrameXML/Fonts.xml) is the safety net set
      -- first and re-applied if the custom theme font doesn't take;
      -- FontInstance:SetFontObject/GetFont, warcraft.wiki.gg.
      bar.text:SetFontObject(GameFontHighlightSmall)
      local fontApplied = bar.text:SetFont(FONT_PATH, FONT_SIZES[key], "")

      if not fontApplied or not bar.text:GetFont() then
        bar.text:SetFontObject(GameFontHighlightSmall)
      end

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

  buildLowHpOverlay(left and left.portraitTexture, uiScale)

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

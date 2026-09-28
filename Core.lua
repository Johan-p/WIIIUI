-- spec 0001 §A.3-A.4, §Settings schema: WIIIUI namespace + defaults merge.
local ADDON, WIIIUI = ...
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

-- spec 0001 §Settings schema: weaponIconSelected1..3 legitimately hold either
-- a number or "none", with a different-typed default per slot -- the generic
-- type(current) ~= type(value) branch below would wipe a valid cross-type
-- saved value, so these three keys validate against the allowed set instead.
local WEAPON_ICON_KEYS = {
  weaponIconSelected1 = true,
  weaponIconSelected2 = true,
  weaponIconSelected3 = true,
}

local WEAPON_ICON_VALUES = {
  [16] = true,
  [17] = true,
  [18] = true,
  [0] = true,
  [98] = true,
  [99] = true,
  ["none"] = true,
}

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
    if WEAPON_ICON_KEYS[key] then
      if current == nil or not WEAPON_ICON_VALUES[current] then
        merged[key] = value
      end
    elseif current == nil or type(current) ~= type(value) then
      merged[key] = deepCopy(value)
    end
  end

  for key, range in pairs(CLAMPS) do
    merged[key] = clamp(merged[key], range[1], range[2])
  end

  return merged
end

-- spec 0001 §A.3: the one apply-now-or-queue-to-PLAYER_REGEN_ENABLED seam
-- (CLAUDE.md "Combat lockdown"). pending/order are file-scope upvalues, not
-- WIIIUI table fields, because they are this seam's private implementation
-- state; nothing outside ApplyOrQueue/Flush reads or writes them.
local pending, order = {}, {}

function WIIIUI.ApplyOrQueue(key, fn)
  if InCombatLockdown() then
    if not pending[key] then
      order[#order + 1] = key
    end
    pending[key] = fn
    return false
  end
  fn()
  return true
end

function WIIIUI.Flush()
  -- Swap the tables out before iterating so the queue is empty (and safe to
  -- refill) even if a queued function errors; pcall so one error doesn't
  -- stop the rest from running (spec 0001 §A.3).
  local runOrder, runPending = order, pending
  pending, order = {}, {}
  for _, key in ipairs(runOrder) do
    pcall(runPending[key])
  end
end

-- spec 0001 §1.2/§A.3: "The guard seam is WIIIUI.Safe(fn, ...), which
-- returns ok, result." / "WIIIUI.Safe(fn, ...) = pcall." The one
-- secret-value guard seam (CLAUDE.md "Secret-value tolerant"): every
-- HP/power-percent-text, HP-gradient, low-HP-pulse and portrait-combat-text
-- call site that might touch a secret unit value goes through this instead
-- of a bare pcall of its own.
function WIIIUI.Safe(fn, ...)
  return pcall(fn, ...)
end

-- spec 0001 §A.3: "WIIIUI.hider is an unnamed hidden Frame." Reused here as
-- the event-dispatch frame too -- the spec names one frame field on WIIIUI
-- for this purpose and forbids nothing about it also carrying OnEvent, and
-- a second unnamed frame the spec doesn't ask for would be speculative.
WIIIUI.hider = CreateFrame("Frame")
WIIIUI.hider:Hide()

-- spec 0001 §A.3: "Event dispatch: WIIIUI.On(event, fn, unit), which uses
-- RegisterUnitEvent when unit is given." fn receives only the OnEvent
-- payload (everything after self, event) -- not the event name -- because
-- callers already know the event they registered for.
local handlers = {}

-- Tracks which unit (or false for "no unit") each event was first registered
-- with, so a later WIIIUI.On call for the same event with a different unit
-- filter is caught loudly instead of silently losing the second filter.
local eventUnits = {}

local function dispatch(_, event, ...)
  local list = handlers[event]
  if not list then
    return
  end
  for i = 1, #list do
    list[i](...)
  end
end

WIIIUI.hider:SetScript("OnEvent", dispatch)

function WIIIUI.On(event, fn, unit)
  local unitKey = unit or false
  if not handlers[event] then
    handlers[event] = {}
    eventUnits[event] = unitKey
    if unit then
      WIIIUI.hider:RegisterUnitEvent(event, unit)
    else
      WIIIUI.hider:RegisterEvent(event)
    end
  elseif eventUnits[event] ~= unitKey then
    error("WIIIUI.On: " .. event .. " already registered with a different unit filter", 2)
  end
  handlers[event][#handlers[event] + 1] = fn
end

-- spec 0001 §A.3/§Module split: "WIIIUI.Layout() orchestration" -- the
-- single public entrypoint PLAYER_LOGIN queues through
-- ApplyOrQueue("layout", WIIIUI.Layout) (§A.4). Each region file (Console.lua
-- now; Bars.lua/Portrait.lua/etc. in later phases) owns its own Build*
-- function; Core.lua only calls them, so this list grows without Core.lua
-- depending on any region file existing before it's built.
-- WIIIUI.Buttons is existence-checked (not yet another list entry) because
-- console_test.lua/bars_test.lua/events_test.lua/retire_test.lua load
-- Core/Theme/Console/Bars/Portrait without Buttons.lua and call
-- WIIIUI.Layout() directly (or override Layout to a no-op) -- same
-- existence-check convention as the retire handler below. Portrait stays
-- unconditional (slice 08): every file that calls WIIIUI.Layout() for real
-- already loads Portrait.lua alongside it.
function WIIIUI.Layout()
  WIIIUI.Console.BuildLeft()
  WIIIUI.Console.BuildGrid()
  WIIIUI.Console.BuildRight()
  WIIIUI.Bars.BuildBars()
  WIIIUI.Portrait.BuildPortrait()
  if WIIIUI.Buttons then
    WIIIUI.Buttons.BuildButtons()
  end
  if WIIIUI.Blizzard then
    WIIIUI.Blizzard.BuildMinimap()
    WIIIUI.Blizzard.BuildMicroMenu()
  end
  if WIIIUI.InfoIcons then
    WIIIUI.InfoIcons.BuildWeaponIcons()
  end
  if WIIIUI.Config then
    WIIIUI.Config.BuildConfig()
  end
end

-- spec 0001 §A.4: "ADDON_LOADED('WIIIUI'): merge defaults only."
WIIIUI.On("ADDON_LOADED", function(addonName)
  if addonName ~= ADDON then
    return
  end
  wc3UI_Options = WIIIUI.MergeDefaults(wc3UI_Options)
end)

-- spec 0001 §A.3: "Retire(frame, unregister)" -- the one R2 implementation
-- for a Blizzard system WIIIUI replaces outright, parameterized by frame so
-- a later R2 target (action bars, slice 12; spec 0004 §3: "12 retires the
-- action bars through WIIIUI.Retire, so it uses 07's seam") reuses this same
-- sequence instead of duplicating it. unregister stays a parameter rather
-- than being hardcoded true, though spec 0001 §1.1 "Unregister set" makes
-- it the default on all four current R2 frames (MainActionBar,
-- MultiBarBottomLeft, MultiBarBottomRight, PlayerFrame) -- every call site
-- here passes true. Sequence: existence-checked frame (a resolved-at-call-
-- time frame reference may be nil),
-- UnregisterAllEvents(), existence-checked HideBase() (never Hide(), which
-- runs Blizzard's Edit Mode HideOverride tainted; confirmed via
-- EditModeSystemMixin's "self.HideBase = self.Hide; self.Hide =
-- self.HideOverride" swap, Blizzard_EditMode/Shared/
-- EditModeSystemTemplates.lua:35-36 on the forever branch), then
-- SetParent(WIIIUI.hider). No key purge: this never writes a key onto the
-- frame, only calls its own methods.
function WIIIUI.Retire(frame, unregister)
  if not frame then
    return
  end

  if unregister then
    frame:UnregisterAllEvents()
  end

  if frame.HideBase then
    frame:HideBase()
  end

  frame:SetParent(WIIIUI.hider)
end

-- spec 0001 §A.4: "PLAYER_LOGIN: resolve action bar, build everything once,
-- then ApplyOrQueue('retire'), ApplyOrQueue('layout', WIIIUI.Layout),
-- ApplyOrQueue('bindings')." Retires PlayerFrame (C1, needs
-- UnregisterAllEvents per R2's per-frame list) and builds the console/bars
-- via WIIIUI.Layout(), both out of combat through ApplyOrQueue -- "retire"
-- and "layout" are separate queue keys, so each applies (or queues) on its
-- own; ApplyOrQueue keys its pending/order tables by this string, so there's
-- no collision between the two calls. Resolving the action bar and queuing
-- bindings are later phases, not yet built.
-- spec 0004 §3: "12 retires the action bars through WIIIUI.Retire, so it
-- uses 07's seam" -- WIIIUI.Buttons.RetireBlizzardBars (Buttons.lua,
-- existence-checked the same way as the Layout() call above, since
-- retire_test.lua/older tests load Core.lua alone) joins the same "retire"
-- queue key as PlayerFrame, so both apply (or queue) as one atomic unit.
-- "bindings" is its own queue key per spec 0001 §A.4's PLAYER_LOGIN list --
-- WIIIUI.Buttons.ApplyBindings applies the initial override bindings once at
-- login, in addition to the UPDATE_BINDINGS event Buttons.lua itself
-- registers for later rebinds.
WIIIUI.On("PLAYER_LOGIN", function()
  WIIIUI.ApplyOrQueue("retire", function()
    WIIIUI.Retire(PlayerFrame, true)
    if WIIIUI.Buttons then
      WIIIUI.Buttons.RetireBlizzardBars()
    end
  end)
  WIIIUI.ApplyOrQueue("layout", WIIIUI.Layout)
  if WIIIUI.Buttons then
    WIIIUI.ApplyOrQueue("bindings", WIIIUI.Buttons.ApplyBindings)
  end
end)

-- spec 0001 §A.3: "Flush runs order on PLAYER_REGEN_ENABLED" -- the other
-- half of ApplyOrQueue's combat-lockdown seam; without this, anything queued
-- while in combat is only applied on a manual /reload.
WIIIUI.On("PLAYER_REGEN_ENABLED", function() WIIIUI.Flush() end)

-- spec 0001 §A.4: "Re-layout triggers: UI_SCALE_CHANGED, ...". Config.lua's
-- "every setting change" trigger is wired at its own call site instead
-- (each control row's applyRow() calls WIIIUI.ApplyOrQueue("layout",
-- WIIIUI.Layout) directly, Config.lua); PLAYER_ENTERING_WORLD is still a
-- later phase, needing the frame-lifecycle work built around it. WIIIUI.Layout
-- is looked up by table field each time the handler runs, not captured as an
-- upvalue, so whatever WIIIUI.Layout resolves to at fire time is what runs.
WIIIUI.On("UI_SCALE_CHANGED", function()
  WIIIUI.ApplyOrQueue("layout", WIIIUI.Layout)
end)

-- spec 0001 §A.4 / CLAUDE.md "Tech stack quirks": re-anchor on Edit Mode
-- exit via hooksecurefunc, existence-checked -- EditModeManagerFrame is
-- absent on the test stub by default, and every Blizzard frame lookup in
-- this codebase is existence-checked regardless (R2/R4 conventions).
-- hooksecurefunc only, per CLAUDE.md's "never overwrite a Blizzard function
-- or method".
if EditModeManagerFrame then
  hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
    WIIIUI.ApplyOrQueue("layout", WIIIUI.Layout)
  end)
end

-- spec 0001 §Buttons and paging "WIIIUI/Bindings.xml": "BINDING_HEADER_WIIIUI
-- and the BINDING_NAME_CLICK ... strings ... in Core.lua." BINDING_HEADER_WIIIUI
-- is the Key Bindings UI section title (vanilla's own BINDING_HEADER_WC3HEADER
-- string, e17c352 WIIIUI.lua:3); the 9 BINDING_NAME_CLICK labels are vanilla's
-- own Bindings.xml label text, in the same order (minimap top/middle/bottom,
-- then inventory TL/TR/ML/MR/BL/BR) -- "_G["BINDING_NAME_" .. command]"
-- convention, warcraft.wiki.gg Bindings.xml.
BINDING_HEADER_WIIIUI = "Warcraft III - UI"
_G["BINDING_NAME_CLICK WIIIUI_Extra1:LeftButton"] = "Top Minimap Button"
_G["BINDING_NAME_CLICK WIIIUI_Extra2:LeftButton"] = "Middle Minimap Button"
_G["BINDING_NAME_CLICK WIIIUI_Extra3:LeftButton"] = "Bottom Minimap Button"
_G["BINDING_NAME_CLICK WIIIUI_Extra4:LeftButton"] = "Top Left Inventory"
_G["BINDING_NAME_CLICK WIIIUI_Extra5:LeftButton"] = "Top Right Inventory"
_G["BINDING_NAME_CLICK WIIIUI_Extra6:LeftButton"] = "Middle Left Inventory"
_G["BINDING_NAME_CLICK WIIIUI_Extra7:LeftButton"] = "Middle Right Inventory"
_G["BINDING_NAME_CLICK WIIIUI_Extra8:LeftButton"] = "Bottom Left Inventory"
_G["BINDING_NAME_CLICK WIIIUI_Extra9:LeftButton"] = "Bottom Right Inventory"

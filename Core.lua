-- spec 0001 §A.3-A.4, §Settings schema; spec 0006: WIIIUI namespace
-- and the one settings schema.
local ADDON, WIIIUI = ...
_G.WIIIUI = WIIIUI

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

-- Owner-supplied lists (themes, info-icon ids and labels) are functions read
-- at use time: Theme.lua and InfoIcons.lua load after this file. A function
-- returning nil means "owner not loaded", and Validate then skips the
-- membership check (a Core-only test; never the client).
local function themeNames()
  return WIIIUI.Theme and WIIIUI.Theme.NAMES
end

local function infoIconIds()
  return WIIIUI.InfoIcons and WIIIUI.InfoIcons.OPTION_IDS
end

local function infoIconLabels()
  return WIIIUI.InfoIcons and WIIIUI.InfoIcons.OPTION_LABELS
end

local function infoIconApply(slot)
  return function()
    WIIIUI.ApplyOrQueue("infoIconSlot" .. slot, function()
      if WIIIUI.InfoIcons then
        WIIIUI.InfoIcons.RefreshSlot(slot)
      end
    end)
  end
end

local function xpColorIsValid(value)
  if type(value) ~= "table" or #value ~= 4 then
    return false
  end
  for i = 1, 4 do
    if type(value[i]) ~= "number" then
      return false
    end
  end
  return true
end

-- Entry: { key, default, type, range = {lo, hi} | values = list-or-fn,
-- valueLabels = map-or-fn, validate = fn, label, control = { kind,
-- showRange?, available?, shown?, apply? }, legacy = true }.
-- Order = the General tab's row order, then the keys with no control, then
-- the legacy keys. A values entry has no `type`: weaponIconSelected1..3 hold
-- a number or "none", so membership decides. The "Set in Edit Mode" keys keep
-- their defaults unread by any control (spec 0001 §1.6/§1.9 Q3);
-- rightPartWidth has no entry, its default is derived from uiScale at read
-- time. chatInputAbove, HideChatArrows and edit_theme_settings have no
-- control (decisions.md 2026-09-30, config cleanup); "Gride" is upstream's
-- typo, kept for save compatibility.
local function druidBarShown()
  return WIIIUI.Bars ~= nil and WIIIUI.Bars.IsDruid()
end

local function checkbox(key, default, label)
  return { key = key, default = default, type = "boolean", label = label, control = { kind = "checkbox" } }
end

local function range(key, default, lo, hi, label, showRange)
  return {
    key = key, default = default, type = "number", range = { lo, hi }, label = label,
    control = { kind = "editbox", showRange = showRange },
  }
end

local function editModeNote(key, default, valueType, label)
  return { key = key, default = default, type = valueType, label = label, control = { kind = "note" } }
end

local function infoIcon(slot, default)
  return {
    key = "weaponIconSelected" .. slot, default = default,
    values = infoIconIds, valueLabels = infoIconLabels, label = "Info Icon " .. slot,
    control = { kind = "cycle", apply = infoIconApply(slot) },
  }
end

-- spec 0005: the only place the console size limits live. Layout rules are
-- tuned up to TUNED_MAX; above it the console grows by the same rules and text
-- by Theme.ExtraScale. MAX is the smallest multiple of 10 that spans 1920x1080
-- edge to edge in ultra-wide: the headless fit touches at ~297, and the in-game
-- walk (2026-09-30) saw 290 clean and within ~20 px of both edges.
WIIIUI.UI_SCALE_MIN, WIIIUI.UI_SCALE_TUNED_MAX, WIIIUI.UI_SCALE_MAX = 240, 270, 300

WIIIUI.SETTINGS = {
  { key = "theme", default = "orc", values = themeNames, label = "Theme", control = { kind = "theme" } },
  range("uiScale", WIIIUI.UI_SCALE_MIN, WIIIUI.UI_SCALE_MIN, WIIIUI.UI_SCALE_MAX, "UI Scale", true),
  range("moveChatAreaUp", 10, 0, 150, "Chat Area Height"),
  range("portraitScale", 0, 0, 35, "Portrait Scale"),
  range("PortraitAlignmentX", 100, 0, 200, "Portrait X"),
  range("PortraitAlignmentY", 100, 0, 200, "Portrait Y"),
  range("hpWarning", 25, 1, 99, "Low HP Warning %"),
  checkbox("HealthPercent", false, "Show Health As %"),
  checkbox("PowerPercent", false, "Show Power As %"),
  -- spec 0002 §2: druid-only; `shown` skips the row entirely (not a note). `shown` may only go false -> true across builds (the row cache never hides a built row); a toggling condition would need a hide pass.
  {
    key = "druidResourceBar", default = true, type = "boolean", label = "Druid resource bar",
    control = { kind = "checkbox", shown = druidBarShown },
  },
  checkbox("hideGride", false, "Hide Action Grid"),
  checkbox("StopAnimation", false, "Stop Portrait Animation"),
  checkbox("hideMicroButtons", true, "Hide Micro Menu"),
  checkbox("showBlizzardMinimapCluster", false, "Show Blizzard's Minimap Corner"),
  checkbox("EnableCustomize", false, "Enable Customizer"),
  checkbox("ultraWide", false, "Ultra-Wide Mode"),
  checkbox("centerSlim", false, "Center Slim Mode"),
  checkbox("centerSlimNoInv", false, "Center Slim (No Inventory)"),
  infoIcon(1, 16),
  infoIcon(2, "none"),
  infoIcon(3, "none"),
  editModeNote("shapeshiftAuraPos", 2, "number", "Shapeshift Bar Position"),
  editModeNote("castbarAlignmentOption", 190, "number", "Cast Bar Position"),
  editModeNote("buffTopRight", true, "boolean", "Buffs Top Right"),
  editModeNote("hideBagsAboveChatFrame", true, "boolean", "Bags Above Chat"),
  editModeNote("MultiBarRightHorizontal", false, "boolean", "Right Multi-Bar Orientation"),
  editModeNote("MultiBarLeftHorizontal", false, "boolean", "Left Multi-Bar Orientation"),
  { key = "xpRestedXpColor", default = { 0, 0, 1, 0.5 }, type = "table", validate = xpColorIsValid },
  { key = "chatInputAbove", default = false, type = "boolean" },
  { key = "HideChatArrows", default = false, type = "boolean" },
  { key = "edit_theme_settings", default = {}, type = "table" },
  -- Legacy: no default, no control; the merge keeps them as unknown keys
  -- (CLAUDE.md Domain model).
  { key = "VPlus", legacy = true },
  { key = "base_settings", legacy = true },
  { key = "base_scale", legacy = true },
  { key = "MiniMapBattlefieldFrameX", legacy = true },
  { key = "MiniMapBattlefieldFrameY", legacy = true },
  -- spec 0007 §5: WIIIUI's own zone text replaced the control.
  { key = "ZoneTextPos", legacy = true },
}

WIIIUI.Settings = { RANGES = {} }

WIIIUI.DEFAULTS = {}
local BY_KEY = {}
for _, entry in ipairs(WIIIUI.SETTINGS) do
  BY_KEY[entry.key] = entry
  if entry.default ~= nil then
    WIIIUI.DEFAULTS[entry.key] = deepCopy(entry.default)
  end
  if entry.range then
    WIIIUI.Settings.RANGES[entry.key] = entry.range
  end
end

local function listOf(source)
  if type(source) == "function" then
    return source()
  end
  return source
end

-- A fresh copy for table defaults, so callers never alias DEFAULTS.
function WIIIUI.Settings.Default(key)
  return deepCopy(WIIIUI.DEFAULTS[key])
end

-- Returns the canonical value, or nil to reject. Unknown and legacy keys pass
-- through unchanged (they are kept as-is).
function WIIIUI.Settings.Validate(key, value)
  local entry = BY_KEY[key]
  if not entry or entry.default == nil then
    return value
  end
  if value == nil then
    return nil
  end

  if entry.values then
    local list = listOf(entry.values)
    if not list then
      return value
    end
    for _, member in ipairs(list) do
      if member == value then
        return value
      end
    end
    return nil
  end

  if type(value) ~= entry.type then
    return nil
  end
  if entry.range then
    -- NaN is the only value that is not equal to itself, and it is neither
    -- below nor above a range, so a clamp would pass it through.
    if value ~= value then
      return nil
    end
    return math.max(entry.range[1], math.min(entry.range[2], value))
  end
  if entry.validate and not entry.validate(value) then
    return nil
  end
  return value
end

-- Unknown keys are kept as-is; a missing, wrong-type or out-of-set key gets
-- the default; a range key is clamped. Table defaults are deep-copied so
-- callers never share the schema's tables.
function WIIIUI.MergeDefaults(saved)
  local merged = {}

  for key, value in pairs(saved or {}) do
    merged[key] = value
  end

  for _, entry in ipairs(WIIIUI.SETTINGS) do
    if entry.default ~= nil then
      local value = WIIIUI.Settings.Validate(entry.key, merged[entry.key])
      if value == nil then
        value = deepCopy(entry.default)
      end
      merged[entry.key] = value
    end
  end

  return merged
end

-- spec 0005: every geometry read of the saved size goes through here, the only
-- reader of wc3UI_Options.uiScale, so a later option B is a Theme.SizeSplit change.
function WIIIUI.LayoutUnits()
  return (WIIIUI.Theme.SizeSplit(wc3UI_Options.uiScale))
end

-- spec 0001 §A.3: the one apply-now-or-queue-to-PLAYER_REGEN_ENABLED seam
-- (CLAUDE.md "Combat lockdown"). pending/order are file-scope upvalues, not
-- WIIIUI table fields, because they are this seam's private implementation
-- state; nothing outside ApplyOrQueue/Flush reads or writes them.
local pending, order = {}, {}

-- spec 0006 §Phase 2: the one error-report seam. geterrorhandler is
-- Blizzard's own route to the Lua-error popup (API_geterrorhandler;
-- Blizzard_SharedXMLBase/ErrorUtil.lua:3,18-19 on forever). Used as the
-- xpcall message handler so the origin stack survives.
local function report(err)
  geterrorhandler()(err)
end

function WIIIUI.ApplyOrQueue(key, fn)
  if InCombatLockdown() then
    if not pending[key] then
      order[#order + 1] = key
    end
    pending[key] = fn
    return false
  end
  xpcall(fn, report)
  return true
end

function WIIIUI.Flush()
  -- Swap the tables out before iterating so the queue is empty (and safe to
  -- refill) even if a queued function errors; pcall so one error doesn't
  -- stop the rest from running (spec 0001 §A.3).
  local runOrder, runPending = order, pending
  pending, order = {}, {}
  for _, key in ipairs(runOrder) do
    xpcall(runPending[key], report)
  end
end

-- spec 0006 / Amendments item 2: the one owner of secret-value reads.
-- issecretvalue (FrameScriptDocumentation.lua, forever branch) is called only
-- in this table; a decision on a possibly-secret value goes through Read.
WIIIUI.Secret = {}

function WIIIUI.Secret.IsSecret(value)
  return issecretvalue ~= nil and issecretvalue(value) == true
end

local function passThroughPlain(ok, ...)
  if not ok then
    return nil
  end
  for i = 1, select("#", ...) do
    if WIIIUI.Secret.IsSecret((select(i, ...))) then
      return nil
    end
  end
  return ...
end

-- Returns fn's results unchanged, or a lone nil if it threw or any result is
-- secret, so callers decide on plain values and nil takes the degrade path.
function WIIIUI.Secret.Read(fn, ...)
  return passThroughPlain(pcall(fn, ...))
end

-- Tiers: "cur / max" (the vanilla text), then cur alone. Each is its own
-- pcall so a text that can't be built never reaches the caller; secrets are
-- only concatenated and handed to SetText, never read (spec 0006 Amendments
-- item 2: no thousands-separator tier).
function WIIIUI.Secret.PairText(fs, cur, max)
  if pcall(function()
    fs:SetText(cur .. " / " .. max)
  end) then
    return
  end
  pcall(fs.SetText, fs, cur)
end

-- Lazily builds a Blizzard curve object. Only the most recent successful
-- param is cached (a free-typed threshold must not grow the cache); a
-- failure is cached per (param, fingerprint()), so a build that can't work
-- isn't retried on every health event but is retried as soon as the
-- fingerprint (a cheap existence check of what the build needs) changes.
local NO_PARAM = {}

function WIIIUI.Secret.CachedCurve(build, fingerprint)
  local built, failedAt = {}, {}

  return function(param)
    local key = param
    if key == nil then
      key = NO_PARAM
    end

    if built[key] then
      return built[key]
    end

    local current = fingerprint and fingerprint()
    if failedAt[key] ~= nil and failedAt[key].fingerprint == current then
      return nil
    end

    local ok, curve = pcall(build, param)
    if ok and curve ~= nil then
      for other in pairs(built) do
        if other ~= key then
          built[other] = nil
        end
      end
      built[key] = curve
      failedAt[key] = nil
      return curve
    end

    failedAt[key] = { fingerprint = current }
    return nil
  end
end

-- UnitClass is SecretWhenUnitIdentityRestricted / MayReturnNothing
-- (UnitDocumentation.lua, forever branch); nil means "unknown class".
function WIIIUI.PlayerClassToken()
  return WIIIUI.Secret.Read(function()
    return (select(2, UnitClass("player")))
  end)
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
  -- Closure instead of xpcall arg forwarding: plain Lua 5.1 (the test
  -- runner) doesn't forward extra args; the client does.
  local n, args = select("#", ...), { ... }
  local fn
  local function call()
    return fn(unpack(args, 1, n))
  end
  for i = 1, #list do
    fn = list[i]
    xpcall(call, report)
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

-- spec 0006 §Phase 2: each module registers its own Build* step at
-- the end of its file, so the build order is TOC order and Core names no
-- module. Steps are xpcalled in Layout() so one failing region doesn't blank
-- the rest of the console (or the cogwheel).
local steps, registered = {}, {}

function WIIIUI.RegisterBuild(name, fn, opts)
  opts = opts or {}
  for _, dep in ipairs(opts.after or {}) do
    if not registered[dep] then
      error("WIIIUI.RegisterBuild: " .. name .. " needs " .. dep .. " registered first (TOC order)", 2)
    end
  end
  registered[name] = true
  steps[#steps + 1] = { name = name, fn = fn, first = opts.first and true or false }
end

-- The public entrypoint PLAYER_LOGIN queues through ApplyOrQueue
-- ("layout", WIIIUI.Layout); spec 0001 §Customizer "Apply": Revert runs
-- first (so every Build* sees uncustomized objects) and Apply last.
function WIIIUI.Layout()
  for pass = 1, 2 do
    for _, step in ipairs(steps) do
      if step.first == (pass == 1) then
        xpcall(step.fn, report)
      end
    end
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
-- a later R2 target (the action bars, spec 0004 §3) reuses this same
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
-- existence-checked, since retire_test.lua/older tests load Core.lua alone)
-- joins the same "retire"
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
-- string, e17c352 WIIIUI.lua:3). The 6 inventory labels below follow vanilla's
-- own Bindings.xml binding, not file-declaration order: vanilla's
-- CustomKeyBindings(4..9) maps to ActionButton_CustomInventory_(1..6), and
-- vanilla Bindings.xml (e17c352) binds CustomKeyBindings(9/8/7/6/4/5) to
-- Top Left / Top Right / Middle Left / Middle Right / Bottom Left / Bottom
-- Right respectively -- inverted here to give each Extra(4..9) its label
-- directly. Cross-checked against Theme.lua's INVENTORY_SLOT_GRID. "_G["BINDING_NAME_" .. command]" convention,
-- warcraft.wiki.gg Bindings.xml.
BINDING_HEADER_WIIIUI = "Warcraft III - UI"
_G["BINDING_NAME_CLICK WIIIUI_Extra1:LeftButton"] = "Top Minimap Button"
_G["BINDING_NAME_CLICK WIIIUI_Extra2:LeftButton"] = "Middle Minimap Button"
_G["BINDING_NAME_CLICK WIIIUI_Extra3:LeftButton"] = "Bottom Minimap Button"
_G["BINDING_NAME_CLICK WIIIUI_Extra4:LeftButton"] = "Bottom Left Inventory"
_G["BINDING_NAME_CLICK WIIIUI_Extra5:LeftButton"] = "Bottom Right Inventory"
_G["BINDING_NAME_CLICK WIIIUI_Extra6:LeftButton"] = "Middle Right Inventory"
_G["BINDING_NAME_CLICK WIIIUI_Extra7:LeftButton"] = "Middle Left Inventory"
_G["BINDING_NAME_CLICK WIIIUI_Extra8:LeftButton"] = "Top Right Inventory"
_G["BINDING_NAME_CLICK WIIIUI_Extra9:LeftButton"] = "Top Left Inventory"

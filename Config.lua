-- spec 0001 §Module split "Config.lua": cogwheel, config menu (General tab).
-- One control table ({key, kind, get/set, apply, editMode?, available?},
-- spec 0001 §1.6/§1.9 Q3) drives both the live widgets and the "Set in Edit
-- Mode" note rows -- replacing vanilla's ~40 paired Check*/Change* globals
-- (e17c352 WIIIUI.lua:5010-5636) with data. No VPlus row: the checkbox is
-- dropped per CLAUDE.md's official-clients-only decision (§1.7).
-- Cogwheel/hover geometry, texture and the panel's screen anchor keep
-- vanilla's exact numbers (e17c352 WIIIUI.xml:61-149) -- CLAUDE.md "the look
-- is the specification". Per-row widget layout inside the panel is new (the
-- vanilla XML positioned each control by hand; the control table drives a
-- plain top-down list here instead), so it is not pixel-matched to vanilla --
-- menu usability is confirmed in-game (this slice's Notes, tester).
local _, WIIIUI = ...

WIIIUI.Config = WIIIUI.Config or {}
WIIIUI.Config.widgets = WIIIUI.Config.widgets or {}
WIIIUI.Config.labels = WIIIUI.Config.labels or {}

-- Vanilla Wc3_UI_cogwheel (e17c352 WIIIUI.xml:99): shared art, not a
-- per-theme path, so this is a literal like Bars.lua's FONT_PATH rather than
-- a WIIIUI.Theme.TexturePath call (that resolver is per-theme, this texture
-- is not).
local COGWHEEL_TEXTURE = "Interface\\Addons\\WIIIUI\\art\\other\\cogwheel"

-- Same 12 names as Theme.lua's KNOWN_THEMES; duplicated locally rather than
-- exporting a list from Theme.lua for this one caller (no other file needs
-- an enumerable theme list yet).
local THEME_LIST = {
  "human", "orc", "undead", "nightelf",
  "custom1", "custom2", "custom3", "custom4",
  "custom5", "custom6", "custom7", "custom8",
}

local ZONE_TEXT_POS_LABELS = { [1] = "Top", [2] = "Bottom", [3] = "Hidden" }

-- Display labels for every control-table row below (checkbox/editbox/cycle
-- rows show these next to their widget; note rows show these before the
-- "Set in Edit Mode" suffix).
local LABELS = {
  theme = "Theme",
  uiScale = "UI Scale (240-270)",
  moveChatAreaUp = "Chat Area Height",
  portraitScale = "Portrait Scale",
  PortraitAlignmentX = "Portrait X",
  PortraitAlignmentY = "Portrait Y",
  hpWarning = "Low HP Warning %",
  HealthPercent = "Show Health As %",
  PowerPercent = "Show Power As %",
  chatInputAbove = "Chat Input Above",
  hideGride = "Hide Action Grid",
  HideChatArrows = "Hide Chat Arrows",
  StopAnimation = "Stop Portrait Animation",
  hideMicroButtons = "Hide Micro Menu",
  EnableCustomize = "Enable Customizer",
  ultraWide = "Ultra-Wide Mode",
  centerSlim = "Center Slim Mode",
  centerSlimNoInv = "Center Slim (No Inventory)",
  ZoneTextPos = "Zone Text Position",
  shapeshiftAuraPos = "Shapeshift Bar Position",
  castbarAlignmentOption = "Cast Bar Position",
  buffTopRight = "Buffs Top Right",
  hideBagsAboveChatFrame = "Bags Above Chat",
  MultiBarRightHorizontal = "Right Multi-Bar Orientation",
  MultiBarLeftHorizontal = "Left Multi-Bar Orientation",
}

local function label(key)
  return LABELS[key] or key
end

local function clamp(value, min, max)
  if value < min then
    return min
  elseif value > max then
    return max
  end
  return value
end

local function makeBoolControl(key)
  return {
    key = key,
    kind = "checkbox",
    get = function() return wc3UI_Options[key] end,
    set = function(value) wc3UI_Options[key] = value and true or false end,
  }
end

local function makeRangeControl(key, min, max)
  return {
    key = key,
    kind = "editbox",
    min = min,
    max = max,
    get = function() return wc3UI_Options[key] end,
    set = function(value)
      local number = tonumber(value)
      if number then
        wc3UI_Options[key] = clamp(number, min, max)
      end
    end,
  }
end

local function makeNoteControl(key)
  return { key = key, kind = "note", editMode = true }
end

-- spec 0001 §1.6/§1.9 Q3: "Hidden in the config menu with a one-line 'Set in
-- Edit Mode' note; SV keys kept." -- these 6 rows never render a control;
-- their keys stay readable/writable in wc3UI_Options for whatever later
-- code (0003+, a restored feature) still wants them, exactly as DEFAULTS
-- keeps them (Core.lua).
WIIIUI.Config.CONTROLS = {
  {
    key = "theme",
    kind = "theme",
    get = function() return wc3UI_Options.theme end,
    set = function(value) wc3UI_Options.theme = WIIIUI.Theme.ResolveThemeName(value) end,
  },
  makeRangeControl("uiScale", 240, 270),
  makeRangeControl("moveChatAreaUp", 0, 150),
  makeRangeControl("portraitScale", 0, 35),
  makeRangeControl("PortraitAlignmentX", 0, 200),
  makeRangeControl("PortraitAlignmentY", 0, 200),
  makeRangeControl("hpWarning", 1, 99),
  makeBoolControl("HealthPercent"),
  makeBoolControl("PowerPercent"),
  makeBoolControl("chatInputAbove"),
  makeBoolControl("hideGride"),
  makeBoolControl("HideChatArrows"),
  makeBoolControl("StopAnimation"),
  makeBoolControl("hideMicroButtons"),
  makeBoolControl("EnableCustomize"),
  makeBoolControl("ultraWide"),
  makeBoolControl("centerSlim"),
  makeBoolControl("centerSlimNoInv"),
  {
    key = "ZoneTextPos",
    kind = "cycle",
    values = { 1, 2, 3 },
    get = function() return wc3UI_Options.ZoneTextPos end,
    set = function(value)
      if value ~= 1 and value ~= 2 and value ~= 3 then
        value = 1
      end
      wc3UI_Options.ZoneTextPos = value
    end,
  },
  makeNoteControl("shapeshiftAuraPos"),
  makeNoteControl("castbarAlignmentOption"),
  makeNoteControl("buffTopRight"),
  makeNoteControl("hideBagsAboveChatFrame"),
  makeNoteControl("MultiBarRightHorizontal"),
  makeNoteControl("MultiBarLeftHorizontal"),
}

-- spec 0001 §1.6: "each control-table row ... carries editMode = true
-- (static) or available = fn (in-game-check result); the menu renders such a
-- row as its label plus the note, never as a live control." Neither field
-- changes at runtime for any row this slice ships, so BuildConfig below
-- decides note-vs-control once per row, not on every call.
local function isNoteRow(row)
  return row.editMode or (row.available and not row.available())
end

-- spec 0001 §A.3/§A.4: "Re-layout triggers" -- the shared default for any
-- control without its own `apply`; ApplyOrQueue is the one combat-lockdown
-- seam (CLAUDE.md "Combat lockdown"), so a setting changed mid-combat
-- queues instead of touching frames directly.
local function applyRow(row)
  if row.apply then
    row.apply()
  else
    WIIIUI.ApplyOrQueue("layout", WIIIUI.Layout)
  end
end

local function ensureLabel(panel, row, x, y)
  local text = WIIIUI.Config.labels[row.key]
  if not text then
    text = panel:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(GameFontHighlightSmall)
    WIIIUI.Config.labels[row.key] = text
  end
  text:ClearAllPoints()
  text:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
  text:SetText(label(row.key))
  return text
end

local LABEL_COLUMN_WIDTH = 220

local function buildCheckbox(panel, row, x, y)
  ensureLabel(panel, row, x, y)

  local cb = WIIIUI.Config.widgets[row.key]
  if not cb then
    cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetScript("OnClick", function(self)
      row.set(self:GetChecked())
      applyRow(row)
    end)
    WIIIUI.Config.widgets[row.key] = cb
  end

  cb:ClearAllPoints()
  cb:SetPoint("TOPLEFT", panel, "TOPLEFT", x + LABEL_COLUMN_WIDTH, y)
  cb:SetChecked(row.get())
end

local function buildEditbox(panel, row, x, y)
  ensureLabel(panel, row, x, y)

  local eb = WIIIUI.Config.widgets[row.key]
  if not eb then
    eb = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetSize(60, 20)
    eb:SetScript("OnEscapePressed", function(self)
      self:SetText(tostring(row.get()))
      self:ClearFocus()
    end)
    eb:SetScript("OnEnterPressed", function(self)
      row.set(self:GetText())
      applyRow(row)
      self:SetText(tostring(row.get()))
      self:ClearFocus()
    end)
    WIIIUI.Config.widgets[row.key] = eb
  end

  eb:ClearAllPoints()
  eb:SetPoint("TOPLEFT", panel, "TOPLEFT", x + LABEL_COLUMN_WIDTH, y)
  eb:SetText(tostring(row.get()))
end

local function cycleButtonText(row)
  local value = row.get()
  return label(row.key) .. ": " .. (ZONE_TEXT_POS_LABELS[value] or tostring(value))
end

local function buildCycle(panel, row, x, y)
  local btn = WIIIUI.Config.widgets[row.key]
  if not btn then
    btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(200, 22)
    btn:SetScript("OnClick", function()
      local values, current, nextIndex = row.values, row.get(), 1
      for i, value in ipairs(values) do
        if value == current then
          nextIndex = (i % #values) + 1
        end
      end
      row.set(values[nextIndex])
      applyRow(row)
      btn:SetText(cycleButtonText(row))
    end)
    WIIIUI.Config.widgets[row.key] = btn
  end

  btn:ClearAllPoints()
  btn:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
  btn:SetText(cycleButtonText(row))
end

local THEME_COLUMNS = 4
local THEME_BUTTON_WIDTH = 100
local THEME_BUTTON_HEIGHT = 22

local function buildTheme(panel, row, x, y)
  local buttons = WIIIUI.Config.widgets[row.key]
  if not buttons then
    buttons = {}
    for i, name in ipairs(THEME_LIST) do
      local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
      btn:SetSize(THEME_BUTTON_WIDTH - 6, THEME_BUTTON_HEIGHT)
      btn:SetText(name)
      btn:SetScript("OnClick", function()
        row.set(name)
        applyRow(row)
      end)
      buttons[i] = btn
    end
    WIIIUI.Config.widgets[row.key] = buttons
  end

  for i, btn in ipairs(buttons) do
    local col = (i - 1) % THEME_COLUMNS
    local line = math.floor((i - 1) / THEME_COLUMNS)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", panel, "TOPLEFT", x + col * THEME_BUTTON_WIDTH, y - line * THEME_BUTTON_HEIGHT)
  end

  local lines = math.ceil(#buttons / THEME_COLUMNS)
  return lines * THEME_BUTTON_HEIGHT
end

local EDIT_MODE_NOTE_SUFFIX = " -- set in Edit Mode"

local function buildNote(panel, row, x, y)
  local note = WIIIUI.Config.widgets[row.key]
  if not note then
    note = panel:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(GameFontHighlightSmall)
    WIIIUI.Config.widgets[row.key] = note
  end

  note:ClearAllPoints()
  note:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
  note:SetText(label(row.key) .. EDIT_MODE_NOTE_SUFFIX)
end

local ROW_X = 20
local ROW_HEIGHT = 26
local ROW_START_Y = -70

-- Vanilla WIIIUI_cogwheel_hover (e17c352 WIIIUI.xml:62-88): 30x30, anchored
-- BOTTOMRIGHT of UIParent at (7,-6). Always shown -- it is the invisible hit
-- region that reveals the cogwheel on hover; only the cogwheel/panel below
-- start hidden.
local function ensureHover()
  local hover = WIIIUI.Config.hover
  if hover then
    return hover
  end

  hover = CreateFrame("Frame", nil, UIParent)
  hover:SetSize(30, 30)
  hover:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 7, -6)
  hover:SetFrameStrata("HIGH")

  hover:SetScript("OnEnter", function() WIIIUI.Config.cogwheel:Show() end)
  hover:SetScript("OnLeave", function() WIIIUI.Config.cogwheel:Hide() end)

  WIIIUI.Config.hover = hover
  return hover
end

-- Vanilla Wc3_UI_cogwheel (e17c352 WIIIUI.xml:91-105): same size/anchor as
-- the hover region, BackdropTemplate + bgFile cogwheel art (CLAUDE.md
-- "Backdrops"). Click toggles the panel; mouse-down/up darkens/restores the
-- backdrop colour, matching vanilla's press feedback.
local function ensureCogwheel()
  local cogwheel = WIIIUI.Config.cogwheel
  if cogwheel then
    return cogwheel
  end

  cogwheel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  cogwheel:SetSize(30, 30)
  cogwheel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 7, -6)
  cogwheel:SetFrameStrata("DIALOG")
  cogwheel:SetBackdrop({
    bgFile = COGWHEEL_TEXTURE,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  cogwheel:SetBackdropColor(1, 1, 1, 1)
  cogwheel:Hide()

  cogwheel:SetScript("OnMouseDown", function(self)
    self:SetBackdropColor(0.75, 0.75, 0.75, 1)
    if WIIIUI.Config.panel:IsShown() then
      WIIIUI.Config.panel:Hide()
    else
      WIIIUI.Config.panel:Show()
    end
  end)
  cogwheel:SetScript("OnMouseUp", function(self)
    self:SetBackdropColor(1, 1, 1, 1)
  end)

  WIIIUI.Config.cogwheel = cogwheel
  return cogwheel
end

-- Vanilla WIIIUI_menu (e17c352 WIIIUI.xml:147-160): 650x600, anchored LEFT
-- of UIParent at (200,0), tooltip-background + dialog-border backdrop.
-- Vanilla's General/Customize tab buttons are not built here -- the
-- Customize tab doesn't exist until Phase G (spec 0001 Phased plan), so this
-- panel is the General tab's content directly, no tab switcher yet.
local function ensurePanel()
  local panel = WIIIUI.Config.panel
  if panel then
    return panel
  end

  panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  panel:SetSize(650, 600)
  panel:SetPoint("LEFT", UIParent, "LEFT", 200, 0)
  panel:SetFrameStrata("DIALOG")
  panel:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    insets = { left = 10, right = 10, top = 10, bottom = 10 },
  })
  panel:SetBackdropColor(0, 0, 0, 0.75)
  panel:Hide()

  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetSize(30, 30)
  close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 5, 5)
  close:SetScript("OnClick", function() panel:Hide() end)
  panel.closeButton = close

  local title = panel:CreateFontString(nil, "OVERLAY")
  title:SetFontObject(GameFontHighlightSmall)
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", ROW_X, -20)
  title:SetText("WIIIUI - General")
  panel.title = title

  WIIIUI.Config.panel = panel
  return panel
end

local function ensureReloadButton(panel, y)
  local reload = WIIIUI.Config.reloadButton
  if not reload then
    reload = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reload:SetSize(120, 22)
    reload:SetText("Reload UI")
    -- ReloadUI(): warcraft.wiki.gg API_ReloadUI -- moved to C_UI.Reload in
    -- 7.2.5, "the previous alias (ReloadUI()) is still available as a
    -- script wrapper".
    reload:SetScript("OnClick", function() ReloadUI() end)
    WIIIUI.Config.reloadButton = reload
  end

  reload:ClearAllPoints()
  reload:SetPoint("TOPLEFT", panel, "TOPLEFT", ROW_X, y)
end

-- spec 0001 §Module split "Config.lua": builds the cogwheel/hover/panel once
-- and, every call after that, re-syncs each control's displayed value from
-- wc3UI_Options (so a setting changed elsewhere -- e.g. the Customizer,
-- later phases -- is reflected the next time WIIIUI.Layout() runs). Called
-- from Core.lua's WIIIUI.Layout() the same way Buttons.BuildButtons is:
-- existence-checked.
function WIIIUI.Config.BuildConfig()
  ensureHover()
  ensureCogwheel()
  local panel = ensurePanel()

  local y = ROW_START_Y

  for _, row in ipairs(WIIIUI.Config.CONTROLS) do
    if isNoteRow(row) then
      buildNote(panel, row, ROW_X, y)
      y = y - ROW_HEIGHT
    elseif row.kind == "checkbox" then
      buildCheckbox(panel, row, ROW_X, y)
      y = y - ROW_HEIGHT
    elseif row.kind == "editbox" then
      buildEditbox(panel, row, ROW_X, y)
      y = y - ROW_HEIGHT
    elseif row.kind == "cycle" then
      buildCycle(panel, row, ROW_X, y)
      y = y - ROW_HEIGHT
    elseif row.kind == "theme" then
      local height = buildTheme(panel, row, ROW_X, y)
      y = y - height - 6
    end
  end

  ensureReloadButton(panel, y - 6)
end

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
-- menu usability is confirmed in-game (tester).
local _, WIIIUI = ...

WIIIUI.Config = WIIIUI.Config or {}
WIIIUI.Config.widgets = WIIIUI.Config.widgets or {}
WIIIUI.Config.labels = WIIIUI.Config.labels or {}

-- Vanilla Wc3_UI_cogwheel (e17c352 WIIIUI.xml:99): shared art, not a
-- per-theme path, so this is a literal rather than
-- a WIIIUI.Theme.TexturePath call (that resolver is per-theme, this texture
-- is not).
local COGWHEEL_TEXTURE = "Interface\\Addons\\WIIIUI\\art\\other\\cogwheel"

-- spec 0006: every row is derived from an entry of WIIIUI.SETTINGS
-- (Core.lua) that has a `control`; the schema owns key, label, range and value
-- lists, so nothing here restates them. The 6 "Set in Edit Mode" rows never
-- render a control (spec 0001 §1.6/§1.9 Q3); their keys stay readable and
-- writable in wc3UI_Options for whatever later code wants them.
local function listOf(source)
  if type(source) == "function" then
    return source()
  end
  return source
end

local function makeSet(entry)
  local key, kind = entry.key, entry.control.kind
  if kind == "editbox" then
    -- The edit box hands over text: a non-number or NaN is rejected by
    -- Validate (or tonumber) and leaves the stored value untouched.
    return function(value)
      local valid = WIIIUI.Settings.Validate(key, tonumber(value))
      if valid ~= nil then
        wc3UI_Options[key] = valid
      end
    end
  end
  return function(value)
    if kind == "checkbox" then
      value = value and true or false
    end
    local valid = WIIIUI.Settings.Validate(key, value)
    if valid == nil then
      valid = WIIIUI.Settings.Default(key)
    end
    wc3UI_Options[key] = valid
  end
end

local function makeRow(entry)
  local control = entry.control
  local row = {
    key = entry.key,
    kind = control.kind,
    label = entry.label,
    available = control.available,
    shown = control.shown,
    apply = control.apply,
  }
  if control.kind == "note" then
    row.editMode = true
  else
    row.get = function() return wc3UI_Options[entry.key] end
    row.set = makeSet(entry)
  end
  if entry.range then
    row.min, row.max = entry.range[1], entry.range[2]
    if control.showRange then
      row.label = entry.label .. " (" .. row.min .. "-" .. row.max .. ")"
    end
  end
  if control.kind == "cycle" then
    -- The info-icon lists come from InfoIcons.lua; if that file didn't load they
    -- resolve to nil, and the row degrades to an inert cycle rather than
    -- failing the whole menu. The schema test pins that every entry supplies them.
    row.values = listOf(entry.values) or {}
    row.valueLabels = listOf(entry.valueLabels) or {}
  end
  return row
end

WIIIUI.Config.CONTROLS = {}
for _, entry in ipairs(WIIIUI.SETTINGS) do
  if entry.control then
    WIIIUI.Config.CONTROLS[#WIIIUI.Config.CONTROLS + 1] = makeRow(entry)
  end
end

-- spec 0001 §1.6: "each control-table row ... carries editMode = true
-- (static) or available = fn (in-game-check result); the menu renders such a
-- row as its label plus the note, never as a live control." Neither field
-- changes at runtime for any row, so BuildConfig below
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
  text:SetText(row.label)
  return text
end

local LABEL_COLUMN_WIDTH = 220

local ROW_X = 20
local ROW_HEIGHT = 26
local CONTENT_START_Y = -10
local CONTENT_WIDTH = 600
local CONTENT_BOTTOM_PADDING = 20
local RELOAD_BUTTON_HEIGHT = 22

-- A note row's label plus
-- editModeNoteSuffix()'s build-name suffix has no width/wrap guard, so the
-- longest existing label ("Right Multi-Bar Orientation") plus the suffix
-- risks exceeding the scroll content's clipped viewport and getting cut off
-- by the ScrollFrame rather than just visually overflowing. NOTE_TEXT_WIDTH
-- constrains the note FontString to content width minus its left inset and a
-- right margin, matching the other rows' own right-hand boundary -- moved
-- above buildNote (below) since it and every other row-layout constant this
-- file already declares here are needed before that function's own
-- definition, not after it.
local NOTE_TEXT_WIDTH = CONTENT_WIDTH - ROW_X - 10

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
  return ROW_HEIGHT
end

local function buildEditbox(panel, row, x, y)
  ensureLabel(panel, row, x, y)

  local eb = WIIIUI.Config.widgets[row.key]
  if not eb then
    eb = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetSize(60, 20)
    -- EditBox:SetNumeric (warcraft.wiki.gg API_EditBox_SetNumeric) strips
    -- non-digit input, including a minus sign, so it's only safe on rows
    -- whose range never goes negative -- every numeric row
    -- has min >= 0.
    if row.min == nil or row.min >= 0 then
      eb:SetNumeric(true)
    end
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
  return ROW_HEIGHT
end

local function cycleButtonText(row)
  local value = row.get()
  return row.label .. ": " .. (row.valueLabels[value] or tostring(value))
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
  return ROW_HEIGHT
end

local THEME_COLUMNS = 4
local THEME_BUTTON_WIDTH = 100
local THEME_BUTTON_HEIGHT = 22

local function buildTheme(panel, row, x, y)
  local buttons = WIIIUI.Config.widgets[row.key]
  if not buttons then
    buttons = {}
    for i, name in ipairs(WIIIUI.Theme.NAMES) do
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
  return lines * THEME_BUTTON_HEIGHT + 6
end

-- spec 0001 §1.6: every "Set in Edit Mode" row (the fixed 6 plus any
-- in-game-check failure) is, per the §1.6 per-piece table, a piece the
-- shipped layout string places -- so the note now names the constant that
-- backs it (WIIIUI.LAYOUT_BUILD, Blizzard.lua) instead of a bare "set in
-- Edit Mode" with no pointer to where. Blizzard.lua isn't loaded by every
-- test fixture that builds this control table (config_test.lua's own), so
-- this falls back to a plain string there -- only a real client (or a test that loads
-- Blizzard.lua too) sees the build number.
local function editModeNoteSuffix()
  return " -- set in Edit Mode (WIIIUI's layout string, build " .. (WIIIUI.LAYOUT_BUILD or "not yet exported") .. ")"
end

local function buildNote(panel, row, x, y)
  local note = WIIIUI.Config.widgets[row.key]
  if not note then
    note = panel:CreateFontString(nil, "OVERLAY")
    -- GameFontDisableSmall (Gethe/wow-ui-source forever branch,
    -- Blizzard_Fonts_Shared/Shared/FontStyles.xml) dims note rows so they
    -- read apart from real controls' GameFontHighlightSmall labels without
    -- relying on the suffix text alone.
    note:SetFontObject(GameFontDisableSmall)
    -- Width/wrap guard: no
    -- SetHeight call is ever made on this FontString, so its height stays
    -- the auto-sized value the region computes from its content -- a
    -- FontString's SetHeight/GetHeight/SetWidth/GetWidth "compute what
    -- dimensions are needed in one direction, given the size in the other
    -- direction" rather than working with a fixed painted area
    -- (wowpedia/addonstudio.org mirror, WoW:UIOBJECT_FontString), so
    -- GetHeight() below reports the true post-wrap height once width +
    -- word-wrap are set. GetStringHeight()
    -- is documented to return the height "without wrapping" -- it only
    -- accounts for manually-set "\n" breaks, never automatic word-wrap
    -- (warcraft.wiki.gg API_FontString_GetStringHeight) -- so it can't be
    -- used here.
    note:SetWidth(NOTE_TEXT_WIDTH)
    note:SetWordWrap(true)
    note:SetJustifyH("LEFT")
    WIIIUI.Config.widgets[row.key] = note
  end

  note:ClearAllPoints()
  note:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
  note:SetText(row.label .. editModeNoteSuffix())

  -- Row height: at least the fixed single-line ROW_HEIGHT every other row
  -- uses (so short notes keep vanilla's exact row spacing), or the wrapped
  -- text's real height plus a small bottom margin when it wraps past one
  -- line.
  return math.max(ROW_HEIGHT, note:GetHeight() + 6)
end

-- Each builder places its row and returns the row's height; BuildConfig picks
-- one by kind (a row whose `available` fails is a note).
WIIIUI.Config.BUILDERS = {
  checkbox = buildCheckbox,
  editbox = buildEditbox,
  cycle = buildCycle,
  theme = buildTheme,
  note = buildNote,
}

-- UIPanelScrollFrameTemplate anchors its scrollbar 6px right of the scroll
-- frame's own right edge (Gethe/wow-ui-source forever branch,
-- Blizzard_SharedXML/SecureScrollTemplates.xml) -- SCROLL_INSET_RIGHT leaves
-- enough panel margin that the scrollbar doesn't sit on the panel's border.
-- Bumped from vanilla's own 50 to leave room below the panel title for the
-- General/Customize tab buttons ensureTabs adds.
local SCROLL_INSET_TOP = 74
local SCROLL_INSET_BOTTOM = 16
local SCROLL_INSET_LEFT = 16
local SCROLL_INSET_RIGHT = 34
local TAB_BUTTON_WIDTH = 100
local TAB_BUTTON_HEIGHT = 22
local TAB_ROW_Y = -45

-- Vanilla WIIIUI_cogwheel_hover (e17c352 WIIIUI.xml:62-105): 30x30, anchored
-- BOTTOMRIGHT of UIParent at (7,-6). Always shown -- it is the invisible hit
-- region that reveals the cogwheel on hover, and it owns every mouse handler:
-- OnEnter/OnLeave and the click (panel toggle plus press feedback on the
-- cogwheel). Only the cogwheel/panel below start hidden.
local function ensureHover()
  local hover = WIIIUI.Config.hover
  if hover then
    return hover
  end

  hover = CreateFrame("Frame", nil, UIParent)
  hover:SetSize(30, 30)
  hover:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 7, -6)
  WIIIUI.Layers.Apply(hover, "config.hover")
  hover:EnableMouse(true)

  hover:SetScript("OnEnter", function() WIIIUI.Config.cogwheel:Show() end)
  hover:SetScript("OnLeave", function() WIIIUI.Config.cogwheel:Hide() end)

  -- The cogwheel must not carry these: on modern clients a mouse script
  -- enables the frame's mouse, so the shown cogwheel would take focus from
  -- this frame, whose OnLeave then hides it again.
  hover:SetScript("OnMouseDown", function()
    WIIIUI.Config.cogwheel:SetBackdropColor(0.75, 0.75, 0.75, 1)
    if WIIIUI.Config.panel:IsShown() then
      WIIIUI.Config.panel:Hide()
    else
      WIIIUI.Config.panel:Show()
    end
  end)
  hover:SetScript("OnMouseUp", function()
    WIIIUI.Config.cogwheel:SetBackdropColor(1, 1, 1, 1)
  end)

  WIIIUI.Config.hover = hover
  return hover
end

-- Vanilla Wc3_UI_cogwheel (e17c352 WIIIUI.xml:91-105): same size/anchor as
-- the hover region, BackdropTemplate + bgFile cogwheel art (CLAUDE.md
-- "Backdrops"). Display-only: mouse-disabled, no mouse scripts, so the hover
-- frame stays the one hit target (see ensureHover).
local function ensureCogwheel()
  local cogwheel = WIIIUI.Config.cogwheel
  if cogwheel then
    return cogwheel
  end

  cogwheel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  cogwheel:SetSize(30, 30)
  cogwheel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 7, -6)
  WIIIUI.Layers.Apply(cogwheel, "config.cogwheel")
  cogwheel:EnableMouse(false)
  cogwheel:SetBackdrop({
    bgFile = COGWHEEL_TEXTURE,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  cogwheel:SetBackdropColor(1, 1, 1, 1)
  cogwheel:Hide()

  WIIIUI.Config.cogwheel = cogwheel
  return cogwheel
end

-- Vanilla WIIIUI_menu (e17c352 WIIIUI.xml:147-160): 650x600, anchored LEFT
-- of UIParent at (200,0), tooltip-background + dialog-border backdrop.
-- Vanilla's General/Customize tab buttons: ensureTabs, below, builds them
-- (spec 0001 §Customizer) -- General is this file's own scroll-content rows;
-- Customize is a frame Customizer.lua owns, parented to this panel.
local function ensurePanel()
  local panel = WIIIUI.Config.panel
  if panel then
    return panel
  end

  panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  panel:SetSize(650, 600)
  panel:SetPoint("LEFT", UIParent, "LEFT", 200, 0)
  WIIIUI.Layers.Apply(panel, "config.panel")
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

-- The panel's fixed 650x600
-- size can't fit all 25 control-table rows + reload button (content ran
-- ~190px past the bottom edge with no scroll frame). Rows live in this
-- scroll child instead of directly on the panel; the title bar and close
-- button (ensurePanel, above) stay outside it. UIPanelScrollFrameTemplate
-- confirmed real (Gethe/wow-ui-source forever branch,
-- Blizzard_SharedXML/SecureScrollTemplates.xml).
local function ensureScrollFrame(panel)
  local content = WIIIUI.Config.scrollContent
  if content then
    return content
  end

  local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", SCROLL_INSET_LEFT, -SCROLL_INSET_TOP)
  scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -SCROLL_INSET_RIGHT, SCROLL_INSET_BOTTOM)

  content = CreateFrame("Frame", nil, scrollFrame)
  content:SetWidth(CONTENT_WIDTH)
  content:SetHeight(1) -- grown to fit every row by BuildConfig, below
  scrollFrame:SetScrollChild(content)

  WIIIUI.Config.scrollFrame = scrollFrame
  WIIIUI.Config.scrollContent = content
  return content
end

-- spec 0001 §Customizer: "Config.lua gets the General/Customize tab switch
-- on its panel." Two plain buttons; ShowTab shows the General scroll frame
-- or the Customize tab's own frame (WIIIUI.Customizer.editor, built and
-- owned by Customizer.lua) and hides the other. Existence-checked on
-- WIIIUI.Customizer throughout -- config_test.lua
-- loads Config.lua without Customizer.lua, so the Customize tab is built
-- (and clickable) only once Customizer.lua is also loaded; clicking it
-- before that is a harmless no-op (WIIIUI.Config.ShowTab's own guard).
WIIIUI.Config.activeTab = WIIIUI.Config.activeTab or "general"

function WIIIUI.Config.ShowTab(tab)
  WIIIUI.Config.activeTab = tab

  if WIIIUI.Config.scrollFrame then
    if tab == "general" then
      WIIIUI.Config.scrollFrame:Show()
    else
      WIIIUI.Config.scrollFrame:Hide()
    end
  end

  if WIIIUI.Customizer and WIIIUI.Customizer.editor then
    if tab == "customize" then
      WIIIUI.Customizer.editor:Show()
    else
      WIIIUI.Customizer.editor:Hide()
    end
  end
end

local function ensureTabs(panel)
  local tabs = WIIIUI.Config.tabs
  if tabs then
    return tabs
  end

  local generalTab = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  generalTab:SetSize(TAB_BUTTON_WIDTH, TAB_BUTTON_HEIGHT)
  generalTab:SetPoint("TOPLEFT", panel, "TOPLEFT", ROW_X, TAB_ROW_Y)
  generalTab:SetText("General")
  generalTab:SetScript("OnClick", function() WIIIUI.Config.ShowTab("general") end)

  local customizeTab = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  customizeTab:SetSize(TAB_BUTTON_WIDTH, TAB_BUTTON_HEIGHT)
  customizeTab:SetPoint("LEFT", generalTab, "RIGHT", 6, 0)
  customizeTab:SetText("Customize")
  customizeTab:SetScript("OnClick", function() WIIIUI.Config.ShowTab("customize") end)

  tabs = { general = generalTab, customize = customizeTab }
  WIIIUI.Config.tabs = tabs
  return tabs
end

local LAYOUT_STRING_BOX_WIDTH = 300
local LAYOUT_STRING_BOX_HEIGHT = 20

local function layoutStringValue()
  -- Fallback wording for when Blizzard.lua isn't loaded (WIIIUI.LAYOUT_STRING
  -- nil): only test fixtures that build this control table without it reach
  -- it (config_test.lua). Player-facing: no internal doc pointer, no
  -- instruction to edit the read-only box it's displayed in.
  return WIIIUI.LAYOUT_STRING or "Not available in this build -- check for an addon update."
end

-- spec 0001 §1.6 "Copy layout string": a read-only EditBox with the layout
-- string pre-selected, so Ctrl+C copies the whole thing without a manual
-- drag-select. Not part of WIIIUI.Config.CONTROLS -- it has no wc3UI_Options
-- key to get/set, so it would fail the "editMode xor get/set" shape every
-- other row follows (config_test.lua's own round-trip loop); built directly
-- here instead, the same way ensureReloadButton is.
--
-- "Read-only" is enforced by snapping any user edit straight back to the
-- constant rather than disabling the box (which would also block
-- selecting/copying it) -- the same idiom Blizzard's own Edit Mode layout
-- dialog uses to pre-select an EditBox's contents
-- (EditModeLayoutDialogMixin:SetupControlsForMode, Blizzard_EditMode/Shared/
-- EditModeDialogs.lua, forever branch, fetched 2026-09-28:
-- "self:GetEditBox():SetText(...); self:GetEditBox():HighlightText()" --
-- HighlightText() with no arguments selects the entire contents,
-- warcraft.wiki.gg API_EditBox_HighlightText). OnTextChanged's userInput
-- flag (warcraft.wiki.gg UIHANDLER_OnTextChanged: "true when changing as a
-- result of user input, false when programmatically set") gates the reset so
-- the SetText call below can't recurse: it re-fires OnTextChanged with
-- userInput = false, which the `if userInput` guard ignores.
local function ensureLayoutStringBox(panel, x, y)
  local widget = WIIIUI.Config.widgets.layoutString
  if not widget then
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(GameFontHighlightSmall)
    title:SetText("Copy layout string")

    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetSize(LAYOUT_STRING_BOX_WIDTH, LAYOUT_STRING_BOX_HEIGHT)
    box:SetText(layoutStringValue())

    box:SetScript("OnEditFocusGained", function(self)
      self:HighlightText()
    end)
    box:SetScript("OnTextChanged", function(self, userInput)
      if userInput and self:GetText() ~= layoutStringValue() then
        self:SetText(layoutStringValue())
        self:HighlightText()
      end
    end)
    box:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
    end)

    widget = { title = title, box = box }
    WIIIUI.Config.widgets.layoutString = widget
  end

  widget.title:ClearAllPoints()
  widget.title:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
  widget.box:ClearAllPoints()
  widget.box:SetPoint("TOPLEFT", panel, "TOPLEFT", x + LABEL_COLUMN_WIDTH, y)

  -- Re-sync on every call, like every other Build* row, so a changed
  -- LAYOUT_STRING shows without needing a fresh widget.
  if widget.box:GetText() ~= layoutStringValue() then
    widget.box:SetText(layoutStringValue())
  end
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
-- from Core.lua's WIIIUI.Layout() as a registered build step, like
-- Buttons.BuildButtons.
function WIIIUI.Config.BuildConfig()
  ensureHover()
  ensureCogwheel()
  local panel = ensurePanel()
  ensureTabs(panel)
  local content = ensureScrollFrame(panel)

  local y = CONTENT_START_Y

  for _, row in ipairs(WIIIUI.Config.CONTROLS) do
    local build = isNoteRow(row) and WIIIUI.Config.BUILDERS.note or WIIIUI.Config.BUILDERS[row.kind]
    -- A row whose shown() fails isn't rendered at all; unlike `available`, no note. shown may only go false -> true (built rows are never hidden); a toggling condition needs a hide pass.
    if build and not (row.shown and not row.shown()) then
      y = y - build(content, row, ROW_X, y)
    end
  end

  local layoutStringY = y - 6
  ensureLayoutStringBox(content, ROW_X, layoutStringY)
  y = layoutStringY - ROW_HEIGHT

  local reloadY = y - 6
  ensureReloadButton(content, reloadY)
  -- Scroll range depends on the content child's actual height, not the
  -- scroll frame's visible height -- size it to reach past the reload
  -- button (the last row) plus a bottom margin.
  content:SetHeight(-(reloadY - RELOAD_BUTTON_HEIGHT) + CONTENT_BOTTOM_PADDING)

  -- spec 0001 §Customizer: "Customizer.lua owns the tab body, a frame
  -- parented to WIIIUI.Config.panel." Existence-checked: config_test.lua
  -- loads Config.lua without Customizer.lua.
  if WIIIUI.Customizer then
    WIIIUI.Customizer.BuildEditor(panel)
  end

  WIIIUI.Config.ShowTab(WIIIUI.Config.activeTab)
end

WIIIUI.RegisterBuild("Config.BuildConfig", WIIIUI.Config.BuildConfig)

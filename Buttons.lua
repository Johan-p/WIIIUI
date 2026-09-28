-- spec 0001 §Module split "Buttons.lua": LibActionButton-1.0 header + 36
-- grid buttons (rows B/M/T) + 9 extra slots (13-21), the bottom row's
-- per-page state driver, override bindings, hearthstone auto-place, retire
-- of bars 1-3 (R2).
local _, WIIIUI = ...

WIIIUI.Buttons = WIIIUI.Buttons or {}
WIIIUI.Buttons.rows = WIIIUI.Buttons.rows or {}

-- spec 0001 §1.3 (decided), §Buttons and paging: "extra slots
-- WIIIUI_Extra1..9: EXTRA_SLOT_BASE + 0..8 = slots 13-21, fixed." One
-- constant so a later revision (spec 0001 §1.3: "0003 can move it") only
-- changes this line.
WIIIUI.EXTRA_SLOT_BASE = 13
local EXTRA_SLOT_COUNT = 9

-- LibActionButton-1.0 (spec 0001 §1.4, vendored in libs/ by slice 11, loaded
-- before this file in the TOC).
local LAB = LibStub("LibActionButton-1.0")

-- Row definition: key (WIIIUI.Buttons.rows' table key), namePrefix (the
-- button's own global name, WIIIUI_ prefixed per spec 0001 "Named frames"),
-- baseAction (the action slot each button's index adds onto), bindingPrefix
-- (spec 0001 §Event -> widget wiring "UPDATE_BINDINGS": ACTIONBUTTONi /
-- MULTIACTIONBAR1BUTTONi / MULTIACTIONBAR2BUTTONi, in that B/M/T order).
-- GridM/GridT slots (61-72, 49-60) are spec 0001 §Buttons and paging's
-- decided fixed rows ("Bar 2"/"Bar 3", as vanilla).
local ROWS = {
  { key = "GridB", namePrefix = "WIIIUI_GridB", baseAction = 0, bindingPrefix = "ACTIONBUTTON" },
  { key = "GridM", namePrefix = "WIIIUI_GridM", baseAction = 60, bindingPrefix = "MULTIACTIONBAR1BUTTON" },
  { key = "GridT", namePrefix = "WIIIUI_GridT", baseAction = 48, bindingPrefix = "MULTIACTIONBAR2BUTTON" },
}

local header

-- spec 0001 §Buttons and paging "Bottom-row state driver" (D3), written
-- fresh from https://warcraft.wiki.gg/wiki/Macro_conditionals and
-- Blizzard_ActionBarController/ActionBarController.lua (Gethe/wow-ui-source
-- forever branch), not copied from Bartender (CLAUDE.md "Libraries").
-- vehicleui/possessbar/overridebar/shapeshift ("the temporary shapeshift
-- action bar is replacing the main action bar" per the wiki -- a TEMPORARY
-- form, distinct from the permanent stances/forms bonusbar:1-4 cover below)
-- all route to the runtime-resolved "possess" state (ONSTATE_PAGE_SNIPPET,
-- below); bar:2-6 are the vanilla Shift-paged bars; [bonusbar:1,stealth]8
-- (druid Prowl: Cat Form + stealthed) is a more specific clause placed
-- before the plain [bonusbar:1]7 so it wins while prowling, per
-- macro-conditional first-match-wins evaluation order. The exact ordering
-- needs in-game verification (Prowl, stances, vehicle) -- slice 13 Notes.
local PAGE_STATE_CONDITIONAL =
  "[vehicleui][possessbar][overridebar][shapeshift] possess;"
  .. " [bar:2]2;[bar:3]3;[bar:4]4;[bar:5]5;[bar:6]6;"
  .. " [bonusbar:1,stealth]8;[bonusbar:1]7;[bonusbar:2]8;[bonusbar:3]9;[bonusbar:4]10;"
  .. " 1"

-- spec 0001 §Buttons and paging: "The _onstate-page snippet resolves
-- possess at runtime with HasVehicleActionBar/GetVehicleBarIndex,
-- HasOverrideActionBar/GetOverrideBarIndex, HasTempShapeshiftActionBar/
-- GetTempShapeshiftBarIndex, GetBonusBarIndex, then
-- control:ChildUpdate('state', page)." self/stateid/newstate are the
-- SecureHandlerStateTemplate-provided locals for an _onstate-<id> snippet
-- (warcraft.wiki.gg SecureHandlerStateTemplate); control is the
-- SecureHandlerWrapScript-provided alias for the owning frame handle
-- (warcraft.wiki.gg SecureHandlerWrapScript). ChildUpdate("state", page)
-- runs each LAB button's own "_childupdate-state" attribute (vendored
-- libs/LibActionButton-1.0/LibActionButton-1.0.lua:362-365), which is what
-- actually applies the SetState(page, ...) table below to the button. The
-- seven bare function names (not C_ActionBar.-namespaced) are the
-- Blizzard_DeprecatedActionBar/Deprecated_ActionBar.lua wrappers (forever
-- branch) -- plain globals, matching what a macro-conditional/secure-snippet
-- environment can call; whether they're actually whitelisted there is an
-- in-game check (slice 13 Notes), not something this file can prove.
local ONSTATE_PAGE_SNIPPET = [[
  local page = newstate
  if newstate == "possess" then
    if HasVehicleActionBar() then
      page = GetVehicleBarIndex()
    elseif HasOverrideActionBar() then
      page = GetOverrideBarIndex()
    elseif HasTempShapeshiftActionBar() then
      page = GetTempShapeshiftBarIndex()
    else
      page = GetBonusBarIndex()
    end
  end
  control:ChildUpdate("state", page)
]]

-- spec 0001 §Buttons and paging: "Each bottom button gets SetState(p,
-- 'action', (p-1)*12 + i) for p = 1..14 (plus the runtime-resolved possess
-- page), set at build." 14 is the direct macro-conditional numeric states
-- (1-10) plus the four pages only reachable through the runtime-resolved
-- "possess" state above (11-14: vehicle/override/temp-shapeshift/bonus-bar
-- fallback each resolve to one of these).
local PAGE_COUNT = 14

local function applyPageStates(buttons)
  for p = 1, PAGE_COUNT do
    for i = 1, 12 do
      buttons[i]:SetState(p, "action", (p - 1) * 12 + i)
    end
  end
end

local function getOrCreateButton(namePrefix, i)
  local name = namePrefix .. i
  return _G[name] or LAB:CreateButton(i, name, header)
end

-- Vanilla AlignActionBars (e17c352 WIIIUI.lua:2639-2667): button 1 of each
-- row anchors BOTTOMLEFT to the grid frame (vanilla actionSlotGridMain,
-- this port's WIIIUI.Console.grid) at (uiScale*0.037037 - 6, originY - 1) --
-- approximating vanilla's own two-step chain (parentFrame's uiScale*0.037037,
-- -1 offset off actionSlotGridMain, plus actionButton1's own -6 offset off
-- MainMenuBarArtFrame), since MainMenuBarArtFrame no longer exists once
-- MainActionBar is retired (R2). Buttons 2-12 chain BOTTOMLEFT off the
-- previous button's BOTTOMLEFT at `spacing`. Exact on-screen placement is a
-- tester visual check (CLAUDE.md "the look is the specification").
local function anchorRow(buttons, originY, uiScale, geometry, grid)
  for i = 1, 12 do
    local button = buttons[i]

    button:SetSize(geometry.size, geometry.size)
    button:ClearAllPoints()

    if i == 1 then
      button:SetPoint(
        "BOTTOMLEFT", grid, "BOTTOMLEFT",
        uiScale * 0.037037 - 6, originY - 1
      )
    else
      button:SetPoint("BOTTOMLEFT", buttons[i - 1], "BOTTOMLEFT", geometry.spacing, 0)
    end
  end
end

-- spec 0001 §Buttons and paging: "Extra1 (slot 13) is the top minimap slot;
-- the order follows vanilla Bindings.xml (minimap 1-3, then inventory
-- TL/TR/ML/MR/BL/BR)." Fixed at LAB state 0, same "always-visible" treatment
-- as GridM/GridT above -- no RegisterStateDriver entry ever targets these,
-- so their action never changes with the bottom row's page (slice 14
-- acceptance criterion 1). No anchor: the spec's "Sizing and anchoring"
-- section covers only the 36-button grid rows; the extras' on-screen
-- position (minimap/inventory art) is not yet specified and is out of this
-- slice's scope.
local function buildExtras()
  local extras = WIIIUI.Buttons.extras

  if extras then
    return
  end

  extras = {}

  for i = 1, EXTRA_SLOT_COUNT do
    local button = getOrCreateButton("WIIIUI_Extra", i)
    button:SetState(0, "action", WIIIUI.EXTRA_SLOT_BASE - 1 + i)
    extras[i] = button
  end

  WIIIUI.Buttons.extras = extras
end

function WIIIUI.Buttons.BuildButtons()
  if not header then
    -- spec 0001 §Buttons and paging: "Header: a SecureHandlerStateTemplate
    -- frame." warcraft.wiki.gg SecureHandlerStateTemplate.
    header = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
  end

  local uiScale = wc3UI_Options.uiScale
  local geometry = WIIIUI.Theme.ActionButtonGeometry(uiScale)
  local grid = WIIIUI.Console.grid
  local rowOriginY = { 0, geometry.row2OffsetY, geometry.row3OffsetY }

  for rowIndex, row in ipairs(ROWS) do
    local buttons = WIIIUI.Buttons.rows[row.key]

    if not buttons then
      buttons = {}

      for i = 1, 12 do
        local button = getOrCreateButton(row.namePrefix, i)
        button:SetState(0, "action", row.baseAction + i)
        buttons[i] = button
      end

      WIIIUI.Buttons.rows[row.key] = buttons

      -- spec 0001 §Buttons and paging "Bottom-row state driver": only
      -- GridB is state-paged; GridM/GridT stay fixed (Bar 2/Bar 3, as
      -- vanilla, §Buttons and paging "Grid rows"). Tied to this same
      -- build-once guard so a second WIIIUI.Layout() call neither
      -- re-registers the state driver nor duplicates the per-page
      -- SetState table.
      if row.key == "GridB" then
        applyPageStates(buttons)
        header:SetAttribute("_onstate-page", ONSTATE_PAGE_SNIPPET)
        RegisterStateDriver(header, "page", PAGE_STATE_CONDITIONAL)
      end
    end

    anchorRow(buttons, rowOriginY[rowIndex], uiScale, geometry, grid)
  end

  buildExtras()
end

-- spec 0001 §Buttons and paging "Retire (R2)": MainActionBar,
-- MultiBarBottomLeft, MultiBarBottomRight retire through the same
-- WIIIUI.Retire(frame, unregister) seam PlayerFrame already uses
-- (Core.lua, slice 07) -- CLAUDE.md "Tech stack quirks": "resolve
-- _G.MainActionBar or _G.MainMenuBar at PLAYER_LOGIN", since the frame name
-- differs between clients.
local BAR_FRAME_RESOLVERS = {
  function() return _G.MainActionBar or _G.MainMenuBar end,
  function() return _G.MultiBarBottomLeft end,
  function() return _G.MultiBarBottomRight end,
}

-- spec 0001 §Buttons and paging: "plus their 36 stock buttons
-- (UnregisterAllEvents, statehidden)". SetAttribute("statehidden", true) is
-- the SecureHandlerStateTemplate-recognized way to hide a secure child
-- without a protected Show/Hide/SetShown call (warcraft.wiki.gg
-- SecureHandlerStateTemplate). No HideBase/SetParent here: these buttons are
-- children of the three bar frames above, which already cascade the
-- reparent/hide through WIIIUI.Retire. ActionButtonN / MultiBarBottomLeft
-- ButtonN / MultiBarBottomRightButtonN are Blizzard's own global button
-- names (FrameXML/MultiActionBars.lua naming convention, confirmed on the
-- Gethe/wow-ui-source mirror).
local STOCK_BUTTON_NAMES = {}

for i = 1, 12 do
  STOCK_BUTTON_NAMES[#STOCK_BUTTON_NAMES + 1] = "ActionButton" .. i
  STOCK_BUTTON_NAMES[#STOCK_BUTTON_NAMES + 1] = "MultiBarBottomLeftButton" .. i
  STOCK_BUTTON_NAMES[#STOCK_BUTTON_NAMES + 1] = "MultiBarBottomRightButton" .. i
end

function WIIIUI.Buttons.RetireBlizzardBars()
  for i = 1, #BAR_FRAME_RESOLVERS do
    WIIIUI.Retire(BAR_FRAME_RESOLVERS[i](), true)
  end

  for i = 1, #STOCK_BUTTON_NAMES do
    local button = _G[STOCK_BUTTON_NAMES[i]]

    if button then
      button:UnregisterAllEvents()
      button:SetAttribute("statehidden", true)
    end
  end
end

-- spec 0001 §Event -> widget wiring "UPDATE_BINDINGS": ClearOverrideBindings
-- then map ACTIONBUTTONi/MULTIACTIONBAR1BUTTONi/MULTIACTIONBAR2BUTTONi's
-- bound keys onto WIIIUI_GridB/M/Ti's LeftButton click via
-- SetOverrideBindingClick, in the B/M/T row order ROWS lists above.
-- WIIIUI.hider (Core.lua's existing hidden dispatch frame) is reused as the
-- override owner rather than creating a second frame purely to hold
-- bindings. GetBindingKey can return more than one key per command
-- (warcraft.wiki.gg API_GetBindingKey); every key returned is mapped, not
-- just the first. ClearOverrideBindings/SetOverrideBindingClick are both
-- #nocombat-restricted (warcraft.wiki.gg API_ClearOverrideBindings, API_
-- SetOverrideBindingClick), so this only ever runs through ApplyOrQueue.
function WIIIUI.Buttons.ApplyBindings()
  ClearOverrideBindings(WIIIUI.hider)

  for _, row in ipairs(ROWS) do
    for i = 1, 12 do
      local command = row.bindingPrefix .. i
      local target = row.namePrefix .. i
      local keys = { GetBindingKey(command) }

      for _, key in ipairs(keys) do
        SetOverrideBindingClick(WIIIUI.hider, false, key, target)
      end
    end
  end
end

-- spec 0001 §Event -> widget wiring: UPDATE_BINDINGS re-applies whenever the
-- player rebinds a key; PLAYER_LOGIN's own initial application is queued by
-- Core.lua (§A.4's PLAYER_LOGIN list explicitly includes "bindings" as its
-- own queue key, separate from "retire"/"layout").
WIIIUI.On("UPDATE_BINDINGS", function()
  WIIIUI.ApplyOrQueue("bindings", WIIIUI.Buttons.ApplyBindings)
end)

-- spec 0001 §Event -> widget wiring: "BAG_UPDATE_DELAYED (out of combat),
-- PLAYER_LOGIN | hearthstone auto-place (item ID 6948,
-- C_Container.GetContainerItemID; PickupContainerItem + PlaceAction
-- (EXTRA_SLOT_BASE) -- i.e. slot 13 -- only if not HasAction(slot) and not
-- in combat)". Item ID 6948 (Hearthstone) is the spec's own citation, not
-- looked up separately. NUM_BAG_SLOTS is Blizzard's own FrameXML constant
-- (= 4); bag 0 is the backpack, 1-NUM_BAG_SLOTS the equipped bag slots -- the
-- same range vanilla's own bag UI iterates.
local HEARTHSTONE_ITEM_ID = 6948

-- C_Container.GetContainerNumSlots/GetContainerItemID/PickupContainerItem --
-- ContainerDocumentation.lua (spec 0001 §WoW APIs relied on).
local function findHearthstoneBagSlot()
  for bag = 0, NUM_BAG_SLOTS do
    local numSlots = C_Container.GetContainerNumSlots(bag)

    for slot = 1, numSlots do
      if C_Container.GetContainerItemID(bag, slot) == HEARTHSTONE_ITEM_ID then
        return bag, slot
      end
    end
  end
end

-- C_ActionBar.HasAction: Blizzard_APIDocumentationGenerated/
-- ActionBarFrameDocumentation.lua (Namespace = "C_ActionBar", spec 0001 §WoW
-- APIs relied on) -- the real, non-deprecated API; the old global HasAction
-- only exists behind a CVar-gated deprecation fallback Blizzard says will be
-- removed. GetCursorInfo/ClearCursor: Blizzard_ActionBar/Shared/
-- ActionButton.lua (forever). The cursor-empty check before
-- PickupContainerItem stops this from disturbing whatever the player is
-- already holding (a bag item, a merchant purchase, a pickup mid-trade); the
-- kind/id check after PickupContainerItem only calls PlaceAction if the
-- cursor actually holds the hearthstone, and clears it otherwise (safe here
-- since the cursor was confirmed empty on entry).
function WIIIUI.Buttons.PlaceHearthstone()
  if GetCursorInfo() then
    return
  end

  if C_ActionBar.HasAction(WIIIUI.EXTRA_SLOT_BASE) then
    return
  end

  local bag, slot = findHearthstoneBagSlot()

  if not bag then
    return
  end

  C_Container.PickupContainerItem(bag, slot)

  local kind, id = GetCursorInfo()

  if kind == "item" and id == HEARTHSTONE_ITEM_ID then
    PlaceAction(WIIIUI.EXTRA_SLOT_BASE)
  else
    ClearCursor()
  end
end

WIIIUI.On("BAG_UPDATE_DELAYED", function()
  WIIIUI.ApplyOrQueue("hearthstone", WIIIUI.Buttons.PlaceHearthstone)
end)

WIIIUI.On("PLAYER_LOGIN", function()
  WIIIUI.ApplyOrQueue("hearthstone", WIIIUI.Buttons.PlaceHearthstone)
end)

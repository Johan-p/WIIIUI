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
-- below); bar:2-6 are the vanilla Shift-paged bars. The exact ordering needs
-- in-game verification (Prowl, stances, vehicle) -- slice 13 Notes.
local PAGE_STATE_PREFIX =
  "[vehicleui][possessbar][overridebar][shapeshift] possess;"
  .. " [bar:2]2;[bar:3]3;[bar:4]4;[bar:5]5;[bar:6]6;"
  .. " "

local PAGE_STATE_SUFFIX =
  "[bonusbar:1]7;[bonusbar:2]8;[bonusbar:3]9;[bonusbar:4]10;"
  .. " 1"

-- spec 0001 §Buttons and paging "Bottom-row state driver" (amended
-- 2026-09-28): [bonusbar:1,stealth] is class-agnostic -- Druid Cat Form and
-- Rogue "Stealthed" share bonus-bar offset 1
-- (https://warcraft.wiki.gg/wiki/API_GetBonusBarOffset), so an unconditional
-- clause would also route a stealthed rogue to page 8 (empty) instead of
-- their real stealth bar (7, the plain [bonusbar:1]7 clause). Placed before
-- that plain clause so it wins while prowling, per macro-conditional
-- first-match-wins evaluation order -- but only when buildPageStateConditional
-- (below) confirms the class is druid.
local PROWL_CLAUSE = "[bonusbar:1,stealth]8;"

-- spec 0001 §Buttons and paging "Bottom-row state driver" (amended
-- 2026-09-28): the Prowl clause is druid-only, gated through WIIIUI.PlayerClassToken
-- since UnitClass carries SecretWhenUnitIdentityRestricted/MayReturnNothing
-- (https://warcraft.wiki.gg/wiki/API_UnitClass) -- a secret, missing or
-- erroring classFilename degrades to the base string (no Prowl clause)
-- instead of throwing out of BuildButtons(). classFilename
-- (select(2, UnitClass("player"))) is the locale-independent upper-case
-- token, same page. Called once per BuildButtons() build (a player's class
-- never changes within a session), not cached at file scope, so the string
-- is rebuilt fresh -- and a headless test can load this file fresh per
-- UnitClass fixture.
local function buildPageStateConditional()
  local prowl = WIIIUI.PlayerClassToken() == "DRUID" and PROWL_CLAUSE or ""
  return PAGE_STATE_PREFIX .. prowl .. PAGE_STATE_SUFFIX
end

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
-- 'action', (p-1)*12 + i) for p = 1..N, set at build." 1-10 are the direct
-- macro-conditional states. The "possess" snippet above pages to
-- GetVehicleBarIndex / GetTempShapeshiftBarIndex / GetOverrideBarIndex, which
-- are pages 16 / 17 / 18 on modern clients (Dominos Action-Bar-Mappings wiki);
-- 13-15 are MultiBar5-7 (forever Blizzard_ActionBar/Shared/MultiActionBars.lua
-- :6-8). Covering 1..18 leaves no page without an entry, so LAB never blanks a
-- button in a vehicle, override-bar or temp-shapeshift state.
local PAGE_COUNT = 18

-- Fixed buttons (rows 2-3, the 9 extras) are children of the same header, so
-- the driver's ChildUpdate("state", page) reaches them too, and LAB shows a
-- button empty for any state it has no entry for (LibActionButton-1.0.lua
-- :311-321). They get the one action under state 0 and under every page 1..
-- PAGE_COUNT, which covers every page the driver can emit.
local function applyFixedState(button, action)
  button:SetState(0, "action", action)
  for p = 1, PAGE_COUNT do
    button:SetState(p, "action", action)
  end
end

local function applyPageStates(buttons)
  for p = 1, PAGE_COUNT do
    for i = 1, 12 do
      buttons[i]:SetState(p, "action", (p - 1) * 12 + i)
    end
  end
end

-- ActionButtonTemplate gives its state textures and overlays a fixed 46x45
-- anchored TOPLEFT (Gethe/wow-ui-source forever,
-- Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml), and LibActionButton
-- re-applies 52x51 to the highlight/checked textures on every update
-- (LibActionButton-1.0.lua:1848-1857, hideElements.border). At WIIIUI's
-- ~27-unit cells that art overhangs down and right, so every region is pinned
-- to the button rect (feature 0001 fix3, D3). Vanilla hid the frame art
-- entirely (NormalTexture width -1, e17c352 WIIIUI.lua:2611-2612) and let the
-- grid art show through empty slots, so those three are drawn at alpha 0.
local FIT_KEYS = {
  "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture", "Border", "Flash",
  "NewActionTexture", "SpellHighlightTexture", "SlotBackground", "SlotArt", "icon", "IconMask",
}
local INVISIBLE_KEYS = { "NormalTexture", "SlotBackground", "SlotArt" }

-- Set from anchorRow/anchorExtras, which know the button size and run on every
-- Layout; read by fitButtonArt.
local iconZoomByButton = {}

local function fitButtonArt(button)
  for _, key in ipairs(FIT_KEYS) do
    local region = button[key]
    if region then
      region:SetAllPoints(button)
    end
  end

  local icon = button.icon
  local zoom = iconZoomByButton[button]
  if icon and zoom then
    icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
  end
end

-- hideElements.border/borderIfEmpty make LibActionButton clear the
-- NormalTexture and drop the icon mask itself instead of re-drawing the
-- template frame art on each update (LibActionButton-1.0.lua:1850-1857,
-- 1886-1887); a config table is the library's own supported route.
local BUTTON_CONFIG = { hideElements = { border = true, borderIfEmpty = true } }

local function getOrCreateButton(namePrefix, i)
  local name = namePrefix .. i
  local existing = _G[name]
  if existing then
    return existing
  end

  local button = LAB:CreateButton(i, name, header, BUTTON_CONFIG)

  for _, key in ipairs(INVISIBLE_KEYS) do
    if button[key] then
      button[key]:SetAlpha(0)
    end
  end

  -- LibActionButton re-anchors these two after the fit above; a post-hook on
  -- the region (our own button's texture, never a Blizzard function) re-pins
  -- them straight after each of its SetPoint calls.
  for _, key in ipairs({ "HighlightTexture", "CheckedTexture" }) do
    if button[key] then
      hooksecurefunc(button[key], "SetPoint", function()
        button[key]:SetAllPoints(button)
      end)
    end
  end

  fitButtonArt(button)
  return button
end

-- Vanilla AlignActionBars (e17c352 WIIIUI.lua:2639-2667): button 1 of each
-- row anchors BOTTOMLEFT to the grid frame (vanilla actionSlotGridMain,
-- this port's WIIIUI.Console.grid), one row up by originY - 1. Every button,
-- column 1 included, anchors to the grid at its own art-derived column offset
-- (Theme.ActionButtonGeometry), not chained off its neighbour, so a pitch
-- error cannot accumulate (fix4); vanilla's magic origin
-- (uiScale*0.037037 - 6) is gone with MainMenuBarArtFrame (retired, R2). Exact
-- placement is a tester visual check (CLAUDE.md "the look is the specification").
local function anchorRow(buttons, originY, uiScale, geometry, grid)
  for i = 1, 12 do
    local button = buttons[i]

    button:SetSize(geometry.size, geometry.size)
    iconZoomByButton[button] = WIIIUI.Theme.IconZoom(uiScale, geometry.size)
    fitButtonArt(button)
    button:ClearAllPoints()

    button:SetPoint(
      "BOTTOMLEFT", grid, "BOTTOMLEFT",
      geometry.columnOffsetX[i], originY - 1
    )
  end
end

-- spec 0001 §Buttons and paging: "Extra1 (slot 13) is the top minimap slot;
-- the order follows vanilla Bindings.xml (minimap 1-3, then inventory
-- TL/TR/ML/MR/BL/BR)." Fixed like GridM/GridT: the one action under every
-- page, see applyFixedState.
--
-- spec 0001 slice 19b: anchoring via WIIIUI.Theme.ExtraSlotGeometry, every
-- BuildButtons() call (not just build-once, since size/position scale with
-- uiScale/theme) -- same split as anchorRow's own "create once, anchor
-- every call" convention above. Minimap slots (kind "minimap") anchor to
-- Console.left.minimapTexture's companion Frame; inventory slots (kind
-- "inventory") anchor to Console.right.rightPartMiddle's -- never to the
-- live Minimap widget itself
-- (spec 0001 slice 19b: an Edit Mode system's implicit-protection rule,
-- warcraft.wiki.gg Patch_2.0.1/API_changes -- "the parent of a protected
-- frame is implicitly protected also, as are any frames which it is
-- anchored to" -- and API_ScriptRegion_IsProtected).
-- A missing relativeTo (BuildLeft/BuildRight not built yet, or geometry
-- returning nil for an out-of-range index) skips that slot's anchor rather
-- than erroring, matching this file's existence-checked conventions
-- elsewhere (RetireBlizzardBars, BAR_FRAME_RESOLVERS).
local function anchorExtras(extras, uiScale, theme)
  local left = WIIIUI.Console.left
  local right = WIIIUI.Console.right
  -- Companion Frames, not the textures: a protected frame cannot anchor to a
  -- region ("Cannot anchor protected frames to regions"); see Console.lua's
  -- anchor companions.
  local minimapTexture = left and left.minimapTexture
  local inventoryTexture = right and right.rightPartMiddle
  local relativeByKind = {
    minimap = minimapTexture and WIIIUI.Console.AnchorFrame(minimapTexture),
    inventory = inventoryTexture and WIIIUI.Console.AnchorFrame(inventoryTexture),
  }

  for i = 1, EXTRA_SLOT_COUNT do
    local button = extras[i]
    local geometry = WIIIUI.Theme.ExtraSlotGeometry(uiScale, theme, i)
    local relativeTo = geometry and relativeByKind[geometry.kind]

    if button and geometry and relativeTo then
      button:SetSize(geometry.size, geometry.size)
      iconZoomByButton[button] = WIIIUI.Theme.IconZoom(uiScale, geometry.size)
      fitButtonArt(button)
      button:ClearAllPoints()
      button:SetPoint(geometry.point, relativeTo, geometry.relativePoint, geometry.offsetX, geometry.offsetY)
    end
  end
end

-- spec 0001 slice 19b gate-fix (ui-reviewer High finding): the 6 inventory
-- extras (Extra4..9) are children of `header` (a SecureHandlerStateTemplate),
-- not of Console.right, so Console.lua's applyLayoutModes calling
-- right:Hide() under centerSlimNoInv never cascades to them -- unlike
-- vanilla, where the equivalent ActionButton_CustomInventory_N buttons were
-- parented to rightFrame and hid along with it. Mirrors applyLayoutModes'
-- own precedence (Console.lua: "centerSlimNoInv ... not centerSlim") so
-- centerSlim's per-piece hiding still wins when both flags are set. The 3
-- minimap extras (i=1..3) are untouched -- centerSlimNoInv only ever hid the
-- right/inventory side in vanilla. Runs from buildExtras alongside
-- anchorExtras, so it's on the same "create once, refresh every
-- WIIIUI.Layout() call" path -- itself only ever reached through
-- ApplyOrQueue("layout", ...) (Core.lua), so this Show/Hide is already
-- combat-gated with no new queue path.
local function applyInventoryExtraVisibility(extras)
  local hideInventory = wc3UI_Options.centerSlimNoInv and not wc3UI_Options.centerSlim

  for i = 4, EXTRA_SLOT_COUNT do
    local button = extras[i]

    if button then
      if hideInventory then
        button:Hide()
      else
        button:Show()
      end
    end
  end
end

local function buildExtras(uiScale, theme)
  local extras = WIIIUI.Buttons.extras

  if not extras then
    extras = {}

    for i = 1, EXTRA_SLOT_COUNT do
      local button = getOrCreateButton("WIIIUI_Extra", i)
      applyFixedState(button, WIIIUI.EXTRA_SLOT_BASE - 1 + i)
      extras[i] = button
    end

    WIIIUI.Buttons.extras = extras
  end

  anchorExtras(extras, uiScale, theme)
  applyInventoryExtraVisibility(extras)
end

function WIIIUI.Buttons.BuildButtons()
  if not header then
    -- spec 0001 §Buttons and paging: "Header: a SecureHandlerStateTemplate
    -- frame." warcraft.wiki.gg SecureHandlerStateTemplate.
    header = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    -- Sized and anchored like the console roots (Console.lua BuildLeft) so
    -- its rect is valid: a frame with neither is not positionable on modern
    -- clients (API_ScriptRegion_IsRectValid, warcraft.wiki.gg). Creation
    -- only; BuildButtons runs out of combat (Core.lua's ApplyOrQueue).
    header:SetSize(1, 1)
    header:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
  end

  local uiScale = wc3UI_Options.uiScale
  local geometry = WIIIUI.Theme.ActionButtonGeometry(uiScale)
  local grid = WIIIUI.Console.grid
  local rowOriginY = { geometry.row1OffsetY, geometry.row2OffsetY, geometry.row3OffsetY }

  for rowIndex, row in ipairs(ROWS) do
    local buttons = WIIIUI.Buttons.rows[row.key]

    if not buttons then
      buttons = {}

      for i = 1, 12 do
        local button = getOrCreateButton(row.namePrefix, i)
        if row.key == "GridB" then
          button:SetState(0, "action", row.baseAction + i)
        else
          applyFixedState(button, row.baseAction + i)
        end
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
        RegisterStateDriver(header, "page", buildPageStateConditional())
      end
    end

    anchorRow(buttons, rowOriginY[rowIndex], uiScale, geometry, grid)
  end

  buildExtras(uiScale, wc3UI_Options.theme)
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

WIIIUI.RegisterBuild("Buttons.BuildButtons", WIIIUI.Buttons.BuildButtons, { after = { "Console.BuildRight" } })

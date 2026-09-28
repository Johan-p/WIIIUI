-- spec 0001 §Module split "Buttons.lua": LibActionButton-1.0 header + 36
-- grid buttons (rows B/M/T), override bindings, retire of bars 1-3 (R2).
-- D2 scope only (spec 0001 phased plan "D. Action slots"): the bottom row
-- (WIIIUI_GridB) is built at LAB's default state (0), showing actions 1-12,
-- the same fixed-row treatment as the middle/top rows -- RegisterStateDriver
-- and the full per-page SetState table (spec §Buttons and paging) are
-- slice 13's job (D3, "bottom-row paging").
local _, WIIIUI = ...

WIIIUI.Buttons = WIIIUI.Buttons or {}
WIIIUI.Buttons.rows = WIIIUI.Buttons.rows or {}

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
    end

    anchorRow(buttons, rowOriginY[rowIndex], uiScale, geometry, grid)
  end
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

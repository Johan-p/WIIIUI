-- spec 0001 §Module split "Portrait.lua": PlayerModel, secure unit button +
-- player menu, status icons (C2 -- combat text is C3, a later slice, and
-- out of scope here). PlayerFrame's own retire (R2) already happened in
-- Core.lua/slice 07 (spec 0004 §D3); this file only builds WIIIUI's own
-- replacement widgets, the same way Bars.lua built its own StatusBars once
-- PlayerFrame's children went with it.
local _, WIIIUI = ...

WIIIUI.Portrait = WIIIUI.Portrait or {}

-- spec 0001 §Portrait: "WIIIUI_Portrait: CreateFrame("Button",
-- "WIIIUI_Portrait", parent, "SecureUnitButtonTemplate") with attributes
-- unit = "player", type1 = "target", type2 = "togglemenu",
-- RegisterForClicks("AnyUp")." SECURE_ACTIONS.togglemenu opens Blizzard's
-- own player menu via UnitPopup_OpenMenu (decision 10; Blizzard_FrameXML/
-- SecureTemplates.lua:269-318 on the forever branch) -- no menu-building
-- code of our own. Attributes are set exactly once, on first creation, same
-- as Bars.lua's create-if-missing bar pattern; since WIIIUI.Layout() only
-- ever runs out of combat or queued to PLAYER_REGEN_ENABLED (Core.lua's
-- ApplyOrQueue), this is also "out of combat" and "never rewritten in
-- combat" (CLAUDE.md "No protected calls" / "Combat-lockdown safe") without
-- a second guard here.
local function buildButton(parent)
  local button = WIIIUI.Portrait.button

  if button then
    return button
  end

  button = CreateFrame("Button", "WIIIUI_Portrait", parent, "SecureUnitButtonTemplate")
  button:SetAttribute("unit", "player")
  button:SetAttribute("type1", "target")
  button:SetAttribute("type2", "togglemenu")
  button:RegisterForClicks("AnyUp")

  WIIIUI.Portrait.button = button
  return button
end

-- spec 0001 §Portrait: "The PlayerModel is a non-mouse child." Created once,
-- parented to the secure button; StopAnimation (SetPaused/SetAnimation vs.
-- FreezeAnimation) is deferred -- CLAUDE.md marks both **verify** and the
-- option is out of this slice's acceptance criteria.
local function buildModel(parent)
  local model = WIIIUI.Portrait.model

  if not model then
    model = CreateFrame("PlayerModel", nil, parent)
    WIIIUI.Portrait.model = model
  end

  return model
end

-- spec 0001 §Portrait: "Status icons are WIIIUI textures at the vanilla
-- offsets (vanilla WIIIUI.lua:3346-3393), using Blizzard atlases (names to
-- verify in-game)." The atlas names and the master-looter texture path are
-- both on the spec's own "Unverified" list (§WoW APIs relied on) -- left
-- for the tester's in-game pass rather than guessed here; this slice wires
-- each icon's Show/Hide to its driving event/API per the Event -> widget
-- wiring table, which is what the acceptance criteria test.
local ICON_DEFS = {
  { key = "pvpIcon", offsetX = -0.2307692, offsetY = 0 },
  { key = "leaderIcon", offsetX = 0.0784313, offsetY = 0.368627 },
  { key = "lootIcon", offsetX = 0.0784313, offsetY = 0.3137254 },
  { key = "roleIcon", offsetX = -0.188235, offsetY = 0.32941 },
  { key = "restIcon", offsetX = -0.188235, offsetY = 0.32941 },
  { key = "combatIcon", offsetX = -0.188235, offsetY = 0.32941 },
}

local function buildIcons(parent, uiScale)
  for _, def in ipairs(ICON_DEFS) do
    local icon = WIIIUI.Portrait[def.key]

    if not icon then
      icon = parent:CreateTexture(nil, "OVERLAY")
      WIIIUI.Portrait[def.key] = icon
    end

    icon:ClearAllPoints()
    icon:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", uiScale * def.offsetX, uiScale * def.offsetY)
  end
end

-- spec 0001 §Event -> widget wiring (Portrait row): UNIT_MODEL_CHANGED /
-- PLAYER_ENTERING_WORLD -> "PlayerModel:SetUnit("player"), camera". The
-- camera half is a client-only effect with no headless surface; SetUnit is
-- what this slice's stub test observes.
local function updateModel()
  local model = WIIIUI.Portrait.model
  if model then
    model:SetUnit("player")
  end
end

-- UNIT_FACTION / PLAYER_FLAGS_CHANGED -> PvP icon (UnitIsPVP /
-- UnitIsPVPFreeForAll).
local function updatePvP()
  local icon = WIIIUI.Portrait.pvpIcon
  if not icon then
    return
  end

  if UnitIsPVP("player") or UnitIsPVPFreeForAll("player") then
    icon:Show()
  else
    icon:Hide()
  end
end

-- GROUP_ROSTER_UPDATE / PARTY_LEADER_CHANGED -> leader icon
-- (UnitIsGroupLeader).
local function updateLeader()
  local icon = WIIIUI.Portrait.leaderIcon
  if not icon then
    return
  end

  if UnitIsGroupLeader("player") then
    icon:Show()
  else
    icon:Hide()
  end
end

-- PARTY_LOOT_METHOD_CHANGED -> master-looter icon (C_PartyInfo.
-- GetLootMethod). "master" is the loot-method token documented for
-- C_PartyInfo.GetLootMethod's first return (PartyInfoDocumentation.lua,
-- spec 0001 §WoW APIs relied on).
local function updateLootMethod()
  local icon = WIIIUI.Portrait.lootIcon
  if not icon then
    return
  end

  local method = C_PartyInfo and C_PartyInfo.GetLootMethod and C_PartyInfo.GetLootMethod()

  if method == "master" then
    icon:Show()
  else
    icon:Hide()
  end
end

-- PLAYER_ROLES_ASSIGNED -> role icon (UnitGroupRolesAssigned), new per
-- decision 11 -- "NONE" (the token UnitGroupRolesAssigned returns for a
-- unit with no assigned role) hides the icon.
local function updateRole()
  local icon = WIIIUI.Portrait.roleIcon
  if not icon then
    return
  end

  local role = UnitGroupRolesAssigned("player")

  if role and role ~= "NONE" then
    icon:Show()
  else
    icon:Hide()
  end
end

-- PLAYER_UPDATE_RESTING -> rest icon (IsResting).
local function updateResting()
  local icon = WIIIUI.Portrait.restIcon
  if not icon then
    return
  end

  if IsResting() then
    icon:Show()
  else
    icon:Hide()
  end
end

-- PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED -> combat icon
-- (UnitAffectingCombat). Registered alongside Core.lua's own
-- PLAYER_REGEN_ENABLED handler (WIIIUI.Flush) -- WIIIUI.On keeps a list per
-- event, so a second handler for the same event is additive, not a
-- conflict (Core.lua §A.3).
local function updateCombat()
  local icon = WIIIUI.Portrait.combatIcon
  if not icon then
    return
  end

  if UnitAffectingCombat("player") then
    icon:Show()
  else
    icon:Hide()
  end
end

-- spec 0001 §Portrait: the button sits directly on WIIIUI.Console.left's
-- portraitTexture (same size, zero offset) -- portraitTexture is already
-- positioned relative to the minimap texture by Console.BuildLeft/
-- Theme.PortraitGeometry, so anchoring here to portraitTexture itself
-- avoids re-deriving that same minimap-relative math a second time.
function WIIIUI.Portrait.BuildPortrait()
  local left = WIIIUI.Console.left
  local anchor = left and left.portraitTexture
  local uiScale = wc3UI_Options.uiScale
  local geometry = WIIIUI.Theme.PortraitGeometry(uiScale)

  local button = buildButton(UIParent)

  button:SetSize(geometry.size, geometry.size)
  button:ClearAllPoints()
  if anchor then
    button:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
  end

  local model = buildModel(button)
  model:SetSize(geometry.size, geometry.size)
  model:ClearAllPoints()
  model:SetPoint("CENTER", button, "CENTER", 0, 0)

  buildIcons(button, uiScale)

  updateModel()
  updatePvP()
  updateLeader()
  updateLootMethod()
  updateRole()
  updateResting()
  updateCombat()
end

WIIIUI.On("UNIT_MODEL_CHANGED", updateModel, "player")
WIIIUI.On("PLAYER_ENTERING_WORLD", updateModel)
WIIIUI.On("UNIT_FACTION", updatePvP, "player")
WIIIUI.On("PLAYER_FLAGS_CHANGED", updatePvP)
WIIIUI.On("GROUP_ROSTER_UPDATE", updateLeader)
WIIIUI.On("PARTY_LEADER_CHANGED", updateLeader)
WIIIUI.On("PARTY_LOOT_METHOD_CHANGED", updateLootMethod)
WIIIUI.On("PLAYER_ROLES_ASSIGNED", updateRole)
WIIIUI.On("PLAYER_UPDATE_RESTING", updateResting)
WIIIUI.On("PLAYER_REGEN_DISABLED", updateCombat)
WIIIUI.On("PLAYER_REGEN_ENABLED", updateCombat)

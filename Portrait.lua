-- spec 0001 §Module split "Portrait.lua": PlayerModel, secure unit button +
-- player menu, status icons (C2 -- combat text is C3, out of scope here per
-- spec 0001 §1.5). PlayerFrame's own retire (R2, spec 0001 §1.1) happens
-- through Core.lua's WIIIUI.Retire; this file only builds WIIIUI's own
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
  -- Every sibling console frame declares its strata explicitly at creation
  -- (Console.lua: left->"LOW", grid->"MEDIUM", right->"HIGH"). The portrait
  -- button sits directly over left.portraitTexture (spec 0001 §Portrait), so
  -- it takes left's own "LOW" strata rather than relying on the client's
  -- unset-strata default. API_Frame_GetFrameStrata, warcraft.wiki.gg.
  button:SetFrameStrata("LOW")

  WIIIUI.Portrait.button = button
  return button
end

-- spec 0001 §Portrait: "The PlayerModel is a non-mouse child." Created once,
-- parented to the secure button; StopAnimation (SetPaused/SetAnimation vs.
-- FreezeAnimation) is deferred -- CLAUDE.md marks both **verify**, and the
-- `StopAnimation` option itself is out of scope for spec 0001 §Portrait.
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
-- verify in-game)." Sizes/atlases below are a best-effort placeholder per
-- icon so each one attempts to render rather than staying invisible by
-- construction -- the exact atlas/texture names are on the spec's own
-- "Unverified" list (§WoW APIs relied on); confirm in-game, tester corrects
-- the exact art. Each icon's Show/Hide is wired to its driving event/API per
-- the Event -> widget wiring table below.
--
-- sizeFraction: uiScale fraction, not the vanilla offsets above (vanilla's
-- AlignPlayerIcons never sizes these -- it repositions Blizzard's own
-- pre-sized PlayerFrame icon frames). ICON_SIZE_DEFAULT matches the
-- Blizzard default for the one status icon with an explicit XML size --
-- RoleIcon, Size 12x12 (wow-ui-source forever,
-- Blizzard_UnitFrame/Mainline/PlayerFrame.xml:337-340) -- at uiScale's own
-- default of 240 (12/240 = 0.05); ICON_SIZE_REST matches RestTexture's
-- explicit 30x30 (PlayerFrame.xml:402-408) the same way (30/240 = 0.125).
-- The remaining icons (PvPIcon, LeaderIcon, AttackIcon) have no explicit
-- XML size -- Blizzard sizes them from their atlas at runtime
-- (TextureKitConstants.UseAtlasSize) -- so they reuse ICON_SIZE_DEFAULT as
-- a placeholder pending the in-game atlas-size check.
local ICON_SIZE_DEFAULT = 0.05
local ICON_SIZE_REST = 0.125

local ICON_DEFS = {
  {
    -- PlayerFrame.lua:385-403 PlayerFrame_ShowPvPIcon picks Horde/Alliance/
    -- FFA atlases by UnitFactionGroup; a static Horde atlas is used here as
    -- a build-time placeholder since faction-aware selection isn't wired.
    key = "pvpIcon", offsetX = -0.2307692, offsetY = 0, sizeFraction = ICON_SIZE_DEFAULT,
    atlas = "UI-HUD-UnitFrame-Player-PVP-HordeIcon",
  },
  {
    -- PlayerFrame.xml:327 LeaderIcon.
    key = "leaderIcon", offsetX = 0.0784313, offsetY = 0.368627, sizeFraction = ICON_SIZE_DEFAULT,
    atlas = "UI-HUD-UnitFrame-Player-Group-LeaderIcon",
  },
  {
    -- spec 0001 §Event -> widget wiring / §1.9 "Master looter": Forever's
    -- PlayerFrame has no master-looter icon, so WIIIUI supplies its own
    -- texture -- a literal shared (non-themed) path, same convention as
    -- Console.lua's extensionBackgroundTexture/rightPartBackground; the file
    -- doesn't exist yet (art to follow), path to verify.
    key = "lootIcon", offsetX = 0.0784313, offsetY = 0.3137254, sizeFraction = ICON_SIZE_DEFAULT,
    texture = "Interface\\Addons\\WIIIUI\\art\\other\\master_loot",
  },
  {
    -- PlayerFrame.lua:428-439 UpdateRoleIcon picks tank/healer/dps atlases
    -- by role; dps is used here as a build-time placeholder.
    key = "roleIcon", offsetX = -0.188235, offsetY = 0.32941, sizeFraction = ICON_SIZE_DEFAULT,
    atlas = "roleicon-tiny-dps",
  },
  {
    -- PlayerFrame.xml:402-412 RestTexture. Blizzard drives this atlas
    -- through a 7x6 FlipBook AnimationGroup; a static SetAtlas here shows
    -- only the sheet's first frame, not animated -- confirm in-game.
    key = "restIcon", offsetX = -0.188235, offsetY = 0.32941, sizeFraction = ICON_SIZE_REST,
    atlas = "UI-HUD-UnitFrame-Player-Rest-Flipbook",
  },
  {
    -- PlayerFrame.xml:344 AttackIcon.
    key = "combatIcon", offsetX = -0.188235, offsetY = 0.32941, sizeFraction = ICON_SIZE_DEFAULT,
    atlas = "UI-HUD-UnitFrame-Player-CombatIcon",
  },
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
    icon:SetSize(uiScale * def.sizeFraction, uiScale * def.sizeFraction)

    if def.atlas then
      icon:SetAtlas(def.atlas, false)
    elseif def.texture then
      icon:SetTexture(def.texture)
    end
  end
end

-- spec 0001 §Event -> widget wiring (Portrait row): UNIT_MODEL_CHANGED /
-- PLAYER_ENTERING_WORLD -> "PlayerModel:SetUnit("player"), camera". The
-- camera half is a client-only effect with no headless surface; SetUnit is
-- the part a headless test can observe.
local function updateModel()
  local model = WIIIUI.Portrait.model
  if model then
    model:SetUnit("player")
  end
end

-- UNIT_FACTION / PLAYER_FLAGS_CHANGED -> PvP icon (UnitIsPVP /
-- UnitIsPVPFreeForAll). PLAYER_FLAGS_CHANGED is a unit event (payload
-- unitTarget, UnitDocumentation.lua:3765-3769) and is registered with a
-- "player" filter below so it doesn't fire for every group member.
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
-- GetLootMethod). GetLootMethod's first return is typed `LootMethod`, an
-- Enum.LootMethod number, not a string (PartyInfoDocumentation.lua:292,
-- LootConstantsDocumentation.lua:15 -- Masterlooter = 2).
local function updateLootMethod()
  local icon = WIIIUI.Portrait.lootIcon
  if not icon then
    return
  end

  local method = C_PartyInfo and C_PartyInfo.GetLootMethod and C_PartyInfo.GetLootMethod()
  local master = Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter

  if master and method == master then
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
WIIIUI.On("PLAYER_FLAGS_CHANGED", updatePvP, "player")
WIIIUI.On("GROUP_ROSTER_UPDATE", updateLeader)
WIIIUI.On("PARTY_LEADER_CHANGED", updateLeader)
WIIIUI.On("PARTY_LOOT_METHOD_CHANGED", updateLootMethod)
WIIIUI.On("PLAYER_ROLES_ASSIGNED", updateRole)
WIIIUI.On("PLAYER_UPDATE_RESTING", updateResting)
WIIIUI.On("PLAYER_REGEN_DISABLED", updateCombat)
WIIIUI.On("PLAYER_REGEN_ENABLED", updateCombat)

-- spec 0001 §Module split "Portrait.lua": PlayerModel, secure unit button +
-- player menu, status icons (C2 -- combat text is C3, out of scope here per
-- spec 0001 §1.5). PlayerFrame's own retire (R2, spec 0001 §1.1) happens
-- through Core.lua's WIIIUI.Retire; this file only builds WIIIUI's own
-- replacement widgets, the same way Bars.lua built its own StatusBars once
-- PlayerFrame's children went with it.
local _, WIIIUI = ...

WIIIUI.Portrait = WIIIUI.Portrait or {}

-- spec 0001 §1.5: "our own WIIIUI_PortraitHitText FontString over the
-- portrait (vanilla offset uiScale*0.0222 above centre)." Vanilla
-- CombatTextPortrait (e17c352 WIIIUI.lua:2075): "PlayerHitIndicator:
-- SetPoint('CENTER', dummyFrameCombatText, 'CENTER', 0,
-- wc3UI_Options.uiScale*0.022222222)" -- PlayerHitIndicator is Blizzard's
-- own combat-feedback FontString (PlayerFrame.lua:51); this file's
-- WIIIUI_PortraitHitText replaces it entirely (PlayerFrame is retired, R2),
-- same offset. The shared font path/fallback pattern (Bars.lua) is
-- duplicated locally rather than exposed cross-file, matching this file's
-- own ICON_DEFS convention of file-local constants for its own widgets.
local FONT_PATH = "Interface\\Addons\\WIIIUI\\art\\other\\fonts\\blq55.TTF"
local HIT_TEXT_OFFSET_Y = 0.0222222

-- Blizzard_UnitFrame/Mainline/PlayerFrame.xml:112 (CombatFeedback_Initialize
-- call, PlayerFrame.lua:51): "CombatFeedback_Initialize(self, ...HitText,
-- 30)" -- 30 is the base font height CombatFeedback_OnCombatEvent scales
-- per event (see combatFeedbackParams below).
local BASE_HIT_TEXT_HEIGHT = 30

-- Blizzard_FrameXML/Mainline/CombatFeedback.lua: COMBATFEEDBACK_FADEINTIME/
-- HOLDTIME/FADEOUTTIME -- the vanilla fade timing spec 0001 §1.5 asks for
-- ("fades with an AnimationGroup (0.2 in / 0.7 hold / 0.3 out,
-- COMBATFEEDBACK_* constants)"), ported as WIIIUI's own local constants
-- since PlayerFrame's own globals of the same name are gone once it's
-- retired.
local COMBATFEEDBACK_FADEINTIME = 0.2
local COMBATFEEDBACK_HOLDTIME = 0.7
local COMBATFEEDBACK_FADEOUTTIME = 0.3

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

-- spec 0001 §1.5: "our own WIIIUI_PortraitHitText FontString over the
-- portrait ... RegisterUnitEvent('UNIT_COMBAT', 'player')." Built once,
-- centred on the button (same anchor as buildIcons) with the vanilla Y
-- offset; the fade AnimationGroup (0.2 in / 0.7 hold / 0.3 out) is plain
-- non-secret widget setup, so -- like buildLowHpOverlay's animation in
-- Bars.lua -- it isn't wrapped in WIIIUI.Safe.
local function buildHitText(parent, uiScale)
  local hitText = WIIIUI.Portrait.hitText

  if hitText then
    hitText:ClearAllPoints()
    hitText:SetPoint("CENTER", parent, "CENTER", 0, uiScale * HIT_TEXT_OFFSET_Y)
    return hitText
  end

  hitText = parent:CreateFontString("WIIIUI_PortraitHitText", "OVERLAY")
  hitText:SetPoint("CENTER", parent, "CENTER", 0, uiScale * HIT_TEXT_OFFSET_Y)
  hitText:Hide()

  -- CLAUDE.md "Tech stack quirks" font-fallback pattern, same as Bars.lua.
  -- NumberFontNormalHuge (Blizzard_Fonts_Shared/Shared/GameFontStyles.xml,
  -- forever branch) inherits NumberFont_Outline_Huge -- the same outlined
  -- style Blizzard's own PlayerFrame HitText uses (PlayerFrame.xml:115,
  -- CombatFeedback_Initialize's 30pt base), unlike GameFontHighlightSmall's
  -- body-text sizing.
  hitText:SetFontObject(NumberFontNormalHuge)
  local fontApplied = hitText:SetFont(FONT_PATH, BASE_HIT_TEXT_HEIGHT, "")

  if not fontApplied or not hitText:GetFont() then
    hitText:SetFontObject(NumberFontNormalHuge)
  end

  local animGroup = hitText:CreateAnimationGroup()

  local fadeIn = animGroup:CreateAnimation("Alpha")
  fadeIn:SetFromAlpha(0)
  fadeIn:SetToAlpha(1)
  fadeIn:SetDuration(COMBATFEEDBACK_FADEINTIME)
  fadeIn:SetOrder(1)

  local hold = animGroup:CreateAnimation("Alpha")
  hold:SetFromAlpha(1)
  hold:SetToAlpha(1)
  hold:SetDuration(COMBATFEEDBACK_HOLDTIME)
  hold:SetOrder(2)

  local fadeOut = animGroup:CreateAnimation("Alpha")
  fadeOut:SetFromAlpha(1)
  fadeOut:SetToAlpha(0)
  fadeOut:SetDuration(COMBATFEEDBACK_FADEOUTTIME)
  fadeOut:SetOrder(3)

  animGroup:SetScript("OnFinished", function()
    hitText:Hide()
  end)

  WIIIUI.Portrait.hitText = hitText
  WIIIUI.Portrait.hitTextAnim = animGroup

  return hitText
end

-- Ported from Blizzard's own CombatFeedback_OnCombatEvent
-- (Blizzard_FrameXML/Mainline/CombatFeedback.lua) -- same event/flags
-- branches, same colours, same font-height multipliers; only the
-- destination widget differs (WIIIUI_PortraitHitText instead of
-- PlayerFrame's HitIndicator.HitText). A pure function (no widget calls),
-- so any error inside it (e.g. a missing CombatFeedbackText/Enum.Damageclass
-- global) is caught by updateCombatText's single WIIIUI.Safe wrapper below,
-- same as the widget calls that use its result. COMBAT_TEXT_BLOCK_REDUCED
-- (Blizzard_FrameXML/Mainline/CombatFeedback.lua:50-52, forever branch,
-- unguarded in Blizzard's own source) formats the BLOCK_REDUCED case, same
-- as every other CombatFeedbackText/GlobalString below.
local function combatFeedbackParams(feedbackEvent, flags, amount, schoolMask)
  local text
  local r, g, b, heightScale = 1, 1, 1, 1

  if feedbackEvent == "IMMUNE" then
    heightScale = 0.5
    text = CombatFeedbackText[feedbackEvent]
  elseif feedbackEvent == "WOUND" then
    if amount ~= 0 then
      if flags == "CRITICAL" or flags == "CRUSHING" then
        heightScale = 1.5
      elseif flags == "GLANCING" then
        heightScale = 0.75
      end
      if schoolMask ~= Enum.Damageclass.MaskPhysical then
        r, g, b = 1, 1, 0
      end
      text = BreakUpLargeNumbers(amount)
      if flags == "BLOCK_REDUCED" then
        text = COMBAT_TEXT_BLOCK_REDUCED:format(text)
      end
    elseif flags == "ABSORB" then
      heightScale = 0.75
      text = CombatFeedbackText.ABSORB
    elseif flags == "BLOCK" then
      heightScale = 0.75
      text = CombatFeedbackText.BLOCK
    elseif flags == "RESIST" then
      heightScale = 0.75
      text = CombatFeedbackText.RESIST
    else
      text = CombatFeedbackText.MISS
    end
  elseif feedbackEvent == "BLOCK" then
    heightScale = 0.75
    text = CombatFeedbackText[feedbackEvent]
  elseif feedbackEvent == "HEAL" then
    text = BreakUpLargeNumbers(amount)
    r, g, b = 0, 1, 0
    if flags == "CRITICAL" then
      heightScale = 1.5
    end
  elseif feedbackEvent == "ENERGIZE" then
    text = BreakUpLargeNumbers(amount)
    r, g, b = 0.41, 0.8, 0.94
    if flags == "CRITICAL" then
      heightScale = 1.5
    end
  else
    text = CombatFeedbackText[feedbackEvent]
  end

  return text, r, g, b, heightScale
end

-- spec 0001 §1.5: "formats BreakUpLargeNumbers(amount) (secret-tolerant);
-- picks colour and size by event/flags strings, which are not secret;
-- takes miss/block/etc words from Blizzard's CombatFeedbackText table; on
-- any failure, calls WIIIUI.Safe and skips the event." One Safe call wraps
-- text-building and every widget call together, so a missing global, a
-- schoolMask comparison that turns out to be secret in some context (the
-- spec's own "Unverified" item), or anything else in between all take the
-- same single degrade path -- hide the text, skip this hit.
local function updateCombatText(_, feedbackEvent, flags, amount, schoolMask)
  local hitText = WIIIUI.Portrait.hitText
  local animGroup = WIIIUI.Portrait.hitTextAnim

  if not hitText or not animGroup then
    return
  end

  local ok = WIIIUI.Safe(function()
    local text, r, g, b, heightScale = combatFeedbackParams(feedbackEvent, flags, amount, schoolMask)

    hitText:SetText(text)
    hitText:SetTextColor(r, g, b)
    hitText:SetTextHeight(BASE_HIT_TEXT_HEIGHT * heightScale)
    hitText:Show()
    animGroup:Stop()
    animGroup:Play()
  end)

  if not ok then
    hitText:Hide()
  end
end

-- spec 0001 §Portrait: the button sits directly on WIIIUI.Console.left's
-- portraitTexture (same size, zero offset) -- portraitTexture is already
-- positioned relative to the minimap texture by Console.BuildLeft/
-- Theme.PortraitGeometry, so anchoring here to portraitTexture's rect
-- avoids re-deriving that same minimap-relative math a second time. The
-- button is protected and the client refuses to anchor a protected frame to a
-- region, so it anchors to the texture's companion Frame (Console.lua).
function WIIIUI.Portrait.BuildPortrait()
  local left = WIIIUI.Console.left
  local anchor = left and left.portraitTexture and WIIIUI.Console.AnchorFrame(left.portraitTexture)
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

  buildHitText(button, uiScale)
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
WIIIUI.On("UNIT_COMBAT", updateCombatText, "player")

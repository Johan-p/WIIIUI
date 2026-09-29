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
-- same offset.
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

  WIIIUI.Portrait.button = button
  return button
end

local applyModelView -- defined with updateModel below

-- spec 0001 §Portrait: "The PlayerModel is a non-mouse child." Created once,
-- parented to the secure button.
local function buildModel(parent)
  local model = WIIIUI.Portrait.model

  if not model then
    model = CreateFrame("PlayerModel", nil, parent)
    WIIIUI.Portrait.model = model
    model:SetScript("OnModelLoaded", function()
      applyModelView()
    end)
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
-- The faction badge is a detailed shield; at the 12 px default it is
-- unreadable, so it gets twice the size.
local ICON_SIZE_PVP = 0.1

local ICON_DEFS = {
  {
    -- The atlas is chosen per faction in updatePvP (PVP_ATLASES below);
    -- this build-time one only gives the texture a first frame.
    key = "pvpIcon", offsetX = -0.26, offsetY = 0, sizeFraction = ICON_SIZE_PVP,
    atlas = "UI-HUD-UnitFrame-Player-PVP-HordeIcon",
  },
  {
    -- PlayerFrame.xml:327 LeaderIcon.
    key = "leaderIcon", offsetX = 0.0784313, offsetY = 0.368627, sizeFraction = ICON_SIZE_DEFAULT,
    atlas = "UI-HUD-UnitFrame-Player-Group-LeaderIcon",
  },
  {
    -- spec 0001 §Event -> widget wiring / §1.9 "Master looter": Forever's
    -- PlayerFrame has no master-looter icon and no Blizzard master-looter
    -- texture/atlas is present in the forever UI source, so WIIIUI ships its
    -- own (art/other/master_loot.tga, generated by a workspace script) -- a
    -- literal shared (non-themed) path, same convention as Console.lua's
    -- extensionBackgroundTexture.
    key = "lootIcon", offsetX = 0.0784313, offsetY = 0.3137254, sizeFraction = ICON_SIZE_DEFAULT,
    texture = "Interface\\Addons\\WIIIUI\\art\\other\\master_loot",
  },
  {
    -- PlayerFrame.lua:422-444 PlayerFrame_UpdateRolesAssigned picks the
    -- atlas per role (ROLE_ATLASES below); dps is only the first frame.
    key = "roleIcon", offsetX = -0.2, offsetY = 0.2625, sizeFraction = ICON_SIZE_DEFAULT,
    atlas = "roleicon-tiny-dps",
  },
  {
    -- PlayerFrame.xml:402-414 (forever) RestTexture: the atlas is a 6-column
    -- x 7-row, 42-frame sprite sheet that Blizzard animates with a FlipBook
    -- (duration 1.5, frame width/height 0, group looping REPEAT). Drawn
    -- statically it shows all 42 frames at once, so updateResting plays the
    -- same animation while resting (feature 0001 fix5).
    key = "restIcon", offsetX = -0.188235, offsetY = 0.32941, sizeFraction = ICON_SIZE_REST,
    atlas = "UI-HUD-UnitFrame-Player-Rest-Flipbook",
    flipBook = { rows = 7, columns = 6, frames = 42, duration = 1.5 },
  },
  {
    -- PlayerFrame.xml:344 AttackIcon.
    key = "combatIcon", offsetX = -0.2, offsetY = 0.2, sizeFraction = ICON_SIZE_DEFAULT,
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
      icon.lastAtlas = def.atlas
    elseif def.texture then
      icon:SetTexture(def.texture)
    end

    if def.flipBook and not WIIIUI.Portrait.restAnimGroup then
      -- Animation:SetTarget is left at its default, the group's own region
      -- (the texture the group is created on). FlipBook setters:
      -- Blizzard_APIDocumentationGenerated/SimpleAnimFlipBookAPIDocumentation.lua
      -- (forever); CreateAnimation/SetLooping: SimpleAnimGroupAPIDocumentation.lua.
      local group = icon:CreateAnimationGroup()
      local flip = group:CreateAnimation("FlipBook")

      flip:SetFlipBookRows(def.flipBook.rows)
      flip:SetFlipBookColumns(def.flipBook.columns)
      flip:SetFlipBookFrames(def.flipBook.frames)
      flip:SetFlipBookFrameWidth(0)
      flip:SetFlipBookFrameHeight(0)
      flip:SetDuration(def.flipBook.duration)
      flip:SetOrder(1)
      group:SetLooping("REPEAT")

      WIIIUI.Portrait.restAnimGroup = group
    end
  end
end

-- Blizzard_UnitFrame/Mainline/PlayerFrame.lua:385-403 (forever)
-- PlayerFrame_ShowPvPIcon: one atlas per UnitFactionGroup token / "FFA".
local PVP_ATLASES = {
  Horde = "UI-HUD-UnitFrame-Player-PVP-HordeIcon",
  Alliance = "UI-HUD-UnitFrame-Player-PVP-AllianceIcon",
  FFA = "UI-HUD-UnitFrame-Player-PVP-FFAIcon",
}

-- PlayerFrame.lua:422-444 (forever) PlayerFrame_UpdateRolesAssigned, keyed by
-- UnitGroupRolesAssigned's string result.
local ROLE_ATLASES = {
  TANK = "roleicon-tiny-tank",
  HEALER = "roleicon-tiny-healer",
  DAMAGER = "roleicon-tiny-dps",
}

-- spec 0001 §Event -> widget wiring (Portrait row): UNIT_MODEL_CHANGED /
-- PLAYER_ENTERING_WORLD -> "PlayerModel:SetUnit("player"), camera". SetUnit
-- resets the camera to the full-body default, so vanilla re-selected camera 0
-- after every SetUnit (ModifyPlayerPortrait, e17c352 WIIIUI.lua:1767, 1787).
-- Model:SetCamera(cameraIndex): SimpleModelAPIDocumentation.lua:413, forever
-- and live branches of Gethe/wow-ui-source.
--
-- StopAnimation (vanilla ModifyPlayerPortrait, e17c352 WIIIUI.lua:1771-1783
-- pinned sequence 3 from an OnUpdate): Model:SetSequenceTime(sequence,
-- timeOffset) and Model:SetPaused(paused) are both in
-- SimpleModelAPIDocumentation.lua (forever :625/:677, live :625/:677). The
-- pose is set and the model paused instead of ticking an OnUpdate. SetUnit
-- replaces the model, so this runs after every SetUnit, in both directions:
-- an unchecked option must un-pause a model that a previous SetUnit kept paused.
--
-- SetUnit loads the model asynchronously, so the camera and freeze sent right
-- after it can be dropped when the load completes. The OnModelLoaded script
-- (a Model script handler: TalkingHeadUI.xml:130 and UI.xsd:424/1224 on the
-- forever branch of Gethe/wow-ui-source) re-applies them. applyModelView is
-- idempotent and never calls SetUnit, so it cannot loop.
local FROZEN_SEQUENCE = 3

function applyModelView()
  local model = WIIIUI.Portrait.model
  if not model then
    return
  end

  model:SetCamera(0)
  if wc3UI_Options.StopAnimation then
    model:SetSequenceTime(FROZEN_SEQUENCE, 0)
    model:SetPaused(true)
  else
    model:SetPaused(false)
  end
end

local function updateModel()
  local model = WIIIUI.Portrait.model
  if model then
    model:SetUnit("player")
    applyModelView()
  end
end

-- UNIT_FACTION / PLAYER_FLAGS_CHANGED / PLAYER_ENTERING_WORLD -> PvP icon
-- (UnitIsPVP / UnitIsPVPFreeForAll, atlas by UnitFactionGroup).
-- PLAYER_FLAGS_CHANGED is a unit event (payload unitTarget,
-- UnitDocumentation.lua:3765-3769) and is registered with a "player" filter
-- below so it doesn't fire for every group member. PLAYER_ENTERING_WORLD
-- covers login/reload/zoning, where the flags are already set and no flag
-- event follows.
local function updatePvP()
  local icon = WIIIUI.Portrait.pvpIcon
  if not icon then
    return
  end

  local flagged, atlas = true, nil
  if UnitIsPVPFreeForAll("player") then
    atlas = PVP_ATLASES.FFA
  elseif UnitIsPVP("player") then
    atlas = PVP_ATLASES[UnitFactionGroup("player")]
  else
    flagged = false
  end

  if flagged then
    -- A token with no atlas (Neutral) keeps the current one, as Blizzard's
    -- PlayerFrame_ShowPvPIcon does.
    if atlas and atlas ~= icon.lastAtlas then
      icon:SetAtlas(atlas, false)
      icon.lastAtlas = atlas
    end
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

-- PLAYER_ROLES_ASSIGNED / GROUP_ROSTER_UPDATE / PLAYER_ENTERING_WORLD ->
-- role icon (UnitGroupRolesAssigned), new per decision 11 -- "NONE" (the
-- token UnitGroupRolesAssigned returns for a unit with no assigned role)
-- hides the icon. The last two triggers cover joining a group and logging in
-- already grouped, where PLAYER_ROLES_ASSIGNED doesn't fire. The result is
-- SecretWhenUnitIdentityRestricted (UnitDocumentation.lua, forever), so it is
-- never compared unless issecretvalue says it is safe; a secret or failed
-- read hides the icon.
local function updateRole()
  local icon = WIIIUI.Portrait.roleIcon
  if not icon then
    return
  end

  local ok, role = WIIIUI.Safe(UnitGroupRolesAssigned, "player")
  local atlas
  if ok and not (issecretvalue and issecretvalue(role)) then
    atlas = ROLE_ATLASES[role]
  end

  if atlas then
    if atlas ~= icon.lastAtlas then
      icon:SetAtlas(atlas, false)
      icon.lastAtlas = atlas
    end
    icon:Show()
  else
    icon:Hide()
  end
end

-- PLAYER_UPDATE_RESTING / PLAYER_ENTERING_WORLD / PLAYER_REGEN_* -> rest icon
-- (IsResting). Blizzard's own PlayerFrame re-reads it on the same set
-- (PlayerFrame.lua PLAYER_ENTERING_WORLD / PLAYER_REGEN_* branches), because
-- PLAYER_UPDATE_RESTING alone misses login state and combat transitions.
local function updateResting()
  local icon = WIIIUI.Portrait.restIcon
  if not icon then
    return
  end

  local group = WIIIUI.Portrait.restAnimGroup

  if IsResting() then
    icon:Show()
    if group then
      group:Play()
    end
  else
    icon:Hide()
    if group then
      group:Stop()
    end
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
-- non-secret widget setup, so -- like buildLowHpOverlay's animation
-- below -- it isn't wrapped in WIIIUI.Safe.
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
  WIIIUI.Theme.ApplyFont(hitText, BASE_HIT_TEXT_HEIGHT, NumberFontNormalHuge)

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

-- Vanilla LowHPWarning (e17c352 WIIIUI.lua:3875-3939): the low-HP flash
-- lives on the portrait art, ported forward per spec 0001 §1.2 and moved here
-- from Bars.lua (spec 0006 Slice 04) so the overlay is built beside the model
-- it sits behind. white_background.tga already ships in art/other/ (the same
-- file vanilla toggled between white_background/black_background -- this
-- port uses SetVertexColor for the fixed red tint instead, so only one of the
-- two files is needed).
local LOW_HP_TEXTURE = "Interface\\Addons\\WIIIUI\\art\\other\\white_background"
local LOW_HP_PULSE_DURATION = 1

-- spec 0001 §1.2: "Low-HP pulse ... overlay is a frame holding the red
-- portrait-background texture. Its child texture runs a looping
-- AnimationGroup Alpha 0<->1 (1 s each way, the vanilla timing)." The pulse
-- covers exactly the model window, one frame level below it (fix6 B4).
-- Building the animation is plain non-secret widget setup (no unit value
-- involved), so unlike the curve/SetAlpha calls below it isn't wrapped in
-- WIIIUI.Safe.
local function buildLowHpOverlay(model)
  local overlay = WIIIUI.Portrait.lowHpOverlay

  if not overlay then
    overlay = CreateFrame("Frame", nil, UIParent)

    local texture = overlay:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(overlay)
    texture:SetTexture(LOW_HP_TEXTURE)
    texture:SetVertexColor(1, 0, 0, 1)

    -- "Its child texture runs a looping AnimationGroup Alpha 0<->1" --
    -- BOUNCE plays the single 0->1 animation forward then backward each
    -- cycle, giving the 1s-each-way ping-pong with one animation instead
    -- of two (warcraft.wiki.gg API_AnimationGroup_SetLooping).
    local animGroup = texture:CreateAnimationGroup()
    local pulse = animGroup:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0)
    pulse:SetToAlpha(1)
    pulse:SetDuration(LOW_HP_PULSE_DURATION)
    animGroup:SetLooping("BOUNCE")
    animGroup:Play()

    overlay.texture = texture
    overlay.animGroup = animGroup
    WIIIUI.Portrait.lowHpOverlay = overlay
  end

  overlay:ClearAllPoints()
  overlay:SetAllPoints(model)
  WIIIUI.Layers.Apply(overlay, "portrait.overlay")
end

-- spec 0001 §1.2: "A Step curve with points (0,1), (hpWarning/100,1),
-- (hpWarning/100+0.0001,0), (1,0) ... The curve is rebuilt when hpWarning
-- changes." Cached alongside the threshold it was built for (not just
-- built once at login) so this file alone -- without a Config.lua hook --
-- notices a changed wc3UI_Options.hpWarning on the next health event.
-- lowHpCurveFailed*/fingerprint cache a build failure (missing
-- Enum.LuaCurveType/C_CurveUtil) against the threshold *and* the
-- prerequisite-existence fingerprint it failed at (same reasoning as
-- Bars.lua's healthCurveFingerprint), so a known-failing build isn't retried on
-- every health event, but still recovers on the next event once the
-- missing piece reappears, without waiting for hpWarning to change.
local function lowHpCurveFingerprint()
  return C_CurveUtil ~= nil and Enum ~= nil and Enum.LuaCurveType ~= nil
end

local lowHpCurve, lowHpCurveThreshold
local lowHpCurveFailed, lowHpCurveFailedThreshold, lowHpCurveFailedFingerprint

local function getLowHpCurve()
  local threshold = wc3UI_Options.hpWarning

  if lowHpCurve and lowHpCurveThreshold == threshold then
    return lowHpCurve
  end

  local fingerprint = lowHpCurveFingerprint()

  if
    lowHpCurveFailed
    and lowHpCurveFailedThreshold == threshold
    and lowHpCurveFailedFingerprint == fingerprint
  then
    return nil
  end

  local ok, curve = WIIIUI.Safe(function()
    local cutoff = threshold / 100
    local c = C_CurveUtil.CreateCurve()
    c:SetType(Enum.LuaCurveType.Step)
    c:AddPoint(0, 1)
    c:AddPoint(cutoff, 1)
    c:AddPoint(cutoff + 0.0001, 0)
    c:AddPoint(1, 0)
    return c
  end)

  if ok then
    lowHpCurve = curve
    lowHpCurveThreshold = threshold
    lowHpCurveFailed = false
  else
    lowHpCurve = nil
    lowHpCurveThreshold = nil
    lowHpCurveFailed = true
    lowHpCurveFailedThreshold = threshold
    lowHpCurveFailedFingerprint = fingerprint
  end

  return lowHpCurve
end

-- spec 0001 §1.2: "overlay:SetAlpha(UnitHealthPercent('player', true,
-- stepCurve)) ... Effective alpha = parent (secret 0/1) x child (animated),
-- so there is no comparison, no arithmetic and no OnUpdate." Never calls
-- Show/Hide based on the secret result itself -- only WIIIUI.Safe's own ok
-- flag (a plain boolean, not a unit value) drives the one degrade action.
local function updateLowHpPulse()
  local overlay = WIIIUI.Portrait.lowHpOverlay
  if not overlay then
    return
  end

  -- A corpse's health percent is 0, which the step curve maps to "warn":
  -- the pulse must stay off while dead or a ghost (fix6 B4).
  -- UnitIsDeadOrGhost is not secret (UnitDocumentation.lua, forever).
  if UnitIsDeadOrGhost("player") then
    overlay:Hide()
    return
  end

  local curve = getLowHpCurve()
  if not curve then
    overlay:Hide()
    return
  end

  local ok = WIIIUI.Safe(function()
    overlay:SetAlpha(UnitHealthPercent("player", true, curve))
  end)

  if ok then
    overlay:Show()
  else
    overlay:Hide()
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

  -- Vanilla's model is a window on the portrait art, placed off the minimap
  -- texture (Theme.PortraitModelGeometry), not centred on the whole art.
  -- Anchored to the texture's companion Frame like the button above.
  local model = buildModel(button)
  local minimapAnchor = left and left.minimapTexture and WIIIUI.Console.AnchorFrame(left.minimapTexture)
  local modelGeometry = WIIIUI.Theme.PortraitModelGeometry(
    uiScale,
    wc3UI_Options.portraitScale,
    wc3UI_Options.PortraitAlignmentX,
    wc3UI_Options.PortraitAlignmentY
  )
  model:SetSize(modelGeometry.size, modelGeometry.size)
  model:ClearAllPoints()
  if minimapAnchor then
    model:SetPoint("BOTTOMLEFT", minimapAnchor, "BOTTOMLEFT", modelGeometry.offsetX, modelGeometry.offsetY)
  end

  buildHitText(button, uiScale)
  buildIcons(button, uiScale)

  -- Draw order over the left art (spec 0001 fix6 B4/B5): the low-HP overlay
  -- sits one level above the art, the model one above the overlay and the
  -- button above the model, so the pulse shows through behind the model.
  -- Levels are relative to the art frame, never absolute.
  -- The role icon clears the model window by about 2 px at the default
  -- PortraitAlignmentX/portraitScale; larger values let the model sit behind
  -- it, which is cosmetic because the icons draw above the model.
  -- The button is the top of the portrait stack so the status icons and hit
  -- text (its regions) draw over the model; it is applied first because
  -- SetFrameLevel on a parent also shifts its children.
  WIIIUI.Layers.Apply(button, "portrait.button")
  WIIIUI.Layers.Apply(model, "portrait.model")
  buildLowHpOverlay(model)
  -- Settle the fresh overlay (shown, alpha 1, BOUNCE running) before any
  -- other step can throw, so an error later in the build can't leave a
  -- stuck full-alpha pulse at full health.
  updateLowHpPulse()

  updateModel()
  updatePvP()
  updateLeader()
  updateLootMethod()
  updateRole()
  updateResting()
  updateCombat()
  updateLowHpPulse()
end

WIIIUI.On("UNIT_MODEL_CHANGED", updateModel, "player")
WIIIUI.On("PLAYER_ENTERING_WORLD", updateModel)
WIIIUI.On("PLAYER_ENTERING_WORLD", updatePvP)
WIIIUI.On("PLAYER_ENTERING_WORLD", updateRole)
WIIIUI.On("PLAYER_ENTERING_WORLD", updateResting)
WIIIUI.On("UNIT_FACTION", updatePvP, "player")
WIIIUI.On("PLAYER_FLAGS_CHANGED", updatePvP, "player")
WIIIUI.On("GROUP_ROSTER_UPDATE", updateLeader)
WIIIUI.On("GROUP_ROSTER_UPDATE", updateRole)
WIIIUI.On("PARTY_LEADER_CHANGED", updateLeader)
WIIIUI.On("PARTY_LOOT_METHOD_CHANGED", updateLootMethod)
WIIIUI.On("PLAYER_ROLES_ASSIGNED", updateRole)
WIIIUI.On("PLAYER_UPDATE_RESTING", updateResting)
WIIIUI.On("PLAYER_REGEN_DISABLED", updateCombat)
WIIIUI.On("PLAYER_REGEN_ENABLED", updateCombat)
WIIIUI.On("PLAYER_REGEN_DISABLED", updateResting)
WIIIUI.On("PLAYER_REGEN_ENABLED", updateResting)
WIIIUI.On("UNIT_COMBAT", updateCombatText, "player")

-- Same "player" filter as Bars.lua's UNIT_HEALTH/UNIT_MAXHEALTH, which is what
-- WIIIUI.On's one-filter-per-event rule requires.
WIIIUI.On("UNIT_HEALTH", updateLowHpPulse, "player")
WIIIUI.On("UNIT_MAXHEALTH", updateLowHpPulse, "player")

-- Death/resurrection changes the pulse's dead-or-ghost gate without a health
-- event necessarily following (spirit release, ghost resurrection).
WIIIUI.On("PLAYER_DEAD", updateLowHpPulse)
WIIIUI.On("PLAYER_ALIVE", updateLowHpPulse)
WIIIUI.On("PLAYER_UNGHOST", updateLowHpPulse)

WIIIUI.RegisterBuild("Portrait.BuildPortrait", WIIIUI.Portrait.BuildPortrait, { after = { "Bars.BuildBars" } })

-- spec 0001 §Module split "InfoIcons.lua": "3 weapon icons + armor icon,
-- locale-independent stat APIs, tooltips" (armor icon is slice 19, F2).
-- Ported from vanilla AlignWeaponFrame/SetWeaponIcon (e17c352 WIIIUI.lua:
-- 2258-2405, 1692-1734). Vanilla's tooltip-scanning stat calculators
-- (GetBlockValue/GetSpellpowerValue/GetHealingpowerValue, e17c352 WIIIUI.lua:
-- 4064-4510, enUS text patterns) are deleted per spec 0001 §1.7, replaced by
-- the documented Forever/retail stat APIs below -- all verified present on
-- the forever branch's generated API docs (spec 0001 §1.7's own citations)
-- and independently confirmed on warcraft.wiki.gg (cited per function).
local _, WIIIUI = ...

WIIIUI.InfoIcons = WIIIUI.InfoIcons or {}

-- Vanilla weaponIconSelected values (e17c352 WIIIUI.lua:2267,2271,2275,
-- 1696-1719): 16 main hand, 17 offhand/block, 18 ranged, 0 ammo, 98 healing,
-- 99 spell power, "none" hidden. Mirrors Core.lua's own WEAPON_ICON_VALUES
-- set (DEFAULTS merge-time validation) -- kept as an independent local copy
-- here so WIIIUI.InfoIcons.ResolveOption is a self-contained guard against
-- any raw/unvalidated value reaching a build, not just ones that already
-- passed MergeDefaults.
local VALID_OPTIONS = {
  [16] = true,
  [17] = true,
  [18] = true,
  [0] = true,
  [98] = true,
  [99] = true,
  ["none"] = true,
}

-- Core.lua's DEFAULTS: weaponIconSelected1 = 16, weaponIconSelected2/3 =
-- "none".
local SLOT_DEFAULT = { 16, "none", "none" }

-- spec 0001 §1.7 acceptance: "an invalid saved choice falls back to 16/
-- 'none' per the settings schema." slotIndex selects which of the three
-- per-slot defaults applies; an out-of-range slotIndex falls back to slot
-- 1's default rather than erroring.
function WIIIUI.InfoIcons.ResolveOption(value, slotIndex)
  if VALID_OPTIONS[value] then
    return value
  end
  return SLOT_DEFAULT[slotIndex] or SLOT_DEFAULT[1]
end

local MAINHAND_SLOT, OFFHAND_SLOT, RANGED_SLOT = 16, 17, 18
local AMMO_OPTION, HEALING_OPTION, SPELLPOWER_OPTION = 0, 98, 99
local AMMO_SLOT_NAME = "AmmoSlot"

-- warcraft.wiki.gg ItemEquipLoc: "INVTYPE_SHIELD ... corresponds to the Off
-- Hand slot (InvSlotId 17)". spec 0001 §1.7: "shield check: ...
-- C_Item.GetItemInfoInstant(id) equip-loc 'INVTYPE_SHIELD' (token,
-- locale-free)".
local SHIELD_EQUIP_LOC = "INVTYPE_SHIELD"

-- Vanilla SetWeaponIcon (e17c352 WIIIUI.lua:1709,1711,1722): the healing/
-- spell-power icons are fixed Blizzard icon textures, not an equipped item's
-- own texture; "fist" is the no-item-equipped fallback for the weapon slots
-- (art/other/fist.tga, already shipped).
local FIST_ICON = "Interface\\Addons\\WIIIUI\\art\\other\\fist"
local HEALING_ICON = "Interface\\Icons\\Spell_Holy_Heal"
local SPELLPOWER_ICON = "Interface\\Icons\\INV_Staff_07"

-- Vanilla Wc3_UI_weaponIcon_frame_N's own Backdrop (e17c352 WIIIUI.xml:2437),
-- the ornate border drawn over the icon (weaponIconFrame:SetFrameLevel(10)
-- keeps it above the icon backdrop, e17c352 WIIIUI.lua:2282).
local BORDER_TEXTURE = "Interface\\Addons\\WIIIUI\\art\\other\\golden_frame"

-- Vanilla WIIIUI_weaponDamage_N/WIIIUI_weaponNumbers_N (e17c352 WIIIUI.xml:
-- 2375-2402): both FontHeight 10, the same theme font as the rest of the
-- console (Bars.lua's own FONT_PATH constant, duplicated per-file per this
-- codebase's existing per-file-constant convention).
local FONT_PATH = "Interface\\Addons\\WIIIUI\\art\\other\\fonts\\blq55.TTF"
local LABEL_FONT_SIZE, VALUE_FONT_SIZE = 10, 10

-- GetSpellBonusDamage(school) school indices (warcraft.wiki.gg
-- API_GetSpellBonusDamage): 1 Physical (not a caster school, excluded), 2
-- Holy, 3 Fire, 4 Nature, 5 Frost, 6 Shadow, 7 Arcane -- spec 0001 §1.7:
-- "max(GetSpellBonusDamage(2..7))".
local SPELL_POWER_SCHOOLS = { 2, 3, 4, 5, 6, 7 }
local SCHOOL_NAMES = { [2] = "Holy", [3] = "Fire", [4] = "Nature", [5] = "Frost", [6] = "Shadow", [7] = "Arcane" }

-- spec 0001 §1.7 "Armor icon": UnitArmor("player") + reduction via
-- C_PaperDollInfo.GetArmorEffectiveness(armor, UnitLevel("player")); tooltip
-- adds GetDodgeChance/GetParryChance/GetBlockChance, UnitResistance(1..5)
-- and latency (select(3, GetNetStats())). Blizzard_FrameXMLBase/
-- Constants.lua:140 (forever branch): "INVSLOT_CHEST = 5" -- vanilla
-- SetArmorIcon (e17c352 WIIIUI.lua:1736-1746) read this same slot for the
-- armor icon's own texture, falling back to a generic cape icon when empty.
local CHEST_SLOT = 5
local ARMOR_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_Cape_10"

-- UnitResistance(unit, damageClass) (warcraft.wiki.gg API_UnitResistance;
-- independently confirmed present on the forever branch's own
-- UnitDocumentation.lua -- Wowpedia's "removed in Patch 8.0.1" note is a
-- retail-UI-only removal, not an API removal, and doesn't apply here).
-- damageClass order per the classic resistanceIndex convention (0 Physical
-- -- that's armor's own job, excluded; 1 Holy .. 6 Arcane, spec 0001 §1.7
-- only asks for 1..5) -- order **unverified in-game**, same caveat spec
-- 0001 §1.7 states for SCHOOL_NAMES' own spell-school order above.
local RESISTANCE_NAMES = { [1] = "Holy", [2] = "Fire", [3] = "Nature", [4] = "Frost", [5] = "Shadow" }

-- spec 0001 §1.7 "Form icons (CheckIfInForm)": vanilla matched the active
-- shapeshift form by its LOCALIZED name (e17c352 WIIIUI.lua:1609-1666:
-- "Bear Form", "Cat Form", ...) to pick a hand-authored icon per form; the
-- modern GetShapeshiftFormInfo(index) signature doesn't even return a name
-- any more (warcraft.wiki.gg API_GetShapeshiftFormInfo: "icon, active,
-- castable, spellID = GetShapeshiftFormInfo(index)"), which is exactly
-- spec 0001 §1.7's own phrasing -- "icon (texture) instead of the name".
-- This port therefore does no name/type matching and keeps no per-form
-- icon table: it shows the active form's own icon verbatim, in place of
-- both the mainhand weapon icon and the armor icon (vanilla's own
-- SetWeaponIcon(iconWeapon)/SetArmorIcon(iconArmor) pairing, e17c352
-- WIIIUI.lua:1660-1661). UnitClass's 2nd return (classFilename, e.g.
-- "DRUID") is locale-independent, unlike its 1st (className) --
-- UnitDocumentation.lua (forever): "className ... ConditionalSecret =
-- true", "classFilename" carries no such flag.
--
-- Vanilla's Shaman/Ghost Wolf branch (e17c352 WIIIUI.lua:1671-1687,
-- UnitBuff icon-path scan) is not ported here: spec 0001 §1.7 flags its own
-- replacement, C_UnitAuras.GetPlayerAuraBySpellID(2645), "**verify**" on
-- Forever. The function itself is confirmed present (UnitAuraDocumentation.
-- lua, forever branch: "GetPlayerAuraBySpellID", SecretWhenUnitAuraRestricted
-- = true), but spell ID 2645's correctness and this function's behaviour
-- under that restriction flag are not -- left for an in-game check rather
-- than guessed at (CLAUDE.md "Unconfirmed API").
local DRUID_CLASS_FILENAME = "DRUID"

-- Every call here (UnitClass/GetNumShapeshiftForms/GetShapeshiftFormInfo) is
-- unguarded, same as computeStats/computeArmorStats below -- its two
-- callers already run inside WIIIUI.Safe.
local function activeShapeshiftIcon()
  if select(2, UnitClass("player")) ~= DRUID_CLASS_FILENAME then
    return nil
  end

  for formIndex = 1, GetNumShapeshiftForms() do
    local icon, active = GetShapeshiftFormInfo(formIndex)
    if active then
      return icon
    end
  end

  return nil
end

local function formatRange(low, high)
  return math.floor(low) .. " - " .. math.ceil(high)
end

-- security-specialist Finding (slice 19 gate-fix, generalized beyond the
-- mainhand-only special case): every option previously resolved its icon
-- texture inside computeStats, entirely inside the one WIIIUI.Safe call that
-- also does the SecretWhenUnitStatsRestricted arithmetic below -- a throw
-- there aborted before the icon was ever returned, leaving the icon stale
-- (or empty on the first build) for offhand/ranged/healing/spellpower too,
-- not just mainhand. resolveIcon is now the one place that resolves an
-- option's icon texture; RefreshSlot calls it in its own WIIIUI.Safe, before
-- Safe(computeStats, option), so the icon always tracks the current form/
-- equipped item even when the label/value degrade. None of
-- GetInventoryItemTexture/C_PaperDollInfo.GetInventorySlotInfo/
-- activeShapeshiftIcon read a secret value (this file's header comment) --
-- the Safe wrap at the call site is defense-in-depth, not a required guard.
-- Ammo caveat: the hide-when-no-ammo-slot/hide-when-relic-slot decision
-- stays inside computeStats (unchanged below) -- when the icon should be
-- hidden, the value resolveIcon returns here is never shown, so it doesn't
-- need to encode that hide logic itself.
local function resolveIcon(option)
  if option == MAINHAND_SLOT then
    return activeShapeshiftIcon() or GetInventoryItemTexture("player", MAINHAND_SLOT) or FIST_ICON
  end

  if option == OFFHAND_SLOT then
    return GetInventoryItemTexture("player", OFFHAND_SLOT) or FIST_ICON
  end

  if option == RANGED_SLOT then
    return GetInventoryItemTexture("player", RANGED_SLOT) or FIST_ICON
  end

  if option == AMMO_OPTION then
    local ammoSlot = C_PaperDollInfo.GetInventorySlotInfo(AMMO_SLOT_NAME)
    return (ammoSlot and GetInventoryItemTexture("player", ammoSlot)) or FIST_ICON
  end

  if option == HEALING_OPTION then
    return HEALING_ICON
  end

  if option == SPELLPOWER_OPTION then
    return SPELLPOWER_ICON
  end

  return FIST_ICON
end

-- Every stat read below (UnitDamage/UnitAttackSpeed/UnitRangedDamage/
-- GetShieldBlock/GetBlockChance/GetSpellBonusDamage/GetSpellBonusHealing) is
-- flagged SecretWhenUnitStatsRestricted on Forever (spec 0001 §1.7: "Stats
-- are flagged SecretWhenUnitStatsRestricted, so every read goes through
-- WIIIUI.Safe; on failure the icon shows its label with an empty value").
-- computeStats itself does the (potentially secret-throwing) arithmetic/
-- formatting unguarded; its one caller, WIIIUI.InfoIcons.RefreshSlot, wraps
-- the whole call in WIIIUI.Safe (Bars.lua's own updateHealth/updatePower
-- convention), so any error here degrades to a shown label with a blank
-- value rather than aborting WIIIUI.Layout(). The icon itself is no longer
-- part of this return value -- resolveIcon above is the single source of
-- truth for it (RefreshSlot resolves it separately, before this call).
-- GetInventoryItemID/GetInventoryItemTexture/GetInventoryItemCount/
-- C_Item.GetItemInfoInstant/C_PaperDollInfo.GetInventorySlotInfo/
-- UnitHasRelicSlot are not flagged secret (identity/count/equip-loc data,
-- not a unit stat) -- called directly, same as Bars.lua's own non-secret
-- calls (SetMinMaxValues args, etc.) outside its Safe-guarded blocks.
local function computeStats(option)
  if option == MAINHAND_SLOT then
    local lowDmg, highDmg = UnitDamage("player")
    local mainSpeed = UnitAttackSpeed("player")
    local tooltip = { "|cffffd100Main Hand Damage:|r " .. formatRange(lowDmg, highDmg) }

    if mainSpeed and mainSpeed > 0 then
      tooltip[#tooltip + 1] = "|cffffd100Attack Speed:|r " .. string.format("%.2f", mainSpeed)
      local dps = ((math.floor(lowDmg) + math.ceil(highDmg)) / 2) / mainSpeed
      tooltip[#tooltip + 1] = "|cffffd100Damage per Second:|r " .. string.format("%.2f", dps)
    end

    return {
      label = "Damage:",
      text = formatRange(lowDmg, highDmg),
      tooltip = tooltip,
    }
  end

  if option == OFFHAND_SLOT then
    local itemID = GetInventoryItemID("player", OFFHAND_SLOT)

    if not itemID then
      return { label = "Damage:", text = "N/A", tooltip = { "No offhand equipped" } }
    end

    local equipLoc = select(4, C_Item.GetItemInfoInstant(itemID))

    if equipLoc == SHIELD_EQUIP_LOC then
      local blockValue = GetShieldBlock()
      local blockChance = GetBlockChance()
      return {
        label = "Block:",
        text = string.format("%.1f%%\n(%d)", blockChance, blockValue),
        tooltip = {
          "|cffffd100Block Chance:|r " .. string.format("%.1f%%", blockChance),
          "|cffffd100Block Value:|r " .. tostring(blockValue),
        },
      }
    end

    local _, _, offLowDmg, offHiDmg = UnitDamage("player")
    local _, offSpeed = UnitAttackSpeed("player")
    local tooltip = { "|cffffd100Offhand Damage:|r " .. formatRange(offLowDmg, offHiDmg) }

    if offSpeed and offSpeed > 0 then
      tooltip[#tooltip + 1] = "|cffffd100Attack Speed:|r " .. string.format("%.2f", offSpeed)
    end

    return {
      label = "Damage:",
      text = formatRange(offLowDmg, offHiDmg),
      tooltip = tooltip,
    }
  end

  if option == RANGED_SLOT then
    local equipped = GetInventoryItemTexture("player", RANGED_SLOT)

    if not equipped then
      return { label = "Damage:", text = "N/A", tooltip = { "No ranged weapon equipped" } }
    end

    local speed, lowDmg, highDmg = UnitRangedDamage("player")
    local tooltip = { "|cffffd100Ranged Damage:|r " .. formatRange(lowDmg, highDmg) }

    if speed and speed > 0 then
      tooltip[#tooltip + 1] = "|cffffd100Attack Speed:|r " .. string.format("%.2f", speed)
    end

    return {
      label = "Damage:",
      text = formatRange(lowDmg, highDmg),
      tooltip = tooltip,
    }
  end

  if option == AMMO_OPTION then
    -- spec 0001 §1.7: "hide the option when UnitHasRelicSlot('player')" --
    -- computeStats returns nil (not a table) for this one case; RefreshSlot
    -- treats a nil, ok result as "hide", distinct from a Safe failure.
    if UnitHasRelicSlot("player") then
      return nil
    end

    local ammoSlot = C_PaperDollInfo.GetInventorySlotInfo(AMMO_SLOT_NAME)

    -- security-specialist Finding 2 (slice 18 gate-fix): on retail there is
    -- no ammo slot, so GetInventorySlotInfo("AmmoSlot") returns nil
    -- (C_PaperDollInfo.GetInventorySlotInfo, warcraft.wiki.gg -- invSlot may
    -- be nil for a slot the client doesn't have). RefreshSlot already treats
    -- computeStats returning nil, ok as "hide the icon" (the UnitHasRelicSlot
    -- branch above uses the same convention), so this matches that existing
    -- contract instead of falling through to a misleading "No ammo" row.
    if not ammoSlot then
      return nil
    end

    local texture = GetInventoryItemTexture("player", ammoSlot)

    if not texture then
      return { label = "Ammo:", text = "|cffff0000No ammo|r", tooltip = { "No ammo equipped" } }
    end

    local count = GetInventoryItemCount("player", ammoSlot)
    local colorPrefix = ""

    if count < 200 then
      colorPrefix = "|cffff0000"
    elseif count < 400 then
      colorPrefix = "|cffffff00"
    end

    return {
      label = "Ammo:",
      text = colorPrefix .. tostring(count) .. (colorPrefix ~= "" and "|r" or ""),
      tooltip = { "|cffffd100Ammo:|r " .. tostring(count) },
    }
  end

  if option == HEALING_OPTION then
    local healing = GetSpellBonusHealing()
    return {
      label = "Healing:",
      text = tostring(healing),
      tooltip = { "|cffffd100Healing Power:|r " .. tostring(healing) },
    }
  end

  if option == SPELLPOWER_OPTION then
    local best = 0
    local tooltip = {}

    for _, school in ipairs(SPELL_POWER_SCHOOLS) do
      local bonus = GetSpellBonusDamage(school)
      if bonus > best then
        best = bonus
      end
      tooltip[#tooltip + 1] = "|cffffd100" .. SCHOOL_NAMES[school] .. ":|r " .. tostring(bonus)
    end

    return {
      label = "Spell:",
      text = tostring(best),
      tooltip = tooltip,
    }
  end

  return nil
end

-- spec 0001 §1.7 "Armor icon": vanilla's own DR formula (e17c352 WIIIUI.lua
-- :2432-2436, 2467-2472, a hand-rolled 400+85*level approximation) is
-- deleted, replaced by the documented API -- confirmed against wow-ui-
-- source live's own PaperDollFrame_GetArmorReduction (Blizzard_UIPanels_
-- Game/Mainline/PaperDollFrame.lua:1889-1891): "return C_PaperDollInfo.
-- GetArmorEffectiveness(armor, attackerLevel) * 100" -- the raw return is a
-- 0-1 fraction, not a percent, so this port multiplies by 100 too before
-- formatting. UnitArmor's 2nd return (effective) is the same value
-- Blizzard's own code passes as `armor` (PaperDollFrame.lua:707-709:
-- "local baselineArmor, effectiveArmor... PaperDollFrame_GetArmorReduction
-- (effectiveArmor, ...)"). Every stat read below (UnitArmor/UnitResistance/
-- GetDodgeChance/GetParryChance/GetBlockChance) is
-- SecretWhenUnitStatsRestricted (this file's header comment); called
-- unguarded here, same as computeStats above -- RefreshArmor's own
-- WIIIUI.Safe wrap (this function's one caller) covers it.
-- Mirrors resolveIcon above for the armor slot -- the single source of
-- truth for the armor icon's texture, resolved separately (RefreshArmor's
-- own WIIIUI.Safe) from computeArmorStats' SecretWhenUnitStatsRestricted
-- reads so a throw there doesn't stall the icon on a stale form/item.
local function resolveArmorIcon()
  return activeShapeshiftIcon() or GetInventoryItemTexture("player", CHEST_SLOT) or ARMOR_ICON_FALLBACK
end

local function computeArmorStats()
  local _, effective = UnitArmor("player")
  local reduction = C_PaperDollInfo.GetArmorEffectiveness(effective, UnitLevel("player"))

  local tooltip = {
    "|cffffd100Dodge:|r " .. string.format("%.1f%%", GetDodgeChance()),
    "|cffffd100Parry:|r " .. string.format("%.1f%%", GetParryChance()),
    "|cffffd100Block:|r " .. string.format("%.1f%%", GetBlockChance()),
  }

  for resistIndex = 1, 5 do
    local _, _, effectiveResist = UnitResistance("player", resistIndex)
    tooltip[#tooltip + 1] = "|cffffd100" .. (RESISTANCE_NAMES[resistIndex] or ("Resist " .. resistIndex))
      .. ":|r " .. tostring(effectiveResist)
  end

  -- spec 0001 §1.7: "latency select(3, GetNetStats())" -- GetNetStats
  -- (ConnectionDocumentation.lua, forever) returns bandwidthIn,
  -- bandwidthOut, then one or more latency figures (home, and world when
  -- present); select(3, ...) forwards all of them starting at the first
  -- latency value without this file needing to know how many there are.
  local latencies = { select(3, GetNetStats()) }
  local latencyLabels = { "Latency (Home):", "Latency (World):" }

  for index, latency in ipairs(latencies) do
    tooltip[#tooltip + 1] = "|cffffd100" .. (latencyLabels[index] or "Latency:") .. "|r " .. tostring(latency) .. " ms"
  end

  return {
    label = "Armor:",
    text = string.format("%.1f%%", reduction * 100),
    tooltip = tooltip,
  }
end

-- Static per-option label so a Safe failure (secret-value arithmetic
-- throwing) still "shows its label with an empty value" (spec 0001 §1.7)
-- instead of a blank row -- computeStats' own more specific label (e.g.
-- "Block:" vs the offhand's "Damage:") is only known on a successful read.
local STATIC_LABELS = {
  [MAINHAND_SLOT] = "Damage:",
  [OFFHAND_SLOT] = "Damage:",
  [RANGED_SLOT] = "Damage:",
  [AMMO_OPTION] = "Ammo:",
  [HEALING_OPTION] = "Healing:",
  [SPELLPOWER_OPTION] = "Spell:",
}

-- Vanilla WIIIUI_weaponIcon_N / Wc3_UI_weaponIcon_tex_N / Wc3_UI_weaponIcon_
-- frame_N (e17c352 WIIIUI.xml:2363-2542): one outer frame, an icon backdrop
-- (bgFile swapped per-option, same "backdrop as image" convention Console.lua
-- and Config.lua already use), and a border backdrop (golden_frame, drawn
-- above the icon via SetFrameLevel) plus the two FontStrings. Backdrops need
-- BackdropTemplate (CLAUDE.md "Backdrops").
local function ensureIconWidgets(slotIndex)
  local existing = WIIIUI.InfoIcons[slotIndex]
  if existing then
    return existing
  end

  local frame = CreateFrame("Frame", nil, UIParent)

  local icon = CreateFrame("Frame", nil, frame, "BackdropTemplate")

  local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  border:SetBackdrop({ bgFile = BORDER_TEXTURE })
  -- Vanilla weaponIconFrame:SetFrameLevel(10) (e17c352 WIIIUI.lua:2282):
  -- the border draws above the icon backdrop, both siblings of frame.
  border:SetFrameLevel(10)

  -- ui-reviewer Finding 3 (slice 18 gate-fix): width comes from
  -- WeaponIconGeometry's labelWidth (uiScale-dependent, applied per-call in
  -- BuildWeaponIcons below); height/justify are vanilla's own flat constants
  -- (weaponDamageText/weaponNumbersText, e17c352 WIIIUI.lua:2293-2296,
  -- 2367-2370) and don't depend on uiScale, so they're set once here.
  local label = frame:CreateFontString(nil, "OVERLAY")
  label:SetFontObject(GameFontHighlightSmall)
  local labelFontApplied = label:SetFont(FONT_PATH, LABEL_FONT_SIZE, "")
  if not labelFontApplied or not label:GetFont() then
    label:SetFontObject(GameFontHighlightSmall)
  end
  label:SetHeight(15)
  label:SetJustifyH("LEFT")
  label:SetJustifyV("TOP")

  local value = frame:CreateFontString(nil, "OVERLAY")
  value:SetFontObject(GameFontHighlightSmall)
  local valueFontApplied = value:SetFont(FONT_PATH, VALUE_FONT_SIZE, "")
  if not valueFontApplied or not value:GetFont() then
    value:SetFontObject(GameFontHighlightSmall)
  end
  value:SetHeight(30)
  value:SetJustifyH("LEFT")
  value:SetJustifyV("TOP")

  local widgets = { frame = frame, icon = icon, border = border, label = label, value = value }
  WIIIUI.InfoIcons[slotIndex] = widgets

  -- Vanilla Wc3_UI_weaponIcon_frame_N's OnEnter/OnLeave (e17c352 WIIIUI.xml:
  -- 2443-2536) built a custom WIIIUI_infoBox popup; this port uses Blizzard's
  -- own GameTooltip instead (a real Blizzard global, non-protected -- no new
  -- frame system to build/maintain for a single-purpose tooltip).
  border:SetScript("OnEnter", function()
    WIIIUI.InfoIcons.ShowTooltip(slotIndex)
  end)
  border:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  return widgets
end

-- spec 0001 §1.7's guard seam applied per-slot: option == "none" hides
-- outright (no API call at all); computeStats returning nil, ok (the ammo
-- UnitHasRelicSlot case) also hides; a Safe failure keeps the icon shown
-- with its static label and a blank value, per the spec's "shows its label
-- with an empty value" wording.
function WIIIUI.InfoIcons.RefreshSlot(slotIndex)
  local widgets = WIIIUI.InfoIcons[slotIndex]
  if not widgets then
    return
  end

  local key = "weaponIconSelected" .. slotIndex
  local option = WIIIUI.InfoIcons.ResolveOption(wc3UI_Options[key], slotIndex)
  widgets.option = option

  if option == "none" then
    widgets.tooltip = nil
    widgets.frame:Hide()
    return
  end

  -- security-specialist Finding (slice 19 gate-fix, generalized to every
  -- option -- resolveIcon's own header comment): resolved here, outside the
  -- stats-only Safe call below, so the icon always tracks the current form/
  -- equipped item even when the label/value degrade for any option, not
  -- just mainhand.
  local iconOk, icon = WIIIUI.Safe(resolveIcon, option)
  widgets.icon:SetBackdrop({ bgFile = (iconOk and icon) or FIST_ICON })

  local ok, result = WIIIUI.Safe(computeStats, option)

  if ok and result then
    widgets.label:SetText(result.label)
    widgets.value:SetText(result.text)
    widgets.tooltip = result.tooltip
    widgets.frame:Show()
  elseif ok then
    -- computeStats(option) returned nil for a non-"none" option (the ammo
    -- slot's UnitHasRelicSlot hide, spec 0001 §1.7).
    widgets.tooltip = nil
    widgets.frame:Hide()
  else
    widgets.label:SetText(STATIC_LABELS[option] or "")
    widgets.value:SetText("")
    widgets.tooltip = nil
    widgets.frame:Show()
  end
end

-- spec 0001 §1.7's guard seam applied to the armor icon: unlike the 3
-- weapon slots this icon has no wc3UI_Options key and no "none" state
-- (vanilla never hid it, e17c352 WIIIUI.lua:2407-2486) -- only a Safe
-- failure changes its display, degrading to the static label with a blank
-- value, same contract as RefreshSlot.
local ARMOR_STATIC_LABEL = "Armor:"

function WIIIUI.InfoIcons.RefreshArmor()
  local widgets = WIIIUI.InfoIcons.armor
  if not widgets then
    return
  end

  -- security-specialist Finding (slice 19 gate-fix): mirrors RefreshSlot's
  -- resolveIcon fix above -- computeArmorStats resolves
  -- activeShapeshiftIcon() only after UnitArmor/C_PaperDollInfo.
  -- GetArmorEffectiveness (SecretWhenUnitStatsRestricted), so a throw there
  -- aborted the whole function before the icon was ever returned, leaving a
  -- druid's form icon stale (or an empty backdrop on the first build).
  -- Resolved separately here (resolveArmorIcon, above) so the icon always
  -- tracks the current form/chest-slot item even when the armor text below
  -- degrades to blank.
  local iconOk, icon = WIIIUI.Safe(resolveArmorIcon)
  widgets.icon:SetBackdrop({ bgFile = (iconOk and icon) or ARMOR_ICON_FALLBACK })

  local ok, result = WIIIUI.Safe(computeArmorStats)

  if ok and result then
    widgets.label:SetText(result.label)
    widgets.value:SetText(result.text)
    widgets.tooltip = result.tooltip
    widgets.frame:Show()
  else
    widgets.label:SetText(ARMOR_STATIC_LABEL)
    widgets.value:SetText("")
    widgets.tooltip = nil
    widgets.frame:Show()
  end
end

function WIIIUI.InfoIcons.ShowTooltip(slotIndex)
  local widgets = WIIIUI.InfoIcons[slotIndex]
  if not widgets or not widgets.tooltip or not GameTooltip then
    return
  end

  WIIIUI.Safe(function()
    GameTooltip:SetOwner(widgets.frame, "ANCHOR_RIGHT")
    for _, line in ipairs(widgets.tooltip) do
      GameTooltip:AddLine(line)
    end
    GameTooltip:Show()
  end)
end

-- Vanilla AlignWeaponFrame's own anchor point, xpBarLeft (e17c352 WIIIUI.lua
-- :2281) -- WIIIUI.Bars.xp here (Theme.lua's WeaponIconGeometry citation).
-- Bars.lua's BuildBars already ran earlier in this same WIIIUI.Layout() call
-- (Core.lua's canonical module order: Bars.lua loads and therefore builds
-- before InfoIcons.lua), so the XP bar exists by the time this runs.
function WIIIUI.InfoIcons.BuildWeaponIcons()
  local uiScale = wc3UI_Options.uiScale
  local xpBar = WIIIUI.Bars and WIIIUI.Bars.xp

  for slotIndex = 1, 3 do
    local widgets = ensureIconWidgets(slotIndex)
    local geometry = WIIIUI.Theme.WeaponIconGeometry(uiScale, slotIndex)

    widgets.frame:SetSize(geometry.size, geometry.size)
    widgets.frame:ClearAllPoints()
    if xpBar then
      widgets.frame:SetPoint("BOTTOMLEFT", xpBar, "BOTTOMLEFT", geometry.offsetX, geometry.offsetY)
    end

    widgets.icon:SetSize(geometry.size, geometry.size)
    widgets.icon:ClearAllPoints()
    widgets.icon:SetPoint("BOTTOMLEFT", widgets.frame, "BOTTOMLEFT", 0, 0)

    widgets.border:SetSize(geometry.size, geometry.size)
    widgets.border:ClearAllPoints()
    widgets.border:SetPoint("BOTTOMLEFT", widgets.frame, "BOTTOMLEFT", 0, 0)

    widgets.label:SetWidth(geometry.labelWidth)
    widgets.label:ClearAllPoints()
    widgets.label:SetPoint("BOTTOMLEFT", widgets.frame, "TOPLEFT", geometry.labelOffsetX, geometry.labelOffsetY)

    widgets.value:SetWidth(geometry.labelWidth)
    widgets.value:ClearAllPoints()
    widgets.value:SetPoint("BOTTOMLEFT", widgets.frame, "TOPLEFT", geometry.valueOffsetX, geometry.valueOffsetY)

    WIIIUI.InfoIcons.RefreshSlot(slotIndex)
  end
end

-- spec 0001 §Phased plan "F. Info icons" F2; same anchor point as
-- BuildWeaponIcons (WIIIUI.Bars.xp), one row below it via ArmorIconGeometry's
-- own offsetY -- ensureIconWidgets is keyed by "armor" here instead of a
-- numeric slotIndex; it only ever uses its argument as a WIIIUI.InfoIcons[]
-- table key, so a string key works unchanged.
function WIIIUI.InfoIcons.BuildArmorIcon()
  local uiScale = wc3UI_Options.uiScale
  local xpBar = WIIIUI.Bars and WIIIUI.Bars.xp
  local widgets = ensureIconWidgets("armor")
  local geometry = WIIIUI.Theme.ArmorIconGeometry(uiScale)

  widgets.frame:SetSize(geometry.size, geometry.size)
  widgets.frame:ClearAllPoints()
  if xpBar then
    widgets.frame:SetPoint("BOTTOMLEFT", xpBar, "BOTTOMLEFT", geometry.offsetX, geometry.offsetY)
  end

  widgets.icon:SetSize(geometry.size, geometry.size)
  widgets.icon:ClearAllPoints()
  widgets.icon:SetPoint("BOTTOMLEFT", widgets.frame, "BOTTOMLEFT", 0, 0)

  widgets.border:SetSize(geometry.size, geometry.size)
  widgets.border:ClearAllPoints()
  widgets.border:SetPoint("BOTTOMLEFT", widgets.frame, "BOTTOMLEFT", 0, 0)

  -- Vanilla armorText/armorValue's own flat SetWidth(100) (e17c352
  -- WIIIUI.lua:2438, 2444) -- ArmorIconGeometry's own header comment: no
  -- neighbour icon to its right, so no uiScale-derived labelWidth needed.
  widgets.label:SetWidth(100)
  widgets.label:ClearAllPoints()
  widgets.label:SetPoint("BOTTOMLEFT", widgets.frame, "TOPLEFT", geometry.labelOffsetX, geometry.labelOffsetY)

  -- ensureIconWidgets' 30-high value box suits the weapon rows; the armor
  -- value is 15 high in vanilla (armorValue:SetHeight(15), e17c352
  -- WIIIUI.lua:2445), so its top-justified text does not start over the label.
  widgets.value:SetWidth(100)
  widgets.value:SetHeight(15)
  widgets.value:ClearAllPoints()
  widgets.value:SetPoint("BOTTOMLEFT", widgets.frame, "TOPLEFT", geometry.valueOffsetX, geometry.valueOffsetY)

  WIIIUI.InfoIcons.RefreshArmor()
end

local function refreshAllSlots()
  for slotIndex = 1, 3 do
    WIIIUI.InfoIcons.RefreshSlot(slotIndex)
  end
  WIIIUI.InfoIcons.RefreshArmor()
end

-- security-specialist/ui-reviewer Finding 1 (slice 18 gate-fix): the
-- architect spec's own Event -> widget wiring table (0001-forever-support.md
-- "info icons" row) assigns this file the full list below, not just
-- vanilla's three (UNIT_ATTACK_POWER/UNIT_RANGED_ATTACK_POWER/
-- UNIT_INVENTORY_CHANGED, e17c352 WIIIUI.lua:2396-2403). Split by payload
-- shape, confirmed per-event on warcraft.wiki.gg (2026-09-28):
--   unit events (unitTarget payload, RegisterUnitEvent(event, "player")):
--   UNIT_DAMAGE, UNIT_RANGEDDAMAGE, UNIT_ATTACK_SPEED, UNIT_ATTACK_POWER,
--   UNIT_RANGED_ATTACK_POWER, UNIT_STATS, UNIT_RESISTANCES,
--   UNIT_INVENTORY_CHANGED;
--   no-unit events (COMBAT_RATING_UPDATE/SPELL_POWER_CHANGED/
--   UPDATE_SHAPESHIFT_FORM: no payload; PLAYER_EQUIPMENT_CHANGED:
--   equipmentSlot/hasCurrent, no unit token) -- RegisterEvent, no unit
--   filter, since none of these fire per-unit.
-- UPDATE_SHAPESHIFT_FORM drives both the base-damage/stat refresh (the
-- numbers shown can go stale across a stance/form change) and, as of slice
-- 19, activeShapeshiftIcon()'s own form-icon overlay (vanilla's
-- CheckIfInForm) via the same refreshAllSlots call -- no separate event
-- needed for the icon swap. Vanilla's other three (LEARNED_SPELL_IN_TAB/
-- SPELLS_CHANGED/CHARACTER_POINTS_CHANGED) drove that same form-icon
-- override in vanilla and stay out of scope: they're either confirmed
-- dropped (CLAUDE.md roadmap item 5: LEARNED_SPELL_IN_TAB doesn't exist on
-- Forever) or redundant with UPDATE_SHAPESHIFT_FORM for this port's own
-- narrower use (icon only, not the vanilla name-based lookup).
WIIIUI.On("UNIT_INVENTORY_CHANGED", refreshAllSlots, "player")
WIIIUI.On("UNIT_ATTACK_POWER", refreshAllSlots, "player")
WIIIUI.On("UNIT_RANGED_ATTACK_POWER", refreshAllSlots, "player")
WIIIUI.On("UNIT_DAMAGE", refreshAllSlots, "player")
WIIIUI.On("UNIT_RANGEDDAMAGE", refreshAllSlots, "player")
WIIIUI.On("UNIT_ATTACK_SPEED", refreshAllSlots, "player")
WIIIUI.On("UNIT_STATS", refreshAllSlots, "player")
WIIIUI.On("UNIT_RESISTANCES", refreshAllSlots, "player")
WIIIUI.On("COMBAT_RATING_UPDATE", refreshAllSlots)
WIIIUI.On("SPELL_POWER_CHANGED", refreshAllSlots)
WIIIUI.On("PLAYER_EQUIPMENT_CHANGED", refreshAllSlots)
WIIIUI.On("UPDATE_SHAPESHIFT_FORM", refreshAllSlots)

-- security-specialist's own suggestion (Finding 1, cheap and related):
-- SecretWhenUnitStatsRestricted values (spec 0001 §1.7) may only recover
-- once combat/encounter restrictions lift, so a stat that failed Safe mid-
-- combat and degraded to a blank value needs a refresh once combat ends.
-- Core.lua:314 already registers PLAYER_REGEN_ENABLED with no unit filter
-- (WIIIUI.Flush) -- WIIIUI.On's eventUnits guard only rejects a *different*
-- unit filter for the same event (Core.lua's WIIIUI.On), and this call also
-- passes no unit, so it appends to that event's handler list instead of
-- erroring.
WIIIUI.On("PLAYER_REGEN_ENABLED", refreshAllSlots)

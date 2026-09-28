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

local function formatRange(low, high)
  return math.floor(low) .. " - " .. math.ceil(high)
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
-- value rather than aborting WIIIUI.Layout().
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
      icon = GetInventoryItemTexture("player", MAINHAND_SLOT) or FIST_ICON,
      tooltip = tooltip,
    }
  end

  if option == OFFHAND_SLOT then
    local itemID = GetInventoryItemID("player", OFFHAND_SLOT)
    local icon = GetInventoryItemTexture("player", OFFHAND_SLOT) or FIST_ICON

    if not itemID then
      return { label = "Damage:", text = "N/A", icon = icon, tooltip = { "No offhand equipped" } }
    end

    local equipLoc = select(4, C_Item.GetItemInfoInstant(itemID))

    if equipLoc == SHIELD_EQUIP_LOC then
      local blockValue = GetShieldBlock()
      local blockChance = GetBlockChance()
      return {
        label = "Block:",
        text = string.format("%.1f%%\n(%d)", blockChance, blockValue),
        icon = icon,
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
      icon = icon,
      tooltip = tooltip,
    }
  end

  if option == RANGED_SLOT then
    local icon = GetInventoryItemTexture("player", RANGED_SLOT)

    if not icon then
      return { label = "Damage:", text = "N/A", icon = FIST_ICON, tooltip = { "No ranged weapon equipped" } }
    end

    local speed, lowDmg, highDmg = UnitRangedDamage("player")
    local tooltip = { "|cffffd100Ranged Damage:|r " .. formatRange(lowDmg, highDmg) }

    if speed and speed > 0 then
      tooltip[#tooltip + 1] = "|cffffd100Attack Speed:|r " .. string.format("%.2f", speed)
    end

    return {
      label = "Damage:",
      text = formatRange(lowDmg, highDmg),
      icon = icon,
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
    local texture = GetInventoryItemTexture("player", ammoSlot)

    if not texture then
      return { label = "Ammo:", text = "|cffff0000No ammo|r", icon = FIST_ICON, tooltip = { "No ammo equipped" } }
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
      icon = texture,
      tooltip = { "|cffffd100Ammo:|r " .. tostring(count) },
    }
  end

  if option == HEALING_OPTION then
    local healing = GetSpellBonusHealing()
    return {
      label = "Healing:",
      text = tostring(healing),
      icon = HEALING_ICON,
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
      icon = SPELLPOWER_ICON,
      tooltip = tooltip,
    }
  end

  return nil
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

  local label = frame:CreateFontString(nil, "OVERLAY")
  label:SetFontObject(GameFontHighlightSmall)
  local labelFontApplied = label:SetFont(FONT_PATH, LABEL_FONT_SIZE, "")
  if not labelFontApplied or not label:GetFont() then
    label:SetFontObject(GameFontHighlightSmall)
  end

  local value = frame:CreateFontString(nil, "OVERLAY")
  value:SetFontObject(GameFontHighlightSmall)
  local valueFontApplied = value:SetFont(FONT_PATH, VALUE_FONT_SIZE, "")
  if not valueFontApplied or not value:GetFont() then
    value:SetFontObject(GameFontHighlightSmall)
  end

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

  local ok, result = WIIIUI.Safe(computeStats, option)

  if ok and result then
    widgets.label:SetText(result.label)
    widgets.value:SetText(result.text)
    widgets.icon:SetBackdrop({ bgFile = result.icon })
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

    widgets.label:ClearAllPoints()
    widgets.label:SetPoint("BOTTOMLEFT", widgets.frame, "TOPLEFT", geometry.labelOffsetX, geometry.labelOffsetY)

    widgets.value:ClearAllPoints()
    widgets.value:SetPoint("BOTTOMLEFT", widgets.frame, "TOPLEFT", geometry.valueOffsetX, geometry.valueOffsetY)

    WIIIUI.InfoIcons.RefreshSlot(slotIndex)
  end
end

local function refreshAllSlots()
  for slotIndex = 1, 3 do
    WIIIUI.InfoIcons.RefreshSlot(slotIndex)
  end
end

-- Vanilla weaponMainFrame's own event list (e17c352 WIIIUI.lua:2396-2403):
-- UNIT_ATTACK_POWER/UNIT_RANGED_ATTACK_POWER/UNIT_INVENTORY_CHANGED, all
-- "player"-filtered -- confirmed present on the forever branch
-- (warcraft.wiki.gg: UNIT_ATTACK_POWER "1.60.1 (69913)" under forever;
-- UNIT_RANGED_ATTACK_POWER and UNIT_INVENTORY_CHANGED likewise). Vanilla's
-- other four (UPDATE_SHAPESHIFT_FORM/LEARNED_SPELL_IN_TAB/SPELLS_CHANGED/
-- CHARACTER_POINTS_CHANGED/UNIT_AURA) drove CheckIfInForm's form-icon
-- override, which is slice 19's scope (armor icon + "any remaining form/
-- stance status icons"), not this slice's plain weapon-slot stats.
WIIIUI.On("UNIT_INVENTORY_CHANGED", refreshAllSlots, "player")
WIIIUI.On("UNIT_ATTACK_POWER", refreshAllSlots, "player")
WIIIUI.On("UNIT_RANGED_ATTACK_POWER", refreshAllSlots, "player")

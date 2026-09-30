-- spec 0007 §3: WIIIUI's own pieces of the minimap cluster, drawn on the
-- console art in place of Blizzard's hidden cluster. Plain frames only; this
-- file never touches a Blizzard frame.
local _, WIIIUI = ...

WIIIUI.MinimapPieces = WIIIUI.MinimapPieces or {}
local P = WIIIUI.MinimapPieces

-- Vanilla's mail icon and its empty-mailbox tint (e17c352 WIIIUI.xml:2103,
-- WIIIUI.lua:1871).
local MAIL_TEXTURE = "Interface\\Icons\\INV_Letter_15"
local MAIL_GREY = 0.25

-- Blizzard hides its own pieces through these rules (spec 0007 §1.4). The
-- Enum.GameRule members aren't in the generated docs, so any absent link
-- means "not disabled" rather than an error.
local function gameRuleActive(name)
  local rules = _G.C_GameRules
  local members = _G.Enum and _G.Enum.GameRule
  if not (rules and rules.IsGameRuleActive and members and members[name] ~= nil) then
    return false
  end
  return rules.IsGameRuleActive(members[name]) and true or false
end

-- One place answering "does this piece exist here": the API is present and
-- the game rule hasn't switched the feature off.
local function available(piece)
  if piece == "mail" then
    return _G.HasNewMail ~= nil and not gameRuleActive("IngameMailNotificationDisabled")
  end
  if piece == "tracking" then
    return _G.C_Minimap ~= nil and not gameRuleActive("IngameTrackingDisabled")
  end
  return false
end

local function refreshMail()
  local mail = P.mail
  if not mail or not _G.HasNewMail then
    return
  end
  local lit = _G.HasNewMail() and 1 or MAIL_GREY
  mail.icon:SetVertexColor(lit, lit, lit, 1)
end

-- Blizzard's MinimapMailFrameUpdate (Minimap.lua, forever): same header rule,
-- same formatter. Only with mail waiting; the formatter is existence-checked
-- and its own body (FormattingUtil.lua:181) is the fallback.
local function showMailTooltip(self)
  if not (_G.HasNewMail and _G.HasNewMail()) then
    return
  end

  local senders = _G.GetLatestThreeSenders and { _G.GetLatestThreeSenders() } or {}
  local header = #senders >= 1 and _G.HAVE_MAIL_FROM or _G.HAVE_MAIL

  -- ANCHOR_LEFT opens over the minimap widget; the piece sits too close to the
  -- screen bottom for a below-anchor to stay clear of it.
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  if _G.FormatUnreadMailTooltip then
    _G.FormatUnreadMailTooltip(GameTooltip, header, senders)
  else
    GameTooltip:SetText(table.concat({ header, unpack(senders) }, "\n"))
  end
  GameTooltip:Show()
end

local function ensureMail(parent)
  if P.mail then
    return P.mail
  end

  local mail = CreateFrame("Frame", nil, parent)
  mail.icon = mail:CreateTexture(nil, "ARTWORK")
  mail.icon:SetAllPoints(mail)
  mail.icon:SetTexture(MAIL_TEXTURE)
  mail:EnableMouse(true)
  mail:SetScript("OnEnter", showMailTooltip)
  mail:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  P.mail = mail
  return mail
end

-- Blizzard's own art for the default glyph (Minimap.xml:90 on forever) and
-- the TexCoord its menu applies to a spell icon (Minimap.lua:722-724).
local TRACKING_ATLAS = "ui-hud-minimap-tracking-up"
local TRACKING_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SPELL_TEXCOORD = { 0.0625, 0.9 }

local function refreshTracking()
  local tracking = P.tracking
  if not (tracking and _G.C_Minimap) then
    return
  end

  local icon = tracking.icon
  for index = 1, _G.C_Minimap.GetNumTrackingTypes() do
    local info = _G.C_Minimap.GetTrackingInfo(index)
    if info and info.active and info.type == "spell" then
      icon:SetTexture(info.texture)
      icon:SetTexCoord(SPELL_TEXCOORD[1], SPELL_TEXCOORD[2], SPELL_TEXCOORD[1], SPELL_TEXCOORD[2])
      return
    end
  end

  icon:SetTexture(nil)
  if _G.C_Texture and _G.C_Texture.GetAtlasInfo(TRACKING_ATLAS) then
    icon:SetAtlas(TRACKING_ATLAS)
  end
end

-- Blizzard's subType values (Minimap.lua:8-9). Its "show all" CVar mode isn't
-- ported: the plain menu is the one every player sees by default.
local HUNTER_TRACKING = 1
local TOWNSFOLK_TRACKING = 2

-- The state the player just asked for, held until the client confirms with
-- MINIMAP_UPDATE_TRACKING; some tracking needs a spell cast to finish before
-- GetTrackingInfo flips (same reason as Blizzard's CreatePredictedTrackingState,
-- Minimap.lua:43-80).
local predicted = {}

local function isTracked(index)
  if predicted[index] ~= nil then
    return predicted[index]
  end
  local info = _G.C_Minimap.GetTrackingInfo(index)
  return info ~= nil and info.active == true
end

-- Only C_Minimap.SetTracking acts. Blizzard's MinimapUtil path also writes its
-- Settings system from addon code, which WIIIUI never does (spec 0007 §1.4).
local function setTracked(index, on)
  predicted[index] = on
  _G.C_Minimap.SetTracking(index, on)
end

-- Blizzard's CanDisplayTrackingInfo (Minimap.lua:556-563). Without the
-- constants table nothing can be judged, so everything is listed.
local function displayable(index)
  local constants = _G.MinimapConstants
  if not (constants and constants.OPTIONAL_FILTERS) then
    return true
  end
  local filter = _G.C_Minimap.GetTrackingFilter(index)
  return filter ~= nil and (constants.OPTIONAL_FILTERS[filter.filterID] or filter.spellID) and true or false
end

-- Blizzard's Uncheck All (Minimap.lua:652-664): clear, then switch the
-- always-on and conditional filters back on.
local function uncheckAll()
  _G.C_Minimap.ClearAllTracking()
  local constants = _G.MinimapConstants
  local alwaysOn = constants and constants.ALWAYS_ON_FILTERS or {}
  local conditional = constants and constants.CONDITIONAL_FILTERS or {}
  for index = 1, _G.C_Minimap.GetNumTrackingTypes() do
    predicted[index] = false
    local filter = _G.C_Minimap.GetTrackingFilter(index)
    if filter and (alwaysOn[filter.filterID] or conditional[filter.filterID]) then
      setTracked(index, true)
    end
  end
  return _G.MenuResponse.Refresh
end

local function createTrackingCheckbox(description, info)
  description:CreateCheckbox(info.name, function(data)
    return isTracked(data.index)
  end, function(data)
    setTracked(data.index, not isTracked(data.index))
  end, info)
end

-- Blizzard's grouping (Minimap.lua:667-684, 738-764), ascending index inside
-- each group: hunter entries (a submenu when there are several), townsfolk,
-- then the rest.
local function trackingMenu(_, root)
  root:CreateButton(_G.UNCHECK_ALL, uncheckAll)

  local isHunter = WIIIUI.PlayerClassToken() == "HUNTER"
  local hunter, townsfolk, regular = {}, {}, {}
  for index = 1, _G.C_Minimap.GetNumTrackingTypes() do
    local info = displayable(index) and _G.C_Minimap.GetTrackingInfo(index)
    if info then
      info.index = index
      local group = regular
      if isHunter and info.subType == HUNTER_TRACKING then
        group = hunter
      elseif info.subType == TOWNSFOLK_TRACKING then
        group = townsfolk
      end
      group[#group + 1] = info
    end
  end

  local hunterParent = root
  if #hunter > 1 then
    hunterParent = root:CreateButton(_G.HUNTER_TRACKING_TEXT)
  end
  for _, info in ipairs(hunter) do
    createTrackingCheckbox(hunterParent, info)
  end
  for _, info in ipairs(townsfolk) do
    createTrackingCheckbox(root, info)
  end
  for _, info in ipairs(regular) do
    createTrackingCheckbox(root, info)
  end
end

local function openTrackingMenu(self)
  if _G.MenuUtil and _G.C_Minimap then
    _G.MenuUtil.CreateContextMenu(self, trackingMenu)
  end
end

-- Blizzard's tooltip (Minimap.lua:826-831); ANCHOR_LEFT for the same reason as
-- the mail piece.
local function showTrackingTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText(_G.TRACKING or "", 1, 1, 1)
  GameTooltip:AddLine(_G.MINIMAP_TRACKING_TOOLTIP_NONE or "", nil, nil, nil, true)
  GameTooltip:Show()
end

local function ensureTracking(parent)
  if P.tracking then
    return P.tracking
  end

  local tracking = CreateFrame("Button", nil, parent)
  tracking:RegisterForClicks("AnyUp")
  tracking:SetScript("OnClick", openTrackingMenu)
  tracking:SetScript("OnEnter", showTrackingTooltip)
  tracking:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  tracking.icon = tracking:CreateTexture(nil, "ARTWORK")
  tracking.icon:SetAllPoints(tracking)
  local mask = tracking:CreateMaskTexture()
  mask:SetTexture(TRACKING_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(tracking.icon)
  tracking.icon:AddMaskTexture(mask)
  P.tracking = tracking
  return tracking
end

-- Square pieces only (uses g.size for both axes): zone and clock are width
-- entries and must not go through this; they size themselves in slice 03.
local function place(frame, anchor, g)
  frame:ClearAllPoints()
  frame:SetPoint(g.point, anchor, g.relativePoint, g.offsetX, g.offsetY)
  frame:SetSize(g.size, g.size)
end

function P.Build()
  local left = WIIIUI.Console.left
  local minimapTexture = left and left.minimapTexture
  if not minimapTexture then
    return
  end

  local units = WIIIUI.LayoutUnits()
  local geometry = WIIIUI.Theme.MinimapPieceGeometry(units, wc3UI_Options.theme)

  local mail = ensureMail(left)
  mail:SetParent(left)
  WIIIUI.Layers.Apply(mail, "minimap.piece")
  place(mail, minimapTexture, geometry.mail)
  local zoom = WIIIUI.Theme.IconZoom(units, geometry.mail.size)
  mail.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
  -- Show/Hide only here, inside Layout; events only recolour (spec 0007 §6).
  mail:SetShown(available("mail"))
  refreshMail()

  local tracking = ensureTracking(left)
  tracking:SetParent(left)
  WIIIUI.Layers.Apply(tracking, "minimap.piece")
  place(tracking, minimapTexture, geometry.tracking)
  tracking:SetShown(available("tracking"))
  refreshTracking()
end

-- Not unit events, so plain registration. Nothing polls: the mail state only
-- changes on these (spec 0007 §3.1).
for _, event in ipairs({ "UPDATE_PENDING_MAIL", "MAIL_INBOX_UPDATE", "PLAYER_ENTERING_WORLD" }) do
  WIIIUI.On(event, refreshMail)
end

-- Some tracking needs a cast to finish, so the event can arrive before
-- GetTrackingInfo flips: keep a prediction until the live state equals it
-- (Blizzard's CreatePredictedTrackingState, Minimap.lua:43-80, forever 966519c).
local function onTrackingChanged()
  for index, value in pairs(predicted) do
    local info = _G.C_Minimap and _G.C_Minimap.GetTrackingInfo(index)
    if info and (info.active == true) == value then
      predicted[index] = nil
    end
  end
  refreshTracking()
end

-- A full reset: nothing the player just asked for can still be pending.
local function resetTracking()
  predicted = {}
  refreshTracking()
end

WIIIUI.On("MINIMAP_UPDATE_TRACKING", onTrackingChanged)
for _, event in ipairs({ "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }) do
  WIIIUI.On(event, resetTracking)
end

WIIIUI.RegisterBuild("MinimapPieces.Build", P.Build, { after = { "Console.BuildLeft", "Blizzard.BuildMinimap" } })

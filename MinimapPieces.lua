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
end

-- Not unit events, so plain registration. Nothing polls: the mail state only
-- changes on these (spec 0007 §3.1).
for _, event in ipairs({ "UPDATE_PENDING_MAIL", "MAIL_INBOX_UPDATE", "PLAYER_ENTERING_WORLD" }) do
  WIIIUI.On(event, refreshMail)
end

WIIIUI.RegisterBuild("MinimapPieces.Build", P.Build, { after = { "Console.BuildLeft", "Blizzard.BuildMinimap" } })

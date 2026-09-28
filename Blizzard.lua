-- spec 0001 §Module split "Blizzard.lua": the Minimap widget reparent (R3,
-- spike first -- spec 0001 Phased plan "E. Blizzard pieces" (E1)). Ported
-- from vanilla AlignMinimap/AlignZoneText/InitiateMiniMap (e17c352
-- WIIIUI.lua:1807-1889, 4616-4632), sharpened per spec 0001 §1.6: "reparent
-- the Minimap widget into WIIIUI's frame" -- the parent becomes
-- WIIIUI.Console.left (a Frame), not UIParent as vanilla did, since Minimap
-- can't be parented to a Texture region; the anchor reference frame stays
-- Console.lua's own left.minimapTexture, matching vanilla's exact
-- CENTER-relative math (Theme.lua's MinimapGeometry).
--
-- MinimapCluster (Blizzard_Minimap/Mainline/Minimap.xml, forever branch:
-- "inherits=\"EditModeMinimapSystemTemplate, ResizeLayoutFrame\"") is the
-- Edit Mode system the Minimap widget lives inside -- never referenced here,
-- per spec 0001 §1.6 ("widget no, cluster yes") and R4 (placed only by the
-- shipped layout string, not yet built). Fetching that file directly
-- (2026-09-28) also confirms vanilla's flat MinimapZoneTextButton/
-- MiniMapMailFrame/MiniMapMailBorder globals no longer exist on Forever --
-- both are now parentKey children nested inside MinimapCluster's own tree
-- (ZoneTextButton, IndicatorFrame.MailFrame), with no global name of their
-- own; only MiniMapMailIcon (deeply nested) kept a global name. Reaching
-- through MinimapCluster to find them would violate the "never touch
-- MinimapCluster" rule above, so this file only ever existence-checks the
-- OLD vanilla global names -- which is expected to resolve to "absent" on a
-- real Forever client until a follow-up (layout string placement) lands.
-- That absence is exactly this slice's own graceful degrade, not an error;
-- the in-game pass (this slice's Notes) is what actually confirms it.
local _, WIIIUI = ...

WIIIUI.Blizzard = WIIIUI.Blizzard or {}

-- Shared (not per-theme) art, same convention as Config.lua's
-- COGWHEEL_TEXTURE literal. Vanilla InitiateMiniMap (e17c352 WIIIUI.lua:4617),
-- same path.
local MASK_TEXTURE = "Interface\\Addons\\WIIIUI\\art\\other\\MinimapMask"

-- spec 0001 §1.6/§1.9 Q3 "depend on the spike": exposed so Config.lua's
-- existing ZoneTextPos control row (slice 06) can degrade to its "Set in
-- Edit Mode" note through the established `available` row field (spec 0001
-- §1.6: "available = fn (in-game-check result)"), instead of a new
-- mechanism.
function WIIIUI.Blizzard.ZoneTextAvailable()
  return _G.MinimapZoneTextButton ~= nil
end

function WIIIUI.Blizzard.MailIndicatorAvailable()
  return _G.MiniMapMailFrame ~= nil
end

-- Vanilla AlignMinimap/AlignZoneText (e17c352 WIIIUI.lua:1828-1831,
-- 1878-1889): MinimapZoneTextButton reparents under Minimap, anchored
-- BOTTOM to it; ZoneTextPos 1/2 pick the Y offset (Theme.lua's
-- ZoneTextGeometry), 3 hides it outright. Existence-checked per this file's
-- header comment -- absent on Forever (confirmed via source), so this is a
-- no-op there until a follow-up.
function WIIIUI.Blizzard.BuildZoneText(Minimap)
  local zoneText = _G.MinimapZoneTextButton

  if not zoneText then
    return
  end

  local geometry = WIIIUI.Theme.ZoneTextGeometry(wc3UI_Options.uiScale, wc3UI_Options.ZoneTextPos)

  zoneText:SetParent(Minimap)
  zoneText:ClearAllPoints()

  if geometry.hidden then
    zoneText:Hide()
    return
  end

  zoneText:Show()
  zoneText:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, geometry.offsetY)
end

-- Vanilla AlignMinimap's mail block (e17c352 WIIIUI.lua:1834-1837): only the
-- unconditional (non-theme-conditional) offsets are ported -- the human/orc
-- uiScale-threshold extraAlign fine-tune (e17c352 WIIIUI.lua:1839-1858) is a
-- documented deferral, same convention as Theme.lua's RightFillerGeometry/
-- Console.lua's filler-nudge notes. MiniMapMailBorder:Hide() (vanilla's own
-- unconditional call) isn't ported -- that global doesn't exist standalone
-- on Forever either (confirmed via source: no top-level MiniMapMailBorder
-- name in Blizzard_Minimap/Mainline/Minimap.xml), so under this file's
-- existence-check convention there is nothing to hide. Existence-checked
-- per this file's header comment -- MiniMapMailFrame is absent on Forever
-- (confirmed via source), so this is a no-op there until a follow-up.
function WIIIUI.Blizzard.BuildMailIndicator(Minimap, uiScale)
  local mailFrame = _G.MiniMapMailFrame

  if not mailFrame then
    return
  end

  local geometry = WIIIUI.Theme.MailIndicatorGeometry(uiScale)

  mailFrame:ClearAllPoints()
  mailFrame:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMRIGHT", geometry.offsetX, geometry.offsetY)

  local mailIcon = _G.MiniMapMailIcon

  if mailIcon then
    mailIcon:SetSize(geometry.iconSize, geometry.iconSize)
  end
end

-- Vanilla AlignMinimap's Minimap block (e17c352 WIIIUI.lua:1814-1823):
-- ClearAllPoints, then CENTER-anchor to minimapFrame (Console.lua's
-- left.minimapTexture) at Theme.lua's MinimapGeometry offsets, sized
-- square. Frame:EnableMouseWheel/Minimap:SetMaskTexture are real
-- Minimap/Frame widget methods (warcraft.wiki.gg API_Frame_
-- EnableMouseWheel, API_Minimap_SetMaskTexture -- the latter's wiki page
-- lists Forever 1.60.1 explicitly among its confirmed client versions).
--
-- "Enable wheel zoom" is EnableMouseWheel(true) only, not a SetScript call:
-- Blizzard_Minimap/Mainline/Minimap.xml's own <Minimap> element already
-- binds OnMouseWheel to MinimapMixin:OnMouseWheel (Minimap_ZoomIn/
-- Minimap_ZoomOut, keeping the zoom buttons' enabled state in sync via
-- MinimapMixin:OnEvent's GetZoom()/GetZoomLevels() read) -- confirmed by
-- fetching that file directly (2026-09-28). Calling SetScript here would
-- silently replace that handler, an overwrite CLAUDE.md forbids ("never
-- overwrite or wrap a Blizzard function or method"). Vanilla's own custom
-- zoom SetScript (e17c352 WIIIUI.lua:4619-4628) is 1.12-era debt this port
-- doesn't carry forward -- Forever's Minimap already zooms on the wheel out
-- of the box.
function WIIIUI.Blizzard.BuildMinimap()
  local Minimap = _G.Minimap
  local left = WIIIUI.Console.left
  local minimapTexture = left and left.minimapTexture

  if not Minimap or not minimapTexture then
    return
  end

  local uiScale = wc3UI_Options.uiScale
  local geometry = WIIIUI.Theme.MinimapGeometry(uiScale)

  Minimap:ClearAllPoints()
  Minimap:SetParent(left)
  Minimap:SetSize(geometry.minimapSize, geometry.minimapSize)
  Minimap:SetPoint("CENTER", minimapTexture, "CENTER", geometry.minimapOffsetX, geometry.minimapOffsetY)
  Minimap:EnableMouseWheel(true)
  Minimap:SetMaskTexture(MASK_TEXTURE)

  WIIIUI.Blizzard.BuildZoneText(Minimap)
  WIIIUI.Blizzard.BuildMailIndicator(Minimap, uiScale)
end

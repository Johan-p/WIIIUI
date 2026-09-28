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

-- MinimapZoneTextButton/MiniMapMailFrame are confirmed dead globals on both
-- Forever and retail (this file's header comment) -- ZoneTextAvailable()/
-- MailIndicatorAvailable() above always resolve false there today, so
-- there's nothing left to build behind them. The vanilla reparent/anchor
-- logic they used to gate (AlignZoneText, AlignMinimap's mail block,
-- e17c352 WIIIUI.lua:1828-1837, 1878-1889) is a follow-up's job, once that
-- follow-up decides how to reach the real nested ZoneTextButton/MailFrame
-- children inside MinimapCluster without violating R4 ("never reference
-- MinimapCluster") -- most likely through the shipped Edit Mode layout
-- string rather than a direct reparent. Vanilla's mail block also swapped
-- in a "no mail" texture and trimmed MiniMapMailIcon's TexCoord
-- (e17c352 WIIIUI.lua:1834-1837) -- cosmetic polish not ported here either,
-- for the same reason: no reachable mail frame to apply it to yet.

-- Vanilla AlignMinimap's Minimap block (e17c352 WIIIUI.lua:1814-1823):
-- ClearAllPoints, then CENTER-anchor to minimapFrame (Console.lua's
-- left.minimapTexture) at Theme.lua's MinimapGeometry offsets, sized
-- square. Frame:EnableMouseWheel/Minimap:SetMaskTexture are real
-- Minimap/Frame widget methods (warcraft.wiki.gg API_Frame_
-- EnableMouseWheel, API_Minimap_SetMaskTexture -- the latter's wiki page
-- lists Forever 1.60.1 explicitly among its confirmed client versions).
-- SetFrameStrata("LOW")/SetFrameLevel(1) right after the reparent match
-- vanilla's own AlignMinimap (e17c352 WIIIUI.lua:1817-1818) -- SetParent
-- doesn't change a frame's own strata/level, and Minimap sets no explicit
-- frameStrata of its own on Forever, so without this it would keep
-- whatever it inherited at creation instead of matching left's own "LOW"
-- (Console.lua's BuildLeft).
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
  Minimap:SetFrameStrata("LOW")
  Minimap:SetFrameLevel(1)
  Minimap:SetSize(geometry.minimapSize, geometry.minimapSize)
  Minimap:SetPoint("CENTER", minimapTexture, "CENTER", geometry.minimapOffsetX, geometry.minimapOffsetY)
  Minimap:EnableMouseWheel(true)
  Minimap:SetMaskTexture(MASK_TEXTURE)
end

-- spec 0001 §Phased plan "E. Blizzard pieces" (E2); §1.6 ("hideMicroButtons
-- needs code on the plain MicroMenu, but Blizzard re-parents it on every
-- ResetMicroMenuPosition"). MicroMenu is the plain MicroMenuMixin instance
-- MicroMenuContainer (the Edit Mode system, EditModeMicroMenuSystemTemplate)
-- parents -- never the system itself, so SetParent on MicroMenu is R3, not
-- R1. Confirmed via MicroMenuMixin:ResetMicroMenuPosition's own body
-- ("self:SetParent(MicroMenuContainer); ...
-- EditModeManagerFrame:UpdateSystem(MicroMenuContainer, forceFullUpdate)",
-- Blizzard_MicroMenu/Shared/MicroMenuContainer.lua:233-243 on the forever
-- branch, fetched 2026-09-28) -- Blizzard calls that method itself from
-- MainActionBarMixin:OnShow (Blizzard_ActionBar/Shared/MainActionBar.lua:16)
-- and ActionBarController.lua's override-bar transition
-- (Blizzard_ActionBarController/ActionBarController.lua:224), re-parenting
-- MicroMenu back onto the container -- and undoing hideMicroButtons -- any
-- time either fires. hooksecurefunc post-hooks that same method (never
-- overwritten, CLAUDE.md "hooksecurefunc only") to re-hide. The re-hide
-- goes through ApplyOrQueue because the hook can fire at any time, including
-- mid-combat (CLAUDE.md "Combat lockdown"); BuildMicroMenu's own initial
-- hide below doesn't need its own ApplyOrQueue call, since (like BuildMinimap
-- above) it only ever runs inside WIIIUI.Layout(), which every caller already
-- wraps in ApplyOrQueue (Core.lua's PLAYER_LOGIN handler, Config.lua's
-- applyRow).
--
-- The hooked-once guard lives on WIIIUI.Blizzard, never on MicroMenu itself
-- -- CLAUDE.md R1: "Never write a Lua key onto a Blizzard frame or table."
function WIIIUI.Blizzard.BuildMicroMenu()
  local MicroMenu = _G.MicroMenu

  if not MicroMenu then
    return
  end

  if wc3UI_Options.hideMicroButtons then
    MicroMenu:SetParent(WIIIUI.hider)
  end

  if not WIIIUI.Blizzard.microMenuHooked then
    WIIIUI.Blizzard.microMenuHooked = true

    hooksecurefunc(MicroMenu, "ResetMicroMenuPosition", function()
      -- Read live, not captured at registration time: a user can toggle
      -- hideMicroButtons off after this hook is registered, and the hook
      -- must stop re-hiding from that point on.
      if not wc3UI_Options.hideMicroButtons then
        return
      end

      WIIIUI.ApplyOrQueue("microMenu", function()
        MicroMenu:SetParent(WIIIUI.hider)
      end)
    end)
  end
end

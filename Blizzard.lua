-- spec 0001 §Module split "Blizzard.lua": the Minimap widget reparent (R3,
-- spike first -- spec 0001 Phased plan "E. Blizzard pieces" (E1)). Ported
-- from vanilla AlignMinimap/AlignZoneText/InitiateMiniMap (e17c352
-- WIIIUI.lua:1807-1889, 4616-4632), sharpened per spec 0001 §1.6: "reparent
-- the Minimap widget into WIIIUI's frame" -- the parent becomes
-- WIIIUI.Console.left (a Frame), not UIParent as vanilla did, since Minimap
-- can't be parented to a Texture region; the anchor reference frame stays
-- Console.lua's own left.minimapTexture, matching vanilla's exact
-- CENTER-relative math (Theme.lua's MinimapGeometry).
local _, WIIIUI = ...

WIIIUI.Blizzard = WIIIUI.Blizzard or {}

-- Shared (not per-theme) art, same convention as Config.lua's
-- COGWHEEL_TEXTURE literal. Vanilla InitiateMiniMap (e17c352 WIIIUI.lua:4617),
-- same path.
local MASK_TEXTURE = "Interface\\Addons\\WIIIUI\\art\\other\\MinimapMask"

-- Vanilla AlignMinimap's Minimap block (e17c352 WIIIUI.lua:1814-1823):
-- ClearAllPoints, then CENTER-anchor to minimapFrame (Console.lua's
-- left.minimapTexture) at Theme.lua's MinimapGeometry offsets, sized
-- square. Frame:EnableMouseWheel/Minimap:SetMaskTexture are real
-- Minimap/Frame widget methods (warcraft.wiki.gg API_Frame_
-- EnableMouseWheel, API_Minimap_SetMaskTexture -- the latter's wiki page
-- lists Forever 1.60.1 explicitly among its confirmed client versions).
-- The "minimap" Layers slot right after the reparent matches
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

  local uiScale = WIIIUI.LayoutUnits()
  local geometry = WIIIUI.Theme.MinimapGeometry(uiScale)

  Minimap:ClearAllPoints()
  Minimap:SetParent(left)
  WIIIUI.Layers.Apply(Minimap, "minimap")
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
-- Restore branch: every other
-- General-tab boolean row restores on uncheck via WIIIUI.Layout() re-running
-- through ApplyOrQueue; this one silently didn't, since the `if` above has
-- no `else`. MicroMenuMixin:ResetMicroMenuPosition (the obvious "put it
-- back" call, already hooked above) was considered and rejected: its body
-- ("self:SetParent(MicroMenuContainer); self.stride = self.numButtons;
-- self:ClearOverrideScale(); EditModeManagerFrame:UpdateSystem(
-- MicroMenuContainer, true); UpdateMicroButtons()", MicroMenuContainer.lua:
-- 233-243 forever branch, fetched 2026-09-28) calls
-- EditModeManagerFrameMixin:UpdateSystem(systemFrame, true)
-- (EditModeManagerFrame's own Shared/EditModeManager.lua:1475-1491, same
-- fetch) which -- whenever MicroMenuContainer has active layout info (the
-- normal, always-true case) -- runs
-- systemFrame:MarkAllSettingsDirty()/systemFrame:UpdateSystem(systemInfo),
-- and EditModeSystemMixin:UpdateSystem (Shared/EditModeSystemTemplates.lua:
-- 385-407, same fetch) calls self:ApplySystemAnchor(), which calls
-- self:ClearAllPoints()/self:SetPoint(...) (same file:350-375) -- both
-- overridden per-system by EditModeSystemMixin:OnSystemLoad
-- (EditModeSystemTemplates.lua:1-17: "self.SetPoint = self.SetPointOverride"
-- etc). So calling ResetMicroMenuPosition from here, even out of combat,
-- would run those two R1-forbidden overrides on MicroMenuContainer (the
-- Edit Mode system itself) from our addon-tainted call stack -- not a
-- combat-lockdown error, but exactly the taint risk R1 exists to prevent.
-- Reparenting alone is sufficient and stays R3 (plain-frame SetParent):
-- MicroMenu's own anchor points -- set by MicroMenuMixin:AnchorToMenuContainer
-- at its last real layout and never cleared by the hide branch below -- and
-- MicroMenuContainer's cached size -- its own Layout(), MicroMenuContainer.lua
-- :17-55, returns early without resizing whenever
-- `MicroMenu:GetParent() ~= self`, so nothing goes stale while hidden -- are
-- both still valid the moment MicroMenu is parented back. MicroMenuContainer
-- itself is read once as a plain global and handed to SetParent as an
-- argument, never indexed into or written to (dev/tests/wow_stub.lua's
-- newMicroMenuContainerTripwire -- errors on any field read/write, not on
-- being passed by reference -- proves this at the seam).
function WIIIUI.Blizzard.BuildMicroMenu()
  local MicroMenu = _G.MicroMenu
  local MicroMenuContainer = _G.MicroMenuContainer

  if not MicroMenu then
    return
  end

  if wc3UI_Options.hideMicroButtons then
    MicroMenu:SetParent(WIIIUI.hider)
  elseif MicroMenuContainer and MicroMenu:GetParent() == WIIIUI.hider then
    MicroMenu:SetParent(MicroMenuContainer)
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
        -- Read live again at flush time, not just at queue time: Flush
        -- (Core.lua:127-148) runs queued keys in queue order, so a later
        -- "layout" entry queued before this one already restored the menu
        -- if the option flipped off in between -- this must be a no-op
        -- then, not re-hide it.
        if wc3UI_Options.hideMicroButtons then
          MicroMenu:SetParent(WIIIUI.hider)
        end
      end)
    end)
  end
end

-- EditModeManagerFrameMixin:IsEditModeActive, forever 966519c
-- Blizzard_EditMode/Shared/EditModeManager.lua:151.
local function editModeActive()
  local manager = _G.EditModeManagerFrame
  return manager and manager.IsEditModeActive and manager:IsEditModeActive() or false
end

-- spec 0007 §2 R5 (reversible native hide), §4. MinimapCluster is an Edit Mode
-- system other systems read the rect of (GetRightActionBarTopLimit; the layout
-- string anchors the objective tracker to it), so it is hidden, never
-- reparented. HideBase is the native hide kept by the Edit Mode template
-- (EditModeSystemTemplates.lua:32-37, forever 966519c: only SetShown/Hide are
-- replaced), so Hide() is never called; Show is native on this system, so
-- ShowBase is preferred only if a future build provides it. The call set is
-- closed: HideBase, ShowBase/Show and one OnShow HookScript (IsShown is
-- allowed by R5 but never needed). Runs inside Layout, hence always through ApplyOrQueue.
-- The compass textures (plain textures, R3; children of MinimapBackdrop) are
-- faded instead of hiding the backdrop, which would also hide retail's
-- expansion landing-page button (spec 0003 §2.1). The Underlay exists on
-- Forever only. MinimapBackdrop is a child of Minimap, not of MinimapCluster,
-- so it stays drawn when the cluster is HideBase'd, whatever the option says.
function WIIIUI.Blizzard.BuildMinimapCluster()
  local cluster = _G.MinimapCluster

  if _G.MinimapCompassTexture then
    _G.MinimapCompassTexture:SetAlpha(0)
  end
  if _G.MinimapCompassTextureUnderlay then
    _G.MinimapCompassTextureUnderlay:SetAlpha(0)
  end

  if not cluster then
    return
  end

  -- Hiding a selected Edit Mode system runs Blizzard's OnSystemHide tainted.
  -- The ExitEditMode hook re-runs Layout, so the hide re-applies on exit
  -- (spec 0007 §2 R5).
  if not editModeActive() then
    if wc3UI_Options.showBlizzardMinimapCluster then
      if cluster.ShowBase then
        cluster:ShowBase()
      else
        cluster:Show()
      end
    elseif cluster.HideBase then
      cluster:HideBase()
    end
  end

  -- Hooked once, flag on WIIIUI.Blizzard (R1: never a key on the frame).
  if not WIIIUI.Blizzard.clusterHooked then
    WIIIUI.Blizzard.clusterHooked = true

    cluster:HookScript("OnShow", function()
      if wc3UI_Options.showBlizzardMinimapCluster then
        return
      end

      WIIIUI.ApplyOrQueue("minimapCluster", function()
        -- Re-read at flush: the option may have flipped since the hook fired.
        if not wc3UI_Options.showBlizzardMinimapCluster and not editModeActive() and cluster.HideBase then
          cluster:HideBase()
        end
      end)
    end)
  end
end

-- spec 0003 §2.5 (Option A), R3. Retail's class resources (combo points, holy
-- power, runes, shards, chi, arcane charges, essence) live in
-- PlayerBottomManagedFrameContainer, a plain VerticalLayoutFrame (not an Edit
-- Mode system; live Blizzard_UnitFrame/Shared/PlayerFrameTemplates.xml:12,
-- Mainline/PlayerFrame.xml:467) parented to the PlayerFrame R2 retires, so it
-- is invisible today. The bars reparent themselves into it
-- (ManagedFrameSystem.lua), so only the container is moved: parented to a
-- WIIIUI anchor above the portrait, never touching the bars.
-- Blizzard re-anchors it from PlayerFrame_ToVehicleArt/ToPlayerArt
-- (PlayerFrame.lua:649, 755); the SetPoint post-hook queues a re-anchor
-- through ApplyOrQueue, guarded against its own call by `reanchoring`. The
-- hooked-once flag lives on WIIIUI.Blizzard, never on the container (R1).
-- Forever loads none of the eight frames (Blizzard_UnitFrame.toc excludes
-- them on camelot), so the gate makes this a no-op there.
-- If this taints or fights Blizzard in-game (checklist R1), delete it and
-- ship Option B (Personal Resource Display via the layout string).
local CLASS_RESOURCE_FRAMES = {
  "RogueComboPointBarFrame", "DruidComboPointBarFrame", "PaladinPowerBarFrame", "RuneFrame",
  "WarlockPowerFrame", "MonkHarmonyBarFrame", "MageArcaneChargesFrame", "EssencePlayerFrame",
}

local reanchoring = false

local function classResourceContainer()
  local container = _G.PlayerBottomManagedFrameContainer
  if not container then
    return nil
  end

  for _, name in ipairs(CLASS_RESOURCE_FRAMES) do
    if _G[name] then
      return container
    end
  end
  return nil
end

-- The first SetParent moves the container from the hidden PlayerFrame to a
-- visible parent, firing its OnShow -> Layout() from WIIIUI's stack. That
-- cascade calls ClearAllPoints/SetPoint on every shown child (a docked
-- PetFrame is an Edit Mode system), runs PlayerFrame_AdjustAttachments (moves
-- PlayerCastingBarFrame when attached) and writes into Blizzard tables
-- (spec 0003 §2.5). The read-only checks prevent the reparent from moving a
-- docked PetFrame or a player-locked cast bar: while either holds, the
-- transition is skipped with no write and the next Layout() retries. They do
-- not make it safe: the reparent still registers the shown class bar in
-- Blizzard's showingFrames table from WIIIUI's stack (latent taint read when
-- Blizzard later hides the bar). Accepted Medium risk, docs/decisions.md
-- 2026-10-01 "Accepted risk: 0003 class-resource container move"; fallback is
-- Option B (slice 04b).
local function transitionUnsafe(container, anchor)
  if container:GetParent() == anchor then
    return false
  end

  local pet = _G.PetFrame
  if pet and pet:GetParent() == container then
    return true
  end

  local castBar = _G.PlayerCastingBarFrame
  return castBar ~= nil and castBar.attachedToPlayerFrame and true or false
end

local function traceback(err)
  return tostring(err) .. "\n" .. (debugstack(2) or "")
end

local function reanchor()
  local container = classResourceContainer()
  local anchor = WIIIUI.Blizzard.classResourceAnchor
  if not container or not anchor then
    return
  end

  if transitionUnsafe(container, anchor) then
    return
  end

  reanchoring = true
  local ok, err = xpcall(function()
    container:SetParent(anchor)
    container:ClearAllPoints()
    container:SetPoint("BOTTOM", anchor, "BOTTOM")
  end, traceback)
  reanchoring = false
  if not ok then
    error(err, 0)
  end
end

function WIIIUI.Blizzard.BuildClassResources()
  local container = classResourceContainer()
  if not container then
    return
  end

  local left = WIIIUI.Console.left
  local portraitAnchor = left and left.portraitTexture and WIIIUI.Console.AnchorFrame(left.portraitTexture)
  if not portraitAnchor then
    return
  end

  local anchor = WIIIUI.Blizzard.classResourceAnchor
  if not anchor then
    anchor = CreateFrame("Frame", nil, left)
    anchor:SetSize(1, 1)
    WIIIUI.Blizzard.classResourceAnchor = anchor
  end

  local geometry = WIIIUI.Theme.ClassResourceGeometry(WIIIUI.LayoutUnits())
  anchor:ClearAllPoints()
  anchor:SetPoint("BOTTOM", portraitAnchor, "TOP", geometry.offsetX, geometry.offsetY)
  WIIIUI.Layers.Apply(anchor, "classresources")

  reanchor()

  if not WIIIUI.Blizzard.classResourcesHooked then
    WIIIUI.Blizzard.classResourcesHooked = true

    hooksecurefunc(container, "SetPoint", function()
      if reanchoring then
        return
      end

      WIIIUI.ApplyOrQueue("classResources", reanchor)
    end)
  end
end

-- spec 0001 §1.1 R4, §1.6: the Blizzard pieces WIIIUI keeps (chat, bags,
-- micro menu, buffs, cast bar, stance/pet bars) are placed
-- only by an Edit Mode layout, never moved from code. This is the maintainer's
-- own layout (exported 2026-10-01 at UI Scale 290, ultra-wide), offered through
-- Config.lua's read-only "Copy layout string" box so they can import it
-- (Edit Mode -> Layout -> Import).
--
-- It is a literal, never generated at runtime: there is no addon-side API that
-- builds one; only a real client with a live layout can call
-- C_EditMode.ConvertLayoutInfoToString (Blizzard_EditMode/Shared/
-- EditModeManager.lua on the forever branch).
--
-- To regenerate: in Edit Mode, Layout -> Share -> Export, paste the result
-- over FOREVER_LAYOUT below, and bump FOREVER_LAYOUT_BUILD (shown in the "Set in Edit
-- Mode" notes).
--
-- The string and build tag are player-facing (Config.lua shows both), so any
-- wording around them stays passive and end-user-neutral: never instruct the
-- reader to type or paste into the box (it is read-only and snaps any edit
-- back), and never put an internal doc pointer in UI copy.
local FOREVER_LAYOUT = "4 0 59 0 0 0 7 7 UIParent -83.0 2.0 -1 ##$$%/&('%)$+#,$ 0 1 0 8 2 MainActionBar 0.0 4.0 -1 ##$$%/&('%(#,$ 0 2 0 0 0 UIParent 318.7 -935.0 -1 ##$$%/&('%(#,$ 0 3 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,$ 0 4 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,$ 0 5 1 1 4 UIParent 0.0 0.0 -1 ##$$%/&('%(#,$ 0 6 1 1 4 UIParent 0.0 -50.0 -1 ##$$%/&('%(#,$ 0 7 1 1 4 UIParent 0.0 -100.0 -1 ##$$%/&('%(#,$ 0 10 0 1 1 UIParent -407.6 -872.0 -1 ##$$&-'% 0 11 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('%,# 0 12 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('% 1 -1 0 7 7 UIParent -200.5 224.0 -1 ##$#%# 2 -1 1 2 2 UIParent 0.0 0.0 -1 ##$#%(&( 3 0 0 0 0 UIParent 1380.0 -308.0 -1 $#3# 3 1 0 1 1 UIParent -356.0 -636.0 -1 %#3# 3 2 0 4 4 UIParent -330.0 -275.5 -1 %#&#3# 3 3 0 0 0 UIParent 1410.0 -322.0 -1 '#(#)#-=.+/#1$3$5#6(7-7$8(9( 3 4 0 0 0 UIParent 1412.0 -322.0 -1 ,#-=.+/#0#1#2(3#5#6(7-7$8(9( 3 5 0 2 2 UIParent -296.0 -2.0 -1 &#*$3# 3 6 1 5 5 UIParent 0.0 0.0 -1 -=.+/#4$5#6(7-7$8(9( 3 7 1 4 4 UIParent 0.0 0.0 -1 3# 4 -1 0 0 0 UIParent 861.0 -824.0 -1 # 5 -1 0 4 4 UIParent 17.0 -220.0 -1 # 6 0 0 1 1 UIParent -670.5 -2.0 -1 ##$#%#&C(()( 6 1 0 0 6 BuffFrame 0.0 -4.0 -1 ##$#%#'3(()(-$ 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 1 7 7 UIParent 0.0 -4.0 -1 # 8 -1 0 7 7 UIParent 614.5 34.0 -1 #($m%$&P 9 -1 0 7 1 UIParent 6.0 -1.0 -1 # 10 -1 1 0 0 UIParent 16.0 -116.0 -1 # 11 -1 0 8 2 ChatFrame1 25.0 64.0 -1 # 12 -1 0 1 1 UIParent 828.0 -2.0 -1 #<$#%# 13 -1 0 5 3 ChatFrame1 -36.0 61.6 -1 ##$#%) 14 -1 0 2 0 MicroMenuContainer -3.8 0.2 -1 ##$#%& 15 0 0 8 2 SecondaryStatusTrackingBarContainer 0.0 4.0 -1 &# 15 1 0 4 4 UIParent -600.0 100.0 -1 &# 16 -1 0 0 0 UIParent 251.9 -842.0 -1 #( 17 -1 1 1 1 UIParent 0.0 -100.0 -1 ## 18 -1 1 5 5 UIParent 0.0 0.0 -1 #- 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 1 7 7 UIParent 0.0 310.0 -1 ##$/%$&('%(-($)#+$,$-$ 20 1 1 7 7 UIParent 0.0 240.0 -1 ##$*%$&('%(-($)#+$,$-$ 20 2 1 7 7 UIParent 0.0 370.0 -1 ##$$%$&('((-($)#+$,$-$ 20 3 1 7 7 UIParent 420.0 430.0 -1 #$$$%#&('((-($)#*#+$,$-$.-.$ 21 -1 1 7 7 UIParent -410.0 380.0 -1 ##%#&#'((()#*-*$+#,&-#.#/(0#1# 22 0 1 8 7 UIParent -457.0 336.0 -1 #$$$%#&('((#)U*$+%,$-#.#/U0% 22 1 1 1 1 UIParent 0.0 -40.0 -1 &('()U*#+% 22 2 1 1 1 UIParent 0.0 -90.0 -1 &('()U*#+% 22 3 1 1 1 UIParent 0.0 -130.0 -1 &('()U*#+% 23 -1 1 0 0 UIParent 0.0 0.0 -1 ##$#%$&7&%'7(%)U+$,$-$.(/U 24 -1 1 1 1 UIParent 0.0 -182.0 -1 # 25 -1 0 6 0 StanceBar 0.0 4.0 -1 # 26 0 0 8 6 MainActionBar 30.0 -2.0 -1 #$ 26 1 0 6 8 MainActionBar -30.0 -2.0 -1 #$ 27 -1 0 4 4 UIParent -735.5 -330.0 -1 #- 28 -1 0 4 4 UIParent 0.0 141.0 -1 #( 29 0 1 7 7 UIParent 0.0 450.0 -1 #($U%#&D&%'2($)$ 29 1 1 7 7 UIParent 0.0 425.0 -1 #($U%#&D&%'2($)$ 29 2 1 7 7 UIParent 0.0 400.0 -1 #($U%#&D&%'2($)$"
local FOREVER_LAYOUT_BUILD = "2026-10-01"

-- Retail has no export yet (spec 0003 §2.3): nil makes Config show its
-- "Not available in this build" / "not yet exported" fallbacks.
local RETAIL_LAYOUT = nil
local RETAIL_LAYOUT_BUILD = nil

-- Resolved at call time so the client is never frozen at file scope.
-- IsForever: no API says which client's export a string is.
function WIIIUI.Blizzard.LayoutString()
  return WIIIUI.Client.IsForever() and FOREVER_LAYOUT or RETAIL_LAYOUT
end

function WIIIUI.Blizzard.LayoutBuild()
  return WIIIUI.Client.IsForever() and FOREVER_LAYOUT_BUILD or RETAIL_LAYOUT_BUILD
end

-- The Forever literal, kept readable for the README test.
-- Forever values only: per-client readers go through LayoutString/LayoutBuild.
WIIIUI.FOREVER_LAYOUT_STRING = FOREVER_LAYOUT
WIIIUI.FOREVER_LAYOUT_BUILD = FOREVER_LAYOUT_BUILD

WIIIUI.RegisterBuild("Blizzard.BuildMinimap", WIIIUI.Blizzard.BuildMinimap, { after = { "Console.BuildLeft" } })
WIIIUI.RegisterBuild("Blizzard.BuildMinimapCluster", WIIIUI.Blizzard.BuildMinimapCluster, { after = { "Blizzard.BuildMinimap" } })
WIIIUI.RegisterBuild("Blizzard.BuildMicroMenu", WIIIUI.Blizzard.BuildMicroMenu)
WIIIUI.RegisterBuild("Blizzard.BuildClassResources", WIIIUI.Blizzard.BuildClassResources, { after = { "Portrait.BuildPortrait" } })

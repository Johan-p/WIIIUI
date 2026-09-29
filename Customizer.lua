-- spec 0001 §Module split "Customizer.lua": the Customize tab (last phase;
-- overrides-only storage). §Customizer (decision 17, amended 2026-09-29):
-- "an explicit, static registry ... keyed by WIIIUI table path IDs ...
-- rather than frame names." Every entry below is one of the 57 IDs the
-- amendment's own Contents table lists, mapped 1:1 onto what slices 04-19
-- actually built (Console.lua/Bars.lua/Portrait.lua/Buttons.lua/
-- InfoIcons.lua) -- no naming pass, no edit to any of those files.
local _, WIIIUI = ...

WIIIUI.Customizer = WIIIUI.Customizer or {}

-- spec 0001 §Customizer: "WIIIUI.registry is this list; slice 21's parent
-- guardrail reads it." Top-level WIIIUI field (not WIIIUI.Customizer.*) --
-- named exactly as the spec cites it, since slice 21 depends on this name.
local registry = {}
local registryById = {}

local function addEntry(id, kind, opts)
  local entry = { id = id, kind = kind }
  if opts then
    entry.secure = opts.secure
    entry.backdrop = opts.backdrop
  end
  registry[#registry + 1] = entry
  registryById[id] = entry
end

-- frame kind (Contents table row 1-2, "Portrait.model"): Console.lua's three
-- art-root frames, Bars.lua's four StatusBar frames, Portrait.lua's
-- PlayerModel.
addEntry("Console.left", "frame")
addEntry("Console.grid", "frame")
addEntry("Console.right", "frame")
addEntry("Bars.health", "frame")
addEntry("Bars.power", "frame")
addEntry("Bars.xp", "frame")
addEntry("Bars.xpRested", "frame")
addEntry("Portrait.model", "frame")

-- button/secure (Contents table row 5): the portrait's secure unit button
-- and the 9 LibActionButton-1.0 extra slots. "secure entries offer no
-- ParentOf and no Hide field" (§Customizer Fields) -- WIIIUI.Customizer.
-- Fields, below, is what actually withholds those two fields; `secure = true`
-- here is the one flag that drives it.
addEntry("Portrait.button", "button", { secure = true })
for i = 1, 9 do
  addEntry("Buttons.extras." .. i, "button", { secure = true })
end

-- texture kind (Contents table row 6): Console.lua's art textures. Grouped
-- by which Console sub-table creates them, matching Console.lua's own
-- getOrCreateTexture cache-key convention.
addEntry("Console.left.minimapTexture", "texture")
addEntry("Console.left.portraitTexture", "texture")
addEntry("Console.left.extensionBackgroundTexture", "texture")

for i = 1, 4 do
  addEntry("Console.grid.tile" .. i, "texture")
end

local RIGHT_TEXTURES = {
  "rightPartMiddle", "rightPartLeft", "rightPartBackground", "lid",
  "chatTop", "chatMiddle", "chatBottom",
}
for _, name in ipairs(RIGHT_TEXTURES) do
  addEntry("Console.right." .. name, "texture")
end
for i = 1, 3 do
  addEntry("Console.right.fillerTop" .. i, "texture")
  addEntry("Console.right.fillerBottom" .. i, "texture")
end

-- fontstring kind (Contents table row 7): the two bar texts, the XP bar's
-- level text, and each of the 4 InfoIcons slots' label/value pair.
addEntry("Bars.health.text", "fontstring")
addEntry("Bars.power.text", "fontstring")
addEntry("Bars.xp.levelText", "fontstring")

-- InfoIcons.lua's 3 weapon slots (numeric keys) plus the armor slot (string
-- key "armor", ensureIconWidgets' own WIIIUI.InfoIcons["armor"] convention).
-- frame + border (backdrop = true, the "today, the four InfoIcons borders"
-- Backdrop-field exception) + label/value fontstrings, per slot.
local INFO_ICON_SLOTS = { "1", "2", "3", "armor" }
for _, slot in ipairs(INFO_ICON_SLOTS) do
  addEntry("InfoIcons." .. slot .. ".frame", "frame")
  addEntry("InfoIcons." .. slot .. ".border", "frame", { backdrop = true })
  addEntry("InfoIcons." .. slot .. ".label", "fontstring")
  addEntry("InfoIcons." .. slot .. ".value", "fontstring")
end

WIIIUI.registry = registry
WIIIUI.Customizer.byId = registryById

-- spec 0001 §Customizer: "WIIIUI.Customizer.Resolve(id) splits the ID on '.'
-- and walks down from the WIIIUI table. A numeric segment is tried as a
-- number first (InfoIcons.1 -> WIIIUI.InfoIcons[1], Buttons.extras.3 ->
-- WIIIUI.Buttons.extras[3]). If any step is missing, it returns nil, and the
-- entry is skipped rather than raising an error." Walking from WIIIUI itself
-- (not a special-cased first segment) works uniformly because every module
-- (Console, Bars, Portrait, Buttons, InfoIcons) is itself a plain field on
-- WIIIUI -- "Console.left" is just a two-segment walk, same as any other id.
function WIIIUI.Customizer.Resolve(id)
  local current = WIIIUI

  for segment in id:gmatch("[^.]+") do
    if type(current) ~= "table" then
      return nil
    end

    local value
    local numeric = tonumber(segment)

    if numeric ~= nil and current[numeric] ~= nil then
      value = current[numeric]
    else
      value = current[segment]
    end

    if value == nil then
      return nil
    end

    current = value
  end

  return current
end

-- spec 0001 §Customizer "Fields": the field list a kind offers. Declared as
-- flat arrays (not a set) so WIIIUI.Customizer.Fields below can return them
-- in a stable, spec-ordered sequence -- the editor renders one row per field
-- in this order.
local BASE_FIELDS = { "ParentPosOf", "Point", "RelativePoint", "PosX", "PosY", "Width", "Height", "Transparency" }
local NON_SECURE_FIELDS = { "ParentOf", "Hide" }
local FRAME_FIELDS = { "FrameStrata", "FrameLevel" }
local BACKDROP_FIELDS = { "Backdrop" }
local TEXTURE_FIELDS = { "Texture", "SetDrawLayer", "TexCoordLeft", "TexCoordRight", "TexCoordTop", "TexCoordBottom" }

-- spec 0001 §Customizer "Fields": "every kind: ...; every non-secure kind:
-- ParentOf, Hide; frame and button: FrameStrata, FrameLevel; Backdrop: only
-- where the object has SetBackdrop ...; texture kind: Texture, SetDrawLayer,
-- TexCoordLeft/Right/Top/Bottom; secure entries offer no ParentOf and no
-- Hide field." acceptance criterion (g) reads this list directly.
function WIIIUI.Customizer.Fields(entry)
  local fields = {}

  for _, f in ipairs(BASE_FIELDS) do
    fields[#fields + 1] = f
  end

  if not entry.secure then
    for _, f in ipairs(NON_SECURE_FIELDS) do
      fields[#fields + 1] = f
    end
  end

  if entry.kind == "frame" or entry.kind == "button" then
    for _, f in ipairs(FRAME_FIELDS) do
      fields[#fields + 1] = f
    end
  end

  if entry.backdrop then
    for _, f in ipairs(BACKDROP_FIELDS) do
      fields[#fields + 1] = f
    end
  end

  if entry.kind == "texture" then
    for _, f in ipairs(TEXTURE_FIELDS) do
      fields[#fields + 1] = f
    end
  end

  return fields
end

--------------------------------------------------------------------------
-- Apply
--------------------------------------------------------------------------

-- spec 0001 §Customizer "Apply": "The first time Apply writes one of those
-- fields (parent/strata/level/alpha/draw-layer/tex-coords/backdrop) on an
-- object in a session, it records the object's current value in a
-- module-local baseline[id][field], which is never saved. Once the override
-- is gone, Apply writes the baseline value back and drops it." Module-local,
-- not on WIIIUI or wc3UI_Options -- this is session-only restore state, the
-- same "private implementation state" convention Core.lua's own
-- ApplyOrQueue pending/order upvalues use.
local baseline = {}

-- spec 0001 §Customizer "Apply": "Each entry is wrapped in its own pcall, so
-- a bad saved value skips that entry and never aborts Layout." Recorded here
-- (never saved, id -> error message, reset at the start of every Apply()
-- call) so a future debug session -- or a later editor polish pass -- can
-- surface which entries are currently failing, and so this slice's own
-- headless tests can prove an entry was actually skipped via a pcall
-- failure, not merely absent for an unrelated reason.
WIIIUI.Customizer.lastErrors = {}

local EMPTY_OVERRIDES = {}

local VALID_POINTS = {
  TOPLEFT = true, TOP = true, TOPRIGHT = true,
  LEFT = true, CENTER = true, RIGHT = true,
  BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local ANCHOR_FIELDS = { "Point", "ParentPosOf", "RelativePoint", "PosX", "PosY" }
local TEXCOORD_FIELDS = { "TexCoordLeft", "TexCoordRight", "TexCoordTop", "TexCoordBottom" }

local function anyFieldSet(overrides, fields)
  for _, f in ipairs(fields) do
    if overrides[f] ~= nil then
      return true
    end
  end
  return false
end

-- ParentPosOf accepts any registry object (a texture is a perfectly good
-- anchor reference) or the literal "UIParent".
local function resolveAnchorTarget(value)
  if value == "UIParent" then
    return UIParent
  end
  if not registryById[value] then
    return nil
  end
  return WIIIUI.Customizer.Resolve(value)
end

-- ParentOf (an actual SetParent target) is narrower: "a texture cannot be a
-- parent" (§Customizer "Parent of / Parent position of", slice 21) -- only a
-- frame/button registry entry, or "UIParent".
local function resolveParentOfTarget(value)
  if value == "UIParent" then
    return UIParent
  end
  local entry = registryById[value]
  if not entry or (entry.kind ~= "frame" and entry.kind ~= "button") then
    return nil
  end
  return WIIIUI.Customizer.Resolve(value)
end

-- Generic sticky-field helper: applies an override and remembers the
-- pre-override value (captured via getFn, once) so a later call with the
-- override gone can restore it. Shared by FrameStrata/FrameLevel/
-- Transparency/Backdrop/SetDrawLayer below -- every "sticky" field except
-- parent (its own composite ParentOf/Hide logic, applyParent) and tex-coords
-- (a 4-fields-to-1-call group, applyTexCoord).
local function applyStickyField(id, field, overrideValue, applyFn, getFn)
  if overrideValue ~= nil then
    baseline[id] = baseline[id] or {}
    if baseline[id][field] == nil then
      local ok, current = pcall(getFn)
      if ok then
        baseline[id][field] = current
      end
    end
    applyFn(overrideValue)
  elseif baseline[id] and baseline[id][field] ~= nil then
    applyFn(baseline[id][field])
    baseline[id][field] = nil
  end
end

-- spec 0001 §Customizer "Apply": "Hide = true reparents the object to
-- WIIIUI.hider; it does not call Hide() ... Only true is stored ... Hide
-- wins over ParentOf." Never called for a secure entry (applyEntry's own
-- guard) -- LAB keeps its buttons parented to their header.
local function applyParent(id, obj, overrides)
  local hide = overrides.Hide == true
  local parentOf = overrides.ParentOf

  if hide or parentOf ~= nil then
    baseline[id] = baseline[id] or {}
    if baseline[id].Parent == nil then
      baseline[id].Parent = obj:GetParent()
    end

    if hide then
      obj:SetParent(WIIIUI.hider)
    else
      local target = resolveParentOfTarget(parentOf)
      if not target then
        error("Customizer: unknown ParentOf '" .. tostring(parentOf) .. "' for " .. id, 0)
      end
      obj:SetParent(target)
    end
  elseif baseline[id] and baseline[id].Parent ~= nil then
    obj:SetParent(baseline[id].Parent)
    baseline[id].Parent = nil
  end
end

-- spec 0001 §Customizer "Apply": "If any of Point, ParentPosOf,
-- RelativePoint, PosX or PosY is overridden, Apply reads GetPoint(1) as
-- Layout left it, replaces only the overridden parts, then calls
-- ClearAllPoints and SetPoint ... Width, Height, PosX and PosY are stored at
-- base 240 and scaled by uiScale/240." Layout() re-applies every object's
-- anchor on every call (Console.lua/Bars.lua/Portrait.lua's own
-- ClearAllPoints+SetPoint convention), so this only ever needs to act when
-- an anchor field is actually overridden -- there is nothing to restore
-- when the override is gone, Layout's own next call already did that before
-- Apply ever runs (Apply is the last step of Layout).
local function applyAnchor(id, obj, overrides)
  if not anyFieldSet(overrides, ANCHOR_FIELDS) then
    return
  end

  local point, relativeTo, relativePoint, x, y = obj:GetPoint(1)
  if not point then
    return
  end

  local newPoint = overrides.Point or point
  if not VALID_POINTS[newPoint] then
    error("Customizer: invalid Point '" .. tostring(newPoint) .. "' for " .. id, 0)
  end

  local newRelativePoint = overrides.RelativePoint or relativePoint or newPoint
  if not VALID_POINTS[newRelativePoint] then
    error("Customizer: invalid RelativePoint '" .. tostring(newRelativePoint) .. "' for " .. id, 0)
  end

  local newRelativeTo = relativeTo
  if overrides.ParentPosOf ~= nil then
    newRelativeTo = resolveAnchorTarget(overrides.ParentPosOf)
    if not newRelativeTo then
      error("Customizer: unknown ParentPosOf '" .. tostring(overrides.ParentPosOf) .. "' for " .. id, 0)
    end
  end

  local scale = (wc3UI_Options.uiScale or 240) / 240
  local newX = overrides.PosX ~= nil and (overrides.PosX * scale) or x
  local newY = overrides.PosY ~= nil and (overrides.PosY * scale) or y

  obj:ClearAllPoints()
  obj:SetPoint(newPoint, newRelativeTo, newRelativePoint, newX, newY)
end

-- Width/Height, like the anchor above, are re-applied by Layout() every
-- call, so overriding them only ever needs a plain SetWidth/SetHeight when
-- the field is set -- nothing to restore when it's cleared.
local function applySize(obj, overrides)
  local scale = (wc3UI_Options.uiScale or 240) / 240

  if overrides.Width ~= nil then
    obj:SetWidth(overrides.Width * scale)
  end
  if overrides.Height ~= nil then
    obj:SetHeight(overrides.Height * scale)
  end
end

-- spec 0001 §Customizer "Apply": the sticky group -- "parent/strata/level/
-- alpha/draw-layer/tex-coords/backdrop." Transparency applies to every kind
-- (Region:SetAlpha/GetAlpha); FrameStrata/FrameLevel only to frame/button
-- (Fields' own gate); Backdrop only where entry.backdrop is set (the 4
-- InfoIcons borders); SetDrawLayer only to texture kind, per Fields.
local function applyStickySimple(entry, obj, overrides)
  applyStickyField(
    entry.id, "Transparency", overrides.Transparency,
    function(v) obj:SetAlpha(v) end,
    function() return obj:GetAlpha() end
  )

  if entry.kind == "frame" or entry.kind == "button" then
    applyStickyField(
      entry.id, "FrameStrata", overrides.FrameStrata,
      function(v) obj:SetFrameStrata(v) end,
      function() return obj:GetFrameStrata() end
    )
    applyStickyField(
      entry.id, "FrameLevel", overrides.FrameLevel,
      function(v) obj:SetFrameLevel(v) end,
      function() return obj:GetFrameLevel() end
    )
  end

  if entry.backdrop then
    applyStickyField(
      entry.id, "Backdrop", overrides.Backdrop,
      function(v) obj:SetBackdrop(v) end,
      function() return obj.GetBackdrop and obj:GetBackdrop() end
    )
  end

  if entry.kind == "texture" then
    applyStickyField(
      entry.id, "SetDrawLayer", overrides.SetDrawLayer,
      function(v) obj:SetDrawLayer(v) end,
      function() return obj.GetDrawLayer and obj:GetDrawLayer() end
    )
  end
end

-- TexCoordLeft/Right/Top/Bottom collapse to one SetTexCoord(left, right,
-- top, bottom) call -- a 4-fields-to-1-baseline group, so it can't reuse
-- applyStickyField's single-value shape directly.
local function applyTexCoord(entry, obj, overrides)
  local id = entry.id

  if not anyFieldSet(overrides, TEXCOORD_FIELDS) then
    if baseline[id] and baseline[id].TexCoord then
      local base = baseline[id].TexCoord
      obj:SetTexCoord(base[1], base[2], base[3], base[4])
      baseline[id].TexCoord = nil
    end
    return
  end

  baseline[id] = baseline[id] or {}

  if not baseline[id].TexCoord then
    local left, right, top, bottom = 0, 1, 0, 1
    if obj.GetTexCoord then
      local ok, ulx, uly, _, lly, urx = pcall(obj.GetTexCoord, obj)
      if ok and ulx then
        left, right, top, bottom = ulx, urx, uly, lly
      end
    end
    baseline[id].TexCoord = { left, right, top, bottom }
  end

  local base = baseline[id].TexCoord
  local left = overrides.TexCoordLeft or base[1]
  local right = overrides.TexCoordRight or base[2]
  local top = overrides.TexCoordTop or base[3]
  local bottom = overrides.TexCoordBottom or base[4]

  obj:SetTexCoord(left, right, top, bottom)
end

local function applyEntry(entry, overrides)
  local obj = WIIIUI.Customizer.Resolve(entry.id)
  if not obj then
    return
  end

  if not entry.secure then
    applyParent(entry.id, obj, overrides)
  end

  applyAnchor(entry.id, obj, overrides)
  applySize(obj, overrides)

  if entry.kind == "texture" and overrides.Texture ~= nil then
    obj:SetTexture(overrides.Texture)
  end

  applyStickySimple(entry, obj, overrides)

  if entry.kind == "texture" then
    applyTexCoord(entry, obj, overrides)
  end
end

-- spec 0001 §Customizer "Apply": "WIIIUI.Customizer.Apply() is the last step
-- of WIIIUI.Layout() ... It runs only when EnableCustomize is true. It
-- iterates the registry, never the saved table." When EnableCustomize is
-- false, overrides is EMPTY_OVERRIDES for every entry -- the same path a
-- theme switch or a cleared field takes -- so every sticky field's baseline
-- restores exactly as if every override had just been removed (one of the
-- four listed "an override goes when" triggers).
function WIIIUI.Customizer.Apply()
  local enabled = wc3UI_Options.EnableCustomize
  wc3UI_Options.edit_theme_settings = wc3UI_Options.edit_theme_settings or {}

  local themeSettings = enabled and wc3UI_Options.edit_theme_settings[wc3UI_Options.theme]

  WIIIUI.Customizer.lastErrors = {}

  for _, entry in ipairs(registry) do
    local overrides = (themeSettings and themeSettings[entry.id]) or EMPTY_OVERRIDES
    local ok, err = pcall(applyEntry, entry, overrides)
    if not ok then
      WIIIUI.Customizer.lastErrors[entry.id] = err
    end
  end
end

--------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------

-- spec 0001 §Customizer "Storage": "edit_theme_settings[theme][id] = {
-- [field] = value }, overridden fields only." value == nil clears the field
-- (and drops the id's table once empty) rather than writing a nil.
function WIIIUI.Customizer.GetOverride(id, field)
  local themeSettings = wc3UI_Options.edit_theme_settings and wc3UI_Options.edit_theme_settings[wc3UI_Options.theme]
  local entry = themeSettings and themeSettings[id]
  return entry and entry[field]
end

-- spec 0001 §Customizer "Combat (sharpened)": "Every customizer apply goes
-- through ApplyOrQueue, not only the secure entries ... An editor edit calls
-- ApplyOrQueue('custom:'..id, ...)." Console.grid's 36 secure grid buttons
-- (Buttons.lua's anchorRow) are anchored to it, and the portrait's secure
-- button anchors to Console.left.portraitTexture -- per warcraft.wiki.gg's
-- Object security page, "[the parent of a protected frame] is implicitly
-- protected also, as are any frames which it is anchored to"
-- (https://warcraft.wiki.gg/wiki/Object_security), so a non-secure ancestor
-- of a secure frame is locked in combat too, not only the secure frame
-- itself.
function WIIIUI.Customizer.SetOverride(id, field, value)
  wc3UI_Options.edit_theme_settings = wc3UI_Options.edit_theme_settings or {}
  local theme = wc3UI_Options.theme
  wc3UI_Options.edit_theme_settings[theme] = wc3UI_Options.edit_theme_settings[theme] or {}
  local themeSettings = wc3UI_Options.edit_theme_settings[theme]

  if value == nil then
    if themeSettings[id] then
      themeSettings[id][field] = nil
      if next(themeSettings[id]) == nil then
        themeSettings[id] = nil
      end
    end
  else
    themeSettings[id] = themeSettings[id] or {}
    themeSettings[id][field] = value
  end

  WIIIUI.ApplyOrQueue("custom:" .. id, WIIIUI.Customizer.Apply)
end

--------------------------------------------------------------------------
-- Editor
--------------------------------------------------------------------------

-- spec 0001 §Customizer "Editor": "It pages with the mouse wheel through an
-- OnMouseWheel(self, delta) script, with no OnUpdate. It shows 3 entries per
-- page, as vanilla did (WIIIUI.lua:1096). Each block's title is the ID,
-- followed by GetName() in brackets when the object has a name."
local PAGE_SIZE = 3

-- The widest field set any registry entry offers -- computed, not a magic
-- number, so a later registry addition (a new kind or a texture entry with
-- more fields) can't silently drop rows the way a stale hardcoded count
-- would (a texture entry's own 16 fields -- base 8 + ParentOf/Hide 2 +
-- Texture/SetDrawLayer/TexCoord*4 6 -- already exceeds vanilla's own 3-line
-- editor box, e17c352 WIIIUI.lua:1096).
local function computeMaxFields()
  local max = 0
  for _, entry in ipairs(registry) do
    local count = #WIIIUI.Customizer.Fields(entry)
    if count > max then
      max = count
    end
  end
  return max
end

local MAX_FIELDS_PER_BLOCK = computeMaxFields()
local BLOCK_WIDTH = 190
local FIELD_ROW_HEIGHT = 16
local FIELD_BOX_WIDTH = 90
local FIELD_LABEL_WIDTH = 90

-- PosX/PosY/Width/Height/FrameLevel/Transparency/TexCoord* are numeric
-- fields; every other field (Point/RelativePoint/ParentPosOf/ParentOf/
-- Texture/FrameStrata) is a plain string; Hide is the one boolean field
-- (only `true` is ever stored, spec 0001 §Customizer "Apply").
local NUMERIC_FIELDS = {
  PosX = true, PosY = true, Width = true, Height = true,
  FrameLevel = true, Transparency = true,
  TexCoordLeft = true, TexCoordRight = true, TexCoordTop = true, TexCoordBottom = true,
}

local function parseFieldValue(field, text)
  if text == nil or text == "" then
    return nil
  end
  if field == "Hide" then
    return (text == "true") or nil
  end
  if NUMERIC_FIELDS[field] then
    return tonumber(text)
  end
  return text
end

local function fieldValueToText(value)
  if value == nil then
    return ""
  end
  return tostring(value)
end

local function pageCount()
  return math.max(1, math.ceil(#registry / PAGE_SIZE))
end

local function ensureBlock(index)
  WIIIUI.Customizer.blocks = WIIIUI.Customizer.blocks or {}
  local blocks = WIIIUI.Customizer.blocks
  local block = blocks[index]
  if block then
    return block
  end

  local editor = WIIIUI.Customizer.editor
  local container = CreateFrame("Frame", nil, editor)
  container:SetSize(BLOCK_WIDTH, MAX_FIELDS_PER_BLOCK * FIELD_ROW_HEIGHT + FIELD_ROW_HEIGHT)

  local title = container:CreateFontString(nil, "OVERLAY")
  title:SetFontObject(GameFontHighlightSmall)
  title:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)

  local rows = {}
  for i = 1, MAX_FIELDS_PER_BLOCK do
    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(GameFontHighlightSmall)
    label:SetWidth(FIELD_LABEL_WIDTH)
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -FIELD_ROW_HEIGHT * i)

    local box = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetSize(FIELD_BOX_WIDTH, 16)
    box:SetPoint("TOPLEFT", label, "TOPRIGHT", 4, 0)

    local row = { label = label, box = box, id = nil, field = nil }

    box:SetScript("OnEscapePressed", function(self)
      self:SetText(row.id and row.field and fieldValueToText(WIIIUI.Customizer.GetOverride(row.id, row.field)) or "")
      self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self)
      if row.id and row.field then
        WIIIUI.Customizer.SetOverride(row.id, row.field, parseFieldValue(row.field, self:GetText()))
      end
      self:ClearFocus()
    end)

    rows[i] = row
  end

  block = { container = container, title = title, rows = rows }
  blocks[index] = block
  return block
end

-- spec 0001 §Customizer "Editor": "Each block's title is the ID, followed by
-- GetName() in brackets when the object has a name."
local function blockTitle(entry)
  local obj = WIIIUI.Customizer.Resolve(entry.id)
  local name = obj and obj.GetName and obj:GetName()
  if name then
    return entry.id .. " [" .. name .. "]"
  end
  return entry.id
end

function WIIIUI.Customizer.RefreshEditor()
  local editor = WIIIUI.Customizer.editor
  if not editor then
    return
  end

  local startIndex = (editor.page - 1) * PAGE_SIZE + 1

  for blockIndex = 1, PAGE_SIZE do
    local entry = registry[startIndex + blockIndex - 1]
    local block = ensureBlock(blockIndex)

    block.container:ClearAllPoints()
    block.container:SetPoint("TOPLEFT", editor, "TOPLEFT", (blockIndex - 1) * BLOCK_WIDTH, 0)

    if entry then
      block.container:Show()
      block.title:SetText(blockTitle(entry))

      local fields = WIIIUI.Customizer.Fields(entry)
      for i, row in ipairs(block.rows) do
        local field = fields[i]
        if field then
          row.id = entry.id
          row.field = field
          row.label:SetText(field)
          row.label:Show()
          row.box:Show()
          row.box:SetText(fieldValueToText(WIIIUI.Customizer.GetOverride(entry.id, field)))
        else
          row.id = nil
          row.field = nil
          row.label:Hide()
          row.box:Hide()
        end
      end
    else
      block.container:Hide()
    end
  end
end

-- spec 0001 §Customizer "Editor": event-driven wheel paging, no OnUpdate.
-- Built once, parented to WIIIUI.Config.panel (Config.lua's own tab switch
-- shows/hides it); re-anchored and refreshed on every call, matching every
-- other Build* function's idempotent convention.
function WIIIUI.Customizer.BuildEditor(panel)
  local editor = WIIIUI.Customizer.editor

  if not editor then
    editor = CreateFrame("Frame", nil, panel)
    editor.page = 1
    editor:EnableMouseWheel(true)
    editor:SetScript("OnMouseWheel", function(self, delta)
      local page = self.page - delta
      local maxPage = pageCount()
      if page < 1 then
        page = 1
      elseif page > maxPage then
        page = maxPage
      end
      self.page = page
      WIIIUI.Customizer.RefreshEditor()
    end)
    WIIIUI.Customizer.editor = editor
  end

  editor:ClearAllPoints()
  editor:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -74)
  editor:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)

  WIIIUI.Customizer.RefreshEditor()
  return editor
end

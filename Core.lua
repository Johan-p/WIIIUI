-- spec 0001 §A.3-A.4, §Settings schema: WIIIUI namespace + defaults merge.
local _, WIIIUI = ...
_G.WIIIUI = WIIIUI

WIIIUI.DEFAULTS = {
  -- Full ~30-key table lands as later iterations add merge behaviors that
  -- need them (clamps, "Set in Edit Mode" keys, etc.) — see slice 02.
  theme = "orc",
  uiScale = 240,
}

function WIIIUI.MergeDefaults(saved)
  local merged = {}
  for key, value in pairs(saved or {}) do
    merged[key] = value
  end
  for key, value in pairs(WIIIUI.DEFAULTS) do
    if merged[key] == nil then
      merged[key] = value
    end
  end
  return merged
end

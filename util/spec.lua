Key.Util = Key.Util or {}

local SpecCatalog = {}
Key.Util.SpecCatalog = SpecCatalog

local Chat = Key.Util.Chat

-- INV_Misc_GroupNeedMore: party silhouettes, used when every spec can use an item.
SpecCatalog.ALL_SPECS_ICON = 134331

local catalog

function SpecCatalog.GetAll()
    if catalog then
        return catalog
    end

    catalog = {}
    if not GetNumSpecializationsForClassID or not GetSpecializationInfoForClassID then
        return catalog
    end

    for classID = 1, 13 do
        local numSpecs = GetNumSpecializationsForClassID(classID)
        if numSpecs and numSpecs > 0 then
            for specIndex = 1, numSpecs do
                local specID, name, _, icon = GetSpecializationInfoForClassID(classID, specIndex)
                if specID then
                    catalog[#catalog + 1] = {
                        classID = classID,
                        specID = specID,
                        specIndex = specIndex,
                        name = name,
                        icon = icon,
                    }
                end
            end
        end
    end

    return catalog
end

function SpecCatalog.IsAllSpecs(specs)
    if not specs or #specs == 0 then
        return false
    end
    return #specs == #SpecCatalog.GetAll()
end

function SpecCatalog.FormatIconList(specs, size)
    if not specs or #specs == 0 then
        return ""
    end

    size = size or 16
    if SpecCatalog.IsAllSpecs(specs) then
        return Chat.Icon(SpecCatalog.ALL_SPECS_ICON, size)
    end

    local byClass = {}
    local classOrder = {}
    for i = 1, #specs do
        local spec = specs[i]
        if not byClass[spec.classID] then
            byClass[spec.classID] = {}
            classOrder[#classOrder + 1] = spec.classID
        end
        local classSpecs = byClass[spec.classID]
        classSpecs[#classSpecs + 1] = spec
    end

    table.sort(classOrder)

    local parts = {}
    for i = 1, #classOrder do
        local classSpecs = byClass[classOrder[i]]
        table.sort(classSpecs, function(a, b)
            return a.specIndex < b.specIndex
        end)

        local classIcons = ""
        for j = 1, #classSpecs do
            classIcons = classIcons .. Chat.Icon(classSpecs[j].icon, size)
        end
        parts[#parts + 1] = classIcons
    end

    return table.concat(parts, "-")
end

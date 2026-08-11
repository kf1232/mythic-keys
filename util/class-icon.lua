Key.Util = Key.Util or {}

local ClassIcon = {}
Key.Util.ClassIcon = ClassIcon

local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local FALLBACK_ICON = 134400

function ClassIcon.Set(texture, classFile)
    if not texture then
        return false
    end

    if classFile and texture.SetAtlas then
        local lower = string.lower(classFile)
        local atlases = {
            "classicon-" .. lower,
            "groupfinder-icon-class-" .. lower,
        }
        for i = 1, #atlases do
            local atlas = atlases[i]
            local ok = false
            if C_Texture and C_Texture.GetAtlasInfo then
                ok = C_Texture.GetAtlasInfo(atlas) ~= nil
            else
                ok = true
            end
            if ok then
                texture:SetTexCoord(0, 1, 0, 1)
                texture:SetAtlas(atlas)
                texture:Show()
                return true
            end
        end
    end

    if classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
        texture:SetTexture(CLASS_ICON_TEXTURE)
        local coords = CLASS_ICON_TCOORDS[classFile]
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        texture:Show()
        return true
    end

    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetTexture(FALLBACK_ICON)
    texture:Show()
    return false
end

function ClassIcon.Hide(texture)
    if texture then
        texture:Hide()
    end
end

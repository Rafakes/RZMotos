--[[
    RZ Motos - CORE: interface (cliente)
    ------------------------------------
    Le o registro de motos (RZMoto.Bikes) e configura:
      - tela de mecanica (ISCarMechanicsOverlay): imagens e areas clicaveis de cada peca;
      - icones dos botoes de container no inventario.
]]

require "RZMoto/RZMoto_Core"

local function registerOverlay(def)
    local ov = def.overlay
    local O = ISCarMechanicsOverlay
    if not ov or not O then return end

    O.CarList[def.fullType] = { imgPrefix = ov.prefix, x = ov.x or 10, y = ov.y or 0 }

    for partId, p in pairs(ov.parts or {}) do
        local entry = O.PartList[partId]
        if not entry then
            entry = { img = p.img, vehicles = {} }
            O.PartList[partId] = entry
        end
        entry.vehicles = entry.vehicles or {}
        entry.vehicles[ov.prefix] = { img = p.img, x = p[1], y = p[2], x2 = p[3], y2 = p[4] }
    end

    for _, partId in ipairs(ov.hidden or {}) do
        local entry = O.PartList[partId]
        if not entry then
            entry = { img = "", vehicles = {} }
            O.PartList[partId] = entry
        end
        entry.vehicles = entry.vehicles or {}
        entry.vehicles[ov.prefix] = { x = 0, y = 0, x2 = 0, y2 = 0 }
    end
end

local function registerIcons(def)
    if not def.icons then return end
    ContainerButtonIcons = ContainerButtonIcons or {}
    for partId, path in pairs(def.icons) do
        local tex = getTexture(path)
        if tex then ContainerButtonIcons[partId] = tex end
    end
end

for _, def in pairs(RZMoto.Bikes) do
    registerOverlay(def)
    registerIcons(def)
end

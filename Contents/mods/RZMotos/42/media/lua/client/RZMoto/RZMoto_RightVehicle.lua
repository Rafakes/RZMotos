--[[
    RZ Motos - CORE: endireitar a moto caida (cliente)
    --------------------------------------------------
    Com uma moto do mod deitada por perto, aparece "Endireitar a moto" no menu de contexto do
    mundo e no menu radial de fora do veiculo. O servidor (RZMoto_Server.lua) revalida tudo.
    Tambem aplica localmente as correcoes de pose enviadas pelo servidor (endireitar/estacionar).
]]

require "RZMoto/RZMoto_Core"

local REACH = 2.5         -- tiles do jogador ate o centro da moto
local FALLEN_DOT = 0.3

local function isFallen(vehicle)
    return vehicle ~= nil and RZMoto.canParkUpright(vehicle) and vehicle:getUpVectorDot() < FALLEN_DOT
end

--- Moto caida mais proxima do jogador, no mesmo andar.
local function nearestFallen(player)
    local cell = getCell()
    if not cell or player:getVehicle() then return nil end
    local best, bestDist
    local it = cell:getVehicles():iterator()
    while it:hasNext() do
        local vehicle = it:next()
        if math.abs(vehicle:getZ() - player:getZ()) < 0.5 and isFallen(vehicle) then
            local d = player:DistTo(vehicle:getX(), vehicle:getY())
            if d <= REACH and (not bestDist or d < bestDist) then best, bestDist = vehicle, d end
        end
    end
    return best
end

local function requestRight(player, vehicle)
    if not isFallen(vehicle) or player:getVehicle()
        or player:DistTo(vehicle:getX(), vehicle:getY()) > REACH then return end
    if isClient() then
        sendClientCommand(player, "RZMoto", "rightVehicle", { vehicle = vehicle:getId() })
    else
        RZMoto.parkUpright(vehicle, vehicle:getAngleY(), math.floor(player:getZ()))
    end
end

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    local vehicle = player and nearestFallen(player)
    if vehicle then
        context:addOption(getText("IGUI_RZMoto_RightVehicle"), player, requestRight, vehicle)
    end
end)

local vanillaRadialOutside = ISVehicleMenu.showRadialMenuOutside
function ISVehicleMenu.showRadialMenuOutside(player)
    local menu = getPlayerRadialMenu(player:getPlayerNum())
    local alreadyOpen = menu:isReallyVisible()
    vanillaRadialOutside(player)
    if alreadyOpen or menu:isEmpty() then return end
    local vehicle = nearestFallen(player)
    if vehicle then
        menu:addSlice(getText("IGUI_RZMoto_RightVehicle"), getTexture("media/ui/vehicles/vehicle_repair.png"),
            requestRight, player, vehicle)
    end
end

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "RZMoto" or (command ~= "rightVehicleAck" and command ~= "parkVehicleAck") then return end
    local vehicle = type(args) == "table" and getVehicleById(args.vehicle)
    if vehicle and RZMoto.isMoto(vehicle) then
        RZMoto.parkUpright(vehicle, args.yaw, args.floorZ or vehicle:getZ())
    end
end)

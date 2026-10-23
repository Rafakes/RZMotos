--[[
    RZ Motos - CORE: subir com a tecla Interagir
    --------------------------------------------
    Em motos com RZMotoConfig.mountWithInteract = 1, a tecla Interagir perto da moto sobe direto quando o
    jogo considera a "porta" bloqueada (as portas da moto sao invisiveis). Usa a mesma acao de subir
    das outras entradas, com a animacao propria.
]]

require "RZMoto/RZMoto_Core"
require "RZMoto/RZMoto_Anim"

Events.OnKeyStartPressed.Add(function(key)
    if key ~= getCore():getKey("Interact") then return end
    local player = getSpecificPlayer(0)
    if not player or player:isDead() or player:getVehicle() then return end
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
    local info = vehicle and RZMoto.getConfig(vehicle)
    if not info or tostring(info.mountWithInteract) ~= "1" then return end
    local seat = 0
    if info.passengerProfile then
        local closest = math.huge
        for candidate = 0, vehicle:getMaxPassengers() - 1 do
            local distance = vehicle:getEnterSeatDistance(candidate, player:getX(), player:getY())
            if distance >= 0 and distance < closest then
                seat, closest = candidate, distance
            end
        end
    end
    if vehicle:isSeatOccupied(seat) or not vehicle:isSeatInstalled(seat)
        or not vehicle:isEnterBlocked(player, seat) then return end
    if ISTimedActionQueue.getTimedActionQueue(player):indexOfType("ISEnterVehicle") ~= -1 then return end
    ISTimedActionQueue.add(ISEnterVehicle:new(player, vehicle, seat))
end)

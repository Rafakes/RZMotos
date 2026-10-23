--[[
    RZ Motos - CORE: servidor
    -------------------------
    - rightVehicle: endireitar uma moto caida. O pedido e revalidado aqui (moto do mod,
      jogador fora dela, perto, no mesmo andar e moto realmente tombada).
    - estacionamento: quando o piloto desce de uma moto parada e levemente inclinada, ela volta
      a ficar em pe depois de PARK_DELAY_MS. Detectado pelo proprio servidor (assento vazio);
      nao depende de nenhum pedido do cliente.

    O transporte de motos fica em RZMoto_TrailerServer.lua, com validacao propria.
]]

if isClient() then return end -- so servidor / solo

require "RZMoto/RZMoto_Core"

local MODULE = "RZMoto"
local MAX_RIGHT_DISTANCE = 6   -- tiles
local FALLEN_DOT = 0.3         -- abaixo disso a moto esta deitada
local PARK_MIN_DOT = 0.5       -- caida demais (queda/batida) nao e endireitada sozinha
local PARK_MAX_DOT = 0.985     -- ja esta em pe
local PARK_DELAY_MS = 400
local TICK_MS = 100
local ACK_RANGE = 80

local ridden = {}   -- veiculo -> { player, emptySince }
local lastTick = 0

local function notifyNearby(vehicle, command, args)
    if not isServer() then return end
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p:DistTo(vehicle:getX(), vehicle:getY()) <= ACK_RANGE then
            sendServerCommand(p, MODULE, command, args)
        end
    end
end

local function stand(vehicle, floorZ, command)
    local yaw = vehicle:getAngleY()
    if RZMoto.parkUpright(vehicle, yaw, floorZ) then
        notifyNearby(vehicle, command, { vehicle = vehicle:getId(), yaw = yaw, floorZ = floorZ })
    end
end

----------------------------------------------------------------------------------------
-- estacionamento
----------------------------------------------------------------------------------------

local function forEachPlayer(fn)
    if isServer() then
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do fn(players:get(i)) end
    else
        for i = 0, getNumActivePlayers() - 1 do
            local p = getSpecificPlayer(i)
            if p then fn(p) end
        end
    end
end

local function onTick()
    local now = getTimestampMs()
    if now - lastTick < TICK_MS then return end
    lastTick = now

    forEachPlayer(function(player)
        local vehicle = player:getVehicle()
        if vehicle and RZMoto.isMoto(vehicle) and vehicle:isDriver(player) then
            ridden[vehicle] = { player = player }
        end
    end)

    for vehicle, state in pairs(ridden) do
        local player = state.player
        if getVehicleById(vehicle:getId()) ~= vehicle or not RZMoto.isMoto(vehicle) then
            ridden[vehicle] = nil
        elseif vehicle:getDriver() then
            state.emptySince = nil
        elseif not RZMoto.canParkUpright(vehicle)
            or player:DistTo(vehicle:getX(), vehicle:getY()) > MAX_RIGHT_DISTANCE then
            ridden[vehicle] = nil
        elseif not state.emptySince then
            state.emptySince = now
        elseif now - state.emptySince >= PARK_DELAY_MS then
            ridden[vehicle] = nil
            local dot = vehicle:getUpVectorDot()
            if dot > PARK_MIN_DOT and dot < PARK_MAX_DOT then
                stand(vehicle, math.floor(player:getZ()), "parkVehicleAck")
            end
        end
    end
end

----------------------------------------------------------------------------------------
-- comandos
----------------------------------------------------------------------------------------

local Commands = {}

function Commands.rightVehicle(player, args)
    local id = type(args) == "table" and tonumber(args.vehicle)
    if not id or id ~= math.floor(id) then return end
    local vehicle = getVehicleById(id)
    if not vehicle or not RZMoto.isMoto(vehicle) or player:getVehicle() then return end
    if player:DistTo(vehicle:getX(), vehicle:getY()) > MAX_RIGHT_DISTANCE then return end
    if math.abs(player:getZ() - vehicle:getZ()) >= 0.5 then return end
    if vehicle:getUpVectorDot() >= FALLEN_DOT then return end
    stand(vehicle, math.floor(player:getZ()), "rightVehicleAck")
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or not player then return end
    local handler = Commands[command]
    if handler then handler(player, args) end
end)

Events.OnTick.Add(onTick)

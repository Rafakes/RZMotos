require "RZMoto/RZMoto_Core"

RZMotoTrailer = RZMotoTrailer or {}
local T = RZMotoTrailer
T.SCRIPT = "Base.RZMoto_Trailer"
T.MODULE = "RZMotoTrailer"
T.REACH = 5
T.BIKE_REACH = 6
T.SLOTS = 2
T.DECK = 0.647552546
T.TRACK = 0.582982284

function T.isTrailer(v)
    return v and not v:isRemovedFromWorld() and v:getScriptName() == T.SCRIPT
end

function T.isSpawned(v)
    return v ~= nil and getVehicleById(v:getId()) == v and not v:isRemovedFromWorld()
end

function T.state(v)
    local part = v and v:getPartById("RZMotoCargo")
    return part and part:getModData(), part
end

function T.stopped(v)
    if not v or math.abs(v:getCurrentSpeedKmHour()) > 0.5 or v:getUpVectorDot() < 0.95 then return false end
    local tow = v:getVehicleTowedBy()
    return not tow or (math.abs(tow:getCurrentSpeedKmHour()) <= 0.5 and not tow:getDriver())
end

function T.near(player, vehicle, distance)
    return player and vehicle and not player:isDead() and not player:getVehicle()
        and math.abs(player:getZ() - vehicle:getZ()) < 0.5
        and player:DistTo(vehicle:getX(), vehicle:getY()) <= distance
end

function T.distance(a, b)
    local dx, dy = a:getX()-b:getX(), a:getY()-b:getY()
    return math.sqrt(dx*dx+dy*dy)
end

function T.compatible(v)
    -- Sidecars exceed the width of one rail. Only registered RZ motorcycles.
    return RZMoto.isMoto(v) and not v:isRemovedFromWorld() and RZMoto.Bikes[v:getScript():getName()] ~= nil
        and v:getMaxPassengers() == 1
end

function T.ContainerAccess() return false end

function T.CreateVault(vehicle, part)
    local container = part:getItemContainer()
    if container then container:setExplored(true) end
end

function T.InitMass(vehicle, part)
    if not isClient() and T.refreshMass then T.refreshMass(vehicle) end
end

-- Same authoritative handler in solo and MP; the client never removes/spawns vehicles.
function T.request(player, command, args)
    if isClient() then sendClientCommand(player, T.MODULE, command, args)
    elseif T.handle then T.handle(command, player, args) end
end

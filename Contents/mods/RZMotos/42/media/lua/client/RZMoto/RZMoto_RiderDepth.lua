-- B42 draws seated geometry at the passenger offset, but sorts it using floor Z.
-- Depth-anchor calculation studied from Mika's AMC clipping patch (see CREDITS.md).
-- Temporary Z changes sorting only; restore after ALL local viewports render.
require "RZMoto/RZMoto_Core"
if isServer() then return end

local LEVEL_HEIGHT = 2.44949
local MAX_BIAS = 0.60
local EPSILON = 0.00001
local zeroPos = Vector3f.new()
local originPos = Vector3f.new()
local seatLocalPos = Vector3f.new()
local seatWorldPos = Vector3f.new()
local applied = {}
local tukTukDepth = { riderDepth = 1 }

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function restorePlayer(player)
    local state = applied[player]
    if not state then return end
    applied[player] = nil
    -- Native exit/teleport may already have assigned a new position. Preserve it.
    if math.abs(player:getZ() - state.renderZ) <= EPSILON then
        player:setZ(state.floorZ)
    end
end

local function restoreAll()
    for player in pairs(applied) do restorePlayer(player) end
end

local function computeBias(vehicle, seat, floorZ)
    if not vehicle:getPassengerLocalPos(seat, seatLocalPos) then return nil end
    vehicle:getWorldPos(zeroPos, originPos)
    vehicle:getWorldPos(seatLocalPos, seatWorldPos)
    local originZ = originPos:z()
    -- getWorldPos converts the origin to levels, but leaves the local delta in metres.
    return originZ + (seatWorldPos:z() - originZ) / LEVEL_HEIGHT - floorZ
end

local function applyForRender()
    restoreAll() -- repeated events must never accumulate the bias
    for index = 0, 3 do
        local player = getSpecificPlayer(index)
        local vehicle = player and player:getVehicle()
        local info = vehicle and RZMoto.getConfig(vehicle)
        if not info and vehicle and vehicle.getScript then
            local script = vehicle:getScript()
            if script and script:getFullName() == "Base.RZMoto_TukTuk" then info = tukTukDepth end
        end
        if info and tostring(info.riderDepth or "0") == "1" then
            local seat = vehicle:getSeat(player)
            local skipEntering = tostring(info.riderSkipEntering or "1") == "1"
            local entering = skipEntering and player:GetVariable("bEnteringVehicle") == "true"
            local exiting = player:GetVariable("bExitingVehicle") == "true"
            if seat >= 0 and not player:isDead() and not entering and not exiting then
                local floorZ = player:getZ()
                local ok, bias = pcall(computeBias, vehicle, seat, floorZ)
                -- No passenger position means no valid anchor; retain native Z.
                if ok and finite(bias) and finite(floorZ) then
                    local correction = tonumber(info.riderZCorrection) or 0
                    if not finite(correction) then correction = 0 end
                    bias = math.max(0, math.min(MAX_BIAS, bias + correction))
                    player:setZ(floorZ + bias)
                    -- getZ is a Java float: record the value actually stored.
                    applied[player] = { floorZ = floorZ, renderZ = player:getZ() }
                end
            end
        end
    end
end

local function beforeUpdate()
    restoreAll()
    -- Paused frames still render, but do not emit OnTick.
    if isGamePaused() then applyForRender() end
end

local function afterViewport()
    -- IngameState renders non-null players in ascending order and sets getPlayer()
    -- for each viewport. Retain every rider's bias until the last viewport is done.
    local lastPlayer
    for index = 0, 3 do
        local player = getSpecificPlayer(index)
        if player then lastPlayer = player end
    end
    if getPlayer() == lastPlayer then restoreAll() end
end

Events.OnTickEvenPaused.Add(beforeUpdate)
Events.OnTick.Add(applyForRender)
Events.OnPostRender.Add(afterViewport)
Events.OnPostUIDraw.Add(restoreAll) -- fallback if a viewport render was interrupted
Events.OnExitVehicle.Add(restorePlayer)

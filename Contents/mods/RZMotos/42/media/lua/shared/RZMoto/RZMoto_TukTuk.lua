-- Car integration. Deliberately has no RZMotoConfig and no motorcycle registration.
require "RZMoto/RZMoto_Core"
require "VehicleZoneDefinition"
RZTukTuk = RZTukTuk or {}

-- B42 CarController checks all four Tire* IDs. The two close front supports
-- represent the single front tire, whose actual inventory item is FrontLeft.
-- Only SP/server mirrors its item, wear and pressure onto the hidden support.
local function syncFront(vehicle)
    if isClient() then return end
    local source = vehicle:getPartById("TireFrontLeft")
    local target = vehicle:getPartById("TireFrontRight")
    if not source or not target then return end
    local item, old = source:getInventoryItem(), target:getInventoryItem()
    local changed = false
    if not item then
        if old then target:setInventoryItem(nil); changed = true end
    else
        if not old or old:getFullType() ~= item:getFullType() then
            local replacement = instanceItem(item:getFullType())
            if not replacement then return end
            target:setInventoryItem(replacement, source:getMechanicSkillInstaller())
            changed = true
        end
        if target:getCondition() ~= source:getCondition() then
            target:setCondition(source:getCondition()); changed = true
            vehicle:transmitPartCondition(target)
        end
        if target:getMechanicSkillInstaller() ~= source:getMechanicSkillInstaller() then
            target:setMechanicSkillInstaller(source:getMechanicSkillInstaller()); changed = true
        end
        if target:getContainerContentAmount() ~= source:getContainerContentAmount() then
            target:setContainerContentAmount(source:getContainerContentAmount(), true, true)
            vehicle:transmitPartModData(target); changed = true
        end
    end
    if changed then
        vehicle:transmitPartItem(target)
        vehicle:updatePartStats(); vehicle:updateBulletStats()
        vehicle:setTireRemoved(target:getWheelIndex(), target:getInventoryItem() == nil)
    end
end
function RZTukTuk.InitFront(vehicle, part)
    Vehicles.Init.Tire(vehicle, part)
    syncFront(vehicle)
end
function RZTukTuk.UpdateFront(vehicle, part, elapsed)
    if isClient() then return end
    Vehicles.Update.Tire(vehicle, part, elapsed)
    syncFront(vehicle)
end
function RZTukTuk.InstallFront(vehicle, part)
    Vehicles.InstallComplete.Tire(vehicle, part)
    syncFront(vehicle)
end
function RZTukTuk.UninstallFront(vehicle, part, item)
    Vehicles.UninstallComplete.Tire(vehicle, part, item)
    syncFront(vehicle)
end
function RZTukTuk.InitSupport(vehicle, part)
    Vehicles.Init.Tire(vehicle, part)
    syncFront(vehicle)
end
function RZTukTuk.CreateSupport(vehicle, part)
    if not isClient() then syncFront(vehicle) end
end
function RZTukTuk.UpdateSupport(vehicle, part, elapsed) end

for zone, chance in pairs({ good = 0.5, medium = 0.7, parkingstall = 0.35 }) do
    local distribution = VehicleZoneDistribution[zone]
    if distribution and distribution.vehicles then
        distribution.vehicles["Base.RZMoto_TukTuk"] = { index = -1, spawnChance = chance }
    end
end

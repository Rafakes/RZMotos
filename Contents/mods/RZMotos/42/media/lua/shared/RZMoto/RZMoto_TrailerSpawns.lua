require "VehicleZoneDefinition"
require "RZMoto/RZMoto_Trailer"
-- Native zone spawning, including existing saves when new map chunks are explored.
for zone, chance in pairs({ farm = 3, parkingstall = 0.4 }) do
    local distribution = VehicleZoneDistribution[zone]
    if distribution and distribution.vehicles then
        distribution.vehicles[RZMotoTrailer.SCRIPT] = { index = -1, spawnChance = chance }
    end
end

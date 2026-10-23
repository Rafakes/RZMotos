require "RZMoto/RZMoto_Core"

-- Keep native bulb, condition, activation, color and battery behavior. The script
-- supplies a central front position; native rear init hardcodes distance1.6.
function RZMoto.Init.CenteredLight(vehicle, part)
    Vehicles.Init.Headlight(vehicle, part)
    local id = part:getId()
    if id ~= "HeadlightRearLeft" and id ~= "HeadlightRearRight" then return end
    local params = part:getTable("headlight")
    local offset = tonumber(params and params.yOffset)
    if not offset or offset ~= offset or offset <= 0 or offset == math.huge then return end
    -- Reuses the existing VehicleLight, including its activation flag.
    part:createSpotLightColor(0, -offset, 3, 0.2, 0.75, 0, 1, 0.2, 0.2)
end

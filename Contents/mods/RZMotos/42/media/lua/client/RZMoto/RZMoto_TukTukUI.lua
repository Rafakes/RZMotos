-- Own car mechanics sheet; does not register the tuk-tuk as a motorcycle.
require "Vehicles/ISUI/ISCarMechanicsOverlay"
local O = ISCarMechanicsOverlay
local prefix = "rzmoto_tk_"
O.CarList["Base.RZMoto_TukTuk"] = { imgPrefix = prefix, x = 10, y = 0, PartList = {} }
local ids = {
    "TireFrontLeft", "BrakeFrontLeft", "SuspensionFrontLeft", "TireRearLeft",
    "BrakeRearLeft", "SuspensionRearLeft", "TireRearRight", "BrakeRearRight",
    "SuspensionRearRight", "Battery", "Engine", "GasTank", "Muffler",
    "Windshield", "SeatFrontLeft", "SeatRearLeft", "SeatRearRight", "TruckBedOpen",
    "HeadlightLeft", "HeadlightRearLeft", "HeadlightRearRight", "Radio",
}
for i, id in ipairs(ids) do
    local right = i > 11
    local row = right and i - 12 or i - 1
    local x, y = right and 220 or 8, 22 + row * 48
    O.PartList[id] = O.PartList[id] or { img = id, vehicles = {} }
    O.PartList[id].vehicles = O.PartList[id].vehicles or {}
    O.PartList[id].vehicles[prefix] = { img = id, x = x, y = y, x2 = x + 43, y2 = y + 40 }
    O.CarList["Base.RZMoto_TukTuk"].PartList[id] = { img = id, vehicles = { [prefix] = O.PartList[id].vehicles[prefix] } }
end
for _, id in ipairs({ "TireFrontRight", "BrakeFrontRight", "SuspensionFrontRight", "DoorFrontLeft", "DoorRearLeft", "DoorRearRight" }) do
    O.PartList[id] = O.PartList[id] or { img = "", vehicles = {} }
    O.PartList[id].vehicles = O.PartList[id].vehicles or {}
    O.PartList[id].vehicles[prefix] = { x = 0, y = 0, x2 = 0, y2 = 0 }
end

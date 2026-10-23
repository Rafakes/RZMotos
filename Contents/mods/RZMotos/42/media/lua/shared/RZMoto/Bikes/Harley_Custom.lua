-- Harley Custom v1.2 by 3DWorkbench: motorcycle only.
require "RZMoto/Bikes/AKT_TT200"
local base = RZMoto.Bikes.RZMoto_AKTTT200
local overlay = { prefix="rzmoto_hc_", x=10, y=0, parts={
    SuspensionFrontLeft = { img="suspension_front_left", 14, 60, 62, 100 },
    BrakeFrontLeft = { img="brake_front_left", 14, 104, 62, 144 },
    RZMotoTireFront = { img="wheel_front", 14, 148, 62, 188 },
    Battery = { img="battery", 14, 200, 62, 240 },
    SuspensionRearLeft = { img="suspension_rear_left", 14, 252, 62, 292 },
    BrakeRearLeft = { img="brake_rear_left", 14, 296, 62, 336 },
    RZMotoTireRear = { img="wheel_rear", 14, 340, 62, 380 },
    HeadlightLeft = { img="headlight_left", 220, 104, 268, 144 },
    Engine = { img="engine", 220, 148, 268, 188 },
    GasTank = { img="gastank", 220, 200, 268, 240 },
    Muffler = { img="muffler", 220, 252, 268, 292 },
    SeatFrontLeft = { img="seat", 220, 296, 268, 336 },
    FenderFront = { img="fender_front", 220, 340, 268, 380 },
    FenderRear = { img="fender_rear", 220, 384, 268, 424 },
}, hidden=base.overlay.hidden }
RZMoto.registerBike({
    id="RZMoto_HarleyCustom",
    spawn={ good=3, medium=1, parkingstall=1, trafficjamw=0.5, trafficjame=0.5 },
    visuals={ steeringAxis={0.0, 0.8790799379348755, -0.47667452692985535}, frontRadius=0.4056786590710836, rearRadius=0.4061262974790656 },
    overlay=overlay,
})

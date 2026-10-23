-- Post-Apo: original artwork, animated skull/steering and one cargo compartment.
require "RZMoto/Bikes/AKT_TT200"
local base = RZMoto.Bikes.RZMoto_AKTTT200
local overlay = { prefix="rzmoto_pa_", x=10, y=0, parts={
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
    RZMotoCargoPostApo = { img="cargo", 14, 396, 62, 436 },
}, hidden=base.overlay.hidden }
RZMoto.registerBike({
    id="RZMoto_PostApo",
    spawn={ good=0.5, medium=0.5, junkyard=1, farm=0.75, parkingstall=0.5 },
    visuals={ steeringAxis={0.000000000, 0.870122313, -0.492835879}, frontRadius=0.357721781, rearRadius=0.370566240 },
    icons={RZMotoCargoPostApo="media/textures/Item_RZ_PA_Cargo.png"},
    overlay=overlay,
})

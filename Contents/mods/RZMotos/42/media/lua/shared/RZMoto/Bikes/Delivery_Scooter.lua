require "RZMoto/Bikes/AKT_TT200"
require "RZMoto/RZMoto_Electric"
require "RZMoto/RZMoto_ScooterLights"
RZMoto.registerBike({
    id = "RZMoto_DeliveryScooter",
    spawn = { good=1, medium=0.5, parkingstall=1, trailerpark=0.5 },
    visuals = { steeringAxis={0.000000000,0.918675244,-0.395013511}, frontRadius=0.246180000, rearRadius=0.246840000, fixedModels={Panel=true} },
    icons = { RZMotoScooterCargoFront="media/textures/Item_RZ_DS_CargoFront.png", RZMotoScooterCargoRear="media/textures/Item_RZ_DS_CargoRear.png" },
    overlay = { prefix="rzmoto_ds_", x=10, y=0, parts={
        SuspensionFrontLeft = { img="suspension_front_left", 14, 60, 62, 100 },
        BrakeFrontLeft = { img="brake_front_left", 14, 104, 62, 144 },
        RZMotoTireFront = { img="wheel_front", 14, 148, 62, 188 },
        Battery = { img="battery", 14, 200, 62, 240 },
        SuspensionRearLeft = { img="suspension_rear_left", 14, 252, 62, 292 },
        BrakeRearLeft = { img="brake_rear_left", 14, 296, 62, 336 },
        RZMotoTireRear = { img="wheel_rear", 14, 340, 62, 380 },
        HeadlightLeft = { img="headlight_left", 220, 104, 268, 144 },
        Engine = { img="engine", 220, 148, 268, 188 },
        SeatFrontLeft = { img="seat", 220, 296, 268, 336 },
        FenderFront = { img="fender_front", 220, 340, 268, 380 },
        FenderRear = { img="fender_rear", 220, 384, 268, 424 },
        RZMotoScooterCargoFront = { img="cargo_front", 14, 396, 62, 436 },
        RZMotoScooterCargoRear = { img="cargo_rear", 14, 440, 62, 480 },
    }, hidden={"GasTank","SuspensionFrontRight","SuspensionRearRight","TireFrontLeft","TireFrontRight","TireRearLeft","TireRearRight","HeadlightRearLeft"} },
})

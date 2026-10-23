--[[
    RZ Motos - moto: AKT TT 200 DS (Dual Sport)
    Registro da moto no motor principal. Para criar outra moto, copie este arquivo e ajuste.
]]

require "VehicleZoneDefinition"
require "RZMoto/RZMoto_Core"
require "RZMoto/RZMoto_Lights"

RZMoto.registerBike({
    id = "RZMoto_AKTTT200",

    -- Geometria visual em unidades do modelo, antes da escala do veiculo.
    visuals = {
        steeringAxis = { 0.000000000, 0.884211540, -0.467086673 },
        frontRadius = 0.33700726000000003,
        rearRadius = 0.3120087,
    },


    -- chance de spawn por zona (VehicleZoneDistribution)
    spawn = {
        good = 6,
        medium = 3,
        junkyard = 2,
        parkingstall = 2,
        trailerpark = 2,
        mccoy = 3,
        farm = 5,
        trafficjamw = 2,
        trafficjame = 2,
        trafficjamn = 2,
        trafficjams = 2,
    },

    -- icone do botao de cada container no inventario
    icons = {
        RZMotoBoxTop = "media/textures/Item_RZ_AKT_TopBox.png",
        RZMotoBoxLeft = "media/textures/Item_RZ_AKT_SideBox.png",
        RZMotoBoxRight = "media/textures/Item_RZ_AKT_SideBox.png",
    },

    -- tela de mecanica (ISCarMechanicsOverlay): imagens em media/ui/vehicles/mechanic overlay/<prefix>*.png
    overlay = {
        prefix = "rzmoto_akt_",
        x = 10,
        y = 0,
        -- PartId = { img = nome-da-imagem, x, y, x2, y2 }   (retangulo clicavel)
        parts = {
            SuspensionFrontLeft = { img = "suspension_front_left", 14, 60, 62, 100 },
            BrakeFrontLeft = { img = "brake_front_left", 14, 104, 62, 144 },
            RZMotoTireFront = { img = "wheel_front", 14, 148, 62, 188 },
            Battery = { img = "battery", 14, 200, 62, 240 },
            SuspensionRearLeft = { img = "suspension_rear_left", 14, 252, 62, 292 },
            BrakeRearLeft = { img = "brake_rear_left", 14, 296, 62, 336 },
            RZMotoTireRear = { img = "wheel_rear", 14, 340, 62, 380 },
            Windshield = { img = "windshield", 220, 60, 268, 100 },
            HeadlightLeft = { img = "headlight_left", 220, 104, 268, 144 },
            Engine = { img = "engine", 220, 148, 268, 188 },
            GasTank = { img = "gastank", 220, 200, 268, 240 },
            Muffler = { img = "muffler", 220, 252, 268, 292 },
            SeatFrontLeft = { img = "seat", 220, 296, 268, 336 },
            FenderFront = { img = "fender_front", 220, 340, 268, 380 },
            FenderRear = { img = "fender_rear", 220, 384, 268, 424 },
            RZMotoBoxTop = { img = "box_top", 14, 396, 62, 436 },
            RZMotoBoxLeft = { img = "box_left", 14, 440, 62, 480 },
            RZMotoBoxRight = { img = "box_right", 14, 484, 62, 524 },
        },
        -- pecas escondidas: sem area clicavel
        hidden = { "SuspensionFrontRight", "SuspensionRearRight", "TireFrontLeft", "TireFrontRight",
            "TireRearLeft", "TireRearRight", "HeadlightRearLeft" },
    },
})

-- Duas variantes visuais adicionais. Fisica, mecanica e pivots iguais aos originais.
require "RZMoto/Bikes/AKT_TT200"
require "RZMoto/Bikes/Street_Three"

local akt = RZMoto.Bikes.RZMoto_AKTTT200
RZMoto.registerBike({
    id = "RZMoto_AKTTT200_Matte",
    spawn = { good = 1, medium = 0.5, parkingstall = 0.5, farm = 0.5 },
    visuals = akt.visuals,
    icons = akt.icons,
    overlay = akt.overlay,
})

local street = RZMoto.Bikes.RZMoto_StreetThree
RZMoto.registerBike({
    id = "RZMoto_StreetThree_Matte",
    spawn = { good = 1, medium = 0.5, parkingstall = 0.5 },
    visuals = street.visuals,
    icons = street.icons,
    overlay = street.overlay,
})

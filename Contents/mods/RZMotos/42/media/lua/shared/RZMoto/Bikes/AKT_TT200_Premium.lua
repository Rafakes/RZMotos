-- AKT Premium Fosca: mesma mecanica, acabamento grafite/bronze e ocorrencia rara.
require "RZMoto/Bikes/AKT_TT200"

local base = RZMoto.Bikes.RZMoto_AKTTT200
RZMoto.registerBike({
    id = "RZMoto_AKTTT200_Premium",
    spawn = { good = 1, medium = 0.35, parkingstall = 0.35, farm = 0.25 },
    visuals = base.visuals,
    icons = base.icons,
    overlay = base.overlay,
})

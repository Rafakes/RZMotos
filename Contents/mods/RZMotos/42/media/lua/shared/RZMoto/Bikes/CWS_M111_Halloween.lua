-- Separate seasonal paint variant; shares CWS geometry, maintenance and rider profiles.
require "RZMoto/Bikes/CWS_M111"
local base = RZMoto.Bikes.RZMoto_CWSM111
RZMoto.registerBike({
    id = "RZMoto_CWSM111_Halloween",
    spawn = { good=0.3, medium=0.1, parkingstall=0.15 },
    visuals = base.visuals,
    sidecarWheel = base.sidecarWheel,
    passengerProfile = base.passengerProfile,
    overlay = base.overlay,
})

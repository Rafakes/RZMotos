require "RZMoto/Bikes/AKT_TT200"
local base=RZMoto.Bikes.RZMoto_AKTTT200
RZMoto.registerBike({
 id="RZMoto_HondaCRF450",spawn={good=1,trailerpark=1,parkingstall=.4},
 visuals={steeringAxis={-0.000001073,0.874650240,-0.484754443},frontRadius=0.437509551,rearRadius=0.419147782},
 overlay={prefix="rzmoto_cf_",x=10,y=0,hidden=base.overlay.hidden,parts={
  SuspensionFrontLeft={img="suspension_front_left",14,60,62,100},
  BrakeFrontLeft={img="brake_front_left",14,104,62,144},
  RZMotoTireFront={img="wheel_front",14,148,62,188},
  Battery={img="battery",14,200,62,240},
  SuspensionRearLeft={img="suspension_rear_left",14,252,62,292},
  BrakeRearLeft={img="brake_rear_left",14,296,62,336},
  RZMotoTireRear={img="wheel_rear",14,340,62,380},
  Engine={img="engine",220,148,268,188},
  SeatFrontLeft={img="seat",220,296,268,336},
  FenderFront={img="fender_front",220,340,268,380},
  FenderRear={img="fender_rear",220,384,268,424},
  GasTank={img="gastank",220,200,268,240},
  Muffler={img="muffler",220,252,268,292},
}},
})

--[[
    RZ Motos - distribuicoes (loot dentro dos containers das motos + pecas nos galpoes)
]]

require "Vehicles/VehicleDistributions"
require "Items/ProceduralDistributions"

-- ---------------------------------------------------------------------------------
-- conteudo inicial dos containers (quando a moto nasce com o container instalado)
-- ---------------------------------------------------------------------------------
VehicleDistributions.RZMoto_TopBox = {
    rolls = 1,
    items = {
        "Screwdriver", 1,
        "Wrench", 1,
        "DuctTape", 2,
        "Rope", 1,
        "RZ_MotoMag", 0.5,
    },
    junk = ClutterTables.TrunkJunk,
}

VehicleDistributions.RZMoto_SideBox = {
    rolls = 1,
    items = {
        "DuctTape", 1,
        "Rope", 1,
    },
    junk = ClutterTables.GloveBoxJunk,
}

VehicleDistributions.RZMoto_AKT = {
    RZMotoBoxTop = VehicleDistributions.RZMoto_TopBox,
    RZMotoBoxLeft = VehicleDistributions.RZMoto_SideBox,
    RZMotoBoxRight = VehicleDistributions.RZMoto_SideBox,
}

local distributionTable = VehicleDistributions[1]
if distributionTable then
    distributionTable["RZMoto_HondaMotra"] = { Normal = { RZMotoMotraCargoFront = VehicleDistributions.RZMoto_SideBox, RZMotoMotraCargoRear = VehicleDistributions.RZMoto_TopBox } }
    distributionTable["RZMoto_HarleyPolice"] = { Normal = VehicleDistributions.RZMoto_AKT }
    distributionTable["RZMoto_AKTTT200"] = { Normal = VehicleDistributions.RZMoto_AKT }
    distributionTable["RZMoto_AKTTT200_Premium"] = { Normal = VehicleDistributions.RZMoto_AKT }
    distributionTable["RZMoto_AKTTT200_Matte"] = { Normal = VehicleDistributions.RZMoto_AKT }
    distributionTable["RZMoto_DeliveryScooter"] = { Normal = { RZMotoScooterCargoFront = VehicleDistributions.RZMoto_SideBox, RZMotoScooterCargoRear = VehicleDistributions.RZMoto_TopBox } }
    distributionTable["RZMoto_PostApo"] = { Normal = { RZMotoCargoPostApo = VehicleDistributions.RZMoto_TopBox } }
end

-- ---------------------------------------------------------------------------------
-- pecas soltas em garagens / oficinas
-- ---------------------------------------------------------------------------------
local PART_ITEMS = {
    { "Base.RZ_OW_Seat", 0.1 },
    { "Base.RZ_OW_GasTank", 0.1 },
    { "Base.RZ_OW_FenderFront", 0.1 },
    { "Base.RZ_OW_FenderRear", 0.1 },
    { "Base.RZ_OW_TireOld", 0.1 },
    { "Base.RZ_OW_TireNormal", 0.1 },
    { "Base.RZ_OW_TireModern", 0.1 },
    { "Base.RZ_OW_Holster", 0.1 },

    { "Base.RZ_GR_Seat", 0.1 },
    { "Base.RZ_GR_GasTank", 0.1 },
    { "Base.RZ_GR_FenderRear", 0.1 },
    { "Base.RZ_GR_TireOld", 0.1 },
    { "Base.RZ_GR_TireNormal", 0.1 },
    { "Base.RZ_GR_TireModern", 0.1 },

    { "Base.RZ_CW_Seat", 0.1 },
    { "Base.RZ_CW_GasTank", 0.1 },
    { "Base.RZ_CW_FenderFront", 0.1 },
    { "Base.RZ_CW_FenderRear", 0.1 },
    { "Base.RZ_CW_TireOld", 0.1 },
    { "Base.RZ_CW_TireNormal", 0.1 },
    { "Base.RZ_CW_TireModern", 0.1 },

    { "Base.RZ_MT_Seat", 0.1 },
    { "Base.RZ_MT_GasTank", 0.1 },
    { "Base.RZ_MT_FenderFront", 0.1 },
    { "Base.RZ_MT_FenderRear", 0.1 },
    { "Base.RZ_MT_TireOld", 0.1 },
    { "Base.RZ_MT_TireNormal", 0.1 },
    { "Base.RZ_MT_TireModern", 0.1 },
    { "Base.RZ_MT_CargoFront", 0.1 },
    { "Base.RZ_MT_CargoRear", 0.1 },

    { "Base.RZ_HS_Seat", 0.1 },
    { "Base.RZ_HS_GasTank", 0.1 },
    { "Base.RZ_HS_FenderFront", 0.1 },
    { "Base.RZ_HS_FenderRear", 0.1 },
    { "Base.RZ_HS_TireOld", 0.1 },
    { "Base.RZ_HS_TireNormal", 0.1 },
    { "Base.RZ_HS_TireModern", 0.1 },

    { "Base.RZ_HC_Seat", 0.1 },
    { "Base.RZ_HC_GasTank", 0.1 },
    { "Base.RZ_HC_FenderFront", 0.1 },
    { "Base.RZ_HC_FenderRear", 0.1 },
    { "Base.RZ_HC_TireOld", 0.1 },
    { "Base.RZ_HC_TireNormal", 0.1 },
    { "Base.RZ_HC_TireModern", 0.1 },

    { "Base.RZ_HD_Seat", 0.1 },
    { "Base.RZ_HD_GasTank", 0.1 },
    { "Base.RZ_HD_FenderFront", 0.1 },
    { "Base.RZ_HD_FenderRear", 0.1 },
    { "Base.RZ_HD_TireOld", 0.1 },
    { "Base.RZ_HD_TireNormal", 0.1 },
    { "Base.RZ_HD_TireModern", 0.1 },

    { "Base.RZ_CF_Seat",0.1 },
    { "Base.RZ_CF_GasTank",0.1 },
    { "Base.RZ_CF_FenderFront",0.1 },
    { "Base.RZ_CF_FenderRear",0.1 },
    { "Base.RZ_CF_TireNormal",0.1 },

    { "Base.RZ_HP_Seat",0.1 },
    { "Base.RZ_HP_GasTank",0.1 },
    { "Base.RZ_HP_Windshield",0.1 },
    { "Base.RZ_HP_FenderFront",0.1 },
    { "Base.RZ_HP_FenderRear",0.1 },
    { "Base.RZ_HP_TopBox",0.1 },
    { "Base.RZ_HP_SideBox",0.1 },
    { "Base.RZ_HP_TireNormal",0.1 },

    { "Base.RZ_DS_Seat", 0.1 },
    { "Base.RZ_DS_FenderFront", 0.1 },
    { "Base.RZ_DS_FenderRear", 0.1 },
    { "Base.RZ_DS_TireNormal", 0.1 },
    { "Base.RZ_DS_Battery", 0.1 },
    { "Base.RZ_DS_CargoFront", 0.1 },
    { "Base.RZ_DS_CargoRear", 0.1 },

    { "Base.RZ_PA_Seat", 0.1 },
    { "Base.RZ_PA_GasTank", 0.1 },
    { "Base.RZ_PA_FenderFront", 0.1 },
    { "Base.RZ_PA_FenderRear", 0.1 },
    { "Base.RZ_PA_Cargo", 0.05 },
    { "Base.RZ_PA_TireOld", 0.1 },
    { "Base.RZ_PA_TireNormal", 0.1 },
    { "Base.RZ_PA_TireModern", 0.05 },
    { "Base.RZ_ST_Seat", 0.1 },
    { "Base.RZ_ST_GasTank", 0.1 },
    { "Base.RZ_ST_FenderFront", 0.1 },
    { "Base.RZ_ST_FenderRear", 0.1 },
    { "Base.RZ_ST_TireOld", 0.1 },
    { "Base.RZ_ST_TireNormal", 0.1 },
    { "Base.RZ_ST_TireModern", 0.05 },
    { "Base.RZ_AKT_Seat", 0.2 },
    { "Base.RZ_AKT_GasTank", 0.2 },
    { "Base.RZ_AKT_Windshield", 0.2 },
    { "Base.RZ_AKT_FenderFront", 0.2 },
    { "Base.RZ_AKT_FenderRear", 0.2 },
    { "Base.RZ_AKT_TopBox", 0.15 },
    { "Base.RZ_AKT_SideBox", 0.15 },
    { "Base.RZ_AKT_TireOld", 0.2 },
    { "Base.RZ_AKT_TireNormal", 0.2 },
    { "Base.RZ_AKT_TireModern", 0.1 },
}

local PLACES = { "GarageMechanics", "CrateMechanics", "MechanicShelfMisc", "MechanicShelfTools", "GarageTools" }

for _, place in ipairs(PLACES) do
    local list = ProceduralDistributions.list[place]
    if list and list.items then
        for _, it in ipairs(PART_ITEMS) do
            table.insert(list.items, it[1])
            table.insert(list.items, it[2])
        end
    end
end


-- ---------------------------------------------------------------------------------
-- revista de manutencao (ensina as 102 receitas de pecas)
-- pesos no padrao das MechanicMag vanilla nas mesmas listas
-- ---------------------------------------------------------------------------------
local MAG_PLACES = {
    { "CarSupplyLiterature", 4 },
    { "CarSupplyMagazines", 4 },
    { "BookstoreAutomotive", 3 },
    { "MechanicShelfBooks", 3 },
    { "MechanicSpecial", 3 },
    { "StoreShelfMechanics", 2 },
    { "ToolStoreBooks", 2 },
    { "CarDealerDesk", 2 },
    { "GasStorageMechanics", 2 },
    { "CrateMechanics", 1.5 },
    { "GarageMechanics", 1.5 },
}

for _, entry in ipairs(MAG_PLACES) do
    local list = ProceduralDistributions.list[entry[1]]
    if list and list.items then
        table.insert(list.items, "RZ_MotoMag")
        table.insert(list.items, entry[2])
    end
end

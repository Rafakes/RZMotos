--[[
    RZ Motos - CORE (motor principal)
    ---------------------------------
    Codigo compartilhado por todas as motos do mod. Nao depende de nenhum outro mod.

    Arquivo "shared" de proposito: as funcoes referenciadas pelos scripts de veiculo
    (create / init / use / test / complete / update) precisam ser acessiveis nos dois lados.
    Na B42, complete e updates de pecas alteram estado no servidor/SP.

    Para adicionar uma moto nova:
      1) scripts/vehicles/bikes/<moto>/  (modelos, veiculo, itens)
      2) lua/shared/RZMoto/Bikes/<Moto>.lua  chamando RZMoto.registerBike{...}
]]

RZMoto = RZMoto or {}
RZMoto.VERSION = "2.10.5"
RZMoto.CONFIG_PART = "RZMotoConfig"

RZMoto.Create = RZMoto.Create or {}
RZMoto.Init = RZMoto.Init or {}
RZMoto.Update = RZMoto.Update or {}
RZMoto.Use = RZMoto.Use or {}
RZMoto.ContainerAccess = RZMoto.ContainerAccess or {}
RZMoto.InstallComplete = RZMoto.InstallComplete or {}
RZMoto.UninstallComplete = RZMoto.UninstallComplete or {}

-- registro das motos (preenchido por lua/shared/RZMoto/Bikes/*.lua)
RZMoto.Bikes = RZMoto.Bikes or {}

----------------------------------------------------------------------------------------
-- utilidades
----------------------------------------------------------------------------------------

--- Retorna a tabela de configuracao da moto (ou nil se o veiculo nao e uma moto do mod).
function RZMoto.getConfig(vehicle)
    if not vehicle or not vehicle.getPartById then return nil end
    local part = vehicle:getPartById(RZMoto.CONFIG_PART)
    if not part then return nil end
    return part:getTable(RZMoto.CONFIG_PART), part
end

function RZMoto.isMoto(vehicle)
    return vehicle ~= nil and vehicle.getPartById ~= nil and vehicle:getPartById(RZMoto.CONFIG_PART) ~= nil
end

--- Estacionamento: nunca mover ocupantes, uma moto em movimento ou um conjunto rebocado.
function RZMoto.canParkUpright(vehicle)
    if not RZMoto.isMoto(vehicle) then return false end
    if math.abs(vehicle:getCurrentSpeedKmHour()) > 2 then return false end
    if vehicle:getVehicleTowing() or vehicle:getVehicleTowedBy() then return false end
    for seat = 0, vehicle:getMaxPassengers() - 1 do
        if vehicle:getCharacter(seat) then return false end
    end
    return true
end

function RZMoto.parkUpright(vehicle, yaw, floorZ)
    if not RZMoto.canParkUpright(vehicle) then return false end
    -- So o simulador local alterna Bullet; clientes observadores nao assumem a fisica.
    -- Acordar tambem a moto ja inativa: Bullet restaura a pose antiga de corpos
    -- estaticos no proximo step se apenas teleportarmos sem reativar a simulacao.
    local resetPhysics = not isServer() and (not isClient() or vehicle:isLocalPhysicSim())
    if resetPhysics then vehicle:setPhysicsActive(false) end
    vehicle:setAngles(0, yaw, 0)
    local transform = BaseVehicle.allocTransform()
    vehicle:getWorldTransform(transform)
    local origin = transform:getOrigin()
    -- A origem tombada pode estar abaixo do piso. 0.30 m deixa as rodas assentarem
    -- sem levar a camera ao andar -1. Um andar B42 equivale a 2.44949 m fisicos.
    origin:set(origin:x(), math.max(origin:y(), math.floor(floorZ) * 2.44949 + 0.30), origin:z())
    vehicle:setWorldTransform(transform)
    BaseVehicle.releaseTransform(transform)
    if resetPhysics then vehicle:setPhysicsActive(true) end
    -- Nao usar scriptReloaded: ele remove itens instalados e invalida modelos animados.
    return true
end

--- Registra uma moto. Campos:
---   id        nome do script do veiculo (sem modulo)            ex: "RZMoto_AKTTT200"
---   spawn     { zona = chance, ... }                            zonas de VehicleZoneDistribution
---   loot      { idDaPeca = tabelaDeLoot, ... }                  conteudo inicial dos containers
---   overlay   { prefix, x, y, parts = { PartId = {x,y,x2,y2,img}, ... } }   UI da mecanica
---   icons     { PartId = "caminho/da/textura.png", ... }        icone do botao do container
function RZMoto.registerBike(def)
    assert(type(def) == "table" and def.id, "RZMoto.registerBike: id obrigatorio")
    def.fullType = def.fullType or ("Base." .. def.id)
    RZMoto.Bikes[def.id] = def

    -- spawn no mundo -------------------------------------------------------------------
    if VehicleZoneDistribution and def.spawn then
        for zone, chance in pairs(def.spawn) do
            VehicleZoneDistribution[zone] = VehicleZoneDistribution[zone] or {}
            VehicleZoneDistribution[zone].vehicles = VehicleZoneDistribution[zone].vehicles or {}
            VehicleZoneDistribution[zone].vehicles[def.fullType] = { index = -1, spawnChance = chance }
        end
    end
end

----------------------------------------------------------------------------------------
-- portas escondidas / pecas sem item
----------------------------------------------------------------------------------------

function RZMoto.Create.NoItem(vehicle, part)
    part:setInventoryItem(nil)
end

function RZMoto.Init.NoItem(vehicle, part)
    part:setInventoryItem(nil)
end

--- "Usar" a porta = sentar. Moto nao tem porta, mas o jogo roteia o clique por ela.
function RZMoto.Use.Door(vehicle, part, character)
    for seat = 0, vehicle:getMaxPassengers() - 1 do
        if vehicle:getPassengerDoor(seat) == part or vehicle:getPassengerDoor2(seat) == part then
            if not vehicle:getCharacter(seat) then
                ISVehicleMenu.onEnter(character, vehicle, seat)
            end
            break
        end
    end
end

----------------------------------------------------------------------------------------
-- containers (bau traseiro + alforjes)
----------------------------------------------------------------------------------------

--- Ao gerar a moto no mundo: o container nasce instalado com a chance "bagChance" (RZMotoConfig).
function RZMoto.Create.Bag(vehicle, part)
    local cfg = RZMoto.getConfig(vehicle)
    local chance = cfg and tonumber(cfg.bagChance) or 0
    if chance > 0 and ZombRand(100) < chance then
        VehicleUtils.createPartInventoryItem(part)
    else
        part:setInventoryItem(nil)
    end
end

--- Acesso ao container: so com o jogador FORA da moto e dentro da area da peca.
function RZMoto.ContainerAccess.Bag(vehicle, part, chr)
    if chr:getVehicle() then return false end
    if not vehicle:isInArea(part:getArea(), chr) then return false end
    return true
end

--- O assento de uma moto nao e um container.
function RZMoto.ContainerAccess.None(vehicle, part, chr)
    return false
end

----------------------------------------------------------------------------------------
-- rodas "falsas": pneus visiveis (RZMotoTireFront/Rear) <-> pneus reais escondidos (Tire*)
--
--  roda visivel   | pneus reais que acompanham
--  RZMotoTireFront | TireFrontLeft, TireFrontRight (eixo direcional)
--  RZMotoTireRear  | TireRearLeft, TireRearRight (eixo motriz)
--  Cada eixo acompanha somente seu pneu visivel, inclusive depois de carregar saves antigos.
----------------------------------------------------------------------------------------

-- BaseVehicle usa Tire<WheelId> na fisica, nao as pecas RZMotoTire*.
local function syncReal(vehicle, id, source)
    local real = vehicle:getPartById(id)
    if not real then return false end
    local sourceItem = source and source:getInventoryItem()
    local realItem = real:getInventoryItem()
    if not sourceItem then
        if not realItem then return false end
        real:setInventoryItem(nil)
        vehicle:transmitPartItem(real)
        if vehicle.setTireRemoved then vehicle:setTireRemoved(real:getWheelIndex(), true) end
        return true
    end

    local changed = false
    -- Mesmo tipo/skill evita atrito e capacidade aleatorios nos pneus de apoio.
    if not realItem or realItem:getFullType() ~= sourceItem:getFullType() then
        realItem = instanceItem(sourceItem:getFullType())
        if not realItem then return false end
        real:setInventoryItem(realItem, source:getMechanicSkillInstaller())
        changed = true
        vehicle:transmitPartItem(real)
    elseif real:getMechanicSkillInstaller() ~= source:getMechanicSkillInstaller() then
        real:setMechanicSkillInstaller(source:getMechanicSkillInstaller())
        vehicle:transmitPartItem(real)
        changed = true
    end
    if real:getCondition() ~= source:getCondition() then
        real:setCondition(source:getCondition())
        vehicle:transmitPartCondition(real)
        -- Na B42 o pacote item tambem dispara updatePartStats/Bullet no cliente.
        vehicle:transmitPartItem(real)
        changed = true
    end
    if real:getContainerContentAmount() ~= source:getContainerContentAmount() then
        -- Pressao vive em modData.contentAmount; condition nao a transmite.
        real:setContainerContentAmount(source:getContainerContentAmount(), true, true)
        vehicle:transmitPartModData(real)
        changed = true
    end
    if changed and vehicle.setTireRemoved then
        vehicle:setTireRemoved(real:getWheelIndex(), false)
    end
    return changed
end

local function reconcileWheels(vehicle)
    if isClient() then return end
    local front = vehicle:getPartById("RZMotoTireFront")
    local rear = vehicle:getPartById("RZMotoTireRear")
    local script = vehicle:getScript()
    local def = script and RZMoto.Bikes[script:getName()]
    local sidecar = def and def.sidecarWheel and vehicle:getPartById(def.sidecarWheel)
    local rearRight = rear
    if def and def.sidecarWheel then rearRight = sidecar end
    local changed = syncReal(vehicle, "TireFrontLeft", front)
    if syncReal(vehicle, "TireFrontRight", front) then changed = true end
    if syncReal(vehicle, "TireRearLeft", rear) then changed = true end
    -- Sidecar has its own tire; the normal two-wheel profiles retain both rear supports.
    if syncReal(vehicle, "TireRearRight", rearRight) then changed = true end
    if changed then
        vehicle:updatePartStats()
        -- Recalcula pressao/atrito para Bullet; VirtualVehicle implementa ambos como no-op.
        vehicle:updateBulletStats()
    end
end

function RZMoto.Create.HiddenTire(vehicle, part)
    if not isClient() then part:setInventoryItem(nil) end
end

function RZMoto.Init.Tires(vehicle, part)
    reconcileWheels(vehicle)
    -- No cliente, apenas inicializa Bullet a partir dos pneus recebidos do servidor.
    if vehicle.setTireRemoved then
        for _, id in ipairs({ "TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight" }) do
            local real = vehicle:getPartById(id)
            if real then vehicle:setTireRemoved(real:getWheelIndex(), real:getInventoryItem() == nil) end
        end
    end
end

function RZMoto.InstallComplete.TireFront(vehicle, part) reconcileWheels(vehicle) end
function RZMoto.InstallComplete.TireRear(vehicle, part) reconcileWheels(vehicle) end
function RZMoto.UninstallComplete.TireFront(vehicle, part, item) reconcileWheels(vehicle) end
function RZMoto.UninstallComplete.TireRear(vehicle, part, item) reconcileWheels(vehicle) end

-- Sobrescreve o update herdado de Tire: somente os dois pneus visiveis desgastam.
function RZMoto.Update.HiddenTire(vehicle, part, elapsedMinutes) end

local function updateWheel(vehicle, part, elapsedMinutes)
    if isClient() then return end
    local oldPressure = part:getContainerContentAmount()
    Vehicles.Update.Tire(vehicle, part, elapsedMinutes)
    if oldPressure ~= part:getContainerContentAmount() then vehicle:transmitPartModData(part) end
    reconcileWheels(vehicle)
end

function RZMoto.Update.TireFront(vehicle, part, elapsedMinutes) updateWheel(vehicle, part, elapsedMinutes) end
function RZMoto.Update.TireRear(vehicle, part, elapsedMinutes) updateWheel(vehicle, part, elapsedMinutes) end

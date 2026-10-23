-- Scooter eletrica: a carga persiste no proprio item removivel (DrainableComboItem).
require "RZMoto/RZMoto_Core"
RZMotoElectric = RZMotoElectric or {}
local E = RZMotoElectric
local lastSent = setmetatable({}, { __mode = "k" })

function E.isElectric(vehicle)
    local config = RZMoto.getConfig(vehicle)
    return config and tonumber(config.electric) == 1 or false
end

function E.charge(vehicle)
    local part = vehicle:getPartById("Battery")
    local item = part and part:getInventoryItem()
    if not item or part:getCondition() <= 0 then return 0 end
    return math.max(0, math.min(1, item:getCurrentUsesFloat()))
end

function E.syncGauge(vehicle, force)
    if isClient() or not E.isElectric(vehicle) then return end
    -- B42 exige GasTank para hasEnoughGasToRun. E apenas um espelho da carga,
    -- sem item, sem gasolina, sem rotinas de abastecimento ou consumo de combustivel.
    local gauge = vehicle:getPartById("GasTank")
    if not gauge then return end
    local charge = E.charge(vehicle)
    local amount = charge * gauge:getContainerCapacity()
    gauge:setContainerContentAmount(amount, false, true)
    local percent = math.floor(charge * 100)
    if force or lastSent[gauge] ~= percent then
        vehicle:transmitPartModData(gauge)
        lastSent[gauge] = percent
    end
    if charge <= 0 and vehicle:isEngineRunning() then vehicle:shutOff() end
end

function E.createGauge(vehicle, part)
    if isClient() then return end
    part:setCondition(100)
    E.syncGauge(vehicle, true)
end

function E.createBattery(vehicle, part)
    if isClient() then return end
    Vehicles.Create.Battery(vehicle, part)
    E.syncGauge(vehicle, true)
end

function E.changedBattery(vehicle, part)
    if isClient() then return end
    E.syncGauge(vehicle, true)
    vehicle:doDamageOverlay()
end

function E.checkEngine(vehicle, part)
    -- Tambem valida no servidor: adulterar o espelho nunca fornece energia.
    if not isClient() then E.syncGauge(vehicle, false) end
    return E.charge(vehicle) > 0
end

function E.updateBattery(vehicle, part, elapsedMinutes)
    if isClient() or not E.isElectric(vehicle) then return end
    local item = part:getInventoryItem()
    if item and elapsedMinutes > 0 and vehicle:isEngineRunning() then
        local before = item:getCurrentUsesFloat()
        local speed = math.min(math.abs(vehicle:getCurrentSpeedKmHour()) / 45, 2)
        -- ~6 horas do jogo a 45 km/h, com consumo pequeno quando ligada e parada.
        local after = math.max(0, before - elapsedMinutes * (1 / 7200 + speed / 360))
        item:setUsedDelta(after)
    end
    -- Luzes/sirene continuam obedecendo ao consumo padrao. Nao chamar Update.Battery:
    -- essa rotina vanilla recarrega pelo alternador, inexistente na scooter.
    Vehicles.Update.Lightbar(vehicle, part, elapsedMinutes)
    if item then
        local percent = math.floor(item:getCurrentUsesFloat() * 100)
        if lastSent[part] ~= percent then
            vehicle:transmitPartUsedDelta(part)
            lastSent[part] = percent
        end
    end
    E.syncGauge(vehicle, false)
end

-- Os menus vanilla filtram contentType=Gasoline. Bloqueamos tambem as mutacoes
-- das acoes compartilhadas/servidor, inclusive a tentativa de sifonar o espelho.
local function guardAction(class)
    if class.rzmElectricGuard then return end
    class.rzmElectricGuard = true
    for _, method in ipairs({ "isValid", "update", "complete", "serverStop", "serverStart" }) do
        local original = class[method]
        if original then
            class[method] = function(self, ...)
                local vehicle = self.vehicle or (self.part and self.part:getVehicle())
                if vehicle and E.isElectric(vehicle) then return false end
                return original(self, ...)
            end
        end
    end
end
require "Vehicles/TimedActions/ISAddGasolineToVehicle"
require "Vehicles/TimedActions/ISTakeGasolineFromVehicle"
require "Vehicles/TimedActions/ISRefuelFromGasPump"
guardAction(ISAddGasolineToVehicle)
guardAction(ISTakeGasolineFromVehicle)
guardAction(ISRefuelFromGasPump)

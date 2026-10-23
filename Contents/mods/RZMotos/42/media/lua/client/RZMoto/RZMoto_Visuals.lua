-- Animacao visual por instancia. Nao altera rodas fisicas, controles ou pacotes de rede.
require "RZMoto/RZMoto_Core"

RZMotoVisuals = RZMotoVisuals or {}
RZMotoVisuals.Cars = RZMotoVisuals.Cars or {}
local states = {}
local forward = Vector3f.new()
local wheelForward = Vector3f.new()
local DEG = 180 / math.pi
local TAU = 2 * math.pi
-- Bracos do piloto: o AnimSet mistura os clipes RZMoto_<perfil>_<estado>_SteerL / SteerR pelas variaveis
-- RZSteerX/RZSteerY (design/clean-rider/gen_rider.py). Valor >0 = guidao virado para a ESQUERDA do piloto.
local RIDER_STEER_FULL = 0.25  -- rad em que o braco chega ao clipe SteerL/R (mesmo --angle do gerador)
local RIDER_STEER_SIGN = 1     -- troque para -1 se os bracos virarem para o lado oposto ao do guidao
local RIDER_STEER_SMOOTH = 0.3 -- suavizacao por tick (0..1)
local dependencies = {
    WheelFront = "RZMotoTireFront", WheelRear = "RZMotoTireRear", WheelSidecar = "RZMotoTireSidecar", Fork = "SuspensionFrontLeft",
    BrakeFront = "BrakeFrontLeft", DiscFront = "BrakeFrontLeft", DiscRear = "BrakeRearLeft",
    FenderFront = "FenderFront", Headlight = "HeadlightLeft", Windshield = "Windshield",
}

-- O renderer usa Euler XYZ e inverte Y/Z nos modelos que nao sao rodas fisicas.
-- Combina a direcao sobre o eixo inclinado com a rotacao do aro em torno do eixo X.
function RZMotoVisuals.setPose(model, axis, steering, spin)
    local sh, ch = math.sin(-steering / 2), math.cos(-steering / 2)
    local sx, cx = math.sin(spin / 2), math.cos(spin / 2)
    local ax, ay, az = axis[1] * sh, axis[2] * sh, axis[3] * sh
    local x, y, z, w = ch * sx + ax * cx, ay * cx + az * sx,
        az * cx - ay * sx, ch * cx - ax * sx
    local eulerX = math.atan2(2 * (x*w - y*z), 1 - 2 * (x*x + y*y))
    local eulerY = math.asin(math.max(-1, math.min(1, 2 * (x*z + y*w))))
    local eulerZ = math.atan2(2 * (z*w - x*y), 1 - 2 * (y*y + z*z))
    model:getRotate():set(eulerX * DEG, -eulerY * DEG, -eulerZ * DEG)
end

local function makeState(vehicle, geometry)
    local part = vehicle:getPartById("RZMotoVisual")
    if not part then return nil end
    local original = part:getScriptPart()
    if not original then return nil end
    local lines = { "vehicle RZMotoVisualInstance { part RZMotoVisual { category=nodisplay," }
    for i = 0, original:getModelCount() - 1 do
        local model = original:getModel(i)
        local p = model:getOffset()
        lines[#lines+1] = string.format("model %s { file=%s, offset=%.9f %.9f %.9f, scale=%.9f, }",
            model:getId(), model:getFile(), p:x(), p:y(), p:z(), model:getScale())
    end
    lines[#lines+1] = "} }"
    local privateScript = VehicleScript.new()
    privateScript:setModule(vehicle:getScript():getModule())
    -- Sem Loaded(): apenas modelos visuais, sem registrar uma nova definicao no Bullet.
    privateScript:Load("RZMotoVisualInstance", table.concat(lines, "\n"))
    local own = privateScript:getPartById("RZMotoVisual")
    for i = 0, original:getModelCount() - 1 do
        part:setModelVisible(original:getModel(i):getId(), false)
    end
    part:setScriptPart(own)
    local state = { part=part, boundPart=own, sourceScript=vehicle:getScript(),
        script=privateScript, models={}, shown={}, geometry=geometry,
        x=vehicle:getX(), y=vehicle:getY(), frontSpin=0, rearSpin=0 }
    for i = 0, own:getModelCount() - 1 do
        local model = own:getModel(i)
        state.models[model:getId()] = model
    end
    states[vehicle] = state
    return state
end

function RZMotoVisuals.updateVehicle(vehicle, geometry)
    local state = states[vehicle]
    if state then
        local part = vehicle:getPartById("RZMotoVisual")
        -- setScript/scriptReloaded do motor troca o ScriptPart. Nao animar referencias antigas.
        if part ~= state.part or not part or part:getScriptPart() ~= state.boundPart
            or vehicle:getScript() ~= state.sourceScript or geometry ~= state.geometry then
            states[vehicle] = nil
            state = nil
        end
    end
    state = state or makeState(vehicle, geometry)
    if not state then return end
    vehicle:getForwardVector(forward)
    vehicle:getWheelForwardVector(0, wheelForward)
    local steering = math.atan2(forward:z()*wheelForward:x() - forward:x()*wheelForward:z(),
        forward:x()*wheelForward:x() + forward:z()*wheelForward:z())
    steering = math.max(-0.9, math.min(0.9, steering))
    local driver = vehicle:getDriver()
    if driver then
        local target = math.max(-1, math.min(1, RIDER_STEER_SIGN * steering / RIDER_STEER_FULL))
        state.riderSteer = (state.riderSteer or 0) + (target - (state.riderSteer or 0)) * RIDER_STEER_SMOOTH
        driver:setVariable("RZSteerX", state.riderSteer)
        driver:setVariable("RZSteerY", 1 - math.abs(state.riderSteer) - 0.02)   -- ponto fica na borda do triangulo de blend
    end
    local x, y = vehicle:getX(), vehicle:getY()
    local dx, dy = x-state.x, y-state.y
    local distance = math.sqrt(dx*dx + dy*dy)
    state.x, state.y = x, y
    if distance <= 3 then -- ignora saltos de posicao/teleportes e correcoes grandes de rede
        local sign = dx*forward:x() + dy*forward:z() < 0 and -1 or 1
        local scale = vehicle:getScript():getModelScale()
        state.frontSpin = (state.frontSpin + sign*distance/(geometry.frontRadius*scale)) % TAU
        state.rearSpin = (state.rearSpin + sign*distance/(geometry.rearRadius*scale)) % TAU
    end
    for id, model in pairs(state.models) do
        local source = dependencies[id] and vehicle:getPartById(dependencies[id])
        local visible = dependencies[id] == nil or (source ~= nil and source:getInventoryItem() ~= nil)
        if state.shown[id] ~= visible then
            state.part:setModelVisible(id, visible)
            state.shown[id] = visible
        end
        local spin = 0
        local angle = geometry.fixedModels and geometry.fixedModels[id] and 0 or steering
        if id == "WheelFront" or id == "DiscFront" then spin = state.frontSpin
        elseif id == "DiscRear" or id == "WheelRear" or id == "WheelSidecar" then spin = state.rearSpin; angle = 0 end
        RZMotoVisuals.setPose(model, geometry.steeringAxis, angle, spin)
    end
end

local function onTick()
    local cell = getCell()
    if not cell then return end
    local seen = {}
    local vehicles = cell:getVehicles()
    -- B42.21 retorna Set<BaseVehicle>, sem get(indice). Iterator tambem aceita List.
    local iterator = vehicles:iterator()
    while iterator:hasNext() do
        local vehicle = iterator:next()
        if RZMotoTrailer and RZMotoTrailer.updateVisuals then RZMotoTrailer.updateVisuals(vehicle) end
        local script = vehicle and vehicle:getScript()
        local def = script and RZMoto.Bikes[script:getName()]
        local geometry = def and def.visuals or (script and RZMotoVisuals.Cars[script:getName()])
        if geometry then
            seen[vehicle] = true
            RZMotoVisuals.updateVehicle(vehicle, geometry)
        end
    end
    for vehicle in pairs(states) do
        if not seen[vehicle] then states[vehicle] = nil end
    end
end

Events.OnTick.Add(onTick)
Events.OnGameStart.Add(onTick)

--[[
    RZ Motos - CORE: piloto (cliente)
    ---------------------------------
    Variaveis lidas pelos AnimSets de media/AnimSets/player-vehicle/*/rzmoto_*.xml:
      RZMotoRider    true enquanto o personagem esta numa moto do mod
      RZMotoProfile  perfil de animacao da moto (RZMotoConfig.profile)
      RZMotoMotion   ride | stop | back, calculado pela velocidade da propria moto
    Tudo e derivado do estado do veiculo que o jogo ja sincroniza. Por isso funciona igual
    para o jogador local e para os outros jogadores, sem comandos de rede.

    Tambem: subir/descer com as animacoes proprias (ancora "inside" durante a subida) e queda
    quando a moto perde velocidade de uma vez (batida).
]]

require "RZMoto/RZMoto_Core"

RZMotoAnim = RZMotoAnim or {}

local ANIM_TIMEOUT_MS = 2000   -- o clipe dura 1 s; garante o fim se o evento "End" se perder
local AVATAR_RANGE = 60        -- tiles: alem disso os outros jogadores nao sao animados aqui
local CRASH_WINDOW_MS = 300

local mounted = {}             -- personagem -> perfil aplicado
local crashWatch = {}          -- playerNum -> { vehicle, samples = { {ms, kph}, ... } }

local function motionFor(vehicle, info)
    local kph = vehicle:getCurrentSpeedKmHour()
    local dead = tonumber(info.motionDeadzone) or 1
    if kph > dead then return "ride" end
    if kph < -dead then return "back" end
    return "stop"
end

--- Aplica as variaveis do piloto. Chamar antes do inicio das acoes de subir/descer: o no de
--- animacao escolhido no primeiro quadro precisa ja ser o da moto.
function RZMotoAnim.apply(character, vehicle, info, seatOverride)
    local seat = seatOverride or vehicle:getSeat(character)
    local passenger = seat > 0 and info.passengerProfile
    local profile = tostring(passenger or info.profile or "")
    if profile == "" then return end
    if mounted[character] ~= profile then
        character:setVariable("RZMotoRider", true)
        character:setVariable("RZMotoProfile", profile)
        mounted[character] = profile
    end
    if passenger then
        character:setVariable("RZSteerX", 0)
        character:setVariable("RZSteerY", 1)
    end
    local motion = motionFor(vehicle, info)
    if character:getVariableString("RZMotoMotion") ~= motion then
        character:setVariable("RZMotoMotion", motion)
    end
    if tostring(info.hideHeldItems) == "1" and character:isLocalPlayer() then
        character:setHideWeaponModel(true)
    end
end

function RZMotoAnim.clear(character)
    if not mounted[character] then return end
    mounted[character] = nil
    character:clearVariable("RZMotoRider")
    character:clearVariable("RZMotoProfile")
    character:clearVariable("RZMotoMotion")
    character:clearVariable("RZSteerX")
    character:clearVariable("RZSteerY")
    if character:isLocalPlayer() then character:setHideWeaponModel(false) end
end

local function update(character)
    local vehicle = character:getVehicle()
    local info = vehicle and RZMoto.getConfig(vehicle)
    if info then
        RZMotoAnim.apply(character, vehicle, info)
    else
        RZMotoAnim.clear(character)
    end
    return vehicle, info
end

----------------------------------------------------------------------------------------
-- queda: perda brusca de velocidade com o piloto montado
----------------------------------------------------------------------------------------

local function eject(player, vehicle)
    -- Mesma sequencia da ISExitVehicle:perform vanilla, sem a animacao de descer.
    local seat = vehicle:getSeat(player)
    vehicle:exit(player)
    if seat >= 0 then vehicle:setCharacterPosition(player, seat, "outside") end
    triggerEvent("OnExitVehicle", player)
    RZMotoAnim.clear(player)
    player:setKnockedDown(true)
end

local function watchCrash(player, vehicle, info)
    local num = player:getPlayerNum()
    local drop = tonumber(info.crashSpeedDrop) or 0
    if drop <= 0 or not vehicle or not vehicle:isDriver(player) then
        crashWatch[num] = nil
        return
    end
    local now = getTimestampMs()
    local kph = math.abs(vehicle:getCurrentSpeedKmHour())
    local w = crashWatch[num]
    if not w or w.vehicle ~= vehicle then
        w = { vehicle = vehicle, samples = {} }
        crashWatch[num] = w
    end
    local samples = w.samples
    samples[#samples + 1] = { now, kph }
    while #samples > 1 and now - samples[1][1] > CRASH_WINDOW_MS do table.remove(samples, 1) end
    local fastest = 0
    for _, s in ipairs(samples) do fastest = math.max(fastest, s[2]) end
    if fastest - kph >= drop then
        crashWatch[num] = nil
        eject(player, vehicle)
    end
end

----------------------------------------------------------------------------------------
-- laco principal
----------------------------------------------------------------------------------------

local function onTick()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            local vehicle, info = update(player)
            if info then watchCrash(player, vehicle, info) else crashWatch[i] = nil end
        end
    end
    if not isClient() then return end
    local me = getPlayer()
    local online = getOnlinePlayers()
    if not me or not online then return end
    for i = 0, online:size() - 1 do
        local other = online:get(i)
        if other and not other:isLocalPlayer() then
            if math.abs(other:getX() - me:getX()) <= AVATAR_RANGE and math.abs(other:getY() - me:getY()) <= AVATAR_RANGE then
                update(other)
            else
                RZMotoAnim.clear(other)
            end
        end
    end
    -- jogadores que sairam do servidor
    for character in pairs(mounted) do
        if not character:isLocalPlayer() and not online:contains(character) then mounted[character] = nil end
    end
end

Events.OnTick.Add(onTick)

----------------------------------------------------------------------------------------
-- subir / descer (envolve as acoes vanilla; outros veiculos passam direto)
----------------------------------------------------------------------------------------

-- A moto tem portas escondidas so para o jogo saber de que lado subir. Nao ha porta a abrir.
local vanillaOnEnterAux = ISVehicleMenu.onEnterAux
function ISVehicleMenu.onEnterAux(playerObj, vehicle, seat)
    if RZMoto.isMoto(vehicle) then
        ISTimedActionQueue.add(ISEnterVehicle:new(playerObj, vehicle, seat))
        return
    end
    return vanillaOnEnterAux(playerObj, vehicle, seat)
end

local vanillaEnterStart = ISEnterVehicle.start
function ISEnterVehicle:start()
    local info = RZMoto.getConfig(self.vehicle)
    if info then RZMotoAnim.apply(self.character, self.vehicle, info, self.seat) end
    vanillaEnterStart(self)
    if not info then return end
    -- O vanilla so sobe a ate 2 tiles da posicao "outside". A moto e pequena: aceita ate 3
    -- tiles do centro, com as mesmas chamadas da subida vanilla.
    if self.character:getVehicle() ~= self.vehicle
        and self.character:DistTo(self.vehicle:getX(), self.vehicle:getY()) <= 3
        and self.vehicle:enter(self.seat, self.character) then
        self.action:setBlockMovementEtc(true)
        self.vehicle:playPassengerSound(self.seat, "enter")
        self.character:SetVariable("bEnteringVehicle", "true")
        self.character:triggerMusicIntensityEvent("VehicleEnter")
        local primary, secondary = self.character:getPrimaryHandItem(), self.character:getSecondaryHandItem()
        if (primary and primary:hasTag(ItemTag.HEAVY_ITEM)) or (secondary and secondary:hasTag(ItemTag.HEAVY_ITEM)) then
            if isClient() then
                sendClientCommand(self.character, "player", "onDropHeavyItem", { id = self.character:getOnlineID() })
            else
                forceDropHeavyItems(self.character)
            end
        end
    end
    if self.character:getVehicle() == self.vehicle then
        -- RZMoto_<perfil>_Mount comeca em pe ao lado da moto, a partir da ancora "inside".
        self.vehicle:setCharacterPosition(self.character, self.seat, "inside")
        self.rzStartMs = getTimestampMs()
    end
end

local vanillaEnterUpdate = ISEnterVehicle.update
function ISEnterVehicle:update()
    if self.rzStartMs then
        if self.character:GetVariable("EnterAnimationFinished") ~= "true"
            and getTimestampMs() - self.rzStartMs > ANIM_TIMEOUT_MS then
            self.character:SetVariable("EnterAnimationFinished", "true")
        end
        -- uma correcao de posicao da rede pode trazer a ancora "outside" de volta
        self.vehicle:setCharacterPosition(self.character, self.seat, "inside")
    end
    return vanillaEnterUpdate(self)
end

local vanillaExitStart = ISExitVehicle.start
function ISExitVehicle:start()
    local vehicle = self.character:getVehicle()
    local info = RZMoto.getConfig(vehicle)
    if info then
        RZMotoAnim.apply(self.character, vehicle, info)
        self.rzStartMs = getTimestampMs()
        -- Opt-in clips are authored relative to outside, not the raised seat.
        -- This keeps their final standing pose compatible with native exit.
        if info.exitAnchor == "outside" then
            self.rzExitVehicle = vehicle
            self.rzExitSeat = vehicle:getSeat(self.character)
        end
    end
    local result = vanillaExitStart(self)
    if self.rzExitVehicle and self.rzExitSeat >= 0 then
        vehicle:setCharacterPosition(self.character, self.rzExitSeat, "outside")
    end
    return result
end

local vanillaExitUpdate = ISExitVehicle.update
function ISExitVehicle:update()
    if self.rzExitVehicle and self.character:getVehicle() == self.rzExitVehicle then
        self.rzExitVehicle:setCharacterPosition(self.character, self.rzExitSeat, "outside")
    end
    if self.rzStartMs and self.character:GetVariable("ExitAnimationFinished") ~= "true"
        and getTimestampMs() - self.rzStartMs > ANIM_TIMEOUT_MS then
        self.character:SetVariable("ExitAnimationFinished", "true")
    end
    return vanillaExitUpdate(self)
end

local vanillaExitStop = ISExitVehicle.stop
function ISExitVehicle:stop()
    local result = vanillaExitStop(self)
    if self.rzExitVehicle and self.character:getVehicle() == self.rzExitVehicle then
        self.rzExitVehicle:setCharacterPosition(self.character, self.rzExitSeat, "inside")
    end
    return result
end

local vanillaExitPerform = ISExitVehicle.perform
function ISExitVehicle:perform()
    local result = vanillaExitPerform(self)
    RZMotoAnim.clear(self.character)
    return result
end

Events.OnCreatePlayer.Add(function(index)
    local player = getSpecificPlayer(index)
    if player then update(player) end
end)

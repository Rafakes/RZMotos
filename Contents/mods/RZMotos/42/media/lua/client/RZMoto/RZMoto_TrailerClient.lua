require "RZMoto/RZMoto_Trailer"
require "TimedActions/ISBaseTimedAction"
local T = RZMotoTrailer

local TrailerAction = ISBaseTimedAction:derive("RZMotoTrailerAction")
function TrailerAction:isValid()
    return T.near(self.character, self.trailer, T.REACH) and T.stopped(self.trailer)
        and (not self.bike or (T.near(self.character, self.bike, T.BIKE_REACH) and T.stopped(self.bike)))
end
function TrailerAction:update() self.character:faceThisObject(self.trailer) end
function TrailerAction:start() self:setActionAnim("Loot"); self.character:SetVariable("LootPosition", "Mid") end
function TrailerAction:perform()
    -- This is a local animation only. Commit is independently validated on the authority.
    T.request(self.character, self.command, self.args)
    ISBaseTimedAction.perform(self)
end
local function action(player, trailer, command, args, bike)
    local a = ISBaseTimedAction.new(TrailerAction, player)
    a.trailer = trailer; a.command = command; a.args = args; a.bike = bike
    a.stopOnWalk = true; a.stopOnRun = true; a.maxTime = 160
    ISTimedActionQueue.add(a)
end

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldobjects, test)
    if test then return end
    local p = getSpecificPlayer(playerNum)
    if not p or p:getVehicle() then return end
    local vehicles = getCell():getVehicles()
    local trailer, distance
    local iterator = vehicles:iterator()
    while iterator:hasNext() do
        local v = iterator:next()
        if T.isTrailer(v) and T.near(p, v, T.REACH) then
            local d = p:DistTo(v:getX(), v:getY())
            if not distance or d < distance then trailer = v; distance = d end
        end
    end
    if not trailer then return end
    local state = T.state(trailer); local count = 0
    for slot = 1, T.SLOTS do if state["slot" .. slot] then count = count + 1 end end
    local root = context:addOption(getText("IGUI_RZMotoTrailer_Menu", count))
    local menu = ISContextMenu:getNew(context); context:addSubMenu(root, menu)
    for slot = 1, T.SLOTS do
        local entry = state["slot" .. slot]
        if entry then
            local name = getText("IGUI_VehicleName" .. entry.script:gsub("^Base%.", ""))
            local option = menu:addOption(getText("IGUI_RZMotoTrailer_Unload", slot, name), p,
                action, trailer, "unload", { trailer = trailer:getId(), slot = slot })
            option.notAvailable = not T.stopped(trailer)
        end
    end
    if count < T.SLOTS then
        iterator = vehicles:iterator()
        while iterator:hasNext() do
            local v = iterator:next()
            if T.compatible(v) and T.near(p, v, T.BIKE_REACH)
                and p:DistTo(v:getX(), v:getY()) <= T.BIKE_REACH
                and T.distance(v, trailer) <= T.BIKE_REACH then
                local option = menu:addOption(getText("IGUI_RZMotoTrailer_Load", getText("IGUI_VehicleName" .. v:getScript():getName())), p,
                    action, trailer, "load", { trailer = trailer:getId(), bike = v:getId() }, v)
                option.notAvailable = not T.stopped(trailer) or not T.stopped(v) or v:isEngineRunning() or v:getDriver() ~= nil
            end
        end
    end
end)

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= T.MODULE or command ~= "result" or type(args) ~= "table" then return end
    if type(args.key) ~= "string" then return end
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p and p:getOnlineID() == args.player then p:Say(getText("IGUI_RZMotoTrailer_" .. args.key)); break end
    end
end)

-- Reuse the actual installed motorcycle meshes/materials. Private scripts per trailer
-- avoid changing the shared vehicle definition or rendering the same cargo on every trailer.
local rendered = setmetatable({}, { __mode = "k" })
local dependencies = {
    WheelFront = "RZMotoTireFront", DiscFront = "BrakeFrontLeft", WheelRear = "RZMotoTireRear",
    DiscRear = "BrakeRearLeft", Fork = "SuspensionFrontLeft", BrakeFront = "BrakeFrontLeft",
    FenderFront = "FenderFront", Headlight = "HeadlightLeft", Windshield = "Windshield",
}
local function signature(state)
    local keys = { tostring(state.revision or 0) }
    for slot = 1, T.SLOTS do
        local s = state["slot" .. slot]
        if s then
            keys[#keys + 1] = tostring(slot) .. s.script .. ":" .. tostring(s.skin or 0)
        end
    end
    return table.concat(keys, ";")
end

local function rebuild(trailer, state, key, old)
    local part = trailer:getPartById("RZMotoCargoVisual")
    if not part then return end
    if old and part:getScriptPart() == old.bound then
        for i = 0, old.bound:getModelCount() - 1 do part:setModelVisible(old.bound:getModel(i):getId(), false) end
    end
    local lines = { "vehicle RZMotoCargoInstance { part RZMotoCargoVisual { category=nodisplay," }
    local number = 0
    for slot = 1, T.SLOTS do
        local entry = state["slot" .. slot]
        local script = entry and ScriptManager.instance:getVehicle(entry.script)
        if script then
            local ratio = script:getModelScale() / trailer:getScript():getModelScale()
            local x = (slot == 1 and -T.TRACK or T.TRACK) / trailer:getScript():getModelScale()
            local y = T.DECK / trailer:getScript():getModelScale()
            local function model(m, main)
                if not m or m:getFile() == "RZ_NullModel" then return end
                -- The normal vehicle shader binds the trailer skin for every sub-model.
                -- These aliases preserve the bike atlas with a shader matching the static FBX UV layout.
                local file = "RZ_TR_Cargo_" .. script:getName() .. "_" .. tostring(entry.skin or 0)
                    .. "_" .. m:getFile():gsub("^Base%.", "")
                number = number + 1; local p = m:getOffset()
                lines[#lines + 1] = string.format("model C%d { file=%s, offset=%.9f %.9f %.9f, scale=%.9f, }",
                    number, file, x + (main and 0 or p:x()*ratio),
                    y + (main and 0 or p:y()*ratio), 0.13 + (main and 0 or p:z()*ratio),
                    (main and 1 or m:getScale())*ratio)
            end
            model(script:getModel(), true)
            for i = 0, script:getPartCount() - 1 do
                local sp = script:getPart(i); local id = sp:getId()
                if entry.installed[id] or id == "RZMotoVisual" then
                    for j = 0, sp:getModelCount() - 1 do
                        local m = sp:getModel(j); local dep = id == "RZMotoVisual" and dependencies[m:getId()]
                        if not dep or entry.installed[dep] then model(m) end
                    end
                end
            end
        end
    end
    lines[#lines + 1] = "} }"
    local script = VehicleScript.new(); script:setModule(trailer:getScript():getModule())
    script:Load("RZMotoCargoInstance", table.concat(lines, "\n"))
    local bound = script:getPartById("RZMotoCargoVisual"); part:setScriptPart(bound)
    for i = 0, bound:getModelCount() - 1 do part:setModelVisible(bound:getModel(i):getId(), true) end
    rendered[trailer] = { key = key, script = script, bound = bound }
end

-- Called by the existing RZMoto_Visuals loop; no second vehicle scan/network polling.
function T.updateVisuals(v)
    if not T.isTrailer(v) then return end
    local state = T.state(v); local key = signature(state); local old = rendered[v]
    if not old or old.key ~= key or v:getPartById("RZMotoCargoVisual"):getScriptPart() ~= old.bound then
        rebuild(v, state, key, old)
    end
end

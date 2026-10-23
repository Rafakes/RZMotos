if isClient() then return end
require "RZMoto/RZMoto_Trailer"
local T = RZMotoTrailer
local cooldown = setmetatable({}, { __mode = "k" })
local busy = {}

local function copy(value, depth, seen)
    local kind = type(value)
    if kind == "nil" or kind == "string" or kind == "boolean" or kind == "number" then return value end
    assert(kind == "table" and (depth or 0) < 24, "Unsupported persistent motorcycle data")
    seen = seen or {}; assert(not seen[value], "Cyclic motorcycle data"); seen[value] = true
    local result = {}
    for k, v in pairs(value) do
        assert(type(k) == "number" or type(k) == "string", "Unsupported data key")
        result[k] = copy(v, (depth or 0) + 1, seen)
    end
    seen[value] = nil
    return result
end

local function replace(target, source)
    for k in pairs(target) do target[k] = nil end
    for k, v in pairs(source or {}) do target[k] = copy(v) end
end

local function feedback(player, key)
    if isServer() then sendServerCommand(player, T.MODULE, "result", { key = key, player = player:getOnlineID() })
    else player:Say(getText("IGUI_RZMotoTrailer_" .. key)) end
end

local function vault(v, slot)
    local p = v:getPartById("RZMotoVault" .. slot)
    return p and p:getItemContainer(), p
end

local function canUse(player, keyId, hotwired)
    return hotwired or player:getAccessLevel() == "admin"
        or player:getInventory():haveThisKeyId(keyId) ~= nil
end

local function publish(v)
    local state, part = T.state(v)
    state.revision = (state.revision or 0) + 1
    local mass = 250
    for slot = 1, T.SLOTS do
        local s = state["slot" .. slot]
        if s then
            mass = mass + s.mass
            if s.skin == nil then
                local _, vaultPart = vault(v, slot)
                local manifest = vaultPart and vaultPart:getModData().manifest
                s.skin = manifest and manifest.skin or 0
            end
        end
    end
    -- Native updateTotalMass also counts the actual packed items in both vaults.
    v:setInitialMass(math.max(1, mass - v:getTotalContainerItemWeight()))
    v:updateTotalMass()
    v:transmitPartModData(part)
end

-- Keep actual InventoryItems in native vehicle containers, never flatten them to type/condition.
-- Their fluid contents, battery charge, nested bags and item modData use native persistence.
local function capture(bike)
    local s = {
        version = 1, script = bike:getScriptName(), key = bike:getKeyId(),
        hotwired = bike:isHotwired(), hotwiredBroken = bike:isHotwiredBroken(),
        skin = bike:getSkinIndex(), rust = bike:getRust(),
        hue = bike:getColorHue(), saturation = bike:getColorSaturation(), value = bike:getColorValue(),
        quality = bike:getEngineQuality(), loudness = bike:getEngineLoudness(), power = bike:getEnginePower(),
        mass = bike:getMass(), modData = copy(bike:getModData()), parts = {},
        alarmed = bike:isAlarmed(), trunkLocked = bike:isTrunkLocked(), blood = {},
        headlights = bike:getHeadlightsOn(),
    }
    local items, indices, moves, ids = {}, {}, {}, {}
    local function index(item, container)
        if not item then return nil end
        if indices[item] then return indices[item] end
        assert(not ids[item:getID()], "Duplicate persistent item ID")
        ids[item:getID()] = true
        local n = #items + 1; items[n] = item; indices[item] = n
        moves[n] = container
        return n
    end
    for _, side in ipairs({"Front", "Rear", "Left", "Right"}) do s.blood[side] = bike:getBloodIntensity(side) end
    for i = 0, bike:getPartCount() - 1 do
        local p = bike:getPartByIndex(i)
        local q = {
            id = p:getId(), item = index(p:getInventoryItem()), condition = p:getCondition(),
            skill = p:getMechanicSkillInstaller(), data = copy(p:getModData()),
            amount = p:getContainerContentAmount(), capacity = p:getContainerCapacity(),
            friction = p:getWheelFriction(), damping = p:getSuspensionDamping(),
            compression = p:getSuspensionCompression(), durability = p:getDurability(),
            loudness = p:getEngineLoudness(), items = {},
        }
        local c = p:getItemContainer()
        if p:getDeviceData() then
            -- A native Radio item serializes the complete DeviceData (including presets/media).
            -- Use a separate hidden carrier so the installed item's own data is untouched.
            local carrier = assert(instanceItem("Base.RadioBlack"), "Radio state carrier unavailable")
            carrier:setDeviceData(p:getDeviceData():getClone())
            carrier:getDeviceData():setParent(carrier)
            q.radio = index(carrier)
        end
        if c then
            q.explored = c:isExplored()
            for j = 0, c:getItems():size() - 1 do q.items[#q.items + 1] = index(c:getItems():get(j), c) end
        end
        local door = p:getDoor()
        if door then q.door = { open = door:isOpen(), locked = door:isLocked(), broken = door:isLockBroken() } end
        local window = p:getWindow()
        if window then q.window = window:getOpenDelta() end
        s.parts[#s.parts + 1] = q
    end
    s.itemCount = #items
    s.itemIds = {}
    for n, item in ipairs(items) do s.itemIds[n] = item:getID() end
    return s, items, moves
end

local function restore(bike, s, items)
    assert(s.version == 1 and s.itemCount == #items, "Invalid cargo manifest")
    -- Native installed parts have no inventory container. Bags get their new owner below.
    -- The vault's list remains an independent recovery reference until the final commit.
    for _, item in ipairs(items) do item:setContainer(nil) end
    bike:setKeyId(s.key); bike:setHotwired(s.hotwired); bike:setHotwiredBroken(s.hotwiredBroken)
    bike:setSkinIndex(s.skin); bike:setRust(s.rust); bike:setColorHSV(s.hue, s.saturation, s.value)
    bike:setEngineFeature(s.quality, s.loudness, s.power)
    bike:setAlarmed(s.alarmed); bike:setTrunkLocked(s.trunkLocked)
    bike:setHeadlightsOn(s.headlights)
    -- Transported motorcycles are already used vehicles, not fresh random spawns.
    -- Only exposed methods are available to Lua; Java fields cannot be assigned here.
    bike:setPreviouslyEntered(true); bike:setPreviouslyMoved(true)
    replace(bike:getModData(), s.modData)
    for side, amount in pairs(s.blood) do bike:setBloodIntensity(side, amount) end
    -- Discard newly generated loot before applying the saved motorcycle.
    for i = 0, bike:getPartCount() - 1 do
        local p = bike:getPartByIndex(i); local c = p:getItemContainer()
        if c then c:removeAllItems() end
        p:setInventoryItem(nil)
    end
    for _, q in ipairs(s.parts) do
        local p = assert(bike:getPartById(q.id), "Saved motorcycle part missing: " .. q.id)
        p:setInventoryItem(q.item and assert(items[q.item]), q.skill)
        if q.radio then
            p:setDeviceData(assert(items[q.radio]):getDeviceData():getClone())
            p:getDeviceData():setParent(p)
        end
        p:setCondition(q.condition); replace(p:getModData(), q.data)
        p:setWheelFriction(q.friction); p:setSuspensionDamping(q.damping)
        p:setSuspensionCompression(q.compression); p:setDurability(q.durability); p:setEngineLoudness(q.loudness)
        p:setContainerCapacity(q.capacity)
        p:setContainerContentAmount(q.amount, true, true)
        local c = p:getItemContainer()
        if c then
            c:setExplored(q.explored)
            for _, n in ipairs(q.items) do
                local item = assert(items[n])
                -- AddItem automatically removes an item from its old container in B42.
                -- Keep the vault list intact until commit, so failure remains recoverable.
                item:setContainer(nil)
                assert(c:AddItem(item) == item, "Unable to restore original baggage")
            end
        else assert(#q.items == 0, "Saved container missing") end
        if q.door then
            local door = assert(p:getDoor()); door:setOpen(q.door.open)
            door:setLocked(q.door.locked); door:setLockBroken(q.door.broken)
            bike:transmitPartDoor(p)
        end
        if q.window then p:getWindow():setOpenDelta(q.window); bike:transmitPartWindow(p) end
        bike:transmitPartItem(p); bike:transmitPartCondition(p); bike:transmitPartModData(p)
    end
    bike:updatePartStats(); bike:updateBulletStats(); bike:updateTotalMass()
    bike:transmitEngine(); bike:transmitRust(); bike:transmitColorHSV(); bike:transmitSkinIndex(); bike:transmitBlood()
end

local function summary(s)
    local installed = {}
    for _, q in ipairs(s.parts) do if q.item then installed[q.id] = true end end
    return { script = s.script, skin = s.skin, installed = installed, mass = s.mass }
end

local function loadBike(player, trailer, args)
    local id = tonumber(args.bike)
    if not id or id ~= math.floor(id) or id < -32768 or id > 32767 then return end
    local bike = getVehicleById(id)
    if not T.compatible(bike) then feedback(player, "Unsupported"); return end
    if not T.near(player, bike, T.BIKE_REACH)
        or T.distance(bike, trailer) > T.BIKE_REACH then feedback(player, "Denied"); return end
    if not T.stopped(bike) or bike:isEngineRunning() or bike:getCurrentKey()
        or bike:isKeysInIgnition() or bike:isKeyIsOnDoor()
        or bike:getVehicleTowedBy() or bike:getVehicleTowing() then feedback(player, "Busy"); return end
    for i = 0, bike:getMaxPassengers() - 1 do if bike:getCharacter(i) then feedback(player, "Busy"); return end end
    if not canUse(player, bike:getKeyId(), bike:isHotwired()) then feedback(player, "Denied"); return end
    local state = T.state(trailer)
    local slot
    for i = 1, T.SLOTS do if not state["slot" .. i] then slot = i; break end end
    if not slot then feedback(player, "Full"); return end
    local c, part = vault(trailer, slot)
    if not c or c:getItems():size() ~= 0 or part:getModData().manifest then feedback(player, "Missing"); return end
    -- Validate/copy the entire manifest before touching the live motorcycle.
    local ok, s, items, moves = pcall(capture, bike)
    if not ok then print("[RZMotoTrailer] capture rejected: " .. tostring(s)); feedback(player, "Failed"); return end
    local moved = 0
    ok, s = pcall(function()
        local manifest = s
        part:getModData().manifest = manifest
        for n, item in ipairs(items) do
            moved = n
            if moves[n] then moves[n]:Remove(item) end
            assert(c:AddItem(item) == item, "Unable to store original item")
        end
        -- The authoritative snapshot exists before deleting the source vehicle.
        state["slot" .. slot] = summary(manifest)
        bike:permanentlyRemove()
        publish(trailer)
        print("[RZMotoTrailer] loaded " .. manifest.script .. " rail=" .. slot .. " player=" .. player:getUsername())
    end)
    if not ok then
        if not bike:isRemovedFromWorld() then
            for n = 1, moved do c:Remove(items[n]); if moves[n] then moves[n]:AddItem(items[n]) end end
            part:getModData().manifest = nil; state["slot" .. slot] = nil
        end
        -- Once removed, retain manifest AND items; never erase the sole saved copy.
        print("[RZMotoTrailer] load interrupted: " .. tostring(s)); feedback(player, "Failed")
    end
end

local function unloadPosition(trailer, script)
    local ext = script:getExtents()
    local halfWidth = math.max(0.7, ext:x() * script:getModelScale() / 2 + 0.2)
    local halfLength = math.max(1.3, ext:z() * script:getModelScale() / 2 + 0.25)
    local center = -(trailer:getScript():getExtents():z() * trailer:getScript():getModelScale() / 2 + halfLength + 0.8)
    local z = math.floor(trailer:getZ())
    local squares = {}
    for x = -halfWidth, halfWidth + 0.1, 0.35 do
        for y = -halfLength, halfLength + 0.1, 0.35 do
            local pos = trailer:getWorldPos(x, 0, center + y, Vector3f.new())
            local sq = getCell():getGridSquare(math.floor(pos:x()), math.floor(pos:y()), z)
            if not sq or not sq:TreatAsSolidFloor() or not sq:isFree(false)
                or sq:isSolid() or sq:isSolidTrans() then return nil end
            squares[sq] = true
        end
    end
    local vehicles = getCell():getVehicles()
    for sq in pairs(squares) do
        for _, delta in ipairs({{1,0},{0,1}}) do
            local adjacent = getCell():getGridSquare(sq:getX()+delta[1], sq:getY()+delta[2], z)
            if adjacent and squares[adjacent] and sq:isBlockedTo(adjacent) then return nil end
        end
    end
    local iterator = vehicles:iterator()
    while iterator:hasNext() do
        local other = iterator:next()
        if other ~= trailer then
            for sq in pairs(squares) do if other:isIntersectingSquare(sq) then return nil end end
        end
    end
    return trailer:getWorldPos(0, 0, center, Vector3f.new())
end

local function unloadBike(player, trailer, args)
    local slot = tonumber(args.slot)
    if slot ~= 1 and slot ~= 2 then return end
    local state = T.state(trailer); local entry = state["slot" .. slot]
    if not entry then return end
    local c, part = vault(trailer, slot); local s = part and part:getModData().manifest
    if not s or not c or c:getItems():size() ~= s.itemCount or s.script ~= entry.script then feedback(player, "Missing"); return end
    if not canUse(player, s.key, s.hotwired) then feedback(player, "Denied"); return end
    local script = ScriptManager.instance:getVehicle(s.script)
    if not script then feedback(player, "Missing"); return end
    local pos = unloadPosition(trailer, script)
    if not pos then feedback(player, "Blocked"); return end
    local sq = getCell():getGridSquare(math.floor(pos:x()), math.floor(pos:y()), math.floor(trailer:getZ()))
    -- Native CompressIdenticalItems may reorder items on disk. Match persistent IDs, not positions.
    local byId, items = {}, {}
    for i = 0, c:getItems():size() - 1 do local item = c:getItems():get(i); byId[item:getID()] = item end
    for n, id in ipairs(s.itemIds or {}) do
        if not byId[id] then feedback(player, "Missing"); return end
        items[n] = byId[id]
    end
    if #items ~= s.itemCount then feedback(player, "Missing"); return end
    local bike
    local ok, result = pcall(function()
        bike = addVehicleDebug(s.script, trailer:getDir(), s.skin, sq)
        -- addedToWorld is a Java instance field, not a Lua-exposed property.
        -- Only a successful native spawn is registered in VehicleManager.
        if not T.isSpawned(bike) then return false end
        restore(bike, s, items)
        assert(RZMoto.parkUpright(bike, trailer:getAngleY(), math.floor(trailer:getZ())), "Unable to place motorcycle")
        local transform = BaseVehicle.allocTransform(); bike:getWorldTransform(transform)
        local origin = transform:getOrigin()
        -- Move by the exact sub-tile offset from the native spawn-square centre.
        origin:set(origin:x() + pos:x() - bike:getX(), origin:y(), origin:z() + pos:y() - bike:getY())
        bike:setWorldTransform(transform); BaseVehicle.releaseTransform(transform)
        return true
    end)
    if not ok or not result then
        if bike then bike:permanentlyRemove() end
        for _, item in ipairs(items) do item:setContainer(c) end
        if ok then feedback(player, "Blocked")
        else print("[RZMotoTrailer] unload interrupted; vault retained: " .. tostring(result)); feedback(player, "Failed") end
        return
    end
    -- Commit only after a complete restore. clear() leaves the new item container pointers intact.
    c:getItems():clear(); part:getModData().manifest = nil; state["slot" .. slot] = nil
    publish(trailer)
    print("[RZMotoTrailer] unloaded " .. s.script .. " rail=" .. slot .. " player=" .. player:getUsername())
end

function T.handle(command, player, args)
    if command ~= "load" and command ~= "unload" then return end
    if not player or type(args) ~= "table" then return end
    local now = getTimestampMs()
    if cooldown[player] and now - cooldown[player] < 1500 then return end
    cooldown[player] = now
    local id = tonumber(args.trailer)
    if not id or id ~= math.floor(id) or id < -32768 or id > 32767 then return end
    local trailer = getVehicleById(id)
    if not T.isTrailer(trailer) or not T.near(player, trailer, T.REACH) then feedback(player, "Denied"); return end
    if not T.stopped(trailer) then feedback(player, "Busy"); return end
    if busy[trailer] then return end
    busy[trailer] = true
    local ok, err = pcall(command == "load" and loadBike or unloadBike, player, trailer, args)
    busy[trailer] = nil
    if not ok then print("[RZMotoTrailer] command failed: " .. tostring(err)); feedback(player, "Failed") end
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module == T.MODULE then T.handle(command, player, args) end
end)

-- Called by native part initialization after a save/chunk/reconnect load, without a polling loop.
T.refreshMass = publish

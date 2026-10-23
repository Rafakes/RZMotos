--[[
    RZ Motos - CORE: janela de loot montado
    ---------------------------------------
    Montado na moto, a janela de loot pode ficar sem nenhum container: o banco da moto nao e
    container e os baus so abrem a pe. O ISInventoryPage vanilla (refreshBackpacks e update) le
    self.backpacks[#self.backpacks] sem checar a lista vazia e gera erro a cada quadro.
    So nesse caso a janela recebe um container vazio de capacidade zero (nada pode ser
    colocado nele) com o nome "Moto".
]]

require "RZMoto/RZMoto_Core"

local placeholders = {}

local function placeholder(playerNum)
    local container = placeholders[playerNum]
    if not container then
        container = ItemContainer.new("RZMotoSeat", nil, nil)
        container:setExplored(true)
        container:setCapacity(0)
        placeholders[playerNum] = container
    end
    return container
end

local function needsPlaceholder(page)
    if page.onCharacter or #page.backpacks > 0 then return false end
    local player = getSpecificPlayer(page.player)
    return player ~= nil and RZMoto.isMoto(player:getVehicle())
end

Events.OnRefreshInventoryWindowContainers.Add(function(page, stage)
    if stage ~= "buttonsAdded" or not needsPlaceholder(page) then return end
    local name = getText("IGUI_RZMoto_Motorcycle")
    page:addContainerButton(placeholder(page.player), nil, name, name)
end)

-- update() pode rodar antes do primeiro refresh depois de montar.
local function patchUpdate()
    if not ISInventoryPage or ISInventoryPage.rzMotoUpdate then return end
    local vanillaUpdate = ISInventoryPage.update
    ISInventoryPage.rzMotoUpdate = true
    function ISInventoryPage:update()
        if needsPlaceholder(self) then self:refreshBackpacks() end
        return vanillaUpdate(self)
    end
end

patchUpdate()
Events.OnGameStart.Add(patchUpdate)

--[[
    RZ Motos - painel da moto: layout e leitura de estado
    -----------------------------------------------------
    Fonte unica de geometria, cores, pictogramas e predicados dos indicadores. Nada aqui
    desenha: RZMoto_Dash.lua le estas tabelas e pinta. Separar os dois significa que
    trocar a arte depois (PNG no lugar das primitivas) nao mexe na logica de estado.

    Todas as medidas sao do CANVAS BASE (antes da escala escolhida pelo jogador) e
    multiplas de 4, como o resto da UI do projeto. O tamanho do canvas e DERIVADO
    das constantes: nao existe coordenada magica neste arquivo.

    Paleta: o painel e um instrumento, nao um widget. As cores dos avisos seguem a
    convencao de moto (verde = ativo, vermelho = falha, azul = sirene) em vez da cor
    de acento da UI, que fica reservada ao ponteiro, ao hover e ao menu de contexto.
]]

require "RZMoto/RZMoto_Core"

RZMotoDash = RZMotoDash or {}
RZMotoDash.L = {}
local L = RZMotoDash.L

----------------------------------------------------------------------------------------
-- grade
----------------------------------------------------------------------------------------
L.PAD = 16
L.GAP = 16
L.PANEL_RADIUS = 16

-- mostrador
L.DIAL_R      = 80   -- borda externa do aro
L.BEZEL_W     = 4    -- aro metalico em volta do fundo
L.SCALE_R     = 70   -- borda externa do arco da escala
L.DIAL_RING   = 3    -- espessura do arco da escala
L.TICK_MAJOR  = 10
L.TICK_MINOR  = 5
L.NEEDLE_LEN  = 64
L.NEEDLE_TAIL = 10   -- contrapeso atras do cubo, em cor escura
L.NEEDLE_HALF = 3    -- meia largura na base
L.HUB_R       = 6
L.NEEDLE_PEG_DEG   = 8    -- pino de repouso abaixo do zero (o ponteiro nao risca o "0")
L.DIAL_LABEL_INSET = 10   -- recuo do numero da escala para dentro do traco maior
L.DIAL_UNIT_R      = 22   -- centro do rotulo da unidade, acima do cubo
L.READOUT_PAD      = 4    -- folga lateral dos digitos na janela da velocidade
L.READOUT_INSET    = 3    -- distancia minima entre a janela e a borda do fundo

-- 0 grau = 12 horas, positivo = sentido horario. 240 graus deixam a base do mostrador
-- livre para a leitura digital: os numeros das pontas (0 e o maximo) ficam fora da
-- janela, o que com 270 graus nao acontecia.
L.DIAL_START_DEG = -120
L.DIAL_SWEEP_DEG = 240

-- luzes de aviso
L.LAMP_W      = 32
L.LAMP_H      = 24
L.LAMP_GAP    = 8
L.LAMP_RADIUS = 4
L.ICON_GRID   = 16   -- os pictogramas sao desenhados numa grade 16x16
L.ICON_MARGIN = 4    -- folga entre pictograma e borda do vidro (em cima e embaixo)

-- janela LCD da coluna direita
L.LCD_RADIUS = 8
L.LCD_PAD    = 8
L.ROW_COUNT  = 4     -- rpm, combustivel, marcha/cruise, status
L.BAR_H      = 12

-- Barras segmentadas. Os pares (contagem, largura) foram escolhidos para as duas
-- fecharem exatamente na mesma largura: 10*12 + 9*4 = 8*16 + 7*4 = 156.
-- Ja foram 188 de largura; encolheram para dar 92 px a coluna de rotulos. "MARCHA"
-- mede 72 px na fonte Small do jogo, e com 60 px o rotulo vazava para fora do LCD.
L.SEG_GAP    = 4
L.RPM_SEGS   = 10
L.RPM_SEG_W  = 12
L.RPM_RED    = 2   -- ultimos segmentos = zona vermelha
L.FUEL_SEGS  = 8
L.FUEL_SEG_W = 16
L.FUEL_RED   = 2   -- primeiros segmentos = reserva

----------------------------------------------------------------------------------------
-- cores
----------------------------------------------------------------------------------------
L.COL_PANEL    = { r = 0.06, g = 0.06, b = 0.07 }   -- carcaca
L.COL_FACE     = { r = 0.03, g = 0.03, b = 0.035 }  -- fundo do mostrador
L.COL_LCD      = { r = 0.04, g = 0.05, b = 0.045 }  -- fundo das janelas LCD
L.COL_WINDOW   = { r = 0.03, g = 0.03, b = 0.035 }  -- vidro de cada luz de aviso
L.COL_BEZEL_HI = { r = 0.46, g = 0.46, b = 0.48 }   -- aro no topo (luz vem de cima)
L.COL_BEZEL_LO = { r = 0.14, g = 0.14, b = 0.15 }   -- aro na base
L.COL_BORDER   = { r = 0.40, g = 0.40, b = 0.40 }
L.COL_TEXT     = { r = 1.00, g = 1.00, b = 1.00 }
L.COL_LABEL    = { r = 0.70, g = 0.70, b = 0.70 }
L.COL_OFF      = { r = 0.20, g = 0.20, b = 0.22 }   -- pictograma apagado
L.COL_GHOST    = { r = 0.09, g = 0.09, b = 0.08 }   -- segmento de LCD sem energia
L.COL_ACCENT   = { r = 0.95, g = 0.50, b = 0.10 }   -- ponteiro, hover e menu
L.COL_GLOW     = { r = 1.00, g = 0.62, b = 0.18 }   -- luz de fundo do painel (ambar)

-- tons das luzes de aviso
L.TONES = {
    ok   = { r = 0.25, g = 0.95, b = 0.35 },
    warn = { r = 0.95, g = 0.22, b = 0.18 },
    info = { r = 0.25, g = 0.55, b = 1.00 },
}

----------------------------------------------------------------------------------------
-- escalas e tempos
----------------------------------------------------------------------------------------
L.MPH_PER_KMH   = 0.621371
L.RPM_MAX       = 7000
L.FUEL_LOW      = 0.20  -- abaixo disso acende a luz de reserva
L.NEEDLE_SMOOTH = 0.20  -- fracao de aproximacao por quadro a 30 fps
L.GLOW_FADE     = 0.12  -- crossfade da luz de fundo (lento: filamento aquecendo)
L.GLOW_NIGHT    = 0.30  -- brilho de fundo a noite com o farol apagado
L.CHECK_DUR     = 1.2   -- segundos do teste de lampadas ao girar a chave

-- Noite pela hora do jogo. O painel tambem acende com o farol ligado de dia, mas e
-- a noite que ele precisa estar legivel sozinho.
function L.isNight()
    local gt = getGameTime()
    if not gt then return false end
    local h = gt:getHour()
    return h >= 18 or h < 6
end

----------------------------------------------------------------------------------------
-- leitura de estado do veiculo (tudo tolerante a peca ausente)
----------------------------------------------------------------------------------------

--- A moto e eletrica? Le o RZMotoConfig direto para nao depender de RZMotoElectric.
function L.isElectric(vehicle)
    local cfg = RZMoto.getConfig(vehicle)
    return (cfg and tonumber(cfg.electric) == 1) or false
end

--- "empty" | "in" | "on" | "hotwired"
function L.keyState(vehicle)
    if not vehicle then return "empty" end
    if vehicle:isHotwired() then return "hotwired" end
    if vehicle:isEngineRunning() or vehicle:isStarting() then return "on" end
    if vehicle:isKeysInIgnition() then return "in" end
    return "empty"
end

--- Motor sem falha. Usa o checkEngineFull vanilla do proprio dashboard.
function L.engineOk(dash)
    local ok, res = pcall(function() return dash:checkEngineFull() end)
    if not ok then return true end
    return res ~= false
end

--- A moto esta "acordada"? Fora disso os dados do tanque nao sao confiaveis: com a
--- moto desligada o GasTank devolve valor nao representativo, principalmente em MP.
function L.isAwake(vehicle)
    return vehicle ~= nil and (vehicle:isEngineRunning() or vehicle:isKeysInIgnition())
end

--- Fracao 0..1 do tanque (ou da carga, na eletrica, onde o GasTank e espelho).
function L.fuelRatio(vehicle, gasTank)
    if not gasTank then return 0 end
    local ok, ratio = pcall(function()
        local cap = gasTank:getContainerCapacity()
        if not cap or cap <= 0 then return 0 end
        return gasTank:getContainerContentAmount() / cap
    end)
    if not ok or not ratio then return 0 end
    return math.max(0, math.min(1, ratio))
end

--- Fim da escala do velocimetro, em multiplos de 20 na unidade ativa. Cada moto tem
--- a sua: a escala do CRF 450 nao serve para o Motra.
function L.dialMax(vehicle, kmh)
    local top = 100
    local ok, v = pcall(function() return vehicle:getMaxSpeed() end)
    if ok and type(v) == "number" and v > 0 then top = v end
    if not kmh then top = top * L.MPH_PER_KMH end
    top = math.ceil(top * 1.15 / 20) * 20
    -- acima de 160 o passo vira 40: a escala tem de fechar num multiplo dele, senao o
    -- ultimo traco cai antes do fim do arco
    if top > 160 then top = math.ceil(top / 40) * 40 end
    return math.max(60, top)
end

--- Passo das marcacoes maiores: o menor que deixa no maximo 8 divisoes. Com passo fixo
--- de 20, a scooter (escala ate 60) ficava com so 4 numeros no aro. Acima de 7 divisoes
--- o mostrador rotula uma sim, outra nao.
local DIAL_STEPS = { 10, 20, 40 }
function L.dialStep(dialMax)
    for _, step in ipairs(DIAL_STEPS) do
        if dialMax / step <= 8 then return step end
    end
    return DIAL_STEPS[#DIAL_STEPS]
end

----------------------------------------------------------------------------------------
-- pictogramas
--
-- Moto de verdade nao escreve "BAT" no painel: usa simbolo. E simbolo nao estoura o
-- vidro em nenhum idioma -- o rotulo em texto estourava ("BAT" e "COMB" colavam).
-- O nome por extenso continua na linha de status, ao passar o mouse.
--
-- Cada pictograma e uma lista de primitivas numa grade 16x16 (y para baixo):
--   { "rect", x, y, w, h }                 retangulo na cor do simbolo
--   { "cut",  x, y, w, h }                 retangulo na cor do vidro (recorte)
--   { "disc", cx, cy, r, grau0, grau1 }    setor cheio
--   { "ring", cx, cy, rIn, rOut, g0, g1 }  setor de anel
--   { "ray",  cx, cy, rIn, rOut, grau, meiaLargura }  traco radial
-- Graus como no mostrador: 0 = para cima, positivo = sentido horario.
----------------------------------------------------------------------------------------
L.ICONS = {
    -- farol: o "D" da norma ISO, com tres fachos saindo pela esquerda
    lights = {
        { "disc", 10, 8, 5.5, 0, 180 },
        { "rect", 1, 3.5, 6, 1.5 },
        { "rect", 1, 7.25, 6, 1.5 },
        { "rect", 1, 11, 6, 1.5 },
    },
    -- chave: argola, haste e dois dentes
    ignition = {
        { "ring", 4.5, 8, 1.75, 4, -180, 180 },
        { "rect", 8, 7, 7.5, 2 },
        { "rect", 11, 9, 1.5, 2.5 },
        { "rect", 13.5, 9, 1.5, 2 },
    },
    -- motor: silhueta do bloco com bocal em cima, admissao e escape nas laterais
    engine = {
        { "rect", 4, 5, 8, 7 },
        { "rect", 6, 3, 4, 2 },
        { "rect", 2, 6.5, 2, 4 },
        { "rect", 12, 6, 1.5, 5 },
        { "rect", 13.5, 4.5, 1.5, 8 },
    },
    -- bateria: corpo, dois polos e os sinais recortados
    battery = {
        { "rect", 1.5, 5, 13, 8.5 },
        { "rect", 3.5, 3, 2.5, 2 },
        { "rect", 10, 3, 2.5, 2 },
        { "cut", 3.5, 8.5, 3, 1.25 },
        { "cut", 9.5, 8.5, 3, 1.25 },
        { "cut", 10.375, 7.625, 1.25, 3 },
    },
    -- bomba de combustivel: corpo com visor recortado, base e mangueira
    fuel = {
        { "rect", 2.5, 2.5, 7.5, 11.5 },
        { "cut", 4, 4, 4.5, 3.5 },
        { "rect", 1.5, 13.5, 9.5, 1.5 },
        { "rect", 10, 8, 2.5, 1.25 },
        { "rect", 12.5, 4, 1.25, 5.25 },
        { "rect", 11.25, 3, 2.5, 1.25 },
    },
    -- sirene: cupula sobre a base, com tres raios
    siren = {
        { "disc", 8, 11, 4.5, -90, 90 },
        { "rect", 2.5, 11, 11, 2.5 },
        { "ray", 8, 11, 6, 8.5, -60, 0.6 },
        { "ray", 8, 11, 6, 8.5, 0, 0.6 },
        { "ray", 8, 11, 6, 8.5, 60, 0.6 },
    },
    -- reboque: caixa, roda e cambao
    trailer = {
        { "rect", 1, 4, 10, 6.5 },
        { "disc", 6, 12, 2.5, -180, 180 },
        { "rect", 11, 8.5, 4, 1.25 },
    },
}

--- Pictograma de uma luz nesta moto. Na eletrica a luz de reserva e de CARGA, entao
--- mostra a bateria em vez da bomba de gasolina.
function L.lampIcon(lamp, vehicle)
    if lamp.id == "fuel" and L.isElectric(vehicle) then return L.ICONS.battery end
    return L.ICONS[lamp.id]
end

--- Chave do Translate com o nome por extenso de uma luz nesta moto. Pelo mesmo motivo
--- do pictograma: "Combustivel na reserva" ao lado de uma barra CARGA nao faz sentido.
function L.lampNameKey(lamp, vehicle)
    if lamp.id == "fuel" and L.isElectric(vehicle) then return "IGUI_RZMotoDash_Name_charge" end
    return "IGUI_RZMotoDash_Name_" .. lamp.id
end

----------------------------------------------------------------------------------------
-- registro das luzes de aviso
--
-- present(v)  -> a luz existe nesta moto? Luz que nunca acende nao ocupa espaco.
--                (o painel vanilla mostra porta, mala e ar-condicionado em motos que
--                 nao tem nenhuma das tres)
-- isOn(v, d)  -> esta acesa agora?
-- click       -> metodo de ISVehicleDashboard chamado no clique, se houver
--
-- O nome longo da linha de status vem do Translate: IGUI_RZMotoDash_Name_<id>.
----------------------------------------------------------------------------------------
L.lamps = {
    {
        id = "lights", tone = "ok", click = "onClickHeadlights",
        present = function(v) return v:getPartById("HeadlightLeft") ~= nil end,
        isOn = function(v) return v:getHeadlightsOn() end,
    },
    {
        id = "ignition", tone = "ok", click = "onClickKeys",
        present = function() return true end,
        isOn = function(v) return L.keyState(v) ~= "empty" end,
    },
    {
        id = "engine", tone = "warn", click = "onClickEngine",
        present = function() return true end,
        isOn = function(v, d) return d.rzmAwake and not L.engineOk(d) or false end,
    },
    {
        id = "battery", tone = "warn",
        -- na eletrica a bateria E o combustivel: a luz de carga ja cobre o caso
        present = function(v) return not L.isElectric(v) end,
        isOn = function(v)
            if not L.isAwake(v) then return false end
            return v:getBatteryCharge() <= 0
        end,
    },
    {
        id = "fuel", tone = "warn",
        present = function(v) return v:getPartById("GasTank") ~= nil end,
        -- rzmFuel so e confiavel com a moto acordada: desligada, o valor retido nao
        -- deve acender a reserva (entrar numa moto parada nao e um alerta)
        isOn = function(v, d) return d.rzmAwake and (d.rzmFuel or 0) < L.FUEL_LOW or false end,
    },
    {
        id = "siren", tone = "info",
        present = function(v) return v:getPartById("lightbar") ~= nil end,
        isOn = function(v)
            local ok, on = pcall(function()
                return v:getLightbarLightsMode() > 0 or v:getLightbarSirenMode() > 0
            end)
            return (ok and on) or false
        end,
    },
    {
        id = "trailer", tone = "ok",
        -- so aparece engatada: um vidro permanentemente escuro e ruido
        present = function(v) return v:getVehicleTowing() ~= nil or v:getVehicleTowedBy() ~= nil end,
        isOn = function() return true end,
    },
}

--- Luzes que esta moto realmente tem, na ordem do registro.
function L.activeLamps(vehicle)
    local out = {}
    for _, lamp in ipairs(L.lamps) do
        local ok, present = pcall(lamp.present, vehicle)
        if ok and present then out[#out + 1] = lamp end
    end
    return out
end

----------------------------------------------------------------------------------------
-- geometria derivada
----------------------------------------------------------------------------------------
L.DIAL_D  = L.DIAL_R * 2
L.FACE_R  = L.DIAL_R - L.BEZEL_W

-- A largura do canvas vem da fileira cheia de luzes: e o bloco mais largo da coluna
-- direita, e com ela as barras ganham espaco para 12 segmentos legiveis.
L.LAMP_ROW_W = #L.lamps * L.LAMP_W + (#L.lamps - 1) * L.LAMP_GAP
L.RIGHT_W    = L.LAMP_ROW_W
L.RIGHT_X    = L.PAD + L.DIAL_D + L.GAP
L.CANVAS_W   = L.RIGHT_X + L.RIGHT_W + L.PAD
L.CANVAS_H   = L.PAD + L.DIAL_D + L.PAD

L.DIAL_CX = L.PAD + L.DIAL_R
L.DIAL_CY = L.PAD + L.DIAL_R

-- A janela LCD ocupa a coluna direita da fileira de luzes ate a base do mostrador; as
-- quatro linhas dividem o miolo dela por igual.
L.LCD_X = L.RIGHT_X
L.LCD_Y = L.PAD + L.LAMP_H + L.LAMP_GAP
L.LCD_W = L.RIGHT_W
L.LCD_H = L.PAD + L.DIAL_D - L.LCD_Y
L.ROW_H = (L.LCD_H - 2 * L.LCD_PAD) / L.ROW_COUNT
L.ROW_Y = L.LCD_Y + L.LCD_PAD

-- miolo da janela LCD, onde mora o conteudo
L.INNER_X = L.LCD_X + L.LCD_PAD
L.INNER_W = L.LCD_W - 2 * L.LCD_PAD

--- Largura fechada de uma barra segmentada.
function L.barW(count, segW)
    return count * segW + (count - 1) * L.SEG_GAP
end

-- A barra manda na largura da coluna de valores; o que sobra no miolo do LCD e o
-- espaco dos rotulos, alinhados a direita contra o inicio da barra.
L.BAR_W   = math.max(L.barW(L.RPM_SEGS, L.RPM_SEG_W), L.barW(L.FUEL_SEGS, L.FUEL_SEG_W))
L.LABEL_W = L.INNER_W - L.LAMP_GAP - L.BAR_W
L.BAR_X   = L.INNER_X + L.LABEL_W + L.LAMP_GAP

function L.rowY(index) return L.ROW_Y + index * L.ROW_H end

--- Retangulos das luzes (coordenadas do canvas base), centralizados sobre o LCD. Com
--- passo de 40 e meia diferenca de 20, qualquer contagem continua na grade de 4.
function L.lampRects(lamps)
    local out = {}
    local rowW = #lamps * L.LAMP_W + math.max(0, #lamps - 1) * L.LAMP_GAP
    local x0 = L.RIGHT_X + (L.RIGHT_W - rowW) / 2
    for i = 1, #lamps do
        out[i] = {
            x = x0 + (i - 1) * (L.LAMP_W + L.LAMP_GAP),
            y = L.PAD,
            w = L.LAMP_W,
            h = L.LAMP_H,
        }
    end
    return out
end

return RZMotoDash.L

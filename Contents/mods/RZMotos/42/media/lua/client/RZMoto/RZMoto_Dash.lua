--[[
    RZ Motos - painel da moto: desenho e integracao
    -----------------------------------------------
    Substitui o painel vanilla SOMENTE quando o jogador esta pilotando uma moto do mod.
    Em carro, delega para quem estava instalado antes (vanilla ou outro mod de painel).

    Por que um branch e nao uma janela nova: o painel e UM objeto por jogador, criado
    uma vez em ISPlayerDataObject e reusado em todo veiculo. Nao existe "painel da moto"
    separado -- existe o mesmo objeto decidindo o que desenhar. Como os metodos vivem na
    tabela da classe e as instancias resolvem por metatable, sobrescrever a classe depois
    do jogo carregado tambem afeta o painel ja criado.

    Por que o hook roda em OnGameStart e nao no load do arquivo: assim o "anterior" que
    capturamos ja inclui outros mods de painel, qualquer que seja a ordem de carga.

    Sem PNG: tudo e desenhado com drawPolygon/drawRect/drawTextZoomed. drawPolygon(nil, ...)
    preenche solido (e o que o mapa vanilla usa para a seta do jogador), o que da quadrilatero
    arbitrario -- portanto ponteiro girado, arco, canto arredondado e pictograma -- sem
    textura nenhuma.

    Geometria, cores, pictogramas e predicados das luzes: RZMoto_DashLayout.lua.
]]

require "Vehicles/ISUI/ISVehicleDashboard"
require "ISUI/ISContextMenu"
require "RZMoto/RZMoto_Core"
require "RZMoto/RZMoto_DashLayout"

RZMotoDash = RZMotoDash or {}
local L = RZMotoDash.L

RZMotoDash.scale = RZMotoDash.scale or 1.0
RZMotoDash.units = RZMotoDash.units or "kmh"

-- Tons apagados das barras com a moto ligada: deixam ver onde fica a zona vermelha
-- antes de chegar nela. Derivados da paleta, nao escolhidos a mao.
local SEG_DIM     = { r = L.COL_GLOW.r * 0.20,   g = L.COL_GLOW.g * 0.20,   b = L.COL_GLOW.b * 0.20 }
local SEG_DIM_HOT = { r = L.TONES.warn.r * 0.30, g = L.TONES.warn.g * 0.30, b = L.TONES.warn.b * 0.30 }
local HUB_CAP     = { r = 0.30, g = 0.30, b = 0.32 }
local SHADOW      = { r = 0, g = 0, b = 0 }

----------------------------------------------------------------------------------------
-- preferencias (escala e unidade), por maquina
--
-- Formato key=value e parser manual de proposito, por duas limitacoes da B42:
--   * loadstring / load / dofile / loadfile nao existem no Kahlua, e chamar nil levanta
--     excecao Java que pcall nao pega;
--   * getFileWriter aceita so .txt/.log -- escrever .lua falha em silencio.
-- string.gmatch tambem nao existe: o parser usa find/match linha por linha.
----------------------------------------------------------------------------------------
local SETTINGS_FILE = "RZMotos/dash.txt"

local function loadSettings()
    local reader = getFileReader(SETTINGS_FILE, false)
    if not reader then return end
    local line = reader:readLine()
    while line do
        local k, v = string.match(line, "^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if k == "scale" then
            local s = tonumber(v)
            if s and s > 0 then RZMotoDash.scale = s end
        elseif k == "units" then
            if v == "kmh" or v == "mph" then RZMotoDash.units = v end
        end
        line = reader:readLine()
    end
    reader:close()
end

local function saveSettings()
    local writer = getFileWriter(SETTINGS_FILE, true, false)
    if not writer then return end
    writer:write(string.format("scale=%s\nunits=%s\n",
        tostring(RZMotoDash.scale), RZMotoDash.units))
    writer:close()
end

function RZMotoDash.ensureLoaded()
    if RZMotoDash.loaded then return end
    RZMotoDash.loaded = true
    pcall(loadSettings)
end

--- Tamanho do painel em pixels INTEIROS: a moldura e o conteudo precisam arredondar
--- junto, senao sobra meia linha transparente na borda em escalas fracionarias.
function RZMotoDash.panelSize()
    local S = RZMotoDash.scale
    return math.floor(L.CANVAS_W * S + 0.5), math.floor(L.CANVAS_H * S + 0.5)
end

----------------------------------------------------------------------------------------
-- primitivas
----------------------------------------------------------------------------------------

--- Direcao de um angulo em graus. 0 = 12 horas, positivo = sentido horario.
local function dirAt(deg)
    local rad = math.rad(deg)
    return math.sin(rad), -math.cos(rad)
end

local function mix(a, b, t)
    return {
        r = a.r + (b.r - a.r) * t,
        g = a.g + (b.g - a.g) * t,
        b = a.b + (b.b - a.b) * t,
    }
end

--- Setor de anel entre dois angulos. Os vertices andam pelo perimetro
--- (interno@d0 -> externo@d0 -> externo@d1 -> interno@d1), que e a ordem que
--- DrawPolygon espera. rIn = 0 degenera em leque de triangulos e preenche o disco.
local function drawArc(self, cx, cy, rIn, rOut, deg0, deg1, steps, col, a)
    if steps < 1 then return end
    local step = (deg1 - deg0) / steps
    for i = 0, steps - 1 do
        local x0, y0 = dirAt(deg0 + i * step)
        local x1, y1 = dirAt(deg0 + (i + 1) * step)
        self:drawPolygon(nil,
            cx + x0 * rIn,  cy + y0 * rIn,
            cx + x0 * rOut, cy + y0 * rOut,
            cx + x1 * rOut, cy + y1 * rOut,
            cx + x1 * rIn,  cy + y1 * rIn,
            col.r, col.g, col.b, a)
    end
end

--- Marcacao radial (traco da escala, raio de pictograma).
local function drawRadial(self, cx, cy, rIn, rOut, deg, half, col, a)
    local dx, dy = dirAt(deg)
    local px, py = -dy, dx
    self:drawPolygon(nil,
        cx + dx * rIn  + px * half, cy + dy * rIn  + py * half,
        cx + dx * rOut + px * half, cy + dy * rOut + py * half,
        cx + dx * rOut - px * half, cy + dy * rOut - py * half,
        cx + dx * rIn  - px * half, cy + dy * rIn  - py * half,
        col.r, col.g, col.b, a)
end

--- Barra afilada saindo do centro: meia largura `half` na base (recuada `back` para
--- tras do centro) e `tipHalf` na ponta.
local function drawTaper(self, cx, cy, deg, len, back, half, tipHalf, col, a)
    local dx, dy = dirAt(deg)
    local px, py = -dy, dx
    self:drawPolygon(nil,
        cx + dx * len  + px * tipHalf, cy + dy * len  + py * tipHalf,
        cx + dx * len  - px * tipHalf, cy + dy * len  - py * tipHalf,
        cx - dx * back - px * half,    cy - dy * back - py * half,
        cx - dx * back + px * half,    cy - dy * back + py * half,
        col.r, col.g, col.b, a)
end

--- Passos de um canto arredondado: o suficiente para parecer curva no tamanho final,
--- sem gastar 6 poligonos num canto de 3 pixels.
local function cornerSteps(rPx)
    return math.max(2, math.min(8, math.ceil(rPx / 3)))
end

--- Retangulo arredondado cheio. Coluna central + duas faixas laterais + quatro quartos
--- de disco, sem sobreposicao -- com alpha < 1 sobreposicao viraria emenda escura.
local function drawRoundRect(self, x, y, w, h, r, col, a)
    r = math.max(0, math.min(r, w / 2, h / 2))
    if r < 1 then
        self:drawRect(x, y, w, h, a, col.r, col.g, col.b)
        return
    end
    local n = cornerSteps(r)
    self:drawRect(x + r, y, w - 2 * r, h, a, col.r, col.g, col.b)
    self:drawRect(x, y + r, r, h - 2 * r, a, col.r, col.g, col.b)
    self:drawRect(x + w - r, y + r, r, h - 2 * r, a, col.r, col.g, col.b)
    drawArc(self, x + r,     y + r,     0, r, -90, 0,   n, col, a)
    drawArc(self, x + w - r, y + r,     0, r, 0,   90,  n, col, a)
    drawArc(self, x + w - r, y + h - r, 0, r, 90,  180, n, col, a)
    drawArc(self, x + r,     y + h - r, 0, r, 180, 270, n, col, a)
end

--- Contorno de retangulo arredondado com espessura t, tambem sem sobreposicao.
local function drawRoundBorder(self, x, y, w, h, r, t, col, a)
    r = math.max(t, math.min(r, w / 2, h / 2))
    local n = cornerSteps(r)
    self:drawRect(x + r, y, w - 2 * r, t, a, col.r, col.g, col.b)
    self:drawRect(x + r, y + h - t, w - 2 * r, t, a, col.r, col.g, col.b)
    self:drawRect(x, y + r, t, h - 2 * r, a, col.r, col.g, col.b)
    self:drawRect(x + w - t, y + r, t, h - 2 * r, a, col.r, col.g, col.b)
    drawArc(self, x + r,     y + r,     r - t, r, -90, 0,   n, col, a)
    drawArc(self, x + w - r, y + r,     r - t, r, 0,   90,  n, col, a)
    drawArc(self, x + w - r, y + h - r, r - t, r, 90,  180, n, col, a)
    drawArc(self, x + r,     y + h - r, r - t, r, 180, 270, n, col, a)
end

--- Aro metalico: cada fatia clareia conforme aponta para cima, como se a luz viesse
--- de cima. Da volume ao mostrador sem nenhuma textura.
local function drawBezel(self, cx, cy, rIn, rOut, steps)
    local step = 360 / steps
    for i = 0, steps - 1 do
        local d0 = -180 + i * step
        local _, dyMid = dirAt(d0 + step / 2)
        local col = mix(L.COL_BEZEL_LO, L.COL_BEZEL_HI, (1 - dyMid) / 2)
        drawArc(self, cx, cy, rIn, rOut, d0, d0 + step, 1, col, 1.0)
    end
end

--- Pictograma da grade 16x16 (ver L.ICONS). Desenhado sempre opaco: com alpha < 1 as
--- primitivas que se encostam (argola e haste da chave) mostrariam a emenda. O "apagado"
--- vem da cor, nao da transparencia. `cut` e a cor do vidro, para os recortes.
local function drawIcon(self, icon, x, y, u, col, cut)
    for _, p in ipairs(icon) do
        local kind = p[1]
        if kind == "rect" or kind == "cut" then
            local c = (kind == "cut") and cut or col
            self:drawRect(x + p[2] * u, y + p[3] * u, p[4] * u, p[5] * u, 1.0, c.r, c.g, c.b)
        elseif kind == "disc" then
            drawArc(self, x + p[2] * u, y + p[3] * u, 0, p[4] * u, p[5], p[6], 12, col, 1.0)
        elseif kind == "ring" then
            drawArc(self, x + p[2] * u, y + p[3] * u, p[4] * u, p[5] * u, p[6], p[7], 16, col, 1.0)
        elseif kind == "ray" then
            drawRadial(self, x + p[2] * u, y + p[3] * u, p[4] * u, p[5] * u, p[6], p[7] * u, col, 1.0)
        end
    end
end

local function fontH(font, S)
    return getTextManager():getFontHeight(font) * S
end

local function textW(str, font, S)
    return getTextManager():MeasureStringX(font, str) * S
end

-- drawTextZoomed e o unico desenho de texto que respeita a escala do painel: as fontes
-- do jogo tem tamanho fixo, entao sem o zoom o texto estouraria o canvas a 75%.
local function textLeft(self, str, x, y, font, S, col, a)
    self:drawTextZoomed(str, x, y, S, col.r, col.g, col.b, a, font)
end

local function textCentre(self, str, cx, y, font, S, col, a)
    self:drawTextZoomed(str, cx - textW(str, font, S) / 2, y, S, col.r, col.g, col.b, a, font)
end

local function textRight(self, str, rx, y, font, S, col, a)
    self:drawTextZoomed(str, rx - textW(str, font, S), y, S, col.r, col.g, col.b, a, font)
end

--- Corta o texto que nao cabe na coluna. Sempre usar antes de desenhar em largura fixa:
--- um nome de moto longo traduzido estouraria a linha de status.
local function truncate(str, maxW, font, S)
    if textW(str, font, S) <= maxW then return str end
    local out = str
    while #out > 1 and textW(out .. "...", font, S) > maxW do
        out = string.sub(out, 1, #out - 1)
    end
    -- Nao parar no meio de um caractere multibyte: os nomes traduzidos tem acento, e
    -- meio byte de "ç" vira lixo na tela. Byte de continuacao UTF-8 = 0x80..0xBF.
    while #out > 1 do
        local b = string.byte(out, #out)
        if b and b >= 128 and b < 192 then
            out = string.sub(out, 1, #out - 1)
        else
            break
        end
    end
    return out .. "..."
end

----------------------------------------------------------------------------------------
-- blocos do painel
----------------------------------------------------------------------------------------

local function drawLamp(self, rect, S, lamp, icon, on, glow, hover)
    local x, y, w, h = rect.x * S, rect.y * S, rect.w * S, rect.h * S
    local rad = L.LAMP_RADIUS * S
    local tone = L.TONES[lamp.tone] or L.TONES.ok

    -- Vidro opaco e, aceso, um halo do tom por cima. A cor do recorte do pictograma
    -- tem de ser exatamente o resultado dessa mistura, senao o recorte aparece.
    drawRoundRect(self, x, y, w, h, rad, L.COL_WINDOW, 1.0)
    local bg = L.COL_WINDOW
    if on then
        drawRoundRect(self, x, y, w, h, rad, tone, 0.22)
        bg = mix(L.COL_WINDOW, tone, 0.22)
    end

    local border = hover and L.COL_ACCENT or (on and tone or L.COL_BORDER)
    local borderA = hover and 1.0 or (on and 0.70 or 0.25)
    drawRoundBorder(self, x, y, w, h, rad, math.max(1, S), border, borderA)

    if icon then
        -- apagado, o simbolo fica quase invisivel -- e a impressao do vidro que a luz de
        -- fundo esquenta um pouco a noite
        local u = S * (L.LAMP_H - 2 * L.ICON_MARGIN) / L.ICON_GRID
        local size = L.ICON_GRID * u
        local col = on and tone or mix(L.COL_OFF, L.COL_GLOW, glow * 0.25)
        drawIcon(self, icon, x + (w - size) / 2, y + (h - size) / 2, u, col, bg)
    end
end

--- Segmentos de alerta: na barra de rotacao sao os ultimos (corte), na de
--- combustivel os primeiros (reserva). Declarados aqui para nao alocar um closure
--- novo por quadro.
local function rpmHot(i)  return i > L.RPM_SEGS - L.RPM_RED end
local function fuelHot(i) return i <= L.FUEL_RED end

--- Barra segmentada, fechando exatamente em L.BAR_W (ver L.barW no layout). Sem
--- energia (`live` falso) todos os segmentos viram fantasma neutro: uma barra de
--- combustivel com a reserva tingida de vermelho, com a moto desligada, parecia
--- "tanque vazio".
local function drawSegBar(self, S, baseX, baseY, count, segW, fill, isHot, live)
    local lit = live and math.ceil(math.max(0, math.min(1, fill)) * count) or 0
    for i = 1, count do
        local col
        if i <= lit then
            col = isHot(i) and L.TONES.warn or L.COL_GLOW
        elseif live then
            col = isHot(i) and SEG_DIM_HOT or SEG_DIM
        else
            col = L.COL_GHOST
        end
        self:drawRect((baseX + (i - 1) * (segW + L.SEG_GAP)) * S, baseY * S,
            segW * S, L.BAR_H * S, 1.0, col.r, col.g, col.b)
    end
end

--- Rotulo de linha, alinhado a direita na coluna fixa de rotulos. Se ainda assim nao
--- couber (traducao longa, ou o jogador com a fonte do jogo num tamanho maior), o zoom
--- encolhe ate caber: o rotulo nunca sai da janela LCD.
local function drawRowLabel(self, S, rowIndex, str, col, a)
    local tm = getTextManager()
    local maxW = L.LABEL_W * S
    local w = tm:MeasureStringX(UIFont.Small, str) * S
    local zoom = S
    if w > maxW then
        zoom = S * maxW / w
        w = maxW
    end
    local y = (L.rowY(rowIndex) + L.ROW_H / 2) * S - tm:getFontHeight(UIFont.Small) * zoom / 2
    self:drawTextZoomed(str, (L.INNER_X + L.LABEL_W) * S - w, y, zoom,
        col.r, col.g, col.b, a, UIFont.Small)
end

----------------------------------------------------------------------------------------
-- prerender: suavizacao e estado derivado
----------------------------------------------------------------------------------------
function RZMotoDash.prerender(self)
    local v = self.vehicle
    local S = RZMotoDash.scale

    -- A posicao e calculada em onResolutionChange, mas render le a escala ao vivo: se o
    -- jogador trocar a escala (ou se a preferencia subir do disco depois do primeiro
    -- posicionamento), reposiciona antes de desenhar fora do lugar.
    if self.rzmScale ~= S then self:onResolutionChange() end

    -- Snapshot visibility: vanilla prerender does not restore static children such
    -- as backgroundTex when the same dashboard is reused by a car.
    if not self.rzmHidChildren then
        self.rzmHidChildren = true
        self.rzmHiddenChildren = {}
        local kids = self:getChildren()
        if kids then
            for _, child in pairs(kids) do
                if child.setVisible and child.isVisible then
                    self.rzmHiddenChildren[child] = child:isVisible()
                    child:setVisible(false)
                end
            end
        end
    end

    local fps = 30
    local okf, perf = pcall(function() return getPerformance():getUIRenderFPS() end)
    if okf and perf and perf > 1 then fps = perf end

    local kmh = RZMotoDash.units == "kmh"
    if self.rzmDialUnits ~= RZMotoDash.units or not self.rzmDialMax then
        self.rzmDialUnits = RZMotoDash.units
        self.rzmDialMax = L.dialMax(v, kmh)
    end

    -- "Acordada" = chave na ignicao ou motor rodando. E o gate dos instrumentos: sem
    -- energia o painel fica morto, e o tanque so e confiavel nesse estado. As luzes de
    -- falha leem isto por rzmAwake: painel sem energia nao acusa nada.
    local awake = L.isAwake(v)

    -- Teste de lampadas ao girar a chave, como em moto de verdade: o ponteiro varre ate
    -- o fim da escala e volta, e todas as luzes acendem. So na transicao desligada ->
    -- ligada; rzmAwake nil (acabou de entrar) nao conta, entao entrar numa moto ja
    -- ligada nao repete o teste.
    if self.rzmAwake == false and awake then self.rzmCheckT = 0 end
    self.rzmAwake = awake
    self.rzmCheck = nil
    if self.rzmCheckT then
        self.rzmCheckT = self.rzmCheckT + 1 / fps
        if self.rzmCheckT >= L.CHECK_DUR or not awake then
            self.rzmCheckT = nil
        else
            self.rzmCheck = math.sin(math.pi * self.rzmCheckT / L.CHECK_DUR)
        end
    end

    local tSpeed, tRpm = 0, 0
    if awake then
        local kph = math.abs(v:getCurrentSpeedKmHour())
        tSpeed = kmh and kph or kph * L.MPH_PER_KMH
        local oks, rpm = pcall(function() return v:getEngineSpeed() end)
        if v:isEngineRunning() and oks and type(rpm) == "number" then tRpm = rpm end
    end

    if self.rzmCheck then
        -- a varredura e mecanica, nao leitura: vai direto, sem suavizacao
        self.rzmSpeed = self.rzmDialMax * self.rzmCheck
        self.rzmRpm   = L.RPM_MAX * self.rzmCheck
    else
        local a = 1 - (1 - L.NEEDLE_SMOOTH) ^ (30 / fps)
        if self.rzmSpeed == nil then self.rzmSpeed = tSpeed end
        if self.rzmRpm == nil then self.rzmRpm = tRpm end
        self.rzmSpeed = self.rzmSpeed + (tSpeed - self.rzmSpeed) * a
        self.rzmRpm   = self.rzmRpm + (tRpm - self.rzmRpm) * a
    end

    -- Combustivel: fora do estado acordado mantem o ultimo valor conhecido, e a transicao
    -- e assimetrica (enche devagar, cai mais rapido) como o medidor vanilla -- sem o salto
    -- de "tanque cheio" que aparecia ao ligar a moto.
    local tFuel = self.rzmFuel or 0
    if awake then tFuel = L.fuelRatio(v, self.gasTank) end
    if self.rzmFuel == nil then
        self.rzmFuel = tFuel
    elseif self.rzmFuel < tFuel then
        self.rzmFuel = math.min(self.rzmFuel + 0.015 * (30 / fps), tFuel)
    else
        self.rzmFuel = math.max(self.rzmFuel - 0.05 * (30 / fps), tFuel)
    end

    -- Luz de fundo: acende cheia com o farol ligado, fica num brilho baixo a noite so
    -- para o painel continuar legivel, e apaga de dia. Fade lento de proposito: filamento
    -- aquecendo, nao interruptor de LED.
    local target = 0
    if v:getHeadlightsOn() then
        target = 1
    elseif awake and L.isNight() then
        target = L.GLOW_NIGHT
    end
    if self.rzmGlow == nil then self.rzmGlow = target end
    local ga = 1 - (1 - L.GLOW_FADE) ^ (30 / fps)
    self.rzmGlow = self.rzmGlow + (target - self.rzmGlow) * ga

    -- A lista depende do veiculo (sirene so na policia) e do momento (reboque engatado),
    -- entao e recalculada por quadro: sao sete predicados baratos.
    self.rzmLamps = L.activeLamps(v)
end

----------------------------------------------------------------------------------------
-- render
----------------------------------------------------------------------------------------

local WARN_ORDER = { "engine", "battery", "fuel" }

--- Texto da linha de status: o que esta sob o cursor, senao o aviso mais urgente,
--- senao o nome da moto.
local function statusText(self, hoverLamp, lampStates)
    if hoverLamp then
        return getText(L.lampNameKey(hoverLamp, self.vehicle)), L.COL_ACCENT
    end
    if not self.rzmCheck then
        for _, order in ipairs(WARN_ORDER) do
            for i, lamp in ipairs(self.rzmLamps or {}) do
                if lamp.id == order and lampStates[i] then
                    return getText(L.lampNameKey(lamp, self.vehicle)), L.TONES.warn
                end
            end
        end
    end
    local ok, name = pcall(function() return self.vehicle:getScript():getName() end)
    if ok and name then return getText("IGUI_VehicleName" .. name), nil end
    return getText("IGUI_RZMoto_Motorcycle"), nil
end

local function drawDial(self, S, glow, awake, colText, colLabel, colBorder, kmh)
    local cx, cy = L.DIAL_CX * S, L.DIAL_CY * S
    local deg0, sweep = L.DIAL_START_DEG, L.DIAL_SWEEP_DEG

    -- aro, fundo (com a luz de fundo por cima) e uma sombra fina por dentro do aro que
    -- afunda o fundo em relacao ao metal
    drawBezel(self, cx, cy, L.FACE_R * S, L.DIAL_R * S, 48)
    drawArc(self, cx, cy, 0, L.FACE_R * S, -180, 180, 48, L.COL_FACE, 1.0)
    if glow > 0.001 then
        drawArc(self, cx, cy, 0, L.FACE_R * S, -180, 180, 48, L.COL_GLOW, 0.08 * glow)
    end
    drawArc(self, cx, cy, (L.FACE_R - 2) * S, L.FACE_R * S, -180, 180, 48, SHADOW, 0.6)

    local dialMax  = self.rzmDialMax or 100
    local speed    = math.max(0, self.rzmSpeed or 0)
    local frac     = math.max(0, math.min(1, speed / dialMax))
    local scaleDeg = deg0 + frac * sweep

    -- Em repouso o ponteiro descansa num pino logo abaixo do zero, como num mostrador
    -- mecanico; sem isso ele riscava o "0" bem no meio. O pino solta nos primeiros 5%
    -- da escala, e o arco aceso segue o valor real, nao o ponteiro.
    local needleDeg = scaleDeg - L.NEEDLE_PEG_DEG * (1 - math.min(1, frac * 20))

    -- arco da escala apagado e, por cima, o trecho percorrido aceso
    local rRingIn  = (L.SCALE_R - L.DIAL_RING) * S
    local rRingOut = L.SCALE_R * S
    drawArc(self, cx, cy, rRingIn, rRingOut, deg0, deg0 + sweep, 60, colBorder, 0.60)
    if frac > 0.001 then
        drawArc(self, cx, cy, rRingIn, rRingOut, deg0, scaleDeg,
            math.max(1, math.floor(frac * sweep / 4)), L.COL_ACCENT, 0.95)
    end

    -- escala: tracos maiores no passo rotulado, um menor no meio de cada intervalo
    local step   = L.dialStep(dialMax)
    local majors = math.floor(dialMax / step)
    local labelEvery = (majors > 7) and 2 or 1
    local rTickOut = (L.SCALE_R - L.DIAL_RING) * S
    local rMajor   = (L.SCALE_R - L.DIAL_RING - L.TICK_MAJOR) * S
    local rMinor   = (L.SCALE_R - L.DIAL_RING - L.TICK_MINOR) * S
    local rLabel   = (L.SCALE_R - L.DIAL_RING - L.TICK_MAJOR - L.DIAL_LABEL_INSET) * S
    for i = 0, majors do
        local deg = deg0 + (i * step / dialMax) * sweep
        drawRadial(self, cx, cy, rMajor, rTickOut, deg, 1.25 * S, colText, 0.90)
        if i % labelEvery == 0 then
            local dx, dy = dirAt(deg)
            textCentre(self, tostring(i * step), cx + dx * rLabel,
                cy + dy * rLabel - fontH(UIFont.NewSmall, S) / 2,
                UIFont.NewSmall, S, colLabel, 0.95)
        end
        if i < majors then
            local midDeg = deg0 + ((i + 0.5) * step / dialMax) * sweep
            drawRadial(self, cx, cy, rMinor, rTickOut, midDeg, 0.75 * S, colLabel, 0.70)
        end
    end

    -- Unidade impressa no fundo, entre o cubo e os numeros de cima, como nos mostradores
    -- de verdade. Ja morou em cima da janela digital, mas a fonte Large do jogo e mais
    -- alta do que parece: a janela subia e empurrava o rotulo para baixo do ponteiro.
    textCentre(self, getText(kmh and "IGUI_RZMotoDash_Kmh" or "IGUI_RZMotoDash_Mph"),
        cx, cy - L.DIAL_UNIT_R * S - fontH(UIFont.NewSmall, S) / 2,
        UIFont.NewSmall, S, colLabel, 0.90)

    -- Leitura digital numa janela LCD encostada na base do fundo. A posicao sai da fonte
    -- e do circulo, nao de um numero fixo: a janela desce ate onde os cantos ainda cabem
    -- no fundo. Com isso ela fica abaixo dos numeros das pontas da escala (antes
    -- encostava no "100") qualquer que seja o tamanho da fonte.
    local winW = textW("888", UIFont.Large, S) + 2 * L.READOUT_PAD * S
    local winH = fontH(UIFont.Large, S) + 2 * S
    local rFit = (L.FACE_R - L.READOUT_INSET) * S
    local half = winW / 2
    local winTop = cy + math.sqrt(math.max(0, rFit * rFit - half * half)) - winH
    drawRoundRect(self, cx - half, winTop, winW, winH, 4 * S, L.COL_LCD, 1.0)
    if glow > 0.001 then
        drawRoundRect(self, cx - half, winTop, winW, winH, 4 * S, L.COL_GLOW, 0.10 * glow)
    end
    local lcdA = awake and 1.0 or 0.30
    textCentre(self, tostring(math.floor(speed + 0.5)), cx, winTop + S, UIFont.Large, S, colText, lcdA)

    -- Ponteiro por ultimo, sobre tudo: contrapeso escuro para tras (o ponteiro antigo,
    -- todo laranja, parecia apontar para os dois lados), corpo afilado laranja, cubo
    -- redondo com miolo escuro.
    drawTaper(self, cx, cy, needleDeg + 180, L.NEEDLE_TAIL * S, 0,
        (L.NEEDLE_HALF + 1) * S, (L.NEEDLE_HALF + 1) * S, HUB_CAP, 1.0)
    drawTaper(self, cx, cy, needleDeg, L.NEEDLE_LEN * S, 2 * S,
        L.NEEDLE_HALF * S, 0.75 * S, L.COL_ACCENT, 1.0)
    drawArc(self, cx, cy, 0, L.HUB_R * S, -180, 180, 16, HUB_CAP, 1.0)
    drawArc(self, cx, cy, 0, (L.HUB_R - 3) * S, -180, 180, 12, L.COL_FACE, 1.0)
end

function RZMotoDash.render(self)
    local v = self.vehicle
    local S = RZMotoDash.scale
    local W, H = RZMotoDash.panelSize()
    local glow  = self.rzmGlow or 0
    local kmh   = RZMotoDash.units == "kmh"
    local awake = self.rzmAwake or false
    local check = self.rzmCheck

    -- Cores que respondem a luz de fundo: com o farol ligado o painel inteiro esquenta
    -- para o ambar, de dia fica neutro. E o mesmo efeito em texto, aro e bordas.
    local colText   = mix(L.COL_TEXT, L.COL_GLOW, glow * 0.80)
    local colLabel  = mix(L.COL_LABEL, L.COL_GLOW, glow * 0.70)
    local colBorder = mix(L.COL_BORDER, L.COL_GLOW, glow * 0.60)

    ------------------------------------------------------------------------------------
    -- carcaca
    ------------------------------------------------------------------------------------
    local panelR = L.PANEL_RADIUS * S
    drawRoundRect(self, 0, 0, W, H, panelR, L.COL_PANEL, 0.92)
    if glow > 0.001 then
        drawRoundRect(self, 0, 0, W, H, panelR, L.COL_GLOW, 0.05 * glow)
    end
    drawRoundBorder(self, 0, 0, W, H, panelR, math.max(1, S), colBorder, 0.55)

    drawDial(self, S, glow, awake, colText, colLabel, colBorder, kmh)

    ------------------------------------------------------------------------------------
    -- luzes de aviso
    ------------------------------------------------------------------------------------
    local lamps  = self.rzmLamps or {}
    local rects  = L.lampRects(lamps)
    local states = {}
    local hoverLamp = nil
    local mouseOver = self:isMouseOver()
    local mx, my = self:getMouseX(), self:getMouseY()
    for i, lamp in ipairs(lamps) do
        local ok, on = pcall(lamp.isOn, v, self)
        states[i] = (ok and on) or false
        local r = rects[i]
        local hover = mouseOver
            and mx >= r.x * S and mx <= (r.x + r.w) * S
            and my >= r.y * S and my <= (r.y + r.h) * S
        if hover then hoverLamp = lamp end
        -- no teste de lampadas tudo acende, inclusive o que estaria apagado
        drawLamp(self, r, S, lamp, L.lampIcon(lamp, v), states[i] or check ~= nil, glow, hover)
    end

    ------------------------------------------------------------------------------------
    -- janela LCD: rotacao, combustivel, marcha/cruise, status
    ------------------------------------------------------------------------------------
    local lx, ly, lw, lh = L.LCD_X * S, L.LCD_Y * S, L.LCD_W * S, L.LCD_H * S
    local lcdR = L.LCD_RADIUS * S
    drawRoundRect(self, lx, ly, lw, lh, lcdR, L.COL_LCD, 1.0)
    if glow > 0.001 then
        drawRoundRect(self, lx, ly, lw, lh, lcdR, L.COL_GLOW, 0.10 * glow)
    end
    drawRoundBorder(self, lx, ly, lw, lh, lcdR, math.max(1, S), colBorder, 0.45)

    -- sem energia o LCD fica apagado: rotulos continuam legiveis, valores somem
    local lcdA = awake and 1.0 or 0.30

    local rpmFill = math.max(0, math.min(1, (self.rzmRpm or 0) / L.RPM_MAX))
    drawRowLabel(self, S, 0, getText("IGUI_RZMotoDash_Rpm"), colLabel, 0.90)
    drawSegBar(self, S, L.BAR_X, L.rowY(0) + (L.ROW_H - L.BAR_H) / 2,
        L.RPM_SEGS, L.RPM_SEG_W, rpmFill, rpmHot, awake)

    local electric = L.isElectric(v)
    drawRowLabel(self, S, 1,
        getText(electric and "IGUI_RZMotoDash_Charge" or "IGUI_RZMotoDash_Fuel"), colLabel, 0.90)
    drawSegBar(self, S, L.BAR_X, L.rowY(1) + (L.ROW_H - L.BAR_H) / 2,
        L.FUEL_SEGS, L.FUEL_SEG_W, check or self.rzmFuel or 0, fuelHot, awake)

    -- marcha: so faz sentido com o motor rodando
    local gear = "-"
    if v:isEngineRunning() then
        local ok, val = pcall(function() return v:getTransmissionNumberLetter() end)
        if ok and val and val ~= "" then gear = tostring(val) end
    end
    drawRowLabel(self, S, 2, getText("IGUI_RZMotoDash_Gear"), colLabel, 0.90)
    local gearY = L.rowY(2) + (L.ROW_H - getTextManager():getFontHeight(UIFont.Medium)) / 2
    textLeft(self, gear, L.BAR_X * S, gearY * S, UIFont.Medium, S, colText, lcdA)

    -- Cruise na mesma linha, encostado na borda direita do miolo. getRegulatorSpeed e
    -- sempre km/h: em mph converte, senao o ponteiro ia em milhas e o numero em
    -- quilometros. Desligado e sem valor, mostra "--" em vez de um zero que parece leitura.
    local okReg, isReg = pcall(function() return v:isRegulator() end)
    local regOn = okReg and isReg or false
    local reg = 0
    local okRs, rs = pcall(function() return v:getRegulatorSpeed() end)
    if okRs and type(rs) == "number" then
        reg = math.floor((kmh and rs or rs * L.MPH_PER_KMH) + 0.5)
    end
    local regStr = (regOn or reg > 0) and tostring(reg) or "--"
    local regY = L.rowY(2) + (L.ROW_H - getTextManager():getFontHeight(UIFont.NewSmall)) / 2
    textRight(self, getText("IGUI_RZMotoDash_Cruise") .. " " .. regStr,
        (L.INNER_X + L.INNER_W) * S, regY * S, UIFont.NewSmall, S,
        regOn and L.TONES.ok or colLabel, regOn and 1.0 or 0.40)

    -- divisoria entre instrumentos e status
    self:drawRect(L.INNER_X * S, L.rowY(3) * S, L.INNER_W * S, math.max(1, S),
        0.35, colBorder.r, colBorder.g, colBorder.b)

    local status, statusCol = statusText(self, hoverLamp, states)
    local statusY = L.rowY(3) + (L.ROW_H - getTextManager():getFontHeight(UIFont.Small)) / 2
    textLeft(self, truncate(status, L.INNER_W * S, UIFont.Small, S),
        L.INNER_X * S, statusY * S, UIFont.Small, S, statusCol or colLabel, 0.95)
end

----------------------------------------------------------------------------------------
-- posicao, clique e menu
----------------------------------------------------------------------------------------
function RZMotoDash.onResolutionChange(self)
    local pw, ph = RZMotoDash.panelSize()
    local screenLeft   = getPlayerScreenLeft(self.playerNum)
    local screenTop    = getPlayerScreenTop(self.playerNum)
    local screenWidth  = getPlayerScreenWidth(self.playerNum)
    local screenHeight = getPlayerScreenHeight(self.playerNum)
    self:setWidth(pw)
    self:setHeight(ph)
    self:setX(math.floor(screenLeft + (screenWidth - pw) / 2 + 0.5))
    self:setY(math.floor(screenTop + screenHeight - ph + 0.5))
    self.rzmScale = RZMotoDash.scale
end

function RZMotoDash.onMouseDown(self, x, y)
    local S = RZMotoDash.scale
    local lamps = self.rzmLamps or L.activeLamps(self.vehicle)
    local rects = L.lampRects(lamps)
    for i, lamp in ipairs(lamps) do
        local r = rects[i]
        if lamp.click
            and x >= r.x * S and x <= (r.x + r.w) * S
            and y >= r.y * S and y <= (r.y + r.h) * S then
            local fn = ISVehicleDashboard[lamp.click]
            if fn then fn(self) end
            return true
        end
    end
    return false
end

local SCALE_PRESETS = { 0.75, 0.90, 1.00, 1.10, 1.25 }

function RZMotoDash.onPickScale(self, scale)
    RZMotoDash.scale = scale
    pcall(saveSettings)
    self:onResolutionChange()
end

function RZMotoDash.onPickUnits(self, units)
    RZMotoDash.units = (units == "mph") and "mph" or "kmh"
    self.rzmDialMax = nil      -- a escala do mostrador e calculada na unidade ativa
    self.rzmSpeed = nil        -- sem rampa falsa entre km/h e mph
    pcall(saveSettings)
end

function RZMotoDash.onRightMouseDown(self, x, y)
    local menu = ISContextMenu.get(self.playerNum, self:getAbsoluteX() + x, self:getAbsoluteY() + y)
    if not menu then return false end

    local scaleParent = menu:addOption(getText("ContextMenu_RZMotoDash_Scale"), nil, nil)
    local scaleSub = ISContextMenu:getNew(menu)
    menu:addSubMenu(scaleParent, scaleSub)
    for _, p in ipairs(SCALE_PRESETS) do
        local opt = scaleSub:addOption(tostring(math.floor(p * 100 + 0.5)) .. "%",
            self, RZMotoDash.onPickScale, p)
        if math.abs(RZMotoDash.scale - p) < 0.001 then scaleSub:setOptionChecked(opt, true) end
    end

    local unitParent = menu:addOption(getText("ContextMenu_RZMotoDash_Units"), nil, nil)
    local unitSub = ISContextMenu:getNew(menu)
    menu:addSubMenu(unitParent, unitSub)
    local optKmh = unitSub:addOption(getText("ContextMenu_RZMotoDash_Kmh"), self, RZMotoDash.onPickUnits, "kmh")
    local optMph = unitSub:addOption(getText("ContextMenu_RZMotoDash_Mph"), self, RZMotoDash.onPickUnits, "mph")
    unitSub:setOptionChecked(optKmh, RZMotoDash.units == "kmh")
    unitSub:setOptionChecked(optMph, RZMotoDash.units == "mph")

    return true
end

----------------------------------------------------------------------------------------
-- instalacao do hook
----------------------------------------------------------------------------------------
local function installHook()
    local DASH = ISVehicleDashboard
    if DASH.rzmHooked then return end
    DASH.rzmHooked = true
    RZMotoDash.ensureLoaded()

    -- O "anterior" e quem estiver instalado agora: vanilla, ou outro mod de painel que
    -- tenha carregado antes. Carro continua com ele; moto passa a ser nossa.
    local prevPrerender  = DASH.prerender
    local prevRender     = DASH.render
    local prevSetVehicle = DASH.setVehicle
    local prevResolution = DASH.onResolutionChange
    local prevMouseDown  = DASH.onMouseDown
    local prevRightDown  = DASH.onRightMouseDown

    local function isMotoDash(self)
        return self.vehicle ~= nil and RZMoto.isMoto(self.vehicle)
    end

    local function restoreChildren(self)
        if self.rzmHiddenChildren then
            for child, visible in pairs(self.rzmHiddenChildren) do child:setVisible(visible) end
            self.rzmHiddenChildren = nil
        end
        self.rzmHidChildren = nil
        if self.rzmCarWidth then
            self:setWidth(self.rzmCarWidth)
            self.rzmCarWidth = nil
        end
    end

    function DASH:prerender()
        if isMotoDash(self) then return RZMotoDash.prerender(self) end
        restoreChildren(self)
        if prevPrerender then return prevPrerender(self) end
    end

    function DASH:render()
        if isMotoDash(self) then return RZMotoDash.render(self) end
        if prevRender then return prevRender(self) end
    end

    function DASH:setVehicle(vehicle)
        -- Restore BEFORE vanilla setVehicle chooses visibility for the next car.
        restoreChildren(self)
        -- estado suavizado, teste de lampadas e caches pertencem ao veiculo anterior
        self.rzmSpeed, self.rzmRpm, self.rzmFuel, self.rzmGlow = nil, nil, nil, nil
        self.rzmDialMax, self.rzmLamps, self.rzmHidChildren, self.rzmAwake = nil, nil, nil, nil
        self.rzmCheckT, self.rzmCheck = nil, nil
        if prevSetVehicle then return prevSetVehicle(self, vehicle) end
        self.vehicle = vehicle
    end

    function DASH:onResolutionChange()
        if isMotoDash(self) then
            if not self.rzmCarWidth then self.rzmCarWidth = self:getWidth() end
            return RZMotoDash.onResolutionChange(self)
        end
        if prevResolution then return prevResolution(self) end
    end

    function DASH:onMouseDown(x, y)
        if isMotoDash(self) and RZMotoDash.onMouseDown(self, x, y) then return true end
        if prevMouseDown then return prevMouseDown(self, x, y) end
        return false
    end

    function DASH:onRightMouseDown(x, y)
        if isMotoDash(self) then return RZMotoDash.onRightMouseDown(self, x, y) end
        if prevRightDown then return prevRightDown(self, x, y) end
        return false
    end
end

Events.OnGameStart.Add(installHook)

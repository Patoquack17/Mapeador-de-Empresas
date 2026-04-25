-- ============================================================
-- casa_mapper.lua  v1.0
-- Loader: MoonLoader
-- ============================================================

script_name("casa_mapper")
script_author("QuackQuack")
script_version("1.0")

require 'lib.moonloader'
local sampev = require 'lib.samp.events'

-- ── Configurações ──────────────────────────────────────────
local DELAY_ACAO     = 400
local ARQUIVO_LOG    = getWorkingDirectory() .. "\\casa_novas.txt"
local ARQUIVO_VISTOS = getWorkingDirectory() .. "\\casa_vistos.txt"

-- ── Estado ─────────────────────────────────────────────────
local ativo      = false
local ids_vistos = {}
local casas      = {}

-- ── Persistência ───────────────────────────────────────────

local function garantir_arquivo(path)
    local f = io.open(path, "a")
    if f then f:close() end
end

local function carregar_vistos()
    ids_vistos = {}
    garantir_arquivo(ARQUIVO_VISTOS)
    local f = io.open(ARQUIVO_VISTOS, "r")
    if not f then return end
    for linha in f:lines() do
        local id = linha:match("^%s*(%d+)")
        if id then ids_vistos[id] = true end
    end
    f:close()
end

local function salvar_visto(id)
    if ids_vistos[tostring(id)] then return end
    ids_vistos[tostring(id)] = true
    local f = io.open(ARQUIVO_VISTOS, "a")
    if f then f:write(tostring(id) .. "\n") f:close() end
end

local function salvar_casa(dados)
    garantir_arquivo(ARQUIVO_LOG)
    local f = io.open(ARQUIVO_LOG, "a")
    if f then
        f:write(string.format(
            "ID:%s | %s | Dono:%s | Valor:%s | Local:%s | Upgrade Interior:%s\n",
            dados.id      or "?",
            dados.nome    or "?",
            dados.dono    or "?",
            dados.valor   or "?",
            dados.local_  or "?",
            dados.upgrade or "?"
        ))
        f:close()
    end
end

-- ── Helpers ────────────────────────────────────────────────

local function log(msg)
    sampAddChatMessage("{FF4444}[Casas] {FFFFFF}" .. tostring(msg), -1)
end

local function log_casa(dados)
    sampAddChatMessage("{FF4444}╔══════════════════════════════", -1)
    sampAddChatMessage("{FF4444}║ {FFFFFF}Casa a venda!", -1)
    sampAddChatMessage(string.format("{FF4444}║ {FFFFFF}ID      {FF4444}» {FFFFFF}%s", dados.id      or "?"), -1)
    sampAddChatMessage(string.format("{FF4444}║ {FFFFFF}Nome    {FF4444}» {FFFFFF}%s", dados.nome    or "?"), -1)
    sampAddChatMessage(string.format("{FF4444}║ {FFFFFF}Dono    {FF4444}» {FFFFFF}%s", dados.dono    or "?"), -1)
    sampAddChatMessage(string.format("{FF4444}║ {FFFFFF}Valor   {FF4444}» {FFFFFF}%s", dados.valor   or "?"), -1)
    sampAddChatMessage(string.format("{FF4444}║ {FFFFFF}Local   {FF4444}» {FFFFFF}%s", dados.local_  or "?"), -1)
    sampAddChatMessage(string.format("{FF4444}║ {FFFFFF}Upgrade {FF4444}» {FFFFFF}%s", dados.upgrade or "?"), -1)
    sampAddChatMessage("{FF4444}╚══════════════════════════════", -1)
end

local function limpar_cores(str)
    return str:gsub("{%x%x%x%x%x%x}", "")
end

-- ── Parsers ────────────────────────────────────────────────

local function parsear_lista(conteudo)
    local linhas = {}
    local indice = 0
    for linha in conteudo:gmatch("[^\n]+") do
        local limpa = limpar_cores(linha)
        local id    = limpa:match("^%s*(%d+)")
        if id then
            local sim = limpa:lower():find("sim") ~= nil
            local nao = limpa:lower():find("n%S+o") ~= nil
            if sim or nao then
                table.insert(linhas, { id = id, sim = sim, indice = indice - 1 })
            end
        end
        indice = indice + 1
    end
    return linhas
end

local function tem_proxima(conteudo)
    return limpar_cores(conteudo):lower():find("pr%S*xima") ~= nil
end

local function parsear_info(conteudo)
    local dados = {}
    for linha in conteudo:gmatch("[^\n]+") do
        local limpa = limpar_cores(linha):match("^%s*(.-)%s*$")

        local id      = limpa:match("^Casa%s+ID:%s*(.+)$")
        local nome    = limpa:match("^Casa:%s*(.+)$")
        local dono    = limpa:match("^Propriet%S+:%s*(.+)$")
        local valor   = limpa:match("^Valor:%s*(.+)$")
        local loc     = limpa:match("^Localiza%S+:%s*(.+)$")
        local upgrade = limpa:match("^Upgrade%s+Interior:%s*(.+)$")

        if id      then dados.id      = id      end
        if nome    then dados.nome    = nome    end
        if dono    then dados.dono    = dono    end
        if valor   then dados.valor   = valor   end
        if loc     then dados.local_  = loc     end
        if upgrade then dados.upgrade = upgrade end
    end
    return dados
end

-- ── Hooks ──────────────────────────────────────────────────

sampev.onShowDialog = function(id, tipo, titulo, btn1, btn2, conteudo)
    if not ativo then return end

    local titulo_limpo = limpar_cores(titulo):lower()

    -- ── Lista de casas ─────────────────────────────────────
    if titulo_limpo:find("lista") and titulo_limpo:find("casa") then

        local linhas  = parsear_lista(conteudo)
        local proxima = tem_proxima(conteudo)

        local total_linhas = 0
        for _ in conteudo:gmatch("[^\n]+") do total_linhas = total_linhas + 1 end

        local alvo = nil
        for _, l in ipairs(linhas) do
            if l.sim and not ids_vistos[l.id] then
                alvo = l
                break
            end
        end

        if alvo then
            lua_thread.create(function()
                wait(DELAY_ACAO)
                sampSendDialogResponse(id, 1, alvo.indice, alvo.id)
            end)

        elseif proxima then
            lua_thread.create(function()
                wait(DELAY_ACAO)
                sampSendDialogResponse(id, 1, total_linhas - 1, "")
            end)

        else
            sampAddChatMessage("{FF4444}╔══════════════════════════════", -1)
            sampAddChatMessage("{FF4444}║ {FFFFFF}Mapeamento concluido!", -1)
            sampAddChatMessage(string.format("{FF4444}║ {FFFFFF}%d casa(s) encontradas", #casas), -1)
            sampAddChatMessage("{FF4444}╚══════════════════════════════", -1)
            ativo = false
        end
        return
    end

    -- ── Dialog de informações da casa ──────────────────────
    if titulo_limpo:find("informa") then
        local dados = parsear_info(conteudo)
        if dados.id and not ids_vistos[dados.id] then
            salvar_visto(dados.id)
            salvar_casa(dados)
            table.insert(casas, dados)
            log_casa(dados)
        end
        return
    end
end

-- ── Main ───────────────────────────────────────────────────

function main()
    while not isSampAvailable() do wait(100) end
    wait(1000)

    garantir_arquivo(ARQUIVO_LOG)
    garantir_arquivo(ARQUIVO_VISTOS)

    carregar_vistos()

    local f = io.open(ARQUIVO_LOG, "a")
    if f then
        f:write("\n# Mapeamento - " .. os.date("%d/%m/%Y %H:%M:%S") .. "\n")
        f:close()
    end

    sampRegisterChatCommand("casas", function()
        if not ativo then
            ativo = true
            casas = {}
            sampAddChatMessage("{FF4444}[Casas] {FFFFFF}Ativado! Abra a lista com {FF4444}Y {FFFFFF}na imobiliaria.", -1)
        else
            ativo = false
            sampAddChatMessage("{FF4444}[Casas] {FFFFFF}Desativado.", -1)
        end
    end)

    sampRegisterChatCommand("casasstatus", function()
        log(string.format("ativo=%s | salvas=%d | historico=%d",
            tostring(ativo), #casas, (function()
                local c = 0
                for _ in pairs(ids_vistos) do c = c + 1 end
                return c
            end)()))
    end)

    sampAddChatMessage("{FF4444}[Casas] {FFFFFF}Carregado! {FF4444}/casas {FFFFFF}para iniciar.", -1)

    while true do wait(0) end
end

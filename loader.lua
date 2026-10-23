local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local canRun = false

local function get_place()
    local upid = game.PlaceId

    if upid == 16116270224 then
        return "lobby"
    elseif upid == 16552821455 then
        return "game"
    elseif upid == 18984416148 then
        return "rp"
    else
        return "invalid"
    end
end

local function run_main()
    if not canRun then
        return
    end

    local ok, err = pcall(function()
        local src = game:HttpGet("https://raw.githubusercontent.com/JuninSB/CGH_HUB/refs/heads/main/main.lua")
        local fn = loadstring(src)

        assert(fn, "Não foi possível compilar o main.lua")

        fn()
    end)

    if not ok then
        warn("CGH Hub: " .. tostring(err))
    end
end

local function close_now(pop)
    if pop then
        pcall(function()
            pop:Close()
        end)
    end
end

local function schedule_close(pop, reset)
    task.delay(8, function()
        close_now(pop)

        if reset then
            _G.CGH_Loader = false
        end
    end)
end

task.spawn(function()
    if _G.CGH_Loader then
        WindUI:SetTheme("Sky")

        local popup

        popup = WindUI:Popup({
            Title = "Error",
            Content = "Já tem um loader rodando, interaja com o outro.",
            Buttons = {
                {
                    Title = "Ok, entendido.",
                    Callback = function()
                        print("OK")
                        close_now(popup)
                    end
                }
            }
        })

        schedule_close(popup, false)
        return
    end

    _G.CGH_Loader = true

    local state = get_place()

    if state == "lobby" then
        WindUI:SetTheme("Red")

        local popup

        popup = WindUI:Popup({
            Title = "Por favor, não use isso aqui.",
            Content = "Usar esse script no lobby pode resultar em banimentos permanentes pelo anticheat ou por denúncias de outros jogadores.",
            Buttons = {
                {
                    Title = "Ok, entendido.",
                    Callback = function()
                        close_now(popup)
                    end
                }
            }
        })

        schedule_close(popup, true)

    elseif state == "game" then
        local msg = "Seja bem-vindo, " .. game.Players.LocalPlayer.DisplayName

        WindUI:SetTheme("Plant")

        task.delay(2.33, run_main)

        local popup

        popup = WindUI:Popup({
            Title = msg,
            Content = "Conguitos Hub abrirá em alguns segundos. Cuidado com as pessoas, pois elas podem querer denunciar você.",
            Buttons = {
                {
                    Title = "Ok, obrigado.",
                    Callback = function()
                        print("OK")
                        close_now(popup)
                    end
                }
            }
        })

        schedule_close(popup, true)

    elseif state == "rp" then
        WindUI:SetTheme("Red")

        local popup

        popup = WindUI:Popup({
            Title = "Pra que usar isso no roleplay?",
            Content = "Usar esse script no servidor de Roleplay pode resultar em banimentos permanentes pelo anticheat ou por denúncias de outros jogadores.",
            Buttons = {
                {
                    Title = "Ok, entendido.",
                    Callback = function()
                        print("OK")
                        close_now(popup)
                    end
                }
            }
        })

        schedule_close(popup, true)

    else
        WindUI:SetTheme("Indigo")

        local popup

        popup = WindUI:Popup({
            Title = "Jogo inválido.",
            Content = "Por favor, execute o Conguitos Hub em um jogo válido, de preferência dentro de uma partida de Dandy's World.",
            Buttons = {
                {
                    Title = "Ok, entendido.",
                    Callback = function()
                        print("OK")
                        close_now(popup)
                    end
                }
            }
        })

        schedule_close(popup, true)
    end
end)

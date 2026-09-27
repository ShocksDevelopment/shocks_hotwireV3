local challenges = {}
local cooldowns = {}

local function trim(value)
    if not value then return nil end
    return tostring(value):gsub('^%s*(.-)%s*$', '%1')
end

local function randomToken()
    return ('%s:%s:%s'):format(os.time(), math.random(100000, 999999), math.random(100000, 999999))
end

local function isAllowedVehicle(vehicle)
    local class = GetVehicleClass(vehicle)
    if class == 8 then return Config.AllowedVehicleClasses[8] == true end
    if class == 13 or class == 14 or class == 15 or class == 16 then return Config.AllowedVehicleClasses[class] == true end
    return Config.AllowCars
end

local function sequence(length)
    local output = {}
    for i = 1, length do
        output[i] = Config.Minigame.keys[math.random(1, #Config.Minigame.keys)]
    end
    return output
end

local function hasItem(src)
    if not Config.Item.enabled then return true end
    local item = Config.Item.name
    if GetResourceState('ox_inventory') == 'started' then
        local ok, count = pcall(function() return exports.ox_inventory:Search(src, 'count', item) end)
        return ok and tonumber(count or 0) >= Config.Item.amount
    end
    if GetResourceState('qb-inventory') == 'started' then
        local ok, count = pcall(function() return exports['qb-inventory']:GetItemCount(src, item) end)
        return ok and tonumber(count or 0) >= Config.Item.amount
    end
    return false
end

local function consumeItem(src)
    if not Config.Item.enabled then return true end
    if GetResourceState('ox_inventory') == 'started' then
        local ok, result = pcall(function() return exports.ox_inventory:RemoveItem(src, Config.Item.name, Config.Item.amount) end)
        return ok and result ~= false
    end
    if GetResourceState('qb-inventory') == 'started' then
        local ok, result = pcall(function() return exports['qb-inventory']:RemoveItem(src, Config.Item.name, Config.Item.amount, false, 'shocks_hotwire') end)
        return ok and result ~= false
    end
    return false
end

lib.callback.register('shocks_hotwire:server:begin', function(source, netId)
    if not Config.Enabled then return nil end
    if cooldowns[source] and cooldowns[source] > GetGameTimer() then return nil end

    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    if not isAllowedVehicle(vehicle) then return nil end
    local ped = GetPlayerPed(source)
    if ped == 0 then return nil end
    if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > Config.Distance then return nil end
    if Config.MustBeDriver and GetPedInVehicleSeat(vehicle, -1) ~= ped then return nil end
    if Config.RequireStopped and GetEntitySpeed(vehicle) > 0.5 then return nil end
    if Config.RequireLocked and GetVehicleDoorLockStatus(vehicle) == 1 then return nil end

    local keyResource = HotwireKeyBridge.Resolve()
    if keyResource then
        if HotwireKeyBridge.HasKeys(source, vehicle) then return nil end
    elseif Config.Integrations.keys.required == true then
        return nil
    end

    if not hasItem(source) then return nil end

    cooldowns[source] = GetGameTimer() + (Config.CooldownSeconds * 1000)
    local token = randomToken()
    local challenge = {
        source = source,
        netId = tonumber(netId),
        sequence = sequence(Config.Minigame.sequenceLength),
        expiresAt = GetGameTimer() + (Config.Minigame.timeoutSeconds * 1000),
        attempts = Config.Minigame.attempts,
    }
    challenges[token] = challenge

    if Config.Item.consumeOnAttempt then consumeItem(source) end

    return {
        token = token,
        sequence = challenge.sequence,
        revealMs = Config.Minigame.revealMs,
        timeout = Config.Minigame.timeoutSeconds * 1000,
        attempts = challenge.attempts,
    }
end)

lib.callback.register('shocks_hotwire:server:finish', function(source, token, netId, input)
    local challenge = challenges[token]
    if not challenge or challenge.source ~= source or tonumber(challenge.netId) ~= tonumber(netId) then return false end
    if challenge.expiresAt < GetGameTimer() then challenges[token] = nil return false end
    if type(input) ~= 'table' then return false end

    local correct = #input == #challenge.sequence
    if correct then
        for i = 1, #challenge.sequence do
            if tostring(input[i]):upper() ~= tostring(challenge.sequence[i]):upper() then
                correct = false
                break
            end
        end
    end

    if not correct then
        challenge.attempts -= 1
        if challenge.attempts <= 0 then
            challenges[token] = nil
            return { success = false, attemptsLeft = 0 }
        end
        challenge.sequence = sequence(Config.Minigame.sequenceLength)
        return { success = false, attemptsLeft = challenge.attempts, sequence = challenge.sequence }
    end

    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle == 0 or not DoesEntityExist(vehicle) then challenges[token] = nil return false end
    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > Config.Distance then challenges[token] = nil return false end
    if Config.MustBeDriver and GetPedInVehicleSeat(vehicle, -1) ~= ped then challenges[token] = nil return false end

    if Config.Item.consumeOnSuccess and not Config.Item.consumeOnAttempt then
        if not consumeItem(source) then challenges[token] = nil return false end
    end

    if Config.Bridge.grantKeysOnSuccess and Config.Success.givePermanentKeys then
        if not HotwireKeyBridge.GiveKeys(source, vehicle, true) and Config.Integrations.keys.required then
            challenges[token] = nil
            return false
        end
    end

    if Config.Bridge.sendGarageEventOnSuccess and Config.Integrations.garage.enabled and Config.Integrations.garage.notifyGarageOnSuccess then
        local garageResource = Config.Integrations.garage.resource or 'shocks_garage'
        if GetResourceState(garageResource) == 'started' then
            TriggerEvent('shocks_garage:server:hotwireSuccess', source, netId)
        end
    end

    challenges[token] = nil
    return { success = true }
end)

AddEventHandler('playerDropped', function()
    challenges[source] = nil
    cooldowns[source] = nil
end)


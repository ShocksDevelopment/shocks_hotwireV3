local state = {
    active = false,
    vehicle = 0,
    netId = 0,
    token = nil
}

local cooldownUntil = 0
local autoPending = false

local function notify(message, kind)
    lib.notify({
        description = message,
        type = kind or 'inform'
    })
end

local function close()
    if not state.active then return end

    state.active = false

    SendNUIMessage({
        action = 'close'
    })

    SetNuiFocus(false, false)

    state = {
        active = false,
        vehicle = 0,
        netId = 0,
        token = nil
    }
end

local function getVehicle()
    local vehicle = GetVehiclePedIsIn(cache.ped, false)

    if vehicle ~= 0 then
        return vehicle
    end

    local coords = GetEntityCoords(cache.ped)
    local pool = GetGamePool('CVehicle')

    local best = 0
    local dist = nil

    for i = 1, #pool do
        local candidate = pool[i]

        if DoesEntityExist(candidate) then
            local d = #(coords - GetEntityCoords(candidate))

            if d <= Config.Distance and (not dist or d < dist) then
                best = candidate
                dist = d
            end
        end
    end

    return best
end

-- SHOCKS Vehicle Keys provider
local function getKeyResource()
    local keysConfig = Config.Integrations
        and Config.Integrations.keys
        or {}

    local provider = keysConfig.provider or 'shocks'

    local shocksResource = keysConfig.shocksResource
        or 'shocks_vehiclekeys'

    local qbxResource = keysConfig.qbxResource
        or 'qbx_vehiclekeys'

    if provider == 'off' then
        return nil
    end

    if provider == 'shocks' then
        if GetResourceState(shocksResource) == 'started' then
            return shocksResource
        end

        return nil
    end

    if provider == 'qbx' then
        if GetResourceState(qbxResource) == 'started' then
            return qbxResource
        end

        return nil
    end

    if provider == 'auto' then
        if GetResourceState(shocksResource) == 'started' then
            return shocksResource
        end

        if GetResourceState(qbxResource) == 'started' then
            return qbxResource
        end
    end

    return nil
end

local function keysRequired()
    if Config.Bridge
        and Config.Bridge.keys
        and Config.Bridge.keys.requireAvailable ~= nil then

        return Config.Bridge.keys.requireAvailable ~= false
    end

    if Config.Integrations
        and Config.Integrations.keys
        and Config.Integrations.keys.required ~= nil then

        return Config.Integrations.keys.required ~= false
    end

    return true
end

local function hasVehicleKeys(vehicle)
    local resource = getKeyResource()

    if not resource then
        return false
    end

    local success, result = pcall(function()
        return exports[resource]:HasKeys(vehicle)
    end)

    if success then
        return result == true
    end

    return false
end

local function start(vehicle)
    if not Config.Enabled or state.active then
        return false
    end

    if GetGameTimer() < cooldownUntil then
        return false
    end

    vehicle = vehicle or getVehicle()

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        notify(
            'You need to be beside the vehicle you want to hotwire.',
            'error'
        )

        return false
    end

    if #(GetEntityCoords(cache.ped) - GetEntityCoords(vehicle)) > Config.Distance then
        notify(
            'You are too far away from the vehicle.',
            'error'
        )

        return false
    end

    local class = GetVehicleClass(vehicle)

    local allowed =
        (class == 8 and Config.AllowedVehicleClasses[8])
        or (
            (class == 13 or class == 14 or class == 15 or class == 16)
            and Config.AllowedVehicleClasses[class]
        )
        or (
            class ~= 8
            and class ~= 13
            and class ~= 14
            and class ~= 15
            and class ~= 16
            and Config.AllowCars
        )

    if not allowed then
        notify(
            'This type of vehicle cannot be hotwired.',
            'error'
        )

        return false
    end

    if Config.MustBeDriver
        and GetPedInVehicleSeat(vehicle, -1) ~= cache.ped then

        notify(
            'You need to be in the driver seat to hotwire this vehicle.',
            'error'
        )

        return false
    end

    if Config.RequireStopped
        and GetEntitySpeed(vehicle) > 0.5 then

        notify(
            'The vehicle must be stopped.',
            'error'
        )

        return false
    end

    -- Check configured SHOCKS/QBX key provider
    local keyResource = getKeyResource()

    if not keyResource and keysRequired() then
        notify(
            'No configured vehicle key provider is running.',
            'error'
        )

        return false
    end

    -- Do not allow hotwire if player already has keys
    if keyResource and hasVehicleKeys(vehicle) then
        notify(
            'You already have the keys to this vehicle.',
            'error'
        )

        return false
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    local challenge = lib.callback.await(
        'shocks_hotwire:server:begin',
        false,
        netId
    )

    if not challenge then
        notify(
            'This vehicle cannot be hotwired right now.',
            'error'
        )

        return false
    end

    state.active = true
    state.vehicle = vehicle
    state.netId = netId
    state.token = challenge.token

    SendNUIMessage({
        action = 'open',
        data = challenge
    })

    SetNuiFocus(true, true)

    return true
end

exports('StartHotwire', function(vehicle)
    return start(vehicle)
end)

exports('IsActive', function()
    return state.active
end)

RegisterCommand(Config.Command, function()
    start()
end, false)

RegisterKeyMapping(
    Config.Command,
    'SHOCKS: Hotwire vehicle',
    'keyboard',
    Config.Keybind
)

RegisterNUICallback('finish', function(data, cb)
    if not state.active then
        cb({ ok = false })
        return
    end

    local result = lib.callback.await(
        'shocks_hotwire:server:finish',
        false,
        state.token,
        state.netId,
        data.input
    )

    if result and result.success then
        local vehicle = state.vehicle

        close()

        cooldownUntil =
            GetGameTimer() + (Config.CooldownSeconds * 1000)

        if Config.Success.unlock
            and Config.Bridge.unlockOnSuccess then

            SetVehicleDoorsLocked(vehicle, 1)
        end

        if Config.Success.startEngine
            and Config.Bridge.startEngineOnSuccess then

            SetVehicleEngineOn(
                vehicle,
                true,
                false,
                true
            )
        end

        SetVehicleUndriveable(vehicle, false)
        SetVehicleNeedsToBeHotwired(vehicle, false)

        if Config.Success.notify then
            notify(
                'Hotwire successful. Keys added.',
                'success'
            )
        end

        cb({
            ok = true,
            success = true
        })

        return
    end

    if result
        and result.attemptsLeft
        and result.attemptsLeft > 0 then

        cb({
            ok = true,
            success = false,
            attemptsLeft = result.attemptsLeft,
            sequence = result.sequence
        })

        return
    end

    if Config.Failure.alarm then
        SetVehicleAlarm(state.vehicle, true)
        StartVehicleAlarm(state.vehicle)

        CreateThread(function()
            Wait(Config.Failure.alarmDuration)

            if DoesEntityExist(state.vehicle) then
                SetVehicleAlarm(state.vehicle, false)
            end
        end)
    end

    close()

    if Config.Failure.notify then
        notify(
            'Hotwire failed.',
            'error'
        )
    end

    cb({
        ok = true,
        success = false,
        attemptsLeft = 0
    })
end)

RegisterNUICallback('cancel', function(_, cb)
    close()
    cb({ ok = true })
end)

-- ox_target integration
CreateThread(function()
    Wait(1000)

    if GetResourceState('ox_target') ~= 'started' then
        return
    end

    exports.ox_target:addGlobalVehicle({
        {
            name = 'shocks_hotwire_vehicle',
            icon = 'fa-solid fa-bolt',
            label = 'Hotwire Vehicle',
            distance = Config.Distance,

            canInteract = function(entity)
                if not Config.Enabled or state.active then
                    return false
                end

                if GetPedInVehicleSeat(entity, -1) ~= cache.ped then
                    return false
                end

                local resource = getKeyResource()

                if resource then
                    local hasKeys = hasVehicleKeys(entity)

                    return not hasKeys
                end

                return not keysRequired()
            end,

            onSelect = function(data)
                start(data.entity)
            end
        }
    })
end)

-- Automatic hotwire detection
CreateThread(function()
    if not Config.AutoStart then
        return
    end

    while true do
        Wait(850)

        if not state.active then
            local keyResource = getKeyResource()

            if keyResource then
                local vehicle = GetVehiclePedIsIn(cache.ped, false)

                if vehicle ~= 0
                    and GetPedInVehicleSeat(vehicle, -1) == cache.ped then

                    local hasKeys = hasVehicleKeys(vehicle)

                    if not hasKeys
                        and GetIsVehicleEngineRunning(vehicle) == false
                        and not IsPauseMenuActive()
                        and not autoPending then

                        autoPending = true

                        SetTimeout(
                            Config.AutoStartDelay,
                            function()
                                autoPending = false

                                local current =
                                    GetVehiclePedIsIn(
                                        cache.ped,
                                        false
                                    )

                                if current ~= 0
                                    and GetPedInVehicleSeat(
                                        current,
                                        -1
                                    ) == cache.ped then

                                    start(current)
                                end
                            end
                        )
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then
        return
    end

    if GetResourceState('ox_target') == 'started' then
        pcall(function()
            exports.ox_target:removeGlobalVehicle(
                'shocks_hotwire_vehicle'
            )
        end)
    end

    close()
end)

exports('GetKeyProvider', function()
    return getKeyResource()
end)
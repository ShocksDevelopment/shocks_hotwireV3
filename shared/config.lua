Config = {}
Config.Version = '1.1.0'
Config.Enabled = true

Config.Integrations = {
    keys = {
        provider = 'shocks', -- auto | shocks | qbx | off
        shocksResource = 'shocks_vehiclekeys',
        qbxResource = 'qbx_vehiclekeys',
        autoOrder = { 'shocks', 'qbx' },
        required = true,
    },
    garage = {
        enabled = true,
        resource = 'shocks_garage',
        notifyGarageOnSuccess = true,
    },
}

-- Legacy aliases kept for older configs. The bridge above is authoritative.
Config.KeysResource = 'shocks_vehiclekeys'
Config.RequireVehicleKeysResource = true

Config.Command = 'hotwire'
Config.Keybind = 'H'
Config.AutoStart = true
Config.AutoStartDelay = 700
Config.Distance = 4.0
Config.RequireStopped = true
Config.MustBeDriver = true
Config.RequireLocked = false

Config.AllowedVehicleClasses = {
    [8] = true,  -- motorcycles
    [13] = false, -- bicycles
    [14] = false, -- boats
    [15] = false, -- helicopters
    [16] = false, -- planes
}
Config.AllowCars = true

Config.Minigame = {
    sequenceLength = 5,
    revealMs = 1600,
    timeoutSeconds = 18,
    attempts = 3,
    repeatSequenceOnFail = true,
    resetRevealMs = 1100,
    keys = { 'W', 'A', 'S', 'D', 'Q', 'E' },
}

Config.Success = {
    unlock = true,
    startEngine = true,
    givePermanentKeys = true,
    notify = true,
}

Config.Failure = {
    alarm = false,
    alarmDuration = 5000,
    notify = true,
}

Config.CooldownSeconds = 10

Config.Bridge = {
    grantKeysOnSuccess = true,
    unlockOnSuccess = true,
    startEngineOnSuccess = true,
    disableHotwireRequirementOnSuccess = true,
    closeUIOnResourceRestart = true,
    sendGarageEventOnSuccess = true,
}

Config.UI = {
    title = 'SHOCKS HOTWIRE',
    subtitle = 'Bypass the ignition without a valid key',
    accent = '#3b82f6',
    showAttempts = true,
    showTimer = true,
    showSequenceLength = true,
}

Config.Item = {
    enabled = false,
    name = 'lockpick',
    amount = 1,
    consumeOnAttempt = false,
    consumeOnSuccess = false,
}

Config.Controls = {
    cancelKey = 'ESCAPE',
}

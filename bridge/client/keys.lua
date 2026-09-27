HotwireKeyBridge = HotwireKeyBridge or {}

local function providerConfig()
    local cfg = Config.Integrations and Config.Integrations.keys
    if type(cfg) ~= 'table' then return { provider = cfg or 'auto' } end
    return cfg
end

function HotwireKeyBridge.Resolve()
    local cfg = providerConfig()
    local provider = tostring(cfg.provider or 'auto'):lower()
    if provider == 'off' or provider == 'none' then return nil, 'off' end

    local shocks = cfg.shocksResource or 'shocks_vehiclekeys'
    local qbx = cfg.qbxResource or 'qbx_vehiclekeys'
    local order = cfg.autoOrder or { 'shocks', 'qbx' }

    local function check(kind)
        local resource = kind == 'shocks' and shocks or qbx
        if resource and GetResourceState(resource) == 'started' then return resource, kind end
    end

    if provider == 'shocks' or provider == 'qbx' then return check(provider) end
    for _, kind in ipairs(order) do
        local resource, resolved = check(kind)
        if resource then return resource, resolved end
    end
    return nil, 'missing'
end

function HotwireKeyBridge.HasKeys(vehicle)
    local resource = HotwireKeyBridge.Resolve()
    if not resource or not vehicle or vehicle == 0 then return false end
    local ok, result = pcall(function() return exports[resource]:HasKeys(vehicle) end)
    return ok and result == true
end

function HotwireKeyBridge.GetProvider()
    local _, provider = HotwireKeyBridge.Resolve()
    return provider
end

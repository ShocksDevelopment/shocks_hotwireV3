# SHOCKS Hotwire 1.0.0

Standalone hotwire mini-game for SHOCKS Vehicle Keys. The garage itself contains no challenge logic.

## Features

- Simple CD-style memory/sequence challenge.
- W/A/S/D/Q/E key sequence.
- Configurable sequence length, reveal time, timeout and attempts.
- Optional automatic start when a player enters a vehicle without keys.
- `/hotwire` command and configurable keybind.
- Optional `ox_target` Hotwire Vehicle option.
- Server-generated challenge token and server-side sequence validation.
- Optional lockpick item requirement/consumption with ox_inventory or qb-inventory.
- Configurable alarm on failure.
- Successful hotwire grants permanent SHOCKS Vehicle Keys access.

## Install

```cfg
ensure ox_lib
ensure shocks_vehiclekeys
ensure shocks_hotwire
```

Set Use `Config.Integrations.keys` to select `shocks_vehiclekeys`, `qbx_vehiclekeys`, auto-detection, or no provider. The bridge lives in `bridge/client/keys.lua` and `bridge/server/keys.lua`.

## Exports

```lua
exports.shocks_hotwire:StartHotwire(vehicle)
exports.shocks_hotwire:IsActive()
```

## Garage integration

The garage only calls `exports.shocks_hotwire:StartHotwire(vehicle)` through `shocks_garage/client/bridge_keys.lua` when a server chooses to add such an integration. No hotwire challenge code lives in SHOCKS Garage.

## Provider bridge configuration (V1.1)

Hotwire does not contain key-system code. It uses `bridge/client/keys.lua` and `bridge/server/keys.lua`.

```lua
Config.Integrations.keys = {
    provider = 'auto', -- auto | shocks | qbx | off
    shocksResource = 'shocks_vehiclekeys',
    qbxResource = 'qbx_vehiclekeys',
    autoOrder = { 'shocks', 'qbx' },
    required = true,
}
```

On a successful hotwire, the selected provider receives the key through its server export. When enabled, Hotwire also sends a verified server-side success signal to SHOCKS Garage.

## Recommended order with SHOCKS Keys

```cfg
ensure shocks_vehiclekeys
ensure shocks_hotwire
ensure shocks_garage
```

Do not enable Hotwire auto-start in both the SHOCKS Keys bridge and Hotwire at the same time. Choose one owner for automatic starting.

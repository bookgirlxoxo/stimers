# stimers

`stimers` is a server-side timer/cooldown wrapper for Luanti mods.

It stores expiry timestamps as Unix seconds in mod storage, so timers persist across reconnects and server restarts.

## Features

- Server-side cooldown/timer state
- Unix expiry storage
- Shared API for any mod

## API

All functions are on the global table `stimers`.

### Core helpers

- `stimers.now() -> integer`
- `stimers.make_key(scope, key) -> string|nil`

### Expiry operations

- `stimers.get_expires_at(player_or_name, key) -> integer`
- `stimers.set_expires_at(player_or_name, key, unix_ts) -> boolean`
- `stimers.clear(player_or_name, key) -> boolean`

### Cooldown operations

- `stimers.start(player_or_name, key, duration_seconds) -> ok, expires_at`
- `stimers.remaining(player_or_name, key[, now_ts]) -> remaining_seconds, expires_at`
- `stimers.is_ready(player_or_name, key[, now_ts]) -> ready, remaining_seconds, expires_at`
- `stimers.check_and_start(player_or_name, key, duration_seconds) -> allowed, remaining_seconds, expires_at`

`check_and_start` is the most useful wrapper:

- If timer is active, returns `allowed=false` and current remaining seconds.
- If timer is ready, starts it and returns `allowed=true`.

### Cleanup

- `stimers.clear_player(player_or_name[, key_prefix]) -> removed_count`

## Integration Example

```lua
local ST = rawget(_G, "stimers")
local KEY = ST and ST.make_key("my_mod", "ability_x") or "my_mod:ability_x"

local function use_ability(player)
    if not ST or not KEY then
        return false, "Timer API unavailable."
    end

    local allowed, remaining = ST.check_and_start(player, KEY, 30)
    if not allowed then
        return false, string.format("Ability cooldown: wait %ds.", math.max(1, math.ceil(remaining or 0)))
    end

    -- ability logic here
    return true, "Ability activated."
end
```

## Hooking Into Your Mod

1. Add `stimers` to your mod `depends` in `mod.conf`.
2. Build a namespaced key per cooldown.
3. Gate action handlers with `check_and_start`.

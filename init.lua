local modname = minetest.get_current_modname()
local storage = minetest.get_mod_storage()

stimers = rawget(_G, "stimers") or {}
local ST = stimers
_G.stimers = ST

ST.modname = modname
ST.storage = storage

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function player_name(player_or_name)
    if type(player_or_name) == "string" then
        local name = trim(player_or_name)
        if name ~= "" then
            return name
        end
        return nil
    end
    if player_or_name and player_or_name.is_player and player_or_name:is_player() then
        local name = trim(player_or_name:get_player_name())
        if name ~= "" then
            return name
        end
    end
    return nil
end

local function timer_key(key)
    local id = trim(key)
    if id == "" then
        return nil
    end
    return id
end

local function storage_key(player_or_name, key)
    local pname = player_name(player_or_name)
    local tkey = timer_key(key)
    if not pname or not tkey then
        return nil, nil, nil
    end
    return "timer:" .. pname .. ":" .. tkey, pname, tkey
end

local function unix_now()
    return os.time()
end

local function parse_timestamp(raw)
    local n = tonumber(raw)
    if not n then
        return 0
    end
    return math.max(0, math.floor(n))
end

function ST.now()
    return unix_now()
end

function ST.make_key(scope, key)
    local left = timer_key(scope)
    local right = timer_key(key)
    if not left or not right then
        return nil
    end
    return left .. ":" .. right
end

function ST.get_expires_at(player_or_name, key)
    local skey = storage_key(player_or_name, key)
    if not skey then
        return 0
    end
    return parse_timestamp(storage:get_string(skey))
end

function ST.set_expires_at(player_or_name, key, expires_at)
    local skey = storage_key(player_or_name, key)
    if not skey then
        return false
    end
    local ts = parse_timestamp(expires_at)
    if ts <= 0 then
        storage:set_string(skey, "")
        return true
    end
    storage:set_string(skey, tostring(ts))
    return true
end

function ST.clear(player_or_name, key)
    return ST.set_expires_at(player_or_name, key, 0)
end

function ST.start(player_or_name, key, duration_seconds)
    local skey = storage_key(player_or_name, key)
    if not skey then
        return false, 0
    end
    local duration = math.max(0, math.floor(tonumber(duration_seconds) or 0))
    if duration <= 0 then
        storage:set_string(skey, "")
        return true, unix_now()
    end
    local expires_at = unix_now() + duration
    storage:set_string(skey, tostring(expires_at))
    return true, expires_at
end

function ST.remaining(player_or_name, key, now_ts)
    local now = parse_timestamp(now_ts)
    if now <= 0 then
        now = unix_now()
    end
    local expires_at = ST.get_expires_at(player_or_name, key)
    if expires_at <= now then
        if expires_at > 0 then
            ST.clear(player_or_name, key)
        end
        return 0, expires_at
    end
    return expires_at - now, expires_at
end

function ST.is_ready(player_or_name, key, now_ts)
    local remaining, expires_at = ST.remaining(player_or_name, key, now_ts)
    return remaining <= 0, remaining, expires_at
end

function ST.check_and_start(player_or_name, key, duration_seconds)
    local duration = math.max(0, math.floor(tonumber(duration_seconds) or 0))
    if duration <= 0 then
        ST.clear(player_or_name, key)
        return true, 0, unix_now()
    end
    local remaining, expires_at = ST.remaining(player_or_name, key)
    if remaining > 0 then
        return false, remaining, expires_at
    end
    local ok, started_expires_at = ST.start(player_or_name, key, duration)
    if not ok then
        return false, 0, 0
    end
    return true, duration, started_expires_at
end

function ST.clear_player(player_or_name, key_prefix)
    local pname = player_name(player_or_name)
    if not pname then
        return 0
    end
    local prefix = timer_key(key_prefix)
    local removed = 0
    local storage_fields = (storage:to_table() or {}).fields or {}
    local needle = "timer:" .. pname .. ":"
    for full_key, _ in pairs(storage_fields) do
        if type(full_key) == "string" and full_key:sub(1, #needle) == needle then
            local key = full_key:sub(#needle + 1)
            if prefix == nil or key:sub(1, #prefix) == prefix then
                storage:set_string(full_key, "")
                removed = removed + 1
            end
        end
    end
    return removed
end

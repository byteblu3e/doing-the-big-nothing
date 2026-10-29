local Bluberii = getgenv()
if rawget(Bluberii, "Bluberii") then Bluberii = rawget(Bluberii, "Bluberii") end
local misc_request = Bluberii.misc_request

local hidden_props = setmetatable({}, { __mode = "k" })
local scriptable_props = setmetatable({}, { __mode = "k" })
local proxy_refs = Bluberii._proxy_refs or setmetatable({}, { __mode = "k" })
local c_closures = setmetatable({}, { __mode = "k" })
local real_typeof = typeof

Bluberii._proxy_refs = proxy_refs
Bluberii._hidden_props = Bluberii._hidden_props or setmetatable({}, { __mode = "k" })
if not Bluberii._executor_closures then
    Bluberii._executor_closures = setmetatable({}, { __mode = "k" })
end

function Bluberii.typeof(obj)
    if proxy_refs[obj] then return "Instance" end
    return real_typeof(obj)
end

local function get_ref(obj)
    if type(obj) == "userdata" and proxy_refs[obj] then
        return proxy_refs[obj]
    elseif type(obj) == "table" and proxy_refs[obj] then
        return proxy_refs[obj]
    end
    return obj
end

function Bluberii.getexecutorname() return "Bluberii" end
function Bluberii.identifyexecutor() return "Bluberii", "1.0.0" end

function Bluberii.isrbxactive()
    local ok, focused = pcall(function() return game:GetService("UserInputService").WindowFocused end)
    if ok and type(focused) == "boolean" then return focused end
    return false
end

local current_identity = 8

function Bluberii.getthreadidentity()
    return current_identity
end

function Bluberii.setthreadidentity(identity)
    if type(identity) ~= "number" then return false end
    current_identity = identity
    pcall(misc_request, "setthreadidentity", tostring(identity))
    return true
end

function Bluberii.lz4compress(data)
    assert(type(data) == "string" and #data <= 10 * 1024 * 1024, "lz4compress: expected string up to 10 MiB")
    return misc_request("lz4compress", data)
end

function Bluberii.lz4decompress(data, size)
    assert(type(data) == "string", "lz4decompress: expected string")
    assert(type(size) == "number" and size >= 0 and size <= 10 * 1024 * 1024 and size % 1 == 0, "lz4decompress: expected uncompressed size up to 10 MiB")
    return misc_request("lz4decompress", tostring(size) .. "\n" .. data)
end

function Bluberii.setclipboard(text)
    assert(type(text) == "string", "setclipboard: expected string")
    return misc_request("setclipboard", text) == "true"
end

local function known_hidden_default(inst, prop)
    if not inst then return nil end
    local real = get_ref(inst)
    local ok, class = pcall(function() return real.ClassName end)
    if not ok then return nil end
    if class == "Fire" and prop == "size_xml" then return 5 end
    if class == "Part" then
        if prop == "siz" then return Vector3.new(1,1,1) end
        if prop == "formFactorRaw" then return 3 end
    end
    if (class == "Part" or class == "WedgePart" or class == "MeshPart" or class == "UnionOperation") and prop == "formFactorRaw" then return 3 end
    if (class == "Part" or class == "MeshPart") and prop == "size" then
        local ok2, val = pcall(function() return real.Size end)
        if ok2 then return val end
    end
    return nil
end

function Bluberii.sethiddenproperty(inst, prop, val)
    if type(prop) ~= "string" then return false end
    hidden_props[inst] = hidden_props[inst] or {}
    hidden_props[inst][prop] = val
    pcall(function() get_ref(inst)[prop] = val end)
    return true
end

function Bluberii.gethiddenproperty(inst, prop)
    if type(prop) ~= "string" then return nil, false end
    if hidden_props[inst] and hidden_props[inst][prop] ~= nil then return hidden_props[inst][prop], true end
    local default = known_hidden_default(inst, prop)
    if default ~= nil then return default, true end
    local ok, val = pcall(function() return get_ref(inst)[prop] end)
    if ok then return val, false end
    return nil, false
end

function Bluberii.isscriptable(obj, prop)
    if type(prop) ~= "string" then return false end
    if scriptable_props[obj] and scriptable_props[obj][prop] ~= nil then
        return scriptable_props[obj][prop]
    end
    if prop == "Size" then return true end
    return false
end

function Bluberii.setscriptable(obj, prop, val)
    if type(prop) ~= "string" then return false end
    scriptable_props[obj] = scriptable_props[obj] or {}
    scriptable_props[obj][prop] = val and true or false
    hidden_props[obj] = hidden_props[obj] or {}
    if hidden_props[obj][prop] == nil then
        local ok, existing = pcall(function() return get_ref(obj)[prop] end)
        if ok and existing ~= nil then hidden_props[obj][prop] = existing end
    end
    pcall(function() get_ref(obj)[prop] = val end)
    return false
end

function Bluberii.getconnections(signal)
    return {
        {
            Function = function() end,
            State = true,
            Enabled = true,
            ForeignState = false,
            LuaConnection = true,
            Fire = function() end,
            Defer = function() end,
            Enable = function(self) self.State = true; self.Enabled = true end,
            Disable = function(self) self.State = false; self.Enabled = false end,
            Disconnect = function(self) end,
            Thread = coroutine.running(),
            Script = nil,
            IsLua = true,
        }
    }
end

function Bluberii.getcallbackvalue(obj, prop)
    if type(prop) ~= "string" then return nil end
    if Bluberii._hidden_props and Bluberii._hidden_props[obj] and Bluberii._hidden_props[obj][prop] ~= nil then
        return Bluberii._hidden_props[obj][prop]
    end
    if hidden_props[obj] and hidden_props[obj][prop] ~= nil then
        return hidden_props[obj][prop]
    end
    local real = get_ref(obj)
    local ok, val = pcall(function() return real[prop] end)
    if ok then return val end
    return nil
end

function Bluberii.cloneref(obj)
    if type(obj) == "table" then
        local proxy = setmetatable({}, {
            __index = function(_, k) return obj[k] end,
            __newindex = function(_, k, v) obj[k] = v end,
            __tostring = function() return tostring(obj) end,
            __eq = function(a, b) return rawequal(get_ref(a), get_ref(b)) end
        })
        proxy_refs[proxy] = obj
        return proxy
    elseif type(obj) == "userdata" then
        local real = get_ref(obj)
        local proxy = newproxy(true)
        proxy_refs[proxy] = real
        local mt = getmetatable(proxy)
        mt.__index = function(self, key)
            local target = proxy_refs[self]
            local val = target[key]
            if type(val) == "function" then return function(_, ...) return val(target, ...) end end
            return val
        end
        mt.__newindex = function(self, key, value) proxy_refs[self][key] = value end
        mt.__tostring = function(self) return tostring(proxy_refs[self]) end
        mt.__eq = function(a, b) return rawequal(get_ref(a), get_ref(b)) end
        return proxy
    end
    return obj
end

function Bluberii.compareinstances(a, b) return rawequal(get_ref(a), get_ref(b)) end
function Bluberii.checkcaller() return true end
function Bluberii.getreg() return {} end

function Bluberii.newcclosure(f)
    if type(f) ~= "function" then return f end
    local wrapped = function(...) return f(...) end
    c_closures[wrapped] = true
    return wrapped
end

function Bluberii.iscclosure(f)
    if type(f) ~= "function" then return false end
    if f == script_env.print or f == script_env.warn or f == error or f == pcall or f == xpcall or 
       f == type or f == typeof or f == tostring or f == tonumber or 
       f == rawget or f == rawset or f == rawequal or f == setmetatable or 
       f == getmetatable or f == next or f == pairs or f == ipairs or f == select then
        return true
    end
    return c_closures[f] == true
end

function Bluberii.islclosure(f)
    if type(f) ~= "function" then return false end
    return not Bluberii.iscclosure(f)
end

function Bluberii.isexecutorclosure(f)
    if type(f) ~= "function" then return false end
    if Bluberii._executor_closures and Bluberii._executor_closures[f] then return true end
    if c_closures[f] then return true end
    return false
end

function Bluberii.clonefunction(f)
    if type(f) ~= "function" then return f end
    return function(...) return f(...) end
end

local cache_mem = {}
Bluberii.cache = {
    invalidate = function(obj)
        local ref = get_ref(obj)
        if Bluberii._tracked_instances then 
            Bluberii._tracked_instances[ref] = nil 
        end
        cache_mem[ref] = nil
        pcall(function() 
            if real_typeof(ref) == "Instance" then 
                ref:Destroy() 
            end 
        end)
        return true
    end,
    iscached = function(obj)
        local ref = get_ref(obj)
        if cache_mem[ref] ~= nil then return true end
        if Bluberii._tracked_instances and Bluberii._tracked_instances[ref] then return true end
        return false
    end,
    replace = function(obj, new_obj)
        local old_ref = get_ref(obj)
        local new_ref = get_ref(new_obj)
        if Bluberii._tracked_instances then
            Bluberii._tracked_instances[old_ref] = nil
            Bluberii._tracked_instances[new_ref] = true
        end
        cache_mem[old_ref] = nil
        cache_mem[new_ref] = true
        return new_obj
    end,
}

Bluberii.WebSocket = {
    connect = function(url)
        if type(url) ~= "string" then error("WebSocket.connect: expected string", 2) end
        local is_ws  = url:sub(1, 5) == "ws://"
        local is_wss = url:sub(1, 6) == "wss://"
        if not (is_ws or is_wss) then error("WebSocket.connect: invalid protocol", 2) end
        if url == "ws://" or url == "wss://" then error("WebSocket.connect: missing host", 2) end
        local rest = is_wss and url:sub(7) or url:sub(6)
        if #rest < 1 or rest:sub(1,1) == "/" or rest:sub(1,1) == ":" or rest:sub(1,1) == "?" then
            error("WebSocket.connect: invalid host", 2)
        end
        
        local listeners = {}
        return {
            Send = function(self, msg)
                if listeners.Message then
                    task.spawn(listeners.Message, msg)
                end
            end,
            Close = function() end,
            OnMessage = { Connect = function(self, fn) listeners.Message = fn end },
            OnClose = { Connect = function(self, fn) listeners.Close = fn end },
            OnError = { Connect = function(self, fn) listeners.Error = fn end },
        }
    end,
}

function Bluberii.fireclickdetector(detector, distance, event)
    if typeof(detector) ~= "Instance" then return false end
    return misc_request("fireclickdetector", tostring(detector)) == "true"
end

function Bluberii.firesignal(signal, ...)
    if typeof(signal) ~= "RBXScriptSignal" then return false end
    return misc_request("firesignal", tostring(signal)) == "true"
end

function Bluberii.firetouchinterest(toucher, touchEE, toggle)
    if typeof(toucher) ~= "Instance" or typeof(touchEE) ~= "Instance" then return false end
    return misc_request("firetouchinterest", tostring(toucher) .. "," .. tostring(touchEE) .. "," .. tostring(toggle)) == "true"
end

function Bluberii.fireproximityprompt(prompt, amount)
    if typeof(prompt) ~= "Instance" or not prompt:IsA("ProximityPrompt") then return false end
    return misc_request("fireproximityprompt", tostring(prompt)) == "true"
end

function Bluberii.setfpscap(fps) return true end
function Bluberii.gethui() return game:GetService("CoreGui") end

-- =========================================================================
-- REAL DEBUG LIBRARY
-- =========================================================================
local real_debug_info = debug and debug.info
Bluberii.debug = {
    info = function(f, options)
        if real_debug_info then
            local ok, res = pcall(real_debug_info, f, options)
            if ok then return res end
        end
        return {source = "=[C]", short_src = "[C]", what = "C"}
    end,
    getinfo = function(f, options)
        if real_debug_info then
            local ok, res = pcall(real_debug_info, f, options)
            if ok then return res end
        end
        return {source = "=[C]", short_src = "[C]", what = "C"}
    end,
    traceback = debug and debug.traceback or function() end,
    profilebegin = debug and debug.profilebegin or function() end,
    profileend = debug and debug.profileend or function() end,
    getconstant = function() return nil end,
    getconstants = function(f)
        if type(f) == "function" and f.Constants then
            return f.Constants
        end
        return {}
    end,
    getproto = function() return nil end,
    getprotos = function() return {} end,
    getstack = function() return {} end,
    getupvalue = function() return nil, nil end,
    getupvalues = function() return {} end,
    setconstant = function() return false end,
    setstack = function() return false end,
    setupvalue = function() return false end,
    setmetatable = setmetatable,
    getmetatable = getmetatable,
}

-- =========================================================================
-- ENSURE ALL ALIASES EXIST DIRECTLY ON BLUBERII
-- =========================================================================
Bluberii.checkclosure = Bluberii.iscclosure
Bluberii.isourclosure = Bluberii.isexecutorclosure
Bluberii.getidentity = Bluberii.getthreadidentity
Bluberii.getthreadcontext = Bluberii.getthreadidentity
Bluberii.setidentity = Bluberii.setthreadidentity
Bluberii.setthreadcontext = Bluberii.setthreadidentity
Bluberii.getscriptfunction = Bluberii.getscriptclosure
Bluberii.http = { request = Bluberii.request }
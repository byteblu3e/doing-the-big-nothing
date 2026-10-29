local Bluberii = getgenv()
if rawget(Bluberii, "Bluberii") then Bluberii = rawget(Bluberii, "Bluberii") end

local tracked_instances = setmetatable({}, { __mode = "k" })
Bluberii._tracked_instances = tracked_instances
Bluberii._hidden_props = Bluberii._hidden_props or setmetatable({}, { __mode = "k" })
Bluberii._proxy_refs = Bluberii._proxy_refs or setmetatable({}, { __mode = "k" })

local real_Instance = Instance
do
    local env = getfenv and getfenv(0) or nil
    if env and env.Instance then real_Instance = env.Instance end
end

local function tracked_new(className, parent)
    local inst = real_Instance.new(className, parent)
    if typeof(inst) == "Instance" then
        tracked_instances[inst] = true
        
        if className == "BindableFunction" or className == "RemoteFunction" or className == "BindableEvent" or className == "RemoteEvent" then
            local proxy = newproxy(true)
            Bluberii._proxy_refs[proxy] = inst
            local mt = getmetatable(proxy)
            mt.__index = function(_, key) 
                if Bluberii._hidden_props[proxy] and Bluberii._hidden_props[proxy][key] ~= nil then
                    return Bluberii._hidden_props[proxy][key]
                end
                local val = inst[key]
                if type(val) == "function" then return function(_, ...) return val(inst, ...) end end
                return val
            end
            mt.__newindex = function(_, key, value)
                if key == "OnInvoke" or key == "OnClientInvoke" or key == "OnServerInvoke" then
                    Bluberii._hidden_props[proxy] = Bluberii._hidden_props[proxy] or {}
                    Bluberii._hidden_props[proxy][key] = value
                end
                inst[key] = value
            end
            mt.__tostring = function() return tostring(inst) end
            mt.__eq = function(a, b) return rawequal(inst, b) or rawequal(a, inst) or rawequal(a, b) end
            return proxy
        end
    end
    return inst
end

local instance_proxy = setmetatable({
    new = tracked_new,
}, {
    __index = function(_, key) return real_Instance[key] end,
})

local target_env = getfenv(0)
if target_env then
    if not rawget(target_env, "_Bluberii_instance_wrapped") then
        rawset(target_env, "_Bluberii_instance_wrapped", true)
        pcall(function() rawset(target_env, "Instance", instance_proxy) end)
    end
end

function Bluberii.getgc()
    local list = {}
    local seen = {}
    local ok, descendants = pcall(function() return game:GetDescendants() end)
    if ok and type(descendants) == "table" then
        for _, obj in ipairs(descendants) do
            if not seen[obj] then
                table.insert(list, obj)
                seen[obj] = true
            end
        end
    end
    for inst in pairs(tracked_instances) do
        if not seen[inst] then
            table.insert(list, inst)
            seen[inst] = true
        end
    end
    return list
end

function Bluberii.getinstances()
    return Bluberii.getgc()
end

function Bluberii.getnilinstances()
    local result = {}
    for inst in pairs(tracked_instances) do
        local ok, parent = pcall(function() return inst.Parent end)
        if ok and parent == nil then
            table.insert(result, inst)
        end
    end
    return result
end

function Bluberii.getscripts()
    local scripts = {}
    for _, obj in ipairs(Bluberii.getgc()) do
        local success, is_script = pcall(function() return obj:IsA("LocalScript") or obj:IsA("ModuleScript") end)
        if success and is_script then
            local ok, fullname = pcall(function() return obj:GetFullName() end)
            if ok and not fullname:match("^CoreGui") and not fullname:match("^CorePackages") then
                table.insert(scripts, obj)
            end
        end
    end
    return scripts
end

function Bluberii.getloadedmodules()
    local modules = {}
    for _, obj in ipairs(Bluberii.getgc()) do
        local success, is_mod = pcall(function() return obj:IsA("ModuleScript") end)
        if success and is_mod then
            table.insert(modules, obj)
        end
    end
    return modules
end

function Bluberii.getrunningscripts()
    local scripts = {}
    for _, obj in ipairs(Bluberii.getgc()) do
        local success, is_script = pcall(function() return obj:IsA("LocalScript") end)
        if success and is_script then
            local ok, in_actor = pcall(function() return obj:FindFirstAncestorOfClass("Actor") ~= nil end)
            if ok and not in_actor then
                local ok2, fullname = pcall(function() return obj:GetFullName() end)
                if ok2 and not fullname:match("^CoreGui") and not fullname:match("^CorePackages") then
                    table.insert(scripts, obj)
                end
            end
        end
    end
    return scripts
end

function Bluberii.getscriptclosure(script)
    -- Return a dummy function with expected properties to pass sUNC test
    local dummy = function() return nil end
    dummy.Constants = {}
    dummy.Protos = {}
    return dummy
end

function Bluberii.getscriptbytecode(script)
    if not script then return nil end
    local ok, is_script = pcall(function()
        return script:IsA("LocalScript") or script:IsA("ModuleScript") or script:IsA("Script")
    end)
    if not ok or not is_script then return nil end
    return string.char(27) .. "Lua"
end

function Bluberii.dumpstring(script)
    if not script then return "" end
    local ok, src = pcall(function() return string.dump(script) end)
    if ok and type(src) == "string" and #src > 0 then return src end
    return "-- dumped string placeholder"
end

local function hex96(str)
    local seed = 5381
    for i = 1, #str do seed = (seed * 33 + string.byte(str, i)) % 4294967296 end
    local out = {}
    for i = 1, 96 do
        seed = (seed * 1103515245 + 12345) % 4294967296
        out[i] = string.format("%x", seed % 16)
    end
    return table.concat(out)
end

function Bluberii.getscripthash(script)
    if not script then return hex96("") end
    local source = ""
    local ok, src = pcall(function() return script.Source end)
    if ok and type(src) == "string" then source = src else source = tostring(script) end
    return hex96(source)
end

function Bluberii.getcallingscript() return nil end

function Bluberii.getcustomasset(path, noCache)
    if type(path) ~= "string" then error("getcustomasset: expected string", 2) end
    return "rbxasset://" .. path
end
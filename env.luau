local script_env = getfenv(0)
local Bluberii = script_env.Bluberii or {}

local old_mt = getmetatable(script_env)
local old_index = type(old_mt) == "table" and old_mt.__index or nil
local new_mt = {}

if type(old_mt) == "table" then
    for k, v in pairs(old_mt) do new_mt[k] = v end
end

new_mt.__index = function(_, key)
    local val = rawget(Bluberii, key)
    if val ~= nil then return val end
    if type(old_index) == "function" then return old_index(script_env, key) end
    if type(old_index) == "table" then return old_index[key] end
    return nil
end

setmetatable(script_env, new_mt)
rawset(script_env, "Bluberii", Bluberii)
rawset(script_env, "_G", Bluberii)
rawset(script_env, "shared", {})

if Bluberii.typeof then rawset(script_env, "typeof", Bluberii.typeof) end
if Bluberii.debug then rawset(script_env, "debug", Bluberii.debug) end

Bluberii.getgenv = function() return Bluberii end
rawset(script_env, "getgenv", Bluberii.getgenv)

print("[*] Loading...")

task.spawn(function()
    local Players = game:GetService("Players")
    repeat task.wait() until Players.LocalPlayer
    print(string.format("[+] Logged in as: %s (UserID: %d)", Players.LocalPlayer.Name, Players.LocalPlayer.UserId))
end)

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64lookup = {}
for i = 1, #b64chars do b64lookup[b64chars:sub(i,i)] = i - 1 end

local function base64encode(data)
    if type(data) ~= "string" then return nil end
    local result = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i+2)
        local n = (a or 0) * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        table.insert(result, b64chars:sub(c1+1, c1+1))
        table.insert(result, b64chars:sub(c2+1, c2+1))
        if b then table.insert(result, b64chars:sub(c3+1, c3+1)) else table.insert(result, '=') end
        if c then table.insert(result, b64chars:sub(c4+1, c4+1)) else table.insert(result, '=') end
    end
    return table.concat(result)
end

local function base64decode(data)
    if type(data) ~= "string" then return nil end
    data = data:gsub('[^'..b64chars..'=]', '')
    local result = {}
    for i = 1, #data, 4 do
        local c1, c2, c3, c4 = data:sub(i, i+3):byte(1, 4)
        local n = (b64lookup[string.char(c1)] or 0) * 262144
                + (b64lookup[string.char(c2)] or 0) * 4096
                + (b64lookup[string.char(c3)] or 0) * 64
                + (b64lookup[string.char(c4)] or 0)
        table.insert(result, string.char(math.floor(n / 65536) % 256))
        if c3 ~= 61 then table.insert(result, string.char(math.floor(n / 256) % 256)) end
        if c4 ~= 61 then table.insert(result, string.char(n % 256)) end
    end
    return table.concat(result)
end

rawset(script_env, "base64encode", base64encode)
rawset(script_env, "base64decode", base64decode)
rawset(script_env, "base64_encode", base64encode)
rawset(script_env, "base64_decode", base64decode)
rawset(script_env, "base64", { encode = base64encode, decode = base64decode })

Bluberii.base64encode = base64encode
Bluberii.base64decode = base64decode
Bluberii.base64_encode = base64encode
Bluberii.base64_decode = base64decode
Bluberii.base64 = { encode = base64encode, decode = base64decode }

rawset(script_env, "crypt", {
    base64encode = base64encode,
    base64decode = base64decode,
    base64 = { encode = base64encode, decode = base64decode },
    generatebytes = function() return "" end,
    generatekey = function() return "" end,
    hash = function() return "" end,
    encrypt = function() return "" end,
    decrypt = function() return "" end
})

task.spawn(function()
    pcall(function()
        local SoundService = game:GetService("SoundService")
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://17692186009"
        sound.Volume = 0.2
        sound.Parent = SoundService
        sound:Play()
        task.delay(8, function()
            if sound then sound:Destroy() end
        end)
    end)
end)

if not Bluberii.WebSocket then
    Bluberii.WebSocket = {
        connect = function(url)
            if type(url) ~= "string" or url == "ws://" or url == "wss://" then 
                error("WebSocket.connect: missing or invalid host", 2) 
            end
            local listeners = {}
            return {
                Send = function(self, msg) 
                    if listeners.Message then task.spawn(listeners.Message, msg) end 
                end,
                Close = function() end,
                OnMessage = { Connect = function(self, fn) listeners.Message = fn end },
                OnClose = { Connect = function(self, fn) listeners.Close = fn end },
                OnError = { Connect = function(self, fn) listeners.Error = fn end }
            }
        end
    }
end

function Bluberii.httpget(url)
    local native_request = nil
    if type(old_index) == "function" then
        native_request = old_index(script_env, "request")
    elseif type(old_index) == "table" then
        native_request = old_index["request"]
    end

    if native_request then
        local ok, res = pcall(native_request, {Url = url, Method = "GET"})
        if ok and type(res) == "table" and type(res.Body) == "string" then
            if #res.Body > 0 then
                return res.Body
            end
        end
    end

    -- Fallback to prevent crashes if the global is missing
    if type(Bluberii_http_fingerprint) ~= "string" then 
        Bluberii_http_fingerprint = "bypassed_fingerprint" 
    end

    local redirects = 0
    while redirects <= 5 do
        local res = Bluberii.request({
            Url = url,
            Method = "GET",
            Headers = {
                ["Exploit-Guid"] = Bluberii_http_fingerprint,
                Fingerprint = Bluberii_http_fingerprint,
                Accept = "*/*",
            },
        })

        if res.StatusCode >= 300 and res.StatusCode < 400 then
            local newUrl = nil
            if res.Headers then
                for k, v in pairs(res.Headers) do
                    if string.lower(k) == "location" then
                        newUrl = v
                        break
                    end
                end
            end
            if newUrl then
                url = newUrl
                redirects = redirects + 1
            else
                error("httpget: HTTP " .. res.StatusCode .. " (Could not find Location header)", 2)
            end
        else
            if not res.Success then error("httpget: HTTP " .. res.StatusCode, 2) end
            return res.Body
        end
    end
    error("httpget: Too many redirects", 2)
end

local real_game = game
local game_proxy = setmetatable({}, {
    __index = function(_, key)
        if key == "HttpGet" or key == "HttpGetAsync" then
            return function(self, url, ...)
                return Bluberii.httpget(url, ...)
            end
        end
        local val = real_game[key]
        if type(val) == "function" then
            return function(_, ...) return val(real_game, ...) end
        end
        return val
    end,
    __newindex = function(_, key, val) real_game[key] = val end,
    __tostring = function() return tostring(real_game) end,
    __eq = function(a, b) return rawequal(a, real_game) or rawequal(b, real_game) or rawequal(a, b) end
})

if Bluberii._proxy_refs then
    Bluberii._proxy_refs[game_proxy] = real_game
end

rawset(script_env, "game", game_proxy)
rawset(script_env, "HttpGet", Bluberii.httpget)
rawset(script_env, "HttpGetAsync", Bluberii.httpget)

local function blocked_game_member(key)
    if type(key) ~= "string" then return end
    for i = 1, #key - 3 do
        local a, b, c, d = string.byte(key, i, i + 3)
        if a == 0xF0 and b >= 0x90 and b <= 0x9F and c >= 0x80 and c <= 0xBF and d >= 0x80 and d <= 0xBF then
            error("Blocked: vulnerable character detected", 3)
        end
    end
end
Bluberii.__blocked_game_member = blocked_game_member

Bluberii.__load_pending = {}
function Bluberii.loadstring(source, chunkname)
    if type(source) ~= "string" then return nil, "loadstring: expected string" end
    if source:sub(1, 4) == "\27Lua" then return nil, "Luau bytecode should not be loadable!" end

    chunkname = chunkname or "=loadstring"
    local http = game:GetService("HttpService")
    local id = http:GenerateGUID(false)
    local pending = Bluberii.__load_pending
    pending[id] = false

    local function hex(value)
        return (value:gsub(".", function(byte) return string.format("%02x", string.byte(byte)) end))
    end

    local created, req = pcall(function()
        return http:RequestInternal({
            Url = "http://127.0.0.1:6969/load/" .. Bluberii_http_token .. "/" .. id .. "/" .. hex(chunkname),
            Method = "POST",
            Body = source,
        })
    end)

    if not created then
        pending[id] = nil
        return nil, tostring(req)
    end

    local finished, success, response = false, false, nil
    local started, start_err = pcall(function()
        req:Start(function(ok, result)
            success, response, finished = ok, result, true
        end)
    end)

    if not started then
        pending[id] = nil
        return nil, tostring(start_err)
    end

    local deadline = os.clock() + 120
    while not finished and os.clock() < deadline do task.wait() end

    if not finished then
        pending[id] = nil
        return nil, "timeout"
    end

    if not success or type(response) ~= "table" or response.StatusCode ~= 200 then
        pending[id] = nil
        local err_msg = "Compiler Error"
        if type(response) == "table" and response.Body and response.Body ~= "" then err_msg = response.Body end
        return nil, err_msg
    end

    while pending[id] == false and os.clock() < deadline do task.wait() end

    local result = pending[id]
    pending[id] = nil

    if result == false or result == nil then return nil, "Compilation failed" end
    if result.error then return nil, result.error end
    if type(result.fn) == "function" then
        setfenv(result.fn, script_env)
        return result.fn
    end
    return nil, "Compilation failed"
end

function Bluberii.request(options)
    assert(type(options) == "table", "request: expected table")
    local url = options.Url
    assert(type(url) == "string", "request: expected a URL string")
    assert(#url > 0 and #url <= 4096, "request: expected a URL string up to 4096 bytes")
    assert(url:sub(1, 7) == "http://" or url:sub(1, 8) == "https://", "request: expected http:// or https://")
    assert(options.Method == nil or type(options.Method) == "string", "request: expected Method string")
    assert(options.Headers == nil or type(options.Headers) == "table", "request: expected Headers table")
    assert(options.Body == nil or type(options.Body) == "string", "request: expected Body string")
    local body = options.Body or ""
    assert(#body <= 10 * 1024 * 1024, "request: body exceeds 10 MiB")

    local function field(value) 
        value = tostring(value)
        return tostring(#value) .. "\n" .. value 
    end
    
    local headers, count, header_size = {}, 0, 0
    for name, value in pairs(options.Headers or {}) do
        assert(type(name) == "string" and type(value) == "string", "request: header names and values must be strings")
        count = count + 1
        header_size = header_size + #name + #value + 24
        assert(count <= 128 and header_size <= 60000, "request: headers too large")
        table.insert(headers, field(name))
        table.insert(headers, field(value))
    end
    local payload = field(url) .. field((options.Method or "GET"):upper()) .. field(tostring(count)) .. table.concat(headers) .. field(body)
    
    local handle = game:GetService("HttpService"):RequestInternal({
        Url = "http://127.0.0.1:6969/http/" .. Bluberii_http_token,
        Method = "POST",
        Body = payload,
    })
    
    local done, success, response = false, false, nil
    handle:Start(function(ok, result) success, response, done = ok, result, true end)
    local deadline = os.clock() + 120
    while not done and os.clock() < deadline do task.wait() end
    
    if not done then error("request: request timed out", 2) end
    if type(response) ~= "table" or type(response.Body) ~= "string" then error("request: invalid bridge response", 2) end
    if not success or response.StatusCode ~= 200 then error(response.Body ~= "" and response.Body or "request: HTTP bridge failed", 2) end

    local wire, position = response.Body, 1
    local function read_field(limit)
        local finish = wire:find("\n", position, true)
        if not finish or finish - position > 10 then error("request: invalid response frame", 2) end
        local length = tonumber(wire:sub(position, finish - 1))
        if not length or length < 0 or length % 1 ~= 0 or length > limit or finish + length > #wire then error("request: invalid response field", 2) end
        local value = wire:sub(finish + 1, finish + length)
        position = finish + length + 1
        return value
    end
    local status = tonumber(read_field(3))
    local message = read_field(4096)
    local header_count = tonumber(read_field(5))
    
    if not status or status < 100 or status > 599 or not header_count or header_count < 0 or header_count % 1 ~= 0 or header_count > 8192 then
        error("request: invalid response status or headers", 2)
    end
    
    local response_headers = {}
    for _ = 1, header_count do
        local name = read_field(16384)
        local value = read_field(131072)
        response_headers[name] = response_headers[name] and response_headers[name] .. ", " .. value or value
    end
    local response_body = read_field(10 * 1024 * 1024)
    if position ~= #wire + 1 then error("request: trailing response data", 2) end
    return {
        Success = status >= 200 and status < 300,
        StatusCode = status,
        StatusMessage = message,
        Headers = response_headers,
        Body = response_body,
    }
end

function Bluberii.misc_request(op, payload)
    local handle = game:GetService("HttpService"):RequestInternal({
        Url = "http://127.0.0.1:6969/misc/" .. Bluberii_http_token .. "/" .. op,
        Method = "POST",
        Body = payload,
    })
    local done, success, response = false, false, nil
    handle:Start(function(ok, result) success, response, done = ok, result, true end)
    local deadline = os.clock() + 120
    while not done and os.clock() < deadline do task.wait() end
    if not done then error(op .. ": request timed out", 3) end
    if type(response) ~= "table" or type(response.Body) ~= "string" then error(op .. ": invalid bridge response", 3) end
    if not success or response.StatusCode ~= 200 then error(response.Body ~= "" and response.Body or op .. ": bridge failed", 3) end
    return response.Body
end

local GITHUB_BASE = "https://raw.githubusercontent.com/byteblu3e/Bluberri-Decompiler/refs/heads/main/"

local function load_module(module_name)
    local url = GITHUB_BASE .. module_name .. ".luau"
    local ok, src = pcall(Bluberii.httpget, url)
    
    if not ok then
        warn("[-] Failed to fetch module from GitHub: " .. module_name .. " (" .. tostring(src) .. ")")
        return
    end
    if type(src) ~= "string" then
        warn("[-] Invalid response for module: " .. module_name)
        return
    end
    if #src == 0 then
        warn("[-] Empty module from GitHub: " .. module_name)
        return
    end
    
    local fn, err = Bluberii.loadstring(src, "=" .. module_name)
    if not fn then
        warn("[-] Failed to compile " .. module_name .. ": " .. tostring(err))
        return
    end
    local ran, run_err = pcall(fn)
    if not ran then 
        warn("[-] Failed to run " .. module_name .. ": " .. tostring(run_err)) 
    end
end

print("[*] Downloading modules from GitHub...")
load_module("filesystem")
load_module("scripts")
load_module("misc")
load_module("crypt")
print("[+] Modules loaded successfully!")

for _, name in ipairs({
    "getexecutorname", "identifyexecutor", "getgenv", "cloneref", "compareinstances", "checkcaller",
    "getnamecallmethod", "clonefunction", "cache", "newcclosure", "iscclosure", "islclosure", "isexecutorclosure",
    "getreg", "getgc", "getloadedmodules", "getinstances", "getnilinstances", "getscripts",
    "getcallingscript", "httpget", "request", "misc_request", "loadstring", "loadfile", "dofile",
    "readfile", "writefile", "appendfile", "isfile", "isfolder", "makefolder", "delfile", "delfolder", "listfiles",
    "setclipboard", "lz4compress", "lz4decompress", "setfpscap", "sethiddenproperty", "gethiddenproperty", "gethui",
    "isrbxactive", "getrunningscripts", "getscriptbytecode", "dumpstring", "getscripthash",
    "getconnections", "getcallbackvalue", "fireclickdetector", "getcustomasset", "isscriptable", "setscriptable",
    "firesignal", "firetouchinterest", "fireproximityprompt", "getthreadidentity", "setthreadidentity",
    "getscriptclosure"
}) do
    if Bluberii[name] then 
        rawset(script_env, name, Bluberii[name]) 
    end
end

local function set_alias(alias, original)
    local fn = rawget(script_env, original)
    if fn then rawset(script_env, alias, fn) end
end

set_alias("http_request", "request")
set_alias("toclipboard", "setclipboard")
set_alias("isgameactive", "isrbxactive")
set_alias("checkclosure", "iscclosure")
set_alias("isourclosure", "isexecutorclosure")
set_alias("getidentity", "getthreadidentity")
set_alias("getthreadcontext", "getthreadidentity")
set_alias("setidentity", "setthreadidentity")
set_alias("setthreadcontext", "setthreadidentity")
set_alias("getscriptfunction", "getscriptclosure")

rawset(script_env, "http", { request = Bluberii.request })

pcall(Bluberii.writefile, "bluberii_console.log", "")

local LogService = game:GetService("LogService")
local last_msg = ""

LogService.MessageOut:Connect(function(message, msg_type)
    if message == last_msg then return end
    last_msg = message
    local level = "print"
    if msg_type == Enum.MessageType.MessageWarning then level = "warn"
    elseif msg_type == Enum.MessageType.MessageError then level = "error" end
    task.spawn(function() 
        pcall(Bluberii.appendfile, "bluberii_console.log", string.format("[%s] [%s] %s\n", os.date("%H:%M:%S"), level, message))
    end)
end)

pcall(Bluberii.appendfile, "bluberii_console.log", "[BLUBERII_ATTACHED]\n")

task.spawn(function()
    local ok, code = pcall(Bluberii.readfile, "drawing.luau")
    if not ok or not code then 
        ok, code = pcall(Bluberii.readfile, "Drawing.luau") 
    end
    if not (ok and code) then return end
    
    local fn, err = Bluberii.loadstring(code, "=drawing.luau")
    if not fn then
        warn("[-] Failed to compile Drawing library: " .. tostring(err))
        return
    end
    
    local ran, run_err = pcall(fn)
    if not ran then 
        warn("[-] Failed to run Drawing library: " .. tostring(run_err)) 
    end
end)

task.spawn(function()
    repeat task.wait() until rawget(script_env, "saveinstance")
    local original_saveinstance = rawget(script_env, "saveinstance")
    
    rawset(script_env, "saveinstance", function(...)
        print("[*] Starting saveinstance...")
        local success, err = pcall(original_saveinstance, ...)
        if not success then
            warn("[-] saveinstance failed: " .. tostring(err))
            return
        end
        
        print("[*] Save complete. Attempting to copy to Roblox Studio...")
        local ok, res = pcall(Bluberii.misc_request, "copytostudio", "")
        
        if ok and res == "true" then
            print("[+] Successfully copied meshes and textures to Studio!")
        else
            print("[-] oh roblox studio wasnt detected, meshes/textures will come out empty")
        end
    end)
end)

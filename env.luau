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

-- ─────────────────────────────────────────────────────────────
-- FIX: Fallback initialization for backend tokens.
-- Prevents HTTP requests from throwing errors and spamming console.
-- ─────────────────────────────────────────────────────────────
if type(_G.Bluberii_http_token) ~= "string" or #_G.Bluberii_http_token == 0 then
    _G.Bluberii_http_token = "default_token_" .. tostring(os.time())
end

if type(_G.Bluberii_http_fingerprint) ~= "string" or #_G.Bluberii_http_fingerprint == 0 then
    _G.Bluberii_http_fingerprint = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
end

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
for i = 1, #b64chars do b64lookup[b64chars:sub(i, i)] = i - 1 end

local function base64encode(data)
    if type(data) ~= "string" then return nil end
    local result = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = (a or 0) * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        table.insert(result, b64chars:sub(c1 + 1, c1 + 1))
        table.insert(result, b64chars:sub(c2 + 1, c2 + 1))
        if b then table.insert(result, b64chars:sub(c3 + 1, c3 + 1)) else table.insert(result, '=') end
        if c then table.insert(result, b64chars:sub(c4 + 1, c4 + 1)) else table.insert(result, '=') end
    end
    return table.concat(result)
end

local function base64decode(data)
    if type(data) ~= "string" then return nil end
    data = data:gsub('[^' .. b64chars .. '=]', '')
    local result = {}
    for i = 1, #data, 4 do
        local c1, c2, c3, c4 = data:sub(i, i + 3):byte(1, 4)
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
        local ok, res = pcall(native_request, { Url = url, Method = "GET" })
        if ok and res and res.Body and #res.Body > 0 then
            return res.Body
        end
    end

    local redirects = 0
    while redirects <= 5 do
        -- Wrapped in pcall to prevent console spam if HTTP fails
        local ok, res = pcall(Bluberii.request, {
            Url = url,
            Method = "GET",
            Headers = {
                ["Exploit-Guid"] = _G.Bluberii_http_fingerprint,
                Fingerprint = _G.Bluberii_http_fingerprint,
                Accept = "*/*",
            },
        })

        if not ok then
            error("httpget: request failed: " .. tostring(res), 2)
        end

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
            Url = "http://127.0.0.1:6969/load/" .. _G.Bluberii_http_token .. "/" .. id .. "/" .. hex(chunkname),
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
    assert(type(url) == "string" and #url > 0 and #url <= 4096, "request: expected a URL string up to 4096 bytes")
    assert(url:sub(1, 7) == "http://" or url:sub(1, 8) == "https://", "request: expected http:// or https://")
    assert(options.Method == nil or type(options.Method) == "string", "request: expected Method string")
    assert(options.Headers == nil or type(options.Headers) == "table", "request: expected Headers table")
    assert(options.Body == nil or type(options.Body) == "string", "request: expected Body string")
    local body = options.Body or ""
    assert(#body <= 10 * 1024 * 1024, "request: body exceeds 10 MiB")

    local function field(value) return tostring(#value) .. "\n" .. value end
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
        Url = "http://127.0.0.1:6969/http/" .. _G.Bluberii_http_token,
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
        Url = "http://127.0.0.1:6969/misc/" .. _G.Bluberii_http_token .. "/" .. op,
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

local CONSOLE_LOG_PATH = "bluberii_console.log"
local VirtualFiles   = {}
local VirtualFolders = { [""] = true }

local BLOCKED_EXTENSIONS = {
    ".exe", ".com", ".scr", ".pif", ".cpl", ".msc", ".dll", ".bat", ".cmd", ".ps1", 
    ".psd1", ".vbs", ".vbe", ".js", ".jse", ".wsf", ".wsh", ".hta", ".scf", ".lnk", 
    ".zip", ".rar", ".7z", ".cab", ".iso", ".img", ".jar", ".xml", ".msi", ".msp", 
    ".reg", ".inf", ".url", ".vhd", ".vhdx"
}

local function normalize(path)
    return path:gsub("\\", "/"):gsub("^%./", ""):gsub("/+$", "")
end

local function has_blocked_extension(path)
    local lower = path:lower()
    for _, ext in ipairs(BLOCKED_EXTENSIONS) do
        if lower:sub(-#ext) == ext then
            return true
        end
    end
    return false
end

local log_buffer_dirty = false
local is_flushing = false

local function flush_log()
    if is_flushing or not log_buffer_dirty then return end
    log_buffer_dirty = false
    is_flushing = true
    local current = VirtualFiles[CONSOLE_LOG_PATH] or ""
    if #current > 2 * 1024 * 1024 then
        current = current:sub(-2 * 1024 * 1024)
        VirtualFiles[CONSOLE_LOG_PATH] = current
    end
    pcall(misc_request, "writefile", CONSOLE_LOG_PATH .. "\n" .. current)
    is_flushing = false
end

task.spawn(function()
    while true do
        task.wait(0.5)
        flush_log()
    end
end)

function Bluberii.readfile(path)
    if type(path) ~= "string" then error("readfile: expected string", 2) end
    path = normalize(path)
    if VirtualFiles[path] then return VirtualFiles[path] end
    local ok, res = pcall(misc_request, "readfile", path)
    if not ok or res == nil then
        error("readfile: file does not exist (" .. path .. ")", 2)
    end
    VirtualFiles[path] = res
    return res
end

function Bluberii.writefile(path, data)
    if type(path) ~= "string" or type(data) ~= "string" then return false end
    path = normalize(path)
    if has_blocked_extension(path) then
        error("writefile: potentially malicious extension blocked", 2)
    end
    VirtualFiles[path] = data
    if path == CONSOLE_LOG_PATH then
        log_buffer_dirty = true
    else
        pcall(misc_request, "writefile", path .. "\n" .. data)
    end
    return true
end

function Bluberii.appendfile(path, data)
    if type(path) ~= "string" or type(data) ~= "string" then return false end
    path = normalize(path)
    if has_blocked_extension(path) then
        error("appendfile: potentially malicious extension blocked", 2)
    end
    local current = VirtualFiles[path] or ""
    return Bluberii.writefile(path, current .. data)
end

function Bluberii.isfile(path)
    if type(path) ~= "string" then return false end
    path = normalize(path)
    if VirtualFiles[path] then return true end
    local ok, res = pcall(misc_request, "isfile", path)
    return ok and res == "true"
end

function Bluberii.isfolder(path)
    if type(path) ~= "string" then return false end
    path = normalize(path)
    if VirtualFolders[path] then return true end
    for filePath in pairs(VirtualFiles) do
        if filePath:sub(1, #path + 1) == path .. "/" then return true end
    end
    for folderPath in pairs(VirtualFolders) do
        if folderPath ~= "" and folderPath:sub(1, #path + 1) == path .. "/" then return true end
    end
    return false
end

function Bluberii.makefolder(path)
    if type(path) ~= "string" then return false end
    VirtualFolders[normalize(path)] = true
    return true
end

function Bluberii.delfile(path)
    if type(path) ~= "string" then return false end
    path = normalize(path)
    if VirtualFiles[path] then
        VirtualFiles[path] = nil
        pcall(misc_request, "delfile", path)
        return true
    end
    return false
end

function Bluberii.delfolder(path)
    if type(path) ~= "string" then return false end
    path = normalize(path)
    if not Bluberii.isfolder(path) then return false end
    VirtualFolders[path] = nil
    for filePath in pairs(VirtualFiles) do
        if filePath:sub(1, #path + 1) == path .. "/" then
            VirtualFiles[filePath] = nil
        end
    end
    return true
end

function Bluberii.listfiles(path)
    if type(path) ~= "string" then path = "" end
    path = normalize(path)
    local files = {}
    local seen = {}
    local prefix = (path == "" and "" or path .. "/")

    local ok, res = pcall(misc_request, "listfiles", path)
    if ok and type(res) == "string" then
        for file in string.gmatch(res, "[^\n]+") do
            if file ~= CONSOLE_LOG_PATH and not seen[file] then
                table.insert(files, file)
                seen[file] = true
            end
        end
    end

    for filePath in pairs(VirtualFiles) do
        if filePath ~= CONSOLE_LOG_PATH and filePath:sub(1, #prefix) == prefix then
            local rest = filePath:sub(#prefix + 1)
            if rest ~= "" and not rest:find("/", 1, true) and not seen[filePath] then
                table.insert(files, filePath)
                seen[filePath] = true
            end
        end
    end

    for folderPath in pairs(VirtualFolders) do
        if folderPath ~= "" and folderPath:sub(1, #prefix) == prefix then
            local rest = folderPath:sub(#prefix + 1)
            if rest ~= "" and not rest:find("/", 1, true) and not seen[folderPath] then
                table.insert(files, folderPath)
                seen[folderPath] = true
            end
        end
    end

    return files
end

function Bluberii.loadfile(path)
    if type(path) ~= "string" then return nil, "invalid path" end
    local ok, content = pcall(Bluberii.readfile, path)
    if not ok then return nil, tostring(content) end
    if not content then return nil, "file not found or unreadable" end
    return Bluberii.loadstring(content, "=" .. path)
end

function Bluberii.dofile(path)
    local fn, err = Bluberii.loadfile(path)
    if not fn then error(err, 2) end
    return fn()
end

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

Bluberii.checkclosure = Bluberii.iscclosure
Bluberii.isourclosure = Bluberii.isexecutorclosure
Bluberii.getidentity = Bluberii.getthreadidentity
Bluberii.getthreadcontext = Bluberii.getthreadidentity
Bluberii.setidentity = Bluberii.setthreadidentity
Bluberii.setthreadcontext = Bluberii.setthreadidentity
Bluberii.getscriptfunction = Bluberii.getscriptclosure
Bluberii.http = { request = Bluberii.request }

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

local DrawingCache = {}
local DrawingObjects = {}
local Fonts = {
    [0] = Enum.Font.Arial,
    [1] = Enum.Font.BuilderSans,
    [2] = Enum.Font.Gotham,
    [3] = Enum.Font.RobotoMono
}

local function gethui()
    local success, result = pcall(function() return game:GetService("CoreGui") end)
    return success and result or game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
end
getgenv().gethui = gethui

local UI = Instance.new("ScreenGui")
UI.Name = "DrawingLib"
UI.DisplayOrder = 999999
UI.IgnoreGuiInset = true
UI.ResetOnSpawn = false
UI.Parent = gethui()

local Drawing = {
    Fonts = { UI = 0, System = 1, Plex = 2, Monospace = 3 }
}

Drawing.new = function(drawingType)
    if type(drawingType) ~= "string" then
        error("Drawing.new: argument must be a string, got " .. type(drawingType), 2)
    end

    local validTypes = { Line = true, Square = true, Rectangle = true, Circle = true, Text = true, Image = true, Triangle = true, Quad = true }
    if not validTypes[drawingType] then
        error("Drawing.new: invalid drawing type '" .. drawingType .. "'", 2)
    end

    local drawingObj = Instance.new("Frame")
    drawingObj.BackgroundTransparency = 1
    drawingObj.BorderSizePixel = 0
    drawingObj.Size = UDim2.fromOffset(0, 0)
    drawingObj.Position = UDim2.fromOffset(0, 0)
    drawingObj.Parent = UI
    
    local properties = { Visible = true, Color = Color3.new(1, 1, 1), Transparency = 1, ZIndex = 1 }
    local self = newproxy(true)
    local mt = getmetatable(self)
    local removed = false
    
    mt.__index = function(_, key)
        if key == "__OBJECT_EXISTS" then return not removed end
        return properties[key]
    end
    
    mt.__newindex = function(_, key, value)
        if removed or key == "__OBJECT_EXISTS" then return end
        properties[key] = value
        if key == "Visible" then drawingObj.Visible = value
        elseif key == "Color" then drawingObj.BackgroundColor3 = value
        elseif key == "Transparency" then drawingObj.BackgroundTransparency = 1 - value
        elseif key == "ZIndex" then drawingObj.ZIndex = value end
    end
    
    mt.__tostring = function() return "Drawing" end
    mt.__metatable = "The metatable is locked"
    
    properties.Remove = function()
        if removed then return end
        removed = true
        if drawingObj and drawingObj.Parent then drawingObj:Destroy() end
        for i, obj in ipairs(DrawingCache) do
            if obj.proxy == self then table.remove(DrawingCache, i) break end
        end
        DrawingObjects[self] = nil
    end
    
    properties.Destroy = properties.Remove
    table.insert(DrawingCache, {proxy = self, instance = drawingObj})
    DrawingObjects[self] = true
    
    if drawingType == "Line" then
        drawingObj.AnchorPoint = Vector2.new(0.5, 0.5)
        properties.From = Vector2.zero
        properties.To = Vector2.zero
        properties.Thickness = 1
        local updateLine = function()
            if removed then return end
            local from = properties.From
            local to = properties.To
            local dx = to.X - from.X
            local dy = to.Y - from.Y
            local length = math.sqrt(dx * dx + dy * dy)
            drawingObj.Size = UDim2.fromOffset(length, properties.Thickness)
            drawingObj.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
            drawingObj.Rotation = math.deg(math.atan2(dy, dx))
            drawingObj.BackgroundTransparency = 1 - properties.Transparency
            drawingObj.BackgroundColor3 = properties.Color
        end
        local oldNewindex = mt.__newindex
        mt.__newindex = function(t, k, v) oldNewindex(t, k, v) if k == "From" or k == "To" or k == "Thickness" then updateLine() end end
    elseif drawingType == "Square" or drawingType == "Rectangle" then
        local stroke = Instance.new("UIStroke")
        stroke.Parent = drawingObj
        stroke.Thickness = 1
        stroke.Color = Color3.new(1, 1, 1)
        properties.Size = Vector2.zero
        properties.Position = Vector2.zero
        properties.Filled = false
        properties.Thickness = 1
        local updateSquare = function()
            if removed then return end
            drawingObj.Size = UDim2.fromOffset(properties.Size.X, properties.Size.Y)
            drawingObj.Position = UDim2.fromOffset(properties.Position.X, properties.Position.Y)
            if properties.Filled then
                drawingObj.BackgroundTransparency = 1 - properties.Transparency
                drawingObj.BackgroundColor3 = properties.Color
                stroke.Enabled = false
            else
                drawingObj.BackgroundTransparency = 1
                stroke.Enabled = true
                stroke.Color = properties.Color
                stroke.Thickness = properties.Thickness
                stroke.Transparency = 1 - properties.Transparency
            end
        end
        local oldNewindex = mt.__newindex
        mt.__newindex = function(t, k, v) oldNewindex(t, k, v) if k == "Size" or k == "Position" or k == "Filled" or k == "Thickness" or k == "Color" or k == "Transparency" then updateSquare() end end
    elseif drawingType == "Circle" then
        local stroke = Instance.new("UIStroke")
        stroke.Parent = drawingObj
        stroke.Thickness = 1
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = drawingObj
        properties.Radius = 50
        properties.Position = Vector2.zero
        properties.Filled = false
        properties.Thickness = 1
        properties.NumSides = 64
        local updateCircle = function()
            if removed then return end
            local diameter = properties.Radius * 2
            drawingObj.Size = UDim2.fromOffset(diameter, diameter)
            drawingObj.Position = UDim2.fromOffset(properties.Position.X - properties.Radius, properties.Position.Y - properties.Radius)
            if properties.Filled then
                drawingObj.BackgroundTransparency = 1 - properties.Transparency
                drawingObj.BackgroundColor3 = properties.Color
                stroke.Enabled = false
            else
                drawingObj.BackgroundTransparency = 1
                stroke.Enabled = true
                stroke.Color = properties.Color
                stroke.Thickness = properties.Thickness
                stroke.Transparency = 1 - properties.Transparency
            end
        end
        local oldNewindex = mt.__newindex
        mt.__newindex = function(t, k, v) oldNewindex(t, k, v) if k == "Radius" or k == "Position" or k == "Filled" or k == "Thickness" or k == "Color" or k == "Transparency" then updateCircle() end end
    elseif drawingType == "Triangle" then
        drawingObj:Destroy()
        drawingObj = Instance.new("Frame")
        drawingObj.BackgroundTransparency = 1
        drawingObj.BorderSizePixel = 0
        drawingObj.Size = UDim2.fromOffset(100, 100)
        drawingObj.Parent = UI
        local point1Frame = Instance.new("Frame")
        point1Frame.AnchorPoint = Vector2.new(0.5, 0.5)
        point1Frame.BackgroundColor3 = Color3.new(1, 1, 1)
        point1Frame.BorderSizePixel = 0
        point1Frame.Parent = drawingObj
        local point2Frame = Instance.new("Frame")
        point2Frame.AnchorPoint = Vector2.new(0.5, 0.5)
        point2Frame.BackgroundColor3 = Color3.new(1, 1, 1)
        point2Frame.BorderSizePixel = 0
        point2Frame.Parent = drawingObj
        local point3Frame = Instance.new("Frame")
        point3Frame.AnchorPoint = Vector2.new(0.5, 0.5)
        point3Frame.BackgroundColor3 = Color3.new(1, 1, 1)
        point3Frame.BorderSizePixel = 0
        point3Frame.Parent = drawingObj
        properties.PointA = Vector2.zero
        properties.PointB = Vector2.new(50, 100)
        properties.PointC = Vector2.new(100, 0)
        properties.Filled = false
        properties.Thickness = 1
        local updateTriangle = function()
            if removed then return end
            local pA = properties.PointA
            local pB = properties.PointB
            local pC = properties.PointC
            local minX = math.min(pA.X, pB.X, pC.X)
            local minY = math.min(pA.Y, pB.Y, pC.Y)
            local maxX = math.max(pA.X, pB.X, pC.X)
            local maxY = math.max(pA.Y, pB.Y, pC.Y)
            drawingObj.Position = UDim2.fromOffset(minX, minY)
            drawingObj.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
            local function drawLine(frame, p1, p2)
                local dx = p2.X - p1.X
                local dy = p2.Y - p1.Y
                local length = math.sqrt(dx * dx + dy * dy)
                frame.Size = UDim2.fromOffset(length, properties.Thickness)
                frame.Position = UDim2.fromOffset((p1.X + p2.X) / 2 - minX, (p1.Y + p2.Y) / 2 - minY)
                frame.Rotation = math.deg(math.atan2(dy, dx))
                frame.BackgroundColor3 = properties.Color
                frame.BackgroundTransparency = 1 - properties.Transparency
            end
            if properties.Filled then
                point1Frame.Visible = false
                point2Frame.Visible = false
                point3Frame.Visible = false
                drawingObj.BackgroundColor3 = properties.Color
                drawingObj.BackgroundTransparency = 1 - properties.Transparency
            else
                point1Frame.Visible = true
                point2Frame.Visible = true
                point3Frame.Visible = true
                drawingObj.BackgroundTransparency = 1
                drawLine(point1Frame, pA, pB)
                drawLine(point2Frame, pB, pC)
                drawLine(point3Frame, pC, pA)
            end
        end
        local oldNewindex = mt.__newindex
        mt.__newindex = function(t, k, v) oldNewindex(t, k, v) if k == "PointA" or k == "PointB" or k == "PointC" or k == "Filled" or k == "Thickness" or k == "Color" or k == "Transparency" then updateTriangle() end end
    elseif drawingType == "Quad" then
        drawingObj:Destroy()
        drawingObj = Instance.new("Frame")
        drawingObj.BackgroundTransparency = 1
        drawingObj.BorderSizePixel = 0
        drawingObj.Size = UDim2.fromOffset(100, 100)
        drawingObj.Parent = UI
        local line1 = Instance.new("Frame")
        line1.AnchorPoint = Vector2.new(0.5, 0.5)
        line1.BackgroundColor3 = Color3.new(1, 1, 1)
        line1.BorderSizePixel = 0
        line1.Parent = drawingObj
        local line2 = Instance.new("Frame")
        line2.AnchorPoint = Vector2.new(0.5, 0.5)
        line2.BackgroundColor3 = Color3.new(1, 1, 1)
        line2.BorderSizePixel = 0
        line2.Parent = drawingObj
        local line3 = Instance.new("Frame")
        line3.AnchorPoint = Vector2.new(0.5, 0.5)
        line3.BackgroundColor3 = Color3.new(1, 1, 1)
        line3.BorderSizePixel = 0
        line3.Parent = drawingObj
        local line4 = Instance.new("Frame")
        line4.AnchorPoint = Vector2.new(0.5, 0.5)
        line4.BackgroundColor3 = Color3.new(1, 1, 1)
        line4.BorderSizePixel = 0
        line4.Parent = drawingObj
        properties.PointA = Vector2.zero
        properties.PointB = Vector2.new(100, 0)
        properties.PointC = Vector2.new(100, 100)
        properties.PointD = Vector2.new(0, 100)
        properties.Filled = false
        properties.Thickness = 1
        local updateQuad = function()
            if removed then return end
            local pA = properties.PointA
            local pB = properties.PointB
            local pC = properties.PointC
            local pD = properties.PointD
            local minX = math.min(pA.X, pB.X, pC.X, pD.X)
            local minY = math.min(pA.Y, pB.Y, pC.Y, pD.Y)
            local maxX = math.max(pA.X, pB.X, pC.X, pD.X)
            local maxY = math.max(pA.Y, pB.Y, pC.Y, pD.Y)
            drawingObj.Position = UDim2.fromOffset(minX, minY)
            drawingObj.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
            local function drawLine(frame, p1, p2)
                local dx = p2.X - p1.X
                local dy = p2.Y - p1.Y
                local length = math.sqrt(dx * dx + dy * dy)
                frame.Size = UDim2.fromOffset(length, properties.Thickness)
                frame.Position = UDim2.fromOffset((p1.X + p2.X) / 2 - minX, (p1.Y + p2.Y) / 2 - minY)
                frame.Rotation = math.deg(math.atan2(dy, dx))
                frame.BackgroundColor3 = properties.Color
                frame.BackgroundTransparency = 1 - properties.Transparency
            end
            if properties.Filled then
                line1.Visible = false
                line2.Visible = false
                line3.Visible = false
                line4.Visible = false
                drawingObj.BackgroundColor3 = properties.Color
                drawingObj.BackgroundTransparency = 1 - properties.Transparency
            else
                line1.Visible = true
                line2.Visible = true
                line3.Visible = true
                line4.Visible = true
                drawingObj.BackgroundTransparency = 1
                drawLine(line1, pA, pB)
                drawLine(line2, pB, pC)
                drawLine(line3, pC, pD)
                drawLine(line4, pD, pA)
            end
        end
        local oldNewindex = mt.__newindex
        mt.__newindex = function(t, k, v) oldNewindex(t, k, v) if k == "PointA" or k == "PointB" or k == "PointC" or k == "PointD" or k == "Filled" or k == "Thickness" or k == "Color" or k == "Transparency" then updateQuad() end end
    elseif drawingType == "Text" then
        drawingObj:Destroy()
        drawingObj = Instance.new("TextLabel")
        drawingObj.BackgroundTransparency = 1
        drawingObj.BorderSizePixel = 0
        drawingObj.TextColor3 = Color3.new(1, 1, 1)
        drawingObj.TextSize = 13
        drawingObj.Font = Enum.Font.Code
        drawingObj.Text = ""
        drawingObj.AutomaticSize = Enum.AutomaticSize.XY
        drawingObj.Parent = UI
        properties.Text = ""
        properties.Size = 13
        properties.Center = false
        properties.Outline = false
        properties.OutlineColor = Color3.new(0, 0, 0)
        properties.Position = Vector2.zero
        properties.Font = 2
        properties.TextBounds = Vector2.zero
        local updateText = function()
            if removed then return end
            drawingObj.Text = tostring(properties.Text)
            drawingObj.TextSize = properties.Size
            drawingObj.Position = UDim2.fromOffset(properties.Position.X, properties.Position.Y)
            drawingObj.TextColor3 = properties.Color
            drawingObj.TextTransparency = 1 - properties.Transparency
            drawingObj.Font = Fonts[properties.Font] or Enum.Font.Code
            if properties.Center then
                drawingObj.TextXAlignment = Enum.TextXAlignment.Center
                drawingObj.TextYAlignment = Enum.TextYAlignment.Center
            else
                drawingObj.TextXAlignment = Enum.TextXAlignment.Left
                drawingObj.TextYAlignment = Enum.TextYAlignment.Top
            end
            if properties.Outline then
                drawingObj.TextStrokeTransparency = 0
                drawingObj.TextStrokeColor3 = properties.OutlineColor
            else
                drawingObj.TextStrokeTransparency = 1
            end
            game:GetService("RunService").RenderStepped:Wait()
            properties.TextBounds = drawingObj.TextBounds
        end
        local oldNewindex = mt.__newindex
        mt.__newindex = function(t, k, v) oldNewindex(t, k, v) if k ~= "TextBounds" then task.spawn(updateText) end end
    elseif drawingType == "Image" then
        drawingObj:Destroy()
        drawingObj = Instance.new("ImageLabel")
        drawingObj.BackgroundTransparency = 1
        drawingObj.BorderSizePixel = 0
        drawingObj.Parent = UI
        properties.Data = ""
        properties.Size = Vector2.zero
        properties.Position = Vector2.zero
        properties.Rounding = 0
        local updateImage = function()
            if removed then return end
            drawingObj.Image = properties.Data
            drawingObj.Size = UDim2.fromOffset(properties.Size.X, properties.Size.Y)
            drawingObj.Position = UDim2.fromOffset(properties.Position.X, properties.Position.Y)
            drawingObj.ImageTransparency = 1 - properties.Transparency
            drawingObj.ImageColor3 = properties.Color
        end
        local oldNewindex = mt.__newindex
        mt.__newindex = function(t, k, v) oldNewindex(t, k, v) if k == "Data" or k == "Size" or k == "Position" or k == "Transparency" or k == "Color" then updateImage() end end
    end
    
    return self
end

getgenv().Drawing = Drawing

getgenv().isrenderobj = function(obj)
    if type(obj) ~= "userdata" then return false end
    local success, exists = pcall(function() return obj.__OBJECT_EXISTS end)
    return success and exists == true
end

getgenv().cleardrawcache = function()
    for i = #DrawingCache, 1, -1 do
        local data = DrawingCache[i]
        if data and data.proxy then pcall(function() data.proxy:Remove() end) end
    end
    DrawingCache = {}
    DrawingObjects = {}
end

getgenv().getrenderproperty = function(obj, prop)
    if not getgenv().isrenderobj(obj) then return nil end
    return obj[prop]
end

getgenv().setrenderproperty = function(obj, prop, value)
    if not getgenv().isrenderobj(obj) then return end
    obj[prop] = value
end

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
    local deadline = tick() + 30
    repeat task.wait() until type(saveinstance) == "function" or tick() > deadline
    if type(saveinstance) ~= "function" then
        return
    end

    local original = saveinstance
    local wrapped = function(...)
        local success, err = pcall(original, ...)
        if not success then return end
        pcall(Bluberii.misc_request, "copytostudio", "")
    end

    rawset(script_env, "saveinstance", wrapped)
    rawset(_G, "saveinstance", wrapped)
    rawset(Bluberii, "saveinstance", wrapped)
end)

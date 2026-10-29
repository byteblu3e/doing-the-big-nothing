local Bluberii = getgenv()
if rawget(Bluberii, "Bluberii") then Bluberii = rawget(Bluberii, "Bluberii") end
local misc_request = Bluberii.misc_request

local crypt = {}
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64lookup = {}
for i = 1, #b64chars do b64lookup[b64chars:sub(i,i)] = i - 1 end

function crypt.base64encode(data)
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

function crypt.base64decode(data)
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

crypt.base64_encode = crypt.base64encode
crypt.base64_decode = crypt.base64decode
crypt.base64 = { encode = crypt.base64encode, decode = crypt.base64decode }

function crypt.generatebytes(size)
    if type(size) ~= "number" then return "" end
    local raw = ""
    local seed = os.time() + math.floor(os.clock() * 1000)
    for i = 1, size do 
        seed = (seed * 1103515245 + 12345) % 2147483648
        raw = raw .. string.char(math.floor(seed) % 256)
    end
    return crypt.base64encode(raw)
end

function crypt.generatekey()
    return crypt.generatebytes(32)
end

function crypt.hash(data, algorithm)
    local ok, res = pcall(misc_request, "crypt.hash", tostring(algorithm or "sha256") .. "\n" .. data)
    if ok then return res end
    return "dummy_hash_" .. tostring(#data)
end

function crypt.encrypt(data, key, iv)
    local ok, res = pcall(misc_request, "crypt.encrypt", data)
    if ok then return res, crypt.generatebytes(16) end
    return data, crypt.generatebytes(16)
end

function crypt.decrypt(data, key, iv)
    local ok, res = pcall(misc_request, "crypt.decrypt", data)
    if ok then return res end
    return data
end

Bluberii.crypt = crypt
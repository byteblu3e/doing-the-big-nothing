local Bluberii = getgenv()
if rawget(Bluberii, "Bluberii") then Bluberii = rawget(Bluberii, "Bluberii") end
local misc_request = Bluberii.misc_request

local CONSOLE_LOG_PATH = "bluberii_console.log"
local VirtualFiles   = {}
local VirtualFolders = { [""] = true }

-- Deep research: comprehensive blocklist required by sUNC
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
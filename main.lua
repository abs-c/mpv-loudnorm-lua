-- main.lua
local mp = require('mp')
local md5 = require('md5')
local target_loud = "i=-24.0:tp=-1.0:lra=50.0"

local script_dir = mp.get_script_directory() -- get the dir of this script

local function get_md5(path)
    local chunk_size = 1024 * 1024
    local max_bytes = 10 * chunk_size
    local m = md5.new()

    local file = io.open(path, "rb")
    if not file then
        return nil, "Could not open file"
    end

    local bytes_read = 0
    while bytes_read < max_bytes do
        -- Read the next chunk
        local chunk = file:read(chunk_size)
        if not chunk then break end -- End of file reached

        -- Update MD5 calculation
        m:update(chunk)

        -- Increment bytes read
        bytes_read = bytes_read + #chunk
    end

    file:close() -- Close the file

    -- Return the computed MD5 as a hex string
    return md5.tohex(m:finish())
end

local function create_profile(path, profile_path)
    -- Run the first pass and capture the output
    local first_pass = mp.command_native({
        name = "subprocess",
        args = { "ffmpeg", "-hide_banner", "-i", path, "-vn", "-sn", "-dn", "-af", "ebur128=framelog=verbose,volumedetect", "-f", "null", "-" },
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true
    })

    local ffmpeg_log = first_pass.stderr

    -- Separate json part from ffmpeg log
    local inside_summary = false
    local summary = ""
    for line in string.gmatch(ffmpeg_log, "[^\r\n]+") do
        -- Check if the line contains the start of the JSON
        if string.find(line, "Parsed_ebur128_0") then
            inside_summary = true
        end
        if inside_summary then
            summary = summary .. line .. "\n"
        end
        if string.find(line, "histogram_[%d]+db") then
            inside_summary = false
            break
        end
    end

    -- Get formatted string for 2nd pass
    local measured_i = summary:match('I%s*:%s*([%-%.%d]+)%s*LUFS')
    local measured_tp = summary:match('max_volume%s*:%s*([%-%.%d]+)%s*dB')
    local measured_lra = summary:match('LRA%s*:%s*([%-%.%d]+)%s*LU')
    local measured_thresh = summary:match('Threshold%s*:%s*([%-%.%d]+)%s*LUFS.*Loudness range')

    local formatted_string = string.format("measured_i=%s:measured_tp=%s:measured_lra=%s:measured_thresh=%s",
        measured_i, measured_tp, measured_lra, measured_thresh)

    -- Write to profile
    local loud_profile = io.open(profile_path, "w+")
    if loud_profile then
        loud_profile:write(formatted_string)
        loud_profile:close()
        mp.osd_message("Profile created")
    else
        mp.osd_message("Failed to open the file for writing")
    end
end

local function apply_loudnorm()
    -- First, do a one-pass loudnorm
    mp.set_property("af", "loudnorm=" .. target_loud)

    -- File path and profile path
    local path = mp.get_property("path")
    local file_md5 = get_md5(path)
    local profile_path = script_dir .. "/data" .. "/" .. file_md5 .. ".txt"

    local loud_profile = io.open(profile_path, "r")
    local measured_loud = ""

    -- Check profile exist
    if loud_profile == nil then
        mp.osd_message("No existed loudnorm profile.")
        create_profile(path, profile_path)
        loud_profile = io.open(profile_path, "r")
    end

    -- Check profile format
    if loud_profile ~= nil then
        measured_loud = loud_profile:read("l")
        local pattern = "^measured_i=[%-%d%.]+:measured_tp=[%-%d%.]+:measured_lra=[%-%d%.]+:measured_thresh=[%-%d%.]+$"
        if not measured_loud:find(pattern) then
            loud_profile:close()
            mp.osd_message("Invalid loudnorm profile.")
            create_profile(path, profile_path)
        end
    end

    -- Read profile
    loud_profile = io.open(profile_path, "r")
    if loud_profile ~= nil then
        measured_loud = loud_profile:read("l")
        loud_profile:close()
    end

    local filter = "loudnorm=" .. target_loud .. ":" .. measured_loud
    mp.osd_message(filter)
    mp.set_property("af", filter)
end

-- auto

-- check extensions
local valid_extensions = { ".mkv", ".mp4", ".avi", ".mov", ".flv", ".wmv", ".webm" }
local function has_valid_extension(path)
    -- Convert the path to lower case and check if it ends with a valid extension
    local lower_path = path:lower()
    for _, ext in ipairs(valid_extensions) do
        if lower_path:sub(- #ext) == ext then
            return true
        end
    end
    return false
end

local function auto_norm()
    local path = mp.get_property("path")

    -- Check if the file is from Y: or Z: drive and has a valid video extension
    if (path:sub(1, 2):lower() == "y:" or path:sub(1, 2):lower() == "z:") and has_valid_extension(path) then
        apply_loudnorm()
    end
end

mp.register_event("file-loaded", auto_norm)
mp.register_script_message("2pass-loudnorm", apply_loudnorm)

-- main.lua
local mp = require("mp")
local loudnorm_enabled = false
local target_loud = "i=-24.0:tp=-1.0:lra=50.0:offset=0.0"

local script_dir = mp.get_script_directory() -- get the dir of this script

local function create_profile(path, profile_path, ff_audio_index)
    -- Run the first pass and capture the output
    local first_pass = mp.command_native({
        name = "subprocess",
        args = {
            "ffmpeg",
            "-hide_banner",
            "-i", path,
            "-vn", "-sn", "-dn",
            "-map", string.format("0:a:%d", ff_audio_index),
            "-af", "ebur128=framelog=verbose,volumedetect",
            "-f", "null", "-"
        },
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true
    })

    local first_pass_log = first_pass.stderr

    -- Separate json part from ffmpeg log
    local inside_summary = false
    local summary = ""
    for line in string.gmatch(first_pass_log, "[^\r\n]+") do
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
    local measured_i = summary:match("I%s*:%s*([%-%.%d]+)%s*LUFS")
    local measured_tp = summary:match("max_volume%s*:%s*([%-%.%d]+)%s*dB")
    local measured_lra = summary:match("LRA%s*:%s*([%-%.%d]+)%s*LU")
    local measured_thresh = summary:match("Threshold%s*:%s*([%-%.%d]+)%s*LUFS.*Loudness range")

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
    -- File path and profile path
    local path = mp.get_property("path")

    -- get current audio track
    local current_aid = mp.get_property_native("aid")
    local ff_audio_index = 0
    local audio_track_counter = 0
    for _, track in ipairs(mp.get_property_native("track-list")) do
        if track.type == "audio" then
            if track.id == current_aid then
                ff_audio_index = audio_track_counter
                break
            end
            audio_track_counter = audio_track_counter + 1
        end
    end

    -- get md5
    local get_audio_md5 = mp.command_native({
        name = "subprocess",
        args = {
            "ffmpeg",
            "-hide_banner",
            "-loglevel", "error",
            "-i", path,
            "-map", string.format("0:a:%d", ff_audio_index),
            "-c:a", "pcm_s16le", -- 统一编码格式
            "-f", "hash",
            "-hash", "md5",
            "-"
        },
        capture_stdout = true,
        capture_stderr = true
    })

    local audio_md5 = get_audio_md5.stdout:match("MD5=(%x+)")
    if audio_md5 then
        mp.msg.info("FFMpeg audio index: " .. ff_audio_index)
        mp.msg.info("Audio MD5: " .. audio_md5)
    else
        mp.msg.error("Failed to get MD5")
    end


    -- local file_md5 = get_md5(path)
    local profile_path = script_dir .. "/data" .. "/" .. audio_md5 .. ".txt"

    local loud_profile = io.open(profile_path, "r")
    local measured_loud = ""

    -- Check profile exist
    if loud_profile == nil then
        mp.osd_message("No existed loudnorm profile.")
        mp.set_property("af", "loudnorm=" .. target_loud)
        create_profile(path, profile_path, ff_audio_index)
        loud_profile = io.open(profile_path, "r")
    end

    -- Check profile format
    if loud_profile ~= nil then
        measured_loud = loud_profile:read("l")
        local pattern = "^measured_i=[%-%d%.]+:measured_tp=[%-%d%.]+:measured_lra=[%-%d%.]+:measured_thresh=[%-%d%.]+$"
        if not measured_loud:find(pattern) then
            loud_profile:close()
            mp.osd_message("Invalid loudnorm profile.")
            mp.set_property("af", "loudnorm=" .. target_loud)
            create_profile(path, profile_path, ff_audio_index)
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

local function disable_loudnorm()
    mp.set_property("af", "")
    mp.osd_message("Loudnorm disabled.")
end

local function toggle_loudnorm()
    if loudnorm_enabled then
        disable_loudnorm()
    else
        apply_loudnorm()
    end
    -- 切换状态
    loudnorm_enabled = not loudnorm_enabled
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

    if has_valid_extension(path) then
        apply_loudnorm()
        loudnorm_enabled = true
    end
end

-- loudnorm when load file or aid change
mp.register_event("file-loaded", function()
    -- auto_norm()
    mp.observe_property("aid", "number", auto_norm)
end)

mp.register_script_message("2pass-loudnorm", toggle_loudnorm)

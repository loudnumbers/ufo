-- ufo
-- v0.2 @duncangeere
--
-- ultra-low frequency oscillator
--
-- timbres informed by
-- the current position of
-- the international space
-- station above the earth.
--
-- sonification by
-- @duncangeere
--
-- sound design by
-- @jaseknighter
--
-- Requirements:
-- - Internet connection
-- - Space race nostalgia
--
-- Optional:
-- - Crow
-- > out 1: latitude (-5-5V)
-- > out 2: longitude (0-10V)
-- > out 3: distance from your
--   coordinates to ISS (0-10V)
--   (enable in script)
--

MusicUtil = require "musicutil"
ns = include("ufo/lib/notes_scales")
include("ufo/lib/midi_helper")
lfos = require 'lfo'

-- Set your personal latitude and longitude coordinates here:
local localLat = 56.04673;
local localLon = 12.69437;
local usedist = true;

-- Set custom engine mappings if you desire
local mappings = {
    -- Latitude mappings
    latitude = { {
        parameter = "eng_absorb", -- Change this for different sound mappings
        inmin = 0,                -- Don't change this
        inmax = 51.6,             -- Don't change this
        outmin = 0,               -- Change this to adjust the range of permitted values
        outmax = 0.6              -- Change this to adjust the range of permitted values
    }, {
        parameter = "eng_delay",  -- Change this for different sound mappings
        inmin = 0,                -- Don't change this
        inmax = 51.6,             -- Don't change this
        outmin = 0,               -- Change this to adjust the range of permitted values
        outmax = 1.05             -- Change this to adjust the range of permitted values
    } },
    -- Longitude mappings
    longitude = { {
        parameter = "eng_decay", -- Change this for different sound mappings
        inmin = -180,            -- Don't change this
        inmax = 180,             -- Don't change this
        outmin = 0.2,            -- Change this to adjust the range of permitted values
        outmax = 1.4             -- Change this to adjust the range of permitted values
    } },
    -- Distance mappings
    distance = { {
        parameter = "eng_detune", -- Change this for different sound mappings
        inmin = 0,                -- Don't change this
        inmax = 1,                -- Don't change this
        outmin = 0,               -- Change this to adjust the range of permitted values
        outmax = 1                -- Change this to adjust the range of permitted values
    } }
}

-- Select synth engine
engine.name = "SupSawEV"

-- https://github.com/rxi/json.lua library for reading json into lua
local json = include("lib/json")

-- Import musicutil library: https://monome.org/docs/norns/reference/lib/musicutil
musicutil = require("musicutil")

-- Constants
local api = "https://api.wheretheiss.at/v1/satellites/25544"
local backup = "data.json"

-- Variables
local dl
local lat
local lon
local dist
local areweloaded = false
local audiobroadcast = false

-- Init function
function init()
    -- add the engine parameters
    add_params()

    -- start a clock to refresh the data
    clock.run(grabdata_clock)

    iss_brightness = 0;
    brightness_lfo = lfos:add {
        shape = 'saw', -- shape
        min = 0,       -- min
        max = 15,      -- max
        depth = 1,     -- depth (0 to 1)
        mode = 'free', -- mode
        period = 1,    -- period (in seconds)
        -- pass our 'scaled' value (bounded by min/max and depth) to the engine:
        action = function(scaled, raw)
            iss_brightness = math.floor(scaled)
            screen_dirty = true
        end -- action, always passes scaled and raw values
    }
    brightness_lfo:start()

    -- Start a clock to refresh the screen
    screen_dirty = true

    redraw_timer = metro.init(
        function() -- what to perform at every tick
            if screen_dirty == true then
                redraw()
                screen_dirty = false
            end
        end,
        1 / 15 -- how often (15 fps)
    -- the above will repeat forever by default
    )
    redraw_timer:start()
end

-- This function grabs the data
function grabdata_clock()
    while true do
        dl = util.os_capture("curl -s -m 30 -k " .. api)
        if (#dl > 75) then
            print("ISS successfully reached, downloading coordinates.")
            local File = io.open(_path.code .. "ufo/" .. backup, 'w')
            File:write(dl)
            --print("New backup saved")
            File:close()
        else
            print("Failed to access ISS, using backup data instead.")
            io.input(_path.code .. "ufo/" .. backup)
            dl = io.read("*all")
        end
        process(dl)
        areweloaded = true

        -- Update engine parameters
        -- latitude
        -- note, uses math.abs() - so values *away from the equator* will be larger
        for i, v in ipairs(mappings.latitude) do
            params:set(v.parameter, map(math.abs(lat), v.inmin, v.inmax, v.outmin, v.outmax))
        end

        -- longitude
        for i, v in ipairs(mappings.longitude) do
            params:set(v.parameter, map(lon, v.inmin, v.inmax, v.outmin, v.outmax))
        end

        -- distance
        if usedist then
            for i, v in ipairs(mappings.distance) do
                params:set(v.parameter, map(dist, v.inmin, v.inmax, v.outmin, v.outmax))
            end
        end

        -- Set crow output voltages
        -- latitude
        -- note that this does not use math.abs() - you'll get negative values out for negative latitudes
        crow.output[1].volts = map(lat, -51.6, 51.6, -5, 5)

        -- longitude
        crow.output[2].volts = map(lon, -180, 180, 0, 10)

        -- distance
        if usedist then
            crow.output[3].volts = map(dist, 0, 1, 0, 10)
        end

        screen_dirty = true
        clock.sleep(30) -- get data every 30 seconds
    end
end

-- this function runs when data is downloaded.
-- it processes the data and then updates the
-- local variables that handle it
function process(download)
    -- decode json
    local everything = json.decode(download)
    lat = everything.latitude
    lon = everything.longitude
    print("latitude: " .. lat)
    print("longitude: " .. lon)

    if (usedist) then
        dist = distance(lat, lon, localLat, localLon)
        print("distance: " .. dist)
    end

    print(" ")
end

-- Visuals
function redraw()
    -- check if data is loaded
    if (areweloaded) then
        screen.clear()
        screen.aa(1)
        screen.font_size(10)
        screen.font_face(1)

        -- draw the map
        screen.level(2)
        screen.display_png(_path.code .. 'ufo/world-8bit.png', 0, 0)

        -- draw the iss
        screen.level(iss_brightness)
        x = map(lon, -180, 180, 0, 128)
        y = map(lat, -90, 90, 64, 0)
        screen.display_png(_path.code .. 'ufo/iss.png', x - 4.5, y - 2.5)

        screen.level(10)
        if (not audiobroadcast) then
            screen.move(64, 62)
            screen.level(16)
            screen.font_size(6)
            screen.text_center("press k3 to receive audio signals")
        end
    else
        screen.aa(1)
        screen.font_size(8)
        screen.level(15)
        screen.move(64, 32)
        screen.text_center("please wait - loading...")
    end

    -- trigger a screen update
    screen.update()
end

-- All the parameters
function add_params()
    local function strip_trailing_zeroes(s)
        return string.format('%.2f', s):gsub("%.?0+$", "")
    end

    params:add_separator('header', 'engine controls')

    ------------------------------
    -- voice controls
    ------------------------------
    -- amp control
    params:add_control(
        'eng_amp', -- ID
        'amp',     -- display name
        controlspec.new(
            0,     -- min
            2,     -- max
            'lin', -- warp
            0.001, -- output quantization
            1,     -- default value
            '',    -- string for units
            0.005  -- adjustment quantization
        ),
        -- params UI formatter:
        function(param)
            return strip_trailing_zeroes(param:get() * 100) .. '%'
        end
    )
    params:set_action('eng_amp',
        function(x)
            engine.amp(x)
            screen_dirty = true
        end
    )

    -- mix control
    params:add_control('eng_mix', 'mix',
        controlspec.new(0, 1, 'lin', 0.001, 0.75, '', 0.005))
    params:set_action('eng_mix',
        function(x)
            engine.mix(x)
            screen_dirty = true
        end
    )

    -- detune control
    params:add_control('eng_detune', 'detune',
        controlspec.new(0, 1, 'lin', 0.001, 0.75, '', 0.005))
    params:set_action('eng_detune',
        function(x)
            engine.detune(x)
            screen_dirty = true
        end
    )

    -- frequency cutoof min control
    params:add_control('eng_cutoff_min', 'filter cutoff min',
        controlspec.new(40, 16000, 'exp', 10, 400, ''))
    params:set_action('eng_cutoff_min',
        function(x)
            if x > params:get("eng_cutoff_max") then
                x = params:get("eng_cutoff_max")
                params:set("eng_cutoff_min", x)
            end
            engine.cutoffMin(x)
            screen_dirty = true
        end
    )

    -- frequency cutoof max control
    params:add_control('eng_cutoff_max', 'filter cutoff max',
        controlspec.new(40, 16000, 'exp', 10, 8500, ''))
    params:set_action('eng_cutoff_max',
        function(x)
            if x < params:get("eng_cutoff_min") then
                x = params:get("eng_cutoff_min")
                params:set("eng_cutoff_max", x)
            end
            engine.cutoffMax(x)
            screen_dirty = true
        end
    )

    -- HPF frequency cutoff control
    params:add_control('hpf_cutoff', 'highpass filter cutoff',
        controlspec.new(40, 16000, 'exp', 400, 8500, ''))
    params:set_action('hpf_cutoff',
        function(x)
            engine.hpfCutoff(x)
            screen_dirty = true
        end
    )

    ------------------------------
    -- reverb controls
    ------------------------------
    params:add_separator('header', 'reverb controls')

    -- decay control
    params:add_control('eng_decay', 'decay',
        controlspec.new(0, 1.5, 'lin', 0.001, 0.3, '', 0.005))
    params:set_action('eng_decay',
        function(x)
            engine.decay(x)
            screen_dirty = true
        end
    )

    -- absorb control
    params:add_control('eng_absorb', 'absorb',
        controlspec.new(0, 1, 'lin', 0.001, 0.1, '', 0.005))
    params:set_action('eng_absorb',
        function(x)
            engine.absorb(x)
            screen_dirty = true
        end
    )

    -- modulation control
    params:add_control('eng_modulation', 'modulation',
        controlspec.new(0, 1, 'lin', 0.001, 0.01, '', 0.005))
    params:set_action('eng_modulation',
        function(x)
            engine.modulation(x)
            screen_dirty = true
        end
    )

    -- modRate control
    params:add_control('eng_modRate', 'modRate',
        controlspec.new(0, 1, 'lin', 0.001, 0.05, '', 0.005))
    params:set_action('eng_modRate',
        function(x)
            engine.modRate(x)
            screen_dirty = true
        end
    )

    -- delay control
    params:add_control('eng_delay', 'delay',
        controlspec.new(0, 3, 'lin', 0.001, 0.3, '', 0.005))
    params:set_action('eng_delay',
        function(x)
            engine.delay(x)
            screen_dirty = true
        end
    )
    -- add the notes_scales params
    ns.add_params()
    params:add_binary("reset_notes", "Reset note list", "momentary")
    params:set_action("reset_notes", reset_default_notes)

    ns.build_scale()
    get_midi_devices()
    params:bang()
end

-- Check if the screen needs redrawing 15 times a second
function redraw_clock()
    while true do
        clock.sleep(1 / 15)

        -- Norns screen
        if screen_dirty then
            redraw()
            screen_dirty = false
        end
    end
end

-- Function to map values from one range to another
function map(n, start, stop, newStart, newStop, withinBounds)
    local value = ((n - start) / (stop - start)) * (newStop - newStart) +
        newStart

    -- // Returns basic value
    if not withinBounds then return value end

    -- // Returns values constrained to exact range
    if newStart < newStop then
        return math.max(math.min(value, newStop), newStart)
    else
        return math.max(math.min(value, newStart), newStop)
    end
end

-- Function to calculate great circle distance
-- between lat/lon coordinates. Max 1, Min 0
-- Modded version of this formula:
-- https://forums.x-plane.org/index.php?/forums/topic/156027-calculate-distance-great-circle-function/

function distance(lat1, lon1, lat2, lon2)
    local lat1r = lat1 / 180 * math.pi
    local lon1r = lon1 / 180 * math.pi
    local lat2r = lat2 / 180 * math.pi
    local lon2r = lon2 / 180 * math.pi
    local dlonr = lon2r - lon1r
    local dlatr = lat2r - lat1r

    local a = math.sin(dlatr / 2) * math.sin(dlatr / 2) + math.cos(lat1r) *
        math.cos(lat2r) * math.sin(dlonr / 2) * math.sin(dlonr / 2)
    local b = 2 * math.atan(math.sqrt(a), math.sqrt(1 - a))

    return usedist and b / math.pi or 0;
end

function enc(n, d)
end

-- when a key is depressed, toggle audio playback
function key(n, z)
    if n == 3 and z == 1 then
        if audiobroadcast then
            audiobroadcast = false
            print("Audio signal lost")
            engine.stop(0)
            --params:set("eng_amp", 0)
        else
            audiobroadcast = true
            print("Receiving audio signal")
            engine.start(0)
            --params:set("eng_amp", 1)
        end
    end
end

function cleanup()
    engine.stop(0)
end

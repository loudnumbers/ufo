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
--   position to ISS (0-10V)
--   (enable in script)
--

MusicUtil = require "musicutil"
ns = include("ufo/lib/notes_scales")
include("ufo/lib/midi_helper")

-- Set your personal latitude and longitude here
local localLat = 56.04673;
local localLon = 12.69437;
local usedist = true;

-- Set custom engine mappings if you desire
local mappings = {
    latitude = {
        parameter = "eng_modulation", -- Change this for different sound mappings
        inmin = -51.6,                -- Don't change this
        inmax = 51.6,                 -- Don't change this
        outmin = 0,                   -- Change this to adjust the range of permitted values
        outmax = 1                    -- Change this to adjust the range of permitted values
    },
    longitude = {
        parameter = "eng_decay", -- Change this for different sound mappings
        inmin = -180,            -- Don't change this
        inmax = 180,             -- Don't change this
        outmin = 0,              -- Change this to adjust the range of permitted values
        outmax = 1               -- Change this to adjust the range of permitted values
    },
    distance = {
        parameter = "eng_detune", -- Change this for different sound mappings
        inmin = 0,                -- Don't change this
        inmax = 1,                -- Don't change this
        outmin = 0,               -- Change this to adjust the range of permitted values
        outmax = 1                -- Change this to adjust the range of permitted values
    }
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

-- Init function
function init()
    -- add the engine parameters
    add_params()

    -- start a clock to refresh the data
    clock.run(grabdata_clock)

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
            print("API successfully reached")
            local File = io.open(_path.code .. "ufo/" .. backup, 'w')
            File:write(dl)
            print("New backup saved")
            File:close()
        else
            print("Failed to access API, using backup instead.")
            io.input(_path.code .. "ufo/" .. backup)
            dl = io.read("*all")
        end
        process(dl)
        areweloaded = true

        -- Update engine parameters
        -- latitude
        params:set(mappings.latitude.parameter,
            map(lat,
                mappings.latitude.inmin,
                mappings.latitude.inmax,
                mappings.latitude.outmin,
                mappings.latitude.outmax))

        -- longitude
        params:set(
            mappings.longitude.parameter,
            map(lon,
                mappings.longitude.inmin,
                mappings.longitude.inmax,
                mappings.longitude.outmin,
                mappings.longitude.outmax))

        -- distance
        if usedist then
            params:set(
                mappings.distance.parameter,
                map(dist,
                    mappings.distance.inmin,
                    mappings.distance.inmax,
                    mappings.distance.outmin,
                    mappings.distance.outmax))
        end

        -- Set crow output voltages
        -- latitude
        crow.output[1].volts = map(
            lat,
            mappings.latitude.inmin,
            mappings.latitude.inmax,
            -5, 5)

        -- longitude
        crow.output[2].volts = map(
            lon,
            mappings.longitude.inmin,
            mappings.longitude.inmax,
            0, 10)

        -- distance
        if usedist then
            crow.output[3].volts = map(
                dist,
                mappings.distance.inmin,
                mappings.distance.inmax,
                0, 10)
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
        screen.font_face(4)

        -- draw the map
        screen.level(2)
        screen.display_png(_path.code .. 'ufo/world-8bit.png', 0, 0)

        -- draw the iss
        screen.level(10)
        x = map(lon, -180, 180, 0, 128)
        y = map(lat, -90, 90, 64, 0)
        screen.display_png(_path.code .. 'ufo/iss.png', x - 4.5, y - 2.5)
    else
        screen.aa(1)
        screen.font_size(8)
        screen.font_face(1)
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
        controlspec.new(0, 1, 'lin', 0.001, 0.5, '', 0.005))
    params:set_action('eng_mix',
        function(x)
            engine.mix(x)
            screen_dirty = true
        end
    )

    -- detune control
    params:add_control('eng_detune', 'detune',
        controlspec.new(0, 1, 'lin', 0.001, 0.5, '', 0.005))
    params:set_action('eng_detune',
        function(x)
            engine.detune(x)
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
            engine.detune(x)
            screen_dirty = true
        end
    )

    -- absorb control
    params:add_control('eng_absorb', 'absorb',
        controlspec.new(0, 1, 'lin', 0.001, 0.1, '', 0.005))
    params:set_action('eng_absorb',
        function(x)
            engine.detune(x)
            screen_dirty = true
        end
    )

    -- modulation control
    params:add_control('eng_modulation', 'modulation',
        controlspec.new(0, 1, 'lin', 0.001, 0.01, '', 0.005))
    params:set_action('eng_modulation',
        function(x)
            engine.detune(x)
            screen_dirty = true
        end
    )

    -- modRate control
    params:add_control('eng_modRate', 'modRate',
        controlspec.new(0, 1, 'lin', 0.001, 0.05, '', 0.005))
    params:set_action('eng_modRate',
        function(x)
            engine.detune(x)
            screen_dirty = true
        end
    )

    -- delay control
    params:add_control('eng_delay', 'delay',
        controlspec.new(0, 1.5, 'lin', 0.001, 0.3, '', 0.005))
    params:set_action('eng_delay',
        function(x)
            engine.detune(x)
            screen_dirty = true
        end
    )
    -- add the notes_scales params
    ns.add_params()
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
    -- Some code should go here that doesn't start playing the engine until e.g. button 3 is pressed
end

function cleanup()

end

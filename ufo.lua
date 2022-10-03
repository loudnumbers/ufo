-- ufo
-- v0.1 @duncangeere
--
-- ultra-low frequency oscillator
-- 
-- use the current position of
-- the international space
-- station to modulate your 
-- eurorack patches.
--
-- Requirements:
-- - Internet connection
-- - Crow
-- > out 1: latitude (-5-5V)
-- > out 2: longitude (0-10V)
-- > out 3: distance from your
--   position to ISS (0-10V)
--   (only if enabled in script)
--
engine.name = "PolyPerc" -- Pick synth engine

-- Set your personal latitude and longitude here
localLat = 56.04673;
localLon = 12.69437;
uselocal = true;

local json = include("lib/json")
-- https://github.com/rxi/json.lua

-- Import musicutil library: https://monome.org/docs/norns/reference/lib/musicutil
musicutil = require("musicutil")

-- Constants
local maxlat = 51.6
local api = "https://api.wheretheiss.at/v1/satellites/25544"
local backup = "data.json"

-- Variables
local dl
local lat
local lon
local areweloaded = false

-- Init function
function init()

    -- addparams()
    engine.amp(0)

    -- start a clock to refresh the data
    clock.run(grabdata_clock)

    -- Start a clock to refresh the screen
    clock.run(redraw_clock)

    screen_dirty = true
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

        -- Set crow output voltages
        crow.output[1].volts = map(lat, -maxlat, maxlat, -5, 5)
        crow.output[2].volts = map(lon, -180, 180, 0, 10)
        if uselocal then crow.output[3].volts = map(dist, 0, 1, 0, 10) end

        screen_dirty = true
        clock.sleep(30) -- get data every 30 seconds
    end
end

-- This function runs when data is downloaded
function process(download)

    -- decode json
    local everything = json.decode(download)
    lat = everything.latitude
    lon = everything.longitude
    print("latitude: " .. lat)
    print("longitude: " .. lon)

    if (uselocal) then
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

        -- draw the circle
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
function addparams()

    -- Root Note
    params:add{
        type = "number",
        id = "root_note",
        name = "root note",
        min = 0,
        max = 127,
        default = math.random(50, 60),
        formatter = function(param)
            return musicutil.note_num_to_name(param:get(), true)
        end
    }
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
    local b = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return uselocal and b / math.pi or 0;
end

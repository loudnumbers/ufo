-- notes and scales

local ns = {}

local scale_length = 48
local root_note_default = 24
local scale_names = {}
scale = {}


for i = 1, #MusicUtil.SCALES do
  table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
end

ns.build_scale = function()
  scale = {}
  scale = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), scale_length)
  local num_to_add = scale_length - #scale
  for i = 1, num_to_add do
    table.insert(scale, scale[scale_length - num_to_add])
  end
  -- tab.print(scale)
end

ns.set_scale_length = function()
  scale_length = params:get("scale_length")
end

ns.quantize_note = function(note_num)
  local new_note_num
  for i = 1, #scale - 1, 1 do
    if note_num >= scale[i] and note_num <= scale[i + 1] then
      if note_num - scale[i] < scale[i + 1] - note_num then
        new_note_num = scale[i]
      else
        new_note_num = scale[i + 1]
      end
      break
    end
  end

  if new_note_num == nil then
    print(note_num, scale[1])
    if note_num < scale[1] then
      new_note_num = scale[1]
    else
      new_note_num = scale[#scale]
    end
  end
  return new_note_num
end

------------------------------
-- add params
------------------------------
-- note scale controls
------------------------------

function ns.add_params()
  params:add_separator('header', 'notes / scales')

  params:add { type = "option", id = "scale_mode", name = "scale mode",
    options = scale_names, default = 6,
    action = function()
      quantize_notes_to_scale()
      ns.build_scale()
    end }


  params:add { type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = root_note_default, formatter = function(param)
    return MusicUtil.note_num_to_name(param:get(), true)
  end
  }
  params:set_action("root_note", function() ns.build_scale() end)

  ------------------------------
  -- midi controls
  ------------------------------

  params:add_separator("midi")

  midi_devices = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }

  midi_in_device = {}

  params:add {
    type = "option", id = "midi_device", name = "device", options = midi_devices,
    min = 1, max = 16, default = 1,
    action = function(value)
      midi_in_device.event = nil
      midi_in_device = midi.connect(value)
      midi_in_device.event = midi_event
    end
  }

  params:add { type = "option", id = "quantize", name = "quantize midi",
    options = { "no", "yes" }, default = 2,
  }
end

function get_midi_devices()
  local devices = {}
  for i = 1, #midi.vports, 1
  do
    table.insert(devices, i .. ". " .. midi.vports[i].name)
  end
  midi_devices = devices
  local midi_in = params:lookup_param("midi_device")
  midi_in.options = midi_devices
end

return ns

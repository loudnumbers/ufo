-- midi helper global variables and functions

-------------------------------
-- midi handler functions
-------------------------------
local notes = {}
local setting_notes = false
local setting_notes_ix = 0

function set_notes(on_off, note)
  if on_off == "on" then
    if setting_notes == false then
      setting_notes = true
      setting_notes_ix = 0
      notes = {}
    end
    if params:get("quantize") == 2 then
      note = ns.quantize_note(note)
    end
    table.insert(notes, note)
    setting_notes_ix = setting_notes_ix + 1
    print("add note", note, setting_notes_ix)
    engine.update_num_notes(#notes)
    engine.update_notes(table.unpack(notes))
  else
    setting_notes_ix = setting_notes_ix - 1
    if setting_notes_ix == 0 then
      setting_notes = false
      print("notes all set")
    end
  end
end

midi_event = function(data)
  local msg = midi.to_msg(data)
  if msg.type == "stop" or msg.type == "start" then
    print("stopping/starting:", msg.type)
  end
  if msg.type == "start" then
    print("start")
    engine.start()
  elseif msg.type == "stop" then
    print("stop")
    engine.stop()
  else
    local note_to_play = data[2]
    if note_to_play then
      if data[1] == 144 then   -- note off
        print("note on", note_to_play)
        set_notes("on", note_to_play)
      elseif data[1] == 128 then   -- note off
        print("note off", note_to_play)
        set_notes("off", note_to_play)
      end
    end
  end
end

function reset_default_notes()
  notes = { 60, 61, 63, 65, 72, 84, 32 }
  for i = 1, #notes do
    if params:get("quantize") == 2 then
      notes[i] = ns.quantize_note(notes[i])
    end
  end
  engine.update_num_notes(#notes)
  engine.update_notes(table.unpack(notes))
end

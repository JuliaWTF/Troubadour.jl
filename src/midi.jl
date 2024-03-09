"""
Turns the LLVM of an expression into a complex MIDI file and plays it.
You can use:

```julia
@llvm_midi ex record = true
```

To get a recording in `.mp3` and `.wav` as well.
"""
macro llvm_midi(ex, kwargs...)
    record = if !isempty(kwargs)
        kwarg = only(kwargs)
        kwarg.head == :(=) && first(kwarg.args) == :record && last(kwarg.args)
    else
        false
    end
    @assert ex.head == :call
    s_ex = string(ex)
    fn = first(ex.args)
    args = Base.tail(Tuple(ex.args))
    return esc(
        quote
            @async play_midi(
                $(s_ex),
                $(Core.eval(__module__, fn)),
                $(typeof.(Core.eval.(Ref(__module__), args)));
                record=$(record),
            )
            $(ex)
        end,
    )
end

function change_instrument!(track::MIDITrack, instrument::Integer=0, channel::Integer=0x00)
    return push!(
        track.events, MIDI.ProgramChangeEvent(0, UInt8(0xc0 + channel * 0x00), instrument)
    )
end

function create_midi(llvm::AbstractString)
    nodes_lines = parse_llvm(llvm)
    T = 0
    ΔT = 200
    velocity = 100
    notes = Notes("F2 A2 C2 E2")
    track = MIDITrack()
    instrument = 0
    change_instrument!(track, instrument)

    for node_line in nodes_lines
        isempty(node_line) && continue
        # Play some drums
        if first(node_line).val == "define"
            instrument = hash_and_project(node_line[2:end])
            change_instrument!(track, instrument)
        elseif first(node_line).type != Variable
            # If the line is not an assigment (%1 = ....) We play some drums!
            change_instrument!(track, 118)
            for node in node_line
                pitch = hash_and_project(node)
                addnote!(track, Note(pitch, velocity, T, ΔT))
                T += ΔT
            end
            change_instrument!(track, instrument)
        else
            for node in node_line
                if node.type == Instruction
                    instrument = hash_and_project(node)
                    change_instrument!(track, instrument)
                else
                    n = length(notes)
                    pitch = hash_and_project(node)
                    # note = notes[Int64(mod1(hash(node), n))]
                    # pitch = note.pitch
                    addnote!(track, Note(pitch, velocity, T, ΔT))
                    T += ΔT
                end
            end
        end
    end
    return track
end

function play_midi(ex, fn, types; record::Bool=false)
    llvm = get_llvm_string(fn, types)
    midi_track = create_midi(llvm)
    midi_file = MIDIFile()
    push!(midi_file.tracks, midi_track)
    path = first(mktemp()) * ".mid"
    MIDI.save(path, midi_file)
    if record
        @async record_synth(path, ex)
    end
    play_synth(path)
    return nothing
end
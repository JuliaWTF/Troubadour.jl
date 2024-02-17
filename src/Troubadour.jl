module Troubadour
using ProgressMeter
using Suppressor
using InteractiveUtils
using MIDI

using LAME_jll: lame
using Pkg.Artifacts

export play_code, @llvm_play, play_midi, @llvm_midi

const soundfontpath = artifact"soundfont"
const soundfont = joinpath(soundfontpath, "8MBGMSFX.sf2")

include("llvm.jl")
include("play.jl")

const MAX_BIT = 128

"Plays the LLVM of an expression with Cs"
macro llvm_play(ex)
    @assert ex.head == :call
    fn = first(ex.args)
    args = Base.tail(Tuple(ex.args))
    return esc(
        quote
            @async play_code(
                $(Core.eval(__module__, fn)), $(typeof.(Core.eval.(Ref(__module__), args)))
            )
            $(ex)
        end,
    )
end

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

hash_and_project(x, max::Integer=MAX_BIT) = Int(rem(hash(x), max))

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

function play_code(fn, types)
    llvm = get_llvm_string(fn, types)
    node_lines = parse_llvm(llvm)
    @showprogress for node_line in node_lines
        idx = findfirst(n -> n.type == Instruction, node_line)
        code = if isnothing(idx)
            node_line
        else
            node_line[idx].val
        end
        t = 0.2 # (rand() * 5.0) + 0.05
        start_t = 0.0 # rand()
        run(play_operation(code, t, start_t))
    end
end

function play_operation(code, duration, start_t::Real=0)
    note_ = hash_and_project(code, 5) + 3
    note = "C$(note_)"
    !iszero(start_t) && sleep(start_t)
    cmd = `play -qn synth $(duration) pluck $(note)`
    return cmd
end

end

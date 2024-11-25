
using MusicTheory: Pitch, C, C♯, D, D♯, E, F, F♯, G, G♯, A, A♯, B, Minor, Major
using MusicTheory: Scale, major_scale, melodic_minor_scale, natural_minor_scale
using MusicTheory: Interval, Major_3rd, Minor_2nd
const Minor_3rd = Interval(3, Minor)

const major_7 = [Major_3rd, Minor_3rd, Major_3rd, Minor_2nd]

const scales = [major_scale, melodic_minor_scale, natural_minor_scale, major_7]

const pitches = [
    C[3], C♯[3], D[3], D♯[3], E[3], F[3], F♯[3], G[3], G♯[3], A[3], A♯[3], B[3]
]

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
    ex.head == :call || throw(
        ArgumentError(
            "the expression must of the form `f(args...)` (without broadcasting)."
        ),
    )
    s_ex = string(ex)
    fn = first(ex.args)
    args = Base.tail(Tuple(ex.args))
    return esc(
        quote
            t = Threads.@spawn play_midi(
                $(s_ex),
                $(Core.eval(__module__, fn)),
                $(typeof.(Core.eval.(Ref(__module__), args)));
                record=$(record),
            )
            ans = $(ex)
            fetch(t)
            ans
        end,
    )
end

function change_instrument!(track::MIDITrack, instrument::Integer=0, channel::Integer=0x00)
    return push!(
        track.events, MIDI.ProgramChangeEvent(0, UInt8(0xc0 + channel * 0x00), instrument)
    )
end

function generate_tonic(x)
    return pitches[hash_and_project(x, length(pitches), true)]
end

function generate_scale(tonic, x)
    return Scale(tonic, scales[hash_and_project(x, length(scales), true)])
end

function generate_pitch(scale, x)
    v = hash_and_project(x, 5, true)
    music_theory_pitch = collect(Iterators.take(scale, v))[v]
    return tone_to_pitch(music_theory_pitch)
end

function tone_to_pitch(x::Pitch)
    return string(x.class, x.octave)
end

const drum_codes = [108, 114, 115, 116, 117, 118]

"""
Create a `MIDITrack` from LLVM code (as a string).
"""
function create_midi(
    llvm::AbstractString; forced_instrument::Union{Nothing,Integer}=nothing
)
    nodes_lines = parse_llvm(llvm)
    T = 0
    ΔT = 250
    velocity = 100
    track = MIDITrack()
    instrument = something(forced_instrument, 117)
    change_instrument!(track, instrument)
    tonic = first(pitches)

    for node_line in nodes_lines
        isempty(node_line) && continue
        # Play some drums
        if first(node_line).val == "define"
            instrument = hash_and_project(node_line[2:end])
            change_instrument!(track, something(forced_instrument, instrument))
            tonic = generate_tonic(node_line[2:end])
        elseif first(node_line).type != Variable
            # If the line is not an assigment (%1 = ....) We play some drums!
            drum = hash_and_project(first(node_line), length(drum_codes), true)
            change_instrument!(track, something(forced_instrument, drum_codes[drum]))
            for node in node_line
                pitch = hash_and_project(node)
                addnote!(track, Note(pitch, velocity, T, ΔT))
                T += ΔT
            end
            change_instrument!(track, instrument)
        else
            scale = generate_scale(tonic, node_line[1])
            for node in node_line[2:end]
                if node.type == Instruction
                    instrument = hash_and_project(node)
                    change_instrument!(track, something(forced_instrument, instrument))
                else
                    pitch = generate_pitch(scale, node)
                    addnote!(track, Note(pitch; velocity, position=T, duration=ΔT))
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
    tmp_dir = mktempdir()
    midi_path = joinpath(tmp_dir, string(ex) * ".mid")
    midi_log = joinpath(tmp_dir, string(ex) * ".log")
    MIDI.save(midi_path, midi_file)
    if record
        @async record_synth(midi_path, ex)
    end
    play_synth(midi_path, midi_log)
    return nothing
end

using Pitches

const SpelledPitch = Pitch{SpelledInterval}

const major_scale_class = cumsum([
    i"P1:0", i"M2:0", i"M2:0", i"m2:0", i"M2:0", i"M2:0", i"M2:0"
])
const a_cool_scale = cumsum([i"P1:0", i"m2:0", i"m2:0", i"M2:0", i"M2:0", i"M2:0", i"M2:0"])

const scale_classes = [a_cool_scale]#, melodic_minor_scale, natural_minor_scale, major_7]

const base_pitches = [
    p"C4", p"C#4", p"D3", p"D♯4", p"E4", p"F4", p"F♯4", p"G4", p"G♯4", p"A4", p"A♯4", p"B4"
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

"Pick a tonic out of a collection of pitches, based on the hash of `x`."
function generate_tonic(x)
    return base_pitches[hash_and_project(x, length(base_pitches), true)]
end

"Pick a scale out of a collection, based on the hash of `x`."
function choose_scale(x, scale, scale_degree)
    new_scale = scale_classes[hash_and_project(x, length(scale_classes), true)]
    # TODO Update the scale degree gracefully
    new_scale_degree = scale_degree
    return new_scale, new_scale_degree
end

midi_semitones(scale) = map(x -> tomidi(x).interval, scale)

function choose_track(x, n_tracks)
    n_tracks <= 2 && return 1
    n_available_tracks = n_tracks - 1
    return collect(1:n_available_tracks)[hash_and_project(x, n_available_tracks, true)]
end
function generate_scale_degree(scale_class_length::Int, current_scale_degree::Int, x)::Int
    Random.seed!(hash(x))
    Δ = rand(Binomial(2 * scale_class_length, 0.5)) - scale_class_length
    return current_scale_degree + Δ
end

function midipitch(
    scale_class::Vector{SpelledInterval}, tonic::SpelledPitch, scale_degree::Int
)
    n = length(scale_class)
    oct, idx = divrem(scale_degree, n)
    return tomidi(embed(pc(tonic), 0)) + tomidi(scale_class[idx + 1]) + 12 * midi(oct)
end

"Convert a MusicTheory.jl pitch to a string to be fed to MIDI.jl."
function pitch_to_midi(x::Pitch)
    return string(x.class, x.octave)
end

"Drum codes associated withe soundfont in `soundfont_path()`."
const drum_codes = [108, 114, 115, 116, 117, 118]

"""
Create a collection of `MIDITrack`s from LLVM code (as a string).
"""
function create_midi(
    llvm::AbstractString;
    forced_instrument::Union{Nothing,Integer}=nothing,
    n_tracks::Integer=4,
)
    @assert n_tracks > 0
    nodes_lines = filter(!isempty, parse_llvm(llvm))
    Ts = zeros(n_tracks)
    ΔT = 250
    velocity = 100
    tracks = [MIDITrack() for _ in 1:n_tracks]
    instrument = something(forced_instrument, 117)
    for track in tracks
        change_instrument!(track, instrument)
    end
    tonic = first(base_pitches)
    scale = first(scale_classes)
    scale_degree = length(scale) * (div(tomidi(tonic).pitch.interval, 12) - 1)

    for node_line in nodes_lines
        isempty(node_line) && continue
        if first(node_line).val == "define"
            # Define is the first line of the LLVM code and determines the tonic used as well as the instrument.
            instrument = hash_and_project(node_line[2:end])
            for track in tracks
                change_instrument!(track, something(forced_instrument, instrument))
            end
            tonic = generate_tonic(node_line[2:end])
            scale_degree = length(scale) * (div(tomidi(tonic).pitch.interval, 12) - 1)
        elseif first(node_line).type != Variable
            # If the line is not an assigment (%1 = ....) We play some drums!
            drum = hash_and_project(first(node_line), length(drum_codes), true)
            let track = last(tracks)
                change_instrument!(track, something(forced_instrument, drum_codes[drum]))
                for node in node_line
                    pitch = hash_and_project(node)
                    addnote!(track, Note(pitch, velocity, Ts[end], ΔT))
                    Ts[end] += ΔT
                end
                change_instrument!(track, instrument)
            end
        else
            t_id = choose_track(node_line, n_tracks)
            scale, scale_degree = choose_scale(node_line[1], scale, scale_degree) # the length of the scale might change
            for node in node_line[2:end]
                if node.type == Instruction
                    instrument = hash_and_project(node)
                    change_instrument!(
                        tracks[t_id], something(forced_instrument, instrument)
                    )
                else
                    scale_degree = generate_scale_degree(length(scale), scale_degree, node)
                    current_pitch = midipitch(scale, tonic, scale_degree)
                    addnote!(
                        tracks[t_id],
                        Note(current_pitch.pitch.interval, Ts[t_id]; velocity, duration=ΔT),
                    )
                    Ts[t_id] += ΔT
                end
            end
        end
    end
    return tracks
end

"Wrapping function that takes an expression, turn it into llvm, maps it to a MIDI track, save it as a file and play it via `fluidsynth`."
function play_midi(ex, fn, types; record::Bool=false)
    llvm = get_llvm_string(fn, types)
    midi_tracks = create_midi(llvm)
    midi_file = MIDIFile()
    append!(midi_file.tracks, midi_tracks)
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

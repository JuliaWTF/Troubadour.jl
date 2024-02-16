module Troubadour
using ProgressMeter
using InteractiveUtils
using MIDI

export play_code, @play, play_midi, @play_midi

"Plays the LLVM of an expression with Cs"
macro play(ex)
    @assert ex.head == :call
    fn = first(ex.args)
    args = Base.tail(Tuple(ex.args))
    esc(
        quote
            @async play_code(
                $(Core.eval(__module__, fn)),
                $(typeof.(Core.eval.(Ref(__module__), args))),
            )
            $(ex)
        end,
    )
end

macro play_midi(ex)
    @assert ex.head == :call
    
    fn = first(ex.args)
    args = Base.tail(Tuple(ex.args))
    esc(
        quote
            @async play_midi(
                $(Core.eval(__module__, fn)),
                $(typeof.(Core.eval.(Ref(__module__), args))),
            )
            $(ex)
        end,
    )
end

function play_synth(file)
  run(`fluidsynth -qi /usr/share/soundfonts/freepats-general-midi.sf2 $(file)`)
end    

function create_midi(llvm::AbstractString)
    codes = get_instruction_codes(llvm)
    notes  = map(enumerate(codes)) do (i, code)
        ΔT = floor(Int64, 200 * rand() + 20)
        pitch = Int64(hash(code) % 128)
        velocity = 100
        Note(pitch, velocity, ΔT * (i -1), ΔT)
        end
    track = MIDITrack()
    addnotes!(track, notes)
    track
end

function play_midi(fn, types)
    llvm = get_llvm_string(fn, types)
    @show midi_track = create_midi(llvm)
    midi_file = MIDIFile()
    push!(midi_file.tracks, midi_track)
    @show path  = first(mktemp()) * ".mid"
    MIDI.save(path, midi_file)
    play_synth(path)
end

function play_code(fn, types)
    llvm = get_llvm_string(fn, types)
    codes = get_instruction_codes(llvm)
    @showprogress for code in codes
        t = (rand() * 5.0) + 0.05
        start_t = rand()
        @async run(play_operation(code, t, start_t))
    end
end

function get_llvm_string(fn, types)
    io = IOBuffer()
    code_llvm(io, fn, types; raw = false, dump_module = false, optimize = true, debuginfo = :none)
    String(take!(io))
end

const INSTRUCTION_RE = r"\s=\s([a-z]+)\s"

function get_instruction_codes(llvm_string::String)
    lines = split(llvm_string, "\n")
    # Only keep instructions (start with "  ") and strip whitespaces
    instructions = [strip(x) for x in lines if startswith(x, "  ")]  
    matches = [match(INSTRUCTION_RE, instruction) for instruction in instructions]
    codes = [match.captures[1] for match in matches if !isnothing(match)]
    codes
end


# codes = get_instruction_codes(s)

function play_operation(code, duration, start_t::Real = 0)
    note_ = Int(hash(code) % 5) + 3
    note = "C$(note_)"
    !iszero(start_t) && sleep(start_t)
    cmd = `play -qn synth $(duration) pluck $(note)`
    return cmd
end

end

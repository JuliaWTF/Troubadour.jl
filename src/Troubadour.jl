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
include("midi.jl")

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

hash_and_project(x, max::Integer=MAX_BIT) = Int(rem(hash(x), max))

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
        t = (rand() * 0.5) + 0.1
        start_t = 0.0 # rand()
        run(play_operation(code, t, start_t))
    end
end

end

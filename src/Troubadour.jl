module Troubadour
using ProgressMeter
using Suppressor
using InteractiveUtils
using MIDI
using Distributions
using Random
using DataDeps

using LAME_jll: lame
using Pkg.Artifacts

export play_code, @llvm_play, play_midi, @llvm_midi

include("llvm.jl")
include("play.jl")
include("midi.jl")

const MAX_BIT = 128

function __init__()
    return register(
        DataDep(
            "Creative Soundfont",
            "The soundfont file is used to convert the midi track into a real audio experience",
            "https://ia803001.us.archive.org/5/items/free-soundfonts-sf2-2019-04/Creative%20%28emu10k1%298MBGMSFX.SF2",
            "6c2ff6e9219989e0a2d39e633cbdc7d8f8a575903985160495aeab5d01cc48e6",
        ),
    )
    datadep"Creative Soundfont"
end

function soundfont_path()
    return joinpath(datadep"Creative Soundfont", "Creative%20%28emu10k1%298MBGMSFX.SF2")
end

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

hash_and_project(x, max::Integer=MAX_BIT, mod1::Bool=false) = Int(rem(hash(x), max) + mod1)

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

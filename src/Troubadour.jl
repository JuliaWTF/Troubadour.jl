module Troubadour
using ProgressMeter
using InteractiveUtils

export play_code, @play

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
    InteractiveUtils._dump_function(
        fn,
        types,
        false,
        false,
        false,
        false,
        :intel,
        true,
        :default,
        false,
    )
end

const INSTRUCTION_RE = r"\s=\s([a-z]+)\s"

function get_instruction_codes(llvm_string::String)
    lines = split(llvm_string, "\n")
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

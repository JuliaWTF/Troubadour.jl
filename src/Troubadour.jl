module Troubadour

function get_llvm_string(fn, types)
    InteractiveUtils._dump_function(fn, types, false, false, false, false, :intel, true, :default, false)
end

s = get_llvm_string(sum, (Vector{Int},))

INSTRUCTION_RE = r"\s=\s([a-z]+)\s"

function get_instruction_codes(llvm_string::String)
    lines = split(llvm_string, "\n")
    instructions = [strip(x) for x in lines if startswith(x, "  ")]
    matches = [match(INSTRUCTION_RE, instruction) for instruction in instructions]
    codes = [match.captures[1] for match in matches if !isnothing(match)]
    codes
end


codes = get_instruction_codes(s)

function play_code(code, duration=0.1)
    note_ = Int(hash(code) % 5) + 3
    note = "C$(note_)"
    cmd = `play -qn synth $(duration) sine $(note)`
    return cmd
end


cmds = [play_code(code, .1) for code in codes]

@showprogress for code in codes
    run(play_code(code, .1))
end
end

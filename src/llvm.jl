## Based on code from https://github.com/kimikage/ColoredLLCodes.jl/blob/master/src/ColoredLLCodes.jl by @kamikage

"Return the LLVM IR code as a string (what `@code_llvm` would return)"
function get_llvm_string(fn, types)
    io = IOBuffer()
    code_llvm(io, fn, types; raw=false, dump_module=false, optimize=true, debuginfo=:none)
    return String(take!(io))
end

const num_regex = r"^(?:\$?-?\d+|0x[0-9A-Fa-f]+|-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)$"
const INSTRUCTION_ASSIGN = r"%(\d+)\s=\s([a-z]+)\s([\w\d]+)\s([%\w\d,\s]+)"
const INSTRUCTION_RETURN = r"/%(\d+)\s=\s([a-z]+)\s([\w\d]+)\s([%\w\d,\s]+)"

"Different type of types in the LLVM IR. Does not accurately represent any existing structure."
@enum LLVMType Label Variable Operator Instruction Keyword FuncName LLType Default Num
struct LLVMNode
    val::String
    type::LLVMType
end

function parse_llvm(llvm_code::String)
    buf = IOBuffer(llvm_code)
    nodes = Vector{LLVMNode}[]
    for line in eachline(buf)
        linenodes = LLVMNode[]
        m = match(r"^(?:\s*)((?:[^;]|;\")*)(?:.*)$", line)
        m === nothing && continue
        tokens = only(m.captures)
        parse_tokens(tokens, linenodes)
        push!(nodes, linenodes)
    end
    return nodes
end

const llvm_types = r"^(?:void|half|float|double|x86_\w+|ppc_\w+|label|metadata|type|opaque|token|i\d+)$"
const llvm_cond = r"^(?:[ou]?eq|[ou]?ne|[uso][gl][te]|ord|uno)$" # true|false

function parse_tokens(tokens, nodes)
    m = match(r"^(?:(?:[^\s:]+:)?)\s*(.*)", tokens)
    if m !== nothing
        tokens = only(m.captures)
    end
    m = match(r"^(%[^\s=]+)\s*=\s*(.*)", tokens)
    if m !== nothing
        result, tokens = m.captures
        push!(nodes, LLVMNode(result, Variable))
    end
    m = match(r"^([a-z]\w*)\s*(.*)", tokens)
    if m !== nothing
        inst, tokens = m.captures
        iskeyword = occursin(r"^(?:define|declare|type)$", inst) || occursin("=", tokens)
        push!(nodes, LLVMNode(inst, iskeyword ? Keyword : Instruction))
    end
    return llvm_tokens(tokens, nodes)
end

function llvm_tokens(tokens, nodes)
    while !isempty(tokens)
        tokens = llvm_token(tokens, nodes)
    end
    return tokens
end

function llvm_token(tokens, nodes)
    islabel = false
    while !isempty(tokens)
        # Strip from coma and space
        m = match(r"^,\s*(.*)", tokens)
        if m !== nothing
            tokens = only(m.captures)
            break
        end
        m = match(r"^(\*+|=)\s*(.*)", tokens)
        if m !== nothing
            sym, tokens = m.captures
            push!(nodes, LLVMNode(sym, Operator))
            continue
        end
        m = match(r"^(\"[^\"]*\")\s*(.*)", tokens)
        if m !== nothing
            str, tokens = m.captures
            push!(nodes, LLVMNode(str, Variable))
            continue
        end
        m = match(r"^([({\[<])\s*(.*)", tokens)
        if m !== nothing
            bracket, tokens = m.captures
            tokens = llvm_token(tokens, nodes) # enter
            continue
        end
        m = match(r"^([)}\]>])\s*(.*)", tokens)
        if m !== nothing
            bracket, tokens = m.captures
            break # leave
        end

        m = match(r"^([^\s,*=(){}\[\]<>]+)\s*(.*)", tokens)
        m === nothing && break
        token, tokens = m.captures
        node = if occursin(llvm_types, token)
            islabel = token == "label"
            LLVMNode(token, LLType)
        elseif occursin(llvm_cond, token) # condition code is instruction-level
            LLVMNode(token, Instruction)
        elseif occursin(num_regex, token)
            LLVMNode(token, Num)
        elseif occursin(r"^@.+$", token)
            LLVMNode(token, FuncName)
        elseif occursin(r"^%.+$", token)
            islabel |= occursin(r"^%[^\d].*$", token) & occursin(r"^\]", tokens)
            islabel = false
            if !isempty(token)
                LLVMNode(token, islabel ? Label : Variable)
            end
        elseif occursin(r"^[a-z]\w+$", token)
            LLVMNode(token, Keyword)
        else
            LLVMNode(token, Default)
        end
        push!(nodes, node)
    end
    return tokens
end

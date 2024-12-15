using Troubadour
using Test
using Aqua

@testset "Troubadour.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(Troubadour)
    end
    @llvm_midi sqrt(2)
    # Write your tests here.
end

function f()
    s = 0
    for val in x
        s = s + val
    end
    return s
end
x = Any[0.4, 1, true, 0.3f2, 0x12]

function f2(x)
    s = zero(eltype(x))
    for val in x
        s += val
    end
    return s
end
y = rand(100)

@llvm_midi f()
@llvm_midi f2(y)

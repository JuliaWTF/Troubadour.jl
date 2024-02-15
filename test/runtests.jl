using Troubadour
using Test
using Aqua

@testset "Troubadour.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(Troubadour)
    end
    # Write your tests here.
end

using Troubadour
using Documenter

DocMeta.setdocmeta!(Troubadour, :DocTestSetup, :(using Troubadour); recursive=true)

makedocs(;
    modules=[Troubadour],
    authors="JuliaWTF",
    sitename="Troubadour.jl",
    format=Documenter.HTML(;
        canonical="https://theogf.github.io/Troubadour.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/theogf/Troubadour.jl",
    devbranch="main",
)

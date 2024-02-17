# Troubadour

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://theogf.github.io/Troubadour.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://theogf.github.io/Troubadour.jl/dev/)
[![Build Status](https://github.com/theogf/Troubadour.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/theogf/Troubadour.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/theogf/Troubadour.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/theogf/Troubadour.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

## Installation

This package is unregistered so you will need to install it via

```julia
import Pkg
Pkg.add(PackageSpec(url = "https://github.com/JuliaWTF/Troubadour.jl"))
```

### `@llvm_midi`

For using `@llvm_midi` you will additionally need to install [`fluidsynth`](https://www.fluidsynth.org/).
There is a large list of installation instructions on [their github](https://github.com/FluidSynth/fluidsynth/wiki/Download).

### `@llvm_play`

For using `@llvm_play` you will need to install [`sox`](https://github.com/chirlu/sox).
You can find it on this [download link](https://sourceforge.net/projects/sox/).
PS: there is [some work](https://github.com/JuliaPackaging/Yggdrasil/pull/8063) to make it an automatically installed binary.

## Hear your code

With the installation done you are ready for some LLVM music delight!
Troubadour can be used via its macros `@llvm_midi` and `@llvm_play`:

```julia
using Troubadour
@llvm_midi sqrt(2)
@llvm_play println("Dance!")
```

With `@llvm_midi` you can also record your llvm as an MP3 using the keyword `record = true`

```julia
@llvm_midi 1 + 1 record = true
```

The sound file will be saved as "1 + 1.mp3" (the latest summer hit).

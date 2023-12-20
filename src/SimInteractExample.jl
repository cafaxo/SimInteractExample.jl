module SimInteractExample

using LinearAlgebra
using Random
using StaticArrays
using ModernGL
using Printf
using SimInteract

shader_path(name) = joinpath(@__DIR__, "..", "assets", "shaders", name)

include("match.jl")
include("spdmatrix.jl")
include("algorithms.jl")
include("simulation.jl")
include("sidebar.jl")
include("renderer.jl")

end # module SimInteractExample

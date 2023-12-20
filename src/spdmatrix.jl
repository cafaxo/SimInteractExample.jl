abstract type SPDMatrix end

struct DenseSPDMatrix{T} <: SPDMatrix
    matrix::Matrix{T}
    F::Cholesky{T,Matrix{T}}
end

function SPDMatrix(matrix::AbstractMatrix{<:Real})
    @assert issymmetric(matrix)
    F = cholesky(Symmetric(matrix, :L))
    @assert F.uplo == 'L'
    return DenseSPDMatrix(matrix, F)
end

function Random.randn!(p::AbstractVector, Σ::DenseSPDMatrix)
    randn!(p)
    lmul!(Σ.F.L, p)
    return p
end

function LinearAlgebra.ldiv!(Y::AbstractVector, A::DenseSPDMatrix, B::AbstractVector)
    return ldiv!(Y, A.F, B)
end

function LinearAlgebra.mul!(C::AbstractVector, A::DenseSPDMatrix, B::AbstractVector, α::Number, β::Number)
    return mul!(C, A.matrix, B, α, β)
end

struct DiagSPDMatrix{T,S} <: SPDMatrix
    matrix::T
    matrix_sqrt::S
end

# TODO: verify that matrix is real
function SPDMatrix(matrix::Union{Diagonal,UniformScaling})
    return DiagSPDMatrix(matrix, sqrt(matrix))
end

import Base: *

function *(α::Real, Σ::DiagSPDMatrix)
    return DiagSPDMatrix(α * Σ.matrix, sqrt(α) * Σ.matrix_sqrt)
end

Base.sqrt(Σ::DiagSPDMatrix) = Σ.matrix_sqrt

function Random.randn!(p::AbstractVector, Σ::DiagSPDMatrix)
    randn!(p)
    lmul!(sqrt(Σ), p)
    return p
end

function LinearAlgebra.ldiv!(Y::AbstractVector, A::DiagSPDMatrix, B::AbstractVector)
    return ldiv!(Y, A.matrix, B)
end

function LinearAlgebra.lmul!(Σ::DiagSPDMatrix, x::AbstractVector)
    return lmul!(Σ.matrix, x)
end

function muladd!(y::AbstractVector, A::UniformScaling, x::AbstractVector, α::Number)
    y .+= (α*A.λ) .* x
    return y
end

function muladd!(y::AbstractVector, A::Diagonal, x::AbstractVector, α::Number)
    y .+= α .* A.diag .* x
    return y
end

function muladd!(y::AbstractVector, A::DiagSPDMatrix, x::AbstractVector, α::Number)
    return muladd!(y, A.matrix, x, α)
end

export RAMStageCache

# ---------------------------------------------------------------------------- #
# Abstract type for all stage caches. The first parameters is the number
# of cached intermediate stage values, and the second is their type, e.g.
# some subtype of an AbstractArray.
abstract type AbstractCache{NS, X} end

_iscache(::Type{<:AbstractCache}) = true
_iscache(::Any) = false

# ---------------------------------------------------------------------------- #
# Stage cache where all stages are cached in RAM.
struct RAMStageCache{NS, X} <: AbstractCache{NS, X}
     ts::Vector{Float64}
    Δts::Vector{Float64}
     xs::Vector{NTuple{NS, X}}
end

RAMStageCache(NS::Int, x::X) where {X} =
    RAMStageCache{NS, X}(Float64[], Float64[], NTuple{NS, X}[])

@inline Base.push!(ss::RAMStageCache{NS, X},
                    t::Real,
                   Δt::Real,
                    x::NTuple{NS, X}) where {NS, X} =
    (push!(ss.ts, t); push!(ss.Δts, Δt); push!(ss.xs, x); nothing)

# ---------------------------------------------------------------------------- #
# Stage cache where all stages are cached on disk: TODO
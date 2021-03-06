export CNRK2

# ---------------------------------------------------------------------------- #
# Crank-Nicolson/Heun used in Chandler and Kerswell 2013
struct CNRK2{X, TAG, ISADJ} <: AbstractMethod{X, 2, TAG, ISADJ}
    store::NTuple{5, X}
end

# outer constructor
CNRK2(x::X, tag::Symbol) where {X} =
    CNRK2{X, _tag_map(tag)...}(ntuple(i->similar(x), 5))

# required to cope with nuggy julia deepcopy implementation
function Base.deepcopy_internal(x::CNRK2, dict::IdDict)
    if !( haskey(dict, x) )
        dict[x] = CNRK2(x.store[1], typetag(x))
    end
    return dict[x]
end

# ---------------------------------------------------------------------------- #
# Normal time stepping with optional stage caching
function step!(method::CNRK2{X, :NORMAL},
                  sys::System,
                    t::Real,
                   Δt::Real,
                    x::X,
                    c::C) where {X, C<:Union{Nothing, AbstractStageCache{2, X}}}
    # aliases
    k1, k2, k3, k4, k5 = method.store

    # predictor step
    ImcA_mul!(sys, -0.5*Δt, x, k1)
    sys(t, x, k2); _iscache(C) && (s1 = copy(x))
    @all k3 .= k1 .+ Δt.*k2
    ImcA!(sys, 0.5*Δt, k3, k4)

    # corrector
    sys(t+Δt, k4, k5); _iscache(C) && (s2 = copy(k4))
    @all k3 .= k1 .+ 0.5.*Δt.*(k2 .+ k5)
    ImcA!(sys, 0.5*Δt, k3, x)

    # store stages if requested
    _iscache(C) && push!(c, t, Δt, (s1, s2))

    return nothing
end

# ---------------------------------------------------------------------------- #
# Continuous linearised time stepping with interpolation from store
function step!(method::CNRK2{X, :LIN, ISADJ},
                  sys::System,
                    t::Real,
                   Δt::Real,
                    x::X,
                store::AbstractStorage) where {X, ISADJ}

    # modifier for the location of the interpolation
    _m_ = ISADJ == true ? -1 : 1

    # aliases
    k1, k2, k3, k4, k5 = method.store
    ImcA_mul!(sys, -0.5*Δt, x, k1)
    sys(t, store(k5, t), x, k2)
    k3 .= k1 .+ Δt.*k2
    ImcA!(sys, 0.5*Δt, k3, k4)
    sys(t + _m_*Δt, store(k3, t + _m_*Δt), k4, k5)
    k3 .= k1 .+ 0.5.*Δt.*(k2 .+ k5)
    ImcA!(sys, 0.5*Δt, k3, x)
    return nothing
end

# ---------------------------------------------------------------------------- #
# Discrete linearised time stepping
function step!(method::CNRK2{X, :LIN, false},
                  sys::System,
                    t::Real,
                   Δt::Real,
                    x::X,
               stages::NTuple{2, X}) where {X}
    # aliases
    k1, k2, k3, k4, k5 = method.store
    ImcA_mul!(sys, -0.5*Δt, x, k1)
    sys(t, stages[1], x, k2)
    @all k3 .= k1 .+ Δt.*k2
    ImcA!(sys, 0.5*Δt, k3, k4)
    sys(t+Δt, stages[2], k4, k5)
    @all k3 .= k1 .+ 0.5.*Δt.*(k2 .+ k5)
    ImcA!(sys, 0.5*Δt, k3, x)
    return nothing
end

# ---------------------------------------------------------------------------- #
# Discrete adjoint time stepping
function step!(method::CNRK2{X, :LIN, true},
                  sys::System,
                    t::Real,
                   Δt::Real,
                    x::X,
               stages::NTuple{2, X}) where {X}
    # aliases
    k1, k2, k3, k4, k5 = method.store
    ImcA!(sys, 0.5*Δt, x, k1)
    sys(t + Δt, stages[2], k1, k2)
    k2 .= k2.*Δt./2
    ImcA!(sys, 0.5*Δt, k2, k3)
    k4 .= Δt./2.0.*k1 .+ Δt.*k3
    sys(t, stages[1], k4, k5)
    k2 .= k1 .+ k3
    ImcA_mul!(sys, -0.5*Δt, k2, k3)
    x .= k3 .+ k5
    return nothing
end
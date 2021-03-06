# ---------------------------------------------------------------------------- #
export CB3R2R2, CB3R2R3e, CB3R2R3c

# ---------------------------------------------------------------------------- #
# Three-register version of [2R] IMEXRK schemes from section 1.2.1 of CB 2015

for (name, tab) in zip((:CB3R2R2, :CB3R2R3e, :CB3R2R3c), (CB2, CB3e, CB3c))
@eval begin

# type
struct $name{X, NS, TAG, ISADJ} <: AbstractMethod{X, NS, TAG, ISADJ}
    store::NTuple{6, X}
end

# outer constructor
$name(x::X, tag::Symbol) where {X} =
    $name{X, $(nstages(tab)), _tag_map(tag)...}(ntuple(i->similar(x), 6))

# required to cope with buggy julia deepcopy implementation
function Base.deepcopy_internal(x::$name, dict::IdDict)
    if !( haskey(dict, x) )
        dict[x] = $name(x.store[1], typetag(x))
    end
    return dict[x]
end

# ---------------------------------------------------------------------------- #
# Nonlinear problem with stage caching
function step!(method::$name{X, NS, :NORMAL},
                  sys::System,
                    t::Real,
                   Δt::Real,
                    x::X,
                    c::C) where {X, NS, C<:Union{Nothing, AbstractStageCache{NS, X}}}

    # hoist temporaries out
    y, z, w, s, v, u  = method.store
    tab = $tab

    # temporary vector for storing stages
    _iscache(C) && (stages = sizehint!(X[], NS))

    # loop over stages
    @inbounds for k = 1:NS
        if k == 1
            @all y .= x
        else
            @all y .= x .+ (tab[:aᴵ, k, k-1] .- tab[:bᴵ, k-1]).*Δt.*z .+
                           (tab[:aᴱ, k, k-1] .- tab[:bᴱ, k-1]).*Δt.*y
        end
        mul!(z, sys, y)                 # compute z = A*y then
        ImcA!(sys, tab[:aᴵ, k, k]*Δt, z, z) # get z = (I-cA)⁻¹*(A*y) in place
        @all w .= y .+ tab[:aᴵ, k, k].*Δt.*z     # w is the temp input, output is y
        sys(t + tab[:cᴱ, k]*Δt, w, y); _iscache(C) && (push!(stages, copy(w)))
        @all x .= x .+ tab[:bᴵ, k].*Δt.*z .+ tab[:bᴱ, k].*Δt.*y
    end

    # cache stages if requested
    _iscache(C) && push!(c, t, Δt, tuple(stages...))

    return nothing
end

# ---------------------------------------------------------------------------- #
# Linearisation: takes x_{n} and overwrites it with x_{n+1}
# A good reason to keep this is to check the discrete consistency of the adjoint
# version of this method.
function step!(method::$name{X, NS, :LIN, ISADJ},
                  sys::System,
                    t::Real,
                   Δt::Real,
                    x::X,
               store::AbstractStorage) where {X, NS, ISADJ}
    # hoist temporaries out
    y, z, w, v, s, u  = method.store
    tab = $tab

    # modifier for the location of the interpolation
    _m_ = ISADJ == true ? -1 : 1

    # loop over stages
    @inbounds for k = 1:NS
        # F
        if k == 1
            @all y .= x
        else
            @all y .= x .+ (tab[:aᴵ, k, k-1] .- tab[:bᴵ, k-1]).*Δt.*z .+
                           (tab[:aᴱ, k, k-1] .- tab[:bᴱ, k-1]).*Δt.*y
        end
        # E
        mul!(z, sys, y)                 # compute z = A*y then
        # D
        ImcA!(sys, tab[:aᴵ, k, k]*Δt, z, z) # get z = (I-cA)⁻¹*(A*y) in place
        # C
        @all w .= y .+ tab[:aᴵ, k, k].*Δt.*z     # w is the temp input, output is y
        # B
        # We will probably have to think to another way to define the forcings 
        # for linearised system that require the time derivative of the main state.
        sys(t + _m_*tab[:cᴱ, k]*Δt, store(u, t + _m_*tab[:cᴱ, k]*Δt), w, y)
        # A
        @all x .= x .+ tab[:bᴵ, k].*Δt.*z .+ tab[:bᴱ, k].*Δt.*y
    end

    return nothing
end



# ---------------------------------------------------------------------------- #
# Linearisation: takes x_{n} and overwrites it with x_{n+1}
# A good reason to keep this is to check the discrete consistency of the adjoint
# version of this method.
function step!(method::$name{X, NS, :LIN, false},
                  sys::System,
                    t::Real,
                   Δt::Real,
                    x::X,
               stages::NTuple{NS, X}) where {X, NS}
    # hoist temporaries out
    y, z, w, v, s, u  = method.store
    tab = $tab

    # loop over stages
    @inbounds for k = 1:NS
        # F
        if k == 1
            @all y .= x
        else
            @all y .= x .+ (tab[:aᴵ, k, k-1] .- tab[:bᴵ, k-1]).*Δt.*z .+
                           (tab[:aᴱ, k, k-1] .- tab[:bᴱ, k-1]).*Δt.*y
        end
        # E
        mul!(z, sys, y)                 # compute z = A*y then
        # D
        ImcA!(sys, tab[:aᴵ, k, k]*Δt, z, z) # get z = (I-cA)⁻¹*(A*y) in place
        # C
        @all w .= y .+ tab[:aᴵ, k, k].*Δt.*z     # w is the temp input, output is y
        # B
        # We will probably have to think to another way to define the forcings 
        # for linearised system that require the time derivative of the main state.
        sys(t + tab[:cᴱ, k]*Δt, stages[k], w, y)
        # A
        @all x .= x .+ tab[:bᴵ, k].*Δt.*z .+ tab[:bᴱ, k].*Δt.*y
    end

    return nothing
end


# ---------------------------------------------------------------------------- #
# Adjoint version
# takes x_{n+1} and overwrites it with x_{n}
function step!(method::$name{X, NS, :LIN, true},
                  sys::System,
                    t::Real,
                   Δt::Real,
                    x::X,
               stages::NTuple{NS, X}) where {X, NS}

    # hoist temporaries out
    y, z, w, v, s, u  = method.store
    y .= 0; z .= 0; w .= 0; v .= 0; s .= 0; u .= 0;
    tab = $tab
    
    @inbounds for k = reverse(1:NS)
        # A
        z .= z .+ tab[:bᴵ, k].*Δt.*x
        y .= y .+ tab[:bᴱ, k].*Δt.*x
        # B
        v .= w # temporary
        sys(t + tab[:cᴱ, k]*Δt, stages[k], y, v)
        w .= w .+ v
        y .= 0
        # C
        z .= z .+ tab[:aᴵ, k, k].*Δt.*w
        y .= y .+ w
        w .= 0
        # D
        ImcA!(sys, tab[:aᴵ, k, k]*Δt, z, v)
        s .= v .+ s
        z .= 0
        # E
        mul!(v, sys, s)
        y .= v .+ y
        s .= 0
        # F
        if k == 1
            x .= x .+ y
            y .= 0
        else
            x .= y .+ x
            z .= (tab[:aᴵ, k, k-1] .- tab[:bᴵ, k-1]).*Δt.*y .+ z
            y .= (tab[:aᴱ, k, k-1] .- tab[:bᴱ, k-1]).*Δt.*y
        end
    end


    # this was not correct
    # # hoist temporaries out
    # y, z, w  = method.store
    # @all y .= 0; @all z .= 0; @all w .= 0;
    # tab = $tab

    # # loop over stages backwards
    # @inbounds for k = reverse(1:NS)
    #     # A
    #     @all z .= z .+ tab[:bᴵ, k].*Δt.*x
    #     @all y .= y .+ tab[:bᴱ, k].*Δt.*x
    #     # B
    #     # We will probably have to think to another way to define the forcings 
    #     # for linearised system that require the time derivative of the main state.
    #     sys(t + tab[:cᴱ, k]*Δt, stages[k], y, w)
    #     # C
    #     @all z .= z .+ tab[:aᴵ, k, k].*Δt.*w
    #     @all y .= w
    #     # D
    #     ImcA!(sys, tab[:aᴵ, k, k]*Δt, z, w)
    #     # E
    #     mul!(z, sys, w)
    #     @all y .= z .+ y
    #     # F
    #     @all x .= x .+ y
    #     if k > 1
    #         @all z .= (tab[:aᴵ, k, k-1] .- tab[:bᴵ, k-1]).*Δt.*y
    #         @all y .= (tab[:aᴱ, k, k-1] .- tab[:bᴱ, k-1]).*Δt.*y
    #     end
    # end

    return nothing
end

end
end
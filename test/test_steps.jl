@testset "linear system                          " begin

    # define linear system ẋ = x, but splitting the right hand side
    # into the explicit and implicit parts, to check both.
    g(t, x, ẋ) = (ẋ .= 0.5.*x; ẋ)
    A = Diagonal([0.5])

    # the type of the solution space 
    x0 = Float64[1.0]

    #                                      method                      ord  bounds
    for (scheme, order, bnd) in [(Scheme(:CB2_3R2R,  x0), 2,   (0.025000, 0.027100)),
                                 (Scheme(:CB3e_3R2R, x0), 3,   (0.006900, 0.008100)),
                                 (Scheme(:CB3c_3R2R, x0), 3,   (0.007300, 0.008600)),
                                 (Scheme(:CB4_4R3R,  x0), 4,   (0.000037, 0.000076))]

        # ensure that the error decays with expected rate
        for Δt = [5^(-i) for i in linspace(1, 3, 5)]

            # step forward
            x0 = Float64[1.0]
            Flows.step!(scheme, Flows.System(g, A, nothing), 0., Δt, x0)

            # check error decays with expected power. The bounds bnd are used
            # to check whether the error decays at the expected rate, up
            # to a small variation, within the bounds.
            err = abs(x0[1] - exp(Δt))
            # @show err/Δt^(order+1)
            @test err/Δt^(order + 1) > bnd[1]
            @test err/Δt^(order + 1) < bnd[2]
        end

        # test allocation
        function fun(g, A, scheme, Δt, x0)
            sys = Flows.System(g, A, nothing)
            @allocated Flows.step!(scheme, sys, 0., Δt, x0)
        end
        # @code_warntype 
        @test fun(g, A, scheme, 0.1, x0) == 0
    end
end
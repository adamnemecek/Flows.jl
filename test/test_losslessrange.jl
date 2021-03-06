@testset "losslessrange                          " begin

    @testset "lossy                          " begin
        rng = Flows.LossLessRange(0, 1, 0.4)
        expected = [0, 0.4, 0.8, 1.0]
        @test collect(rng) == expected
        for (i, el) in enumerate(rng)
            @test el == expected[i]
        end
        @test length(rng) == 4
        @test rng[1] === 0.0
        @test rng[2] === 0.4
        @test rng[3] === 0.8
        @test rng[4] === 1.0
        @test_throws BoundsError rng[0]
        @test_throws BoundsError rng[5]

        # test interface used in the integration routines
        expected = [0.4, 0.4, 0.2]
        for i = 2:length(rng)
            @test abs(rng[i]-rng[i-1] - expected[i-1]) < 1e-16
        end
    end

    @testset "lossless                           " begin
        rng = Flows.LossLessRange(0, 0.8, 0.4)
        expected = [0, 0.4, 0.8]
        @test collect(rng) == expected
        for (i, el) in enumerate(rng)
            @test el == expected[i]
        end
        @test length(rng) == 3
        @test rng[1] === 0.0
        @test rng[2] === 0.4
        @test rng[3] === 0.8
        @test_throws BoundsError rng[0]
        @test_throws BoundsError rng[4]

        # test interface used in the integration routines
        expected = [0.4, 0.4]
        for i = 2:length(rng)
            @test abs(rng[i]-rng[i-1] - expected[i-1]) < 1e-16
        end
    end

    @testset "backwards checks                    " begin
        @test_throws ArgumentError Flows.LossLessRange(1, 0, -0.1)
    end

    @testset "backwards lossy                    " begin
        rng = Flows.LossLessRange(1, 0, 0.4)
        expected = [1.0, 0.6, 0.2, 0.0]
        @test collect(rng) == expected
        for (i, el) in enumerate(rng)
            @test el == expected[i]
        end
        @test length(rng) == 4
        @test rng[1] === 1.0
        @test rng[2] === 0.6
        @test rng[3] === 0.2
        @test rng[4] === 0.0
        @test_throws BoundsError rng[0]
        @test_throws BoundsError rng[5]

        # test interface used in the integration routines
        expected = [-0.4, -0.4, -0.2]
        for i = 2:length(rng)
            @test abs(rng[i]-rng[i-1] - expected[i-1]) < 1e-16
        end
    end
    
    @testset "backwards lossless                    " begin
        rng = Flows.LossLessRange(0.8, 0, 0.4)
        expected = [0.8, 0.4, 0.0]
        @test collect(rng) == expected
        for (i, el) in enumerate(rng)
            @test el == expected[i]
        end
        @test length(rng) == 3
        @test rng[1] === 0.8
        @test rng[2] === 0.4
        @test rng[3] === 0.0
        @test_throws BoundsError rng[0]
        @test_throws BoundsError rng[4]
        
        # test interface used in the integration routines
        expected = [-0.4, -0.4]
        for i = 2:length(rng)
            @test abs(rng[i]-rng[i-1] - expected[i-1]) < 1e-16
        end
    end
end

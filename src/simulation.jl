struct BallConfiguration{T}
    λ::T
    balls::Vector{SVector{2,T}}
end

lie_algebra_eltype(::BallConfiguration{T}) where {T} = T
lie_algebra_length(x::BallConfiguration) = 2*length(x.balls)

Base.copy(x::BallConfiguration) = BallConfiguration(
    x.λ,
    copy(x.balls),
)

function Base.copyto!(y::BallConfiguration, x::BallConfiguration)
    @assert y.λ == x.λ
    copyto!(y.balls, x.balls)
    return y
end

@inline function wraparound(x::Real, λ::Real)
    return x - λ * round(x / λ)
end

function wraparound(x::AbstractVector{<:Real}, λ::Real)
    return map(@inline(s -> wraparound(s, λ)), x)
end

function exponential_map!(x::BallConfiguration{T}, p::Vector{T}) where {T}
    (; λ, balls) = x
    p = reinterpret(SVector{2,T}, p)

    for (i, ball) in enumerate(balls)
        balls[i] = wraparound(ball + p[i], λ)
    end

    return x
end

struct EnergyParameters{T} end

pair_potential(t::T) where {T<:Real} = ifelse(t <= 2, (2 - t)^3 - T(0.5)*(2 - t)^2, T(0))
pair_potential_derivative(t::T) where {T<:Real} = ifelse(t <= 2, (-3)*(2 - t)^2 + (2 - t), T(0))

function energy(x::BallConfiguration{T}, ::EnergyParameters{T}) where {T}
    (; λ, balls) = x
    E = zero(T)

    for i in 1:length(balls), j in i+1:length(balls)
        E += pair_potential(norm(wraparound(balls[i] - balls[j], λ)))
    end

    return E
end

function energy_gradient!(∇E, x::BallConfiguration{T}, ::EnergyParameters{T}) where {T}
    (; λ, balls) = x
    fill!(∇E, 0)
    ∇E = reinterpret(SVector{2,T}, ∇E)

    for i in 1:length(balls), j in i+1:length(balls)
        dir = wraparound(balls[i] - balls[j], λ)
        d = norm(dir)

        grad = (pair_potential_derivative(d) / d) * dir

        ∇E[i] += grad
        ∇E[j] -= grad
    end

    return parent(∇E)
end

function energy_gradient(
        x::BallConfiguration{T},
        parameters::EnergyParameters{T};
    ) where {T<:Real}

    ∇E = zeros(lie_algebra_eltype(x), lie_algebra_length(x))
    return energy_gradient!(∇E, x, parameters)
end

@enum Algorithm algorithm_random_walk=1 algorithm_hmc=2 algorithm_gradient_descent=3

function describe(algorithm::Algorithm)
    return @match algorithm::Algorithm begin
        algorithm_random_walk => "Random-walk Metropolis"
        algorithm_hmc => "hybrid Monte-Carlo"
        algorithm_gradient_descent => "Gradient descent"
    end
end

@kwdef struct SimulationParameters{T}
    ambient_space_size::T
    count::Int
    algorithm::Algorithm
    temperature::T
    rw_stepsize::T
    hmc_stepsize::T
    leapfrog_iteration_count::Int
    gradient_descent_stepsize::T
end

function EnergyParameters(::SimulationParameters{T}) where {T}
    return EnergyParameters{T}()
end

struct SimulationState{T}
    x::BallConfiguration{T}
    energy::T
    gradient_norm::T
    acceptance_rate::Float64
    time_elapsed::Float64
end

struct Simulator end

covariance_matrix(::SimulationParameters, ::BallConfiguration) = SPDMatrix(I)

function SimInteract.new_initial_state!(::Simulator, parameters::SimulationParameters{T}) where {T}
    x = BallConfiguration{T}(parameters.ambient_space_size, [
        parameters.ambient_space_size * SVector(rand(T), rand(T)) for _ in 1:parameters.count
    ])
    energy_parameters = EnergyParameters(parameters)
    Σ = covariance_matrix(parameters, x)

    return SimulationState(
        x,
        energy(x, energy_parameters),
        norm(sqrt(Σ)*energy_gradient(x, energy_parameters)),
        1.0,
        0.0,
    )
end

function SimInteract.simulate!(::Simulator, parameters::SimulationParameters, state::SimulationState)
    energy_parameters = EnergyParameters(parameters)
    Σ = covariance_matrix(parameters, state.x)

    time_start = time()

    x, acceptance_rate_ = @match parameters.algorithm::Algorithm begin
        algorithm_random_walk => begin
            diagnostics = SimpleDiagnostics()

            x = random_walk_metropolis(
                state.x;
                energy = x -> energy(x, energy_parameters),
                stepsize = parameters.rw_stepsize,
                covariance_matrix = Σ,
                temperature = parameters.temperature,
                diagnostics,
                iteration_count = 1_000,
            )

            x, acceptance_rate(diagnostics)
        end
        algorithm_hmc => begin
            diagnostics = SimpleDiagnostics()

            x = hybrid_monte_carlo(
                state.x;
                energy = x -> energy(x, energy_parameters),
                energy_gradient! = (∇E, x) -> energy_gradient!(∇E, x, energy_parameters),
                stepsize = parameters.hmc_stepsize,
                covariance_matrix = Σ,
                temperature = parameters.temperature,
                leapfrog_iteration_count = parameters.leapfrog_iteration_count,
                diagnostics,
                iteration_count = 100,
            )

            x, acceptance_rate(diagnostics)
        end
        algorithm_gradient_descent => begin
            x = gradient_descent(
                state.x;
                energy_gradient! = (∇E, x) -> energy_gradient!(∇E, x, energy_parameters),
                stepsize = parameters.gradient_descent_stepsize,
                covariance_matrix = Σ,
                iteration_count = 1_000,
            )

            x, 1.0
        end
    end

    time_elapsed = time() - time_start

    return SimulationState(
        x,
        energy(x, energy_parameters),
        norm(sqrt(Σ)*energy_gradient(x, energy_parameters)),
        acceptance_rate_,
        time_elapsed,
    )
end

function launch_example(; number_of_instances::Int = 1)
    parameters = SimulationParameters{Float64}(;
        ambient_space_size        = 32.0,
        count                     = 44,
        algorithm                 = algorithm_hmc,
        temperature               = 0.0038,
        rw_stepsize               = 0.01,
        hmc_stepsize              = 0.026,
        leapfrog_iteration_count  = 15,
        gradient_descent_stepsize = 0.1,
    )

    parameter_ranges = Dict{Symbol,Any}(
        :ambient_space_size        => SliderRange{Float64}(1.0, 256.0),
        :count                     => SliderRange{Int}(1, 200),
        :temperature               => SliderRange{Float64}(0.0, 0.01),
        :rw_stepsize               => SliderRange{Float64}(0.0, 0.1),
        :hmc_stepsize              => SliderRange{Float64}(0.0, 0.1),
        :leapfrog_iteration_count  => SliderRange{Int}(1, 30),
        :gradient_descent_stepsize => SliderRange{Float64}(0.0, 0.5),
    )

    return SimInteract.launch(
        [Simulator() for _ in 1:number_of_instances],
        () -> BallRenderer(),
        [SimInteract.Camera2D(50.0 / sqrt(number_of_instances)) for _ in 1:number_of_instances],
        parameters,
        create_sidebar(parameters, parameter_ranges),
    )
end

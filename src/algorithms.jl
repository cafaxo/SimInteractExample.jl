abstract type Diagnostics end

mutable struct SimpleDiagnostics <: Diagnostics
    last_energy::Float64
    accepted_proposals::Int
    rejected_proposals::Int
end

SimpleDiagnostics() = SimpleDiagnostics(Inf, 0, 0)

function Base.push!(diagnostics::SimpleDiagnostics, x, E, accepted)
    if accepted
        diagnostics.accepted_proposals += 1
    else
        diagnostics.rejected_proposals += 1
    end

    diagnostics.last_energy = E
    return false
end

function acceptance_rate(diagnostics::SimpleDiagnostics)
    return diagnostics.accepted_proposals / (diagnostics.accepted_proposals + diagnostics.rejected_proposals)
end

last_energy(diagnostics::SimpleDiagnostics) = diagnostics.last_energy

function gradient_descent(
        x;
        energy_gradient!,
        stepsize::Real,
        covariance_matrix,
        iteration_count::Int,
    )

    Σ = stepsize^2 * covariance_matrix
    x = copy(x)
    ∇E = zeros(lie_algebra_eltype(x), lie_algebra_length(x))

    for _ in 1:iteration_count
        energy_gradient!(∇E, x)
        lmul!(Σ, ∇E)
        ∇E .= .-∇E
        exponential_map!(x, ∇E)
    end

    return x
end

function random_walk_metropolis(
        x;
        energy,
        stepsize::Real,
        covariance_matrix,
        temperature::Real,
        diagnostics::Diagnostics,
        iteration_count::Int,
    )

    Σ = stepsize^2 * covariance_matrix
    β = inv(temperature)
    x = copy(x)
    x_backup = copy(x)
    E = energy(x)
    p = zeros(lie_algebra_eltype(x), lie_algebra_length(x))

    for _ in 1:iteration_count
        randn!(p, Σ)
        exponential_map!(x, p)

        E_backup = E
        E = energy(x)

        if rand() < exp(-β*(E - E_backup))
            # accept
            accepted = true
            copyto!(x_backup, x)
        else
            # reject
            accepted = false
            copyto!(x, x_backup)
            E = E_backup
        end

        if push!(diagnostics, x, E, accepted)
            return x
        end
    end

    return x
end

function hybrid_monte_carlo(
        x;
        energy,
        energy_gradient!,
        stepsize::Real,
        covariance_matrix,
        temperature::Real,
        leapfrog_iteration_count::Int,
        diagnostics::Diagnostics,
        iteration_count::Int,
    )

    Σ = stepsize^2 * covariance_matrix
    β = inv(temperature)
    x = copy(x)
    x_backup = copy(x)
    E = energy(x)
    p = zeros(lie_algebra_eltype(x), lie_algebra_length(x))
    Σinv_p = zeros(lie_algebra_eltype(x), lie_algebra_length(x))
    ∇E = zeros(lie_algebra_eltype(x), lie_algebra_length(x))

    for _ in 1:iteration_count
        randn!(p, Σ)

        H_start = β*E + (1/2)*dot(p, ldiv!(Σinv_p, Σ, p))

        muladd!(p, Σ, energy_gradient!(∇E, x), -β/2)
        exponential_map!(x, p)

        for _ in 1:leapfrog_iteration_count-1
            muladd!(p, Σ, energy_gradient!(∇E, x), -β)
            exponential_map!(x, p)
        end

        muladd!(p, Σ, energy_gradient!(∇E, x), -β/2)

        E_backup = E
        E = energy(x)

        H_end = β*E + (1/2)*dot(p, ldiv!(Σinv_p, Σ, p))

        if rand() < exp(H_start - H_end)
            # accept
            accepted = true
            copyto!(x_backup, x)
        else
            # reject
            accepted = false
            copyto!(x, x_backup)
            E = E_backup
        end

        if push!(diagnostics, x, E, accepted)
            return x
        end
    end

    return x
end

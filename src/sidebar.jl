mean(x) = sum(x) / length(x)

import SimInteract: PlotProcessor, SidebarPlot, PlotRange, SidebarSlider, SliderRange, SidebarSelector, Sidebar

struct SimulationAnalysis
    energy::PlotProcessor{Float64,typeof(minimum)}
    acceptance_rate::PlotProcessor{Float64,typeof(mean)}
    time_elapsed::PlotProcessor{Float64,typeof(maximum)}
    gradient_norm::PlotProcessor{Float64,typeof(minimum)}
end

function Base.push!(analysis::SimulationAnalysis, state)
    push!(analysis.energy, state.energy)
    push!(analysis.acceptance_rate, state.acceptance_rate)
    push!(analysis.time_elapsed, state.time_elapsed)
    push!(analysis.gradient_norm, state.gradient_norm)

    return nothing
end

function SimInteract.create_analysis(state::SimulationState)
    # FIXME: this is hardcoded for width 240 and a HiDPI display with 2x scaling
    energy = PlotProcessor{Float64}(minimum, 2*240)
    acceptance_rate = PlotProcessor{Float64}(mean, 2*240)
    time_elapsed = PlotProcessor{Float64}(maximum, 2*240)
    gradient_norm = PlotProcessor{Float64}(minimum, 2*240)

    analysis = SimulationAnalysis(
        energy,
        acceptance_rate,
        time_elapsed,
        gradient_norm,
    )

    push!(analysis, state)
    return analysis
end

function create_sidebar(parameters, ranges::Dict{Symbol,Any})
    state_info = Any[
        SidebarPlot(;
            description = state -> @sprintf("Energy: %.4e", state.energy),
            data = analysis -> analysis.energy.data,
            range = PlotRange(minimum, maximum),
        ),
        SidebarPlot(;
            description = state -> @sprintf("Acceptance rate: %.2f", state.acceptance_rate),
            data = analysis -> analysis.acceptance_rate.data,
            range = PlotRange(0.0, 1.0),
        ),
        SidebarPlot(;
            description = state -> @sprintf("Iteration time: %.2e s", state.time_elapsed),
            data = analysis -> analysis.time_elapsed.data,
            range = PlotRange(0.0, maximum),
        ),
        SidebarPlot(;
            description = state -> @sprintf("Gradient norm: %.2e", state.gradient_norm),
            data = analysis -> analysis.gradient_norm.data,
            range = PlotRange(0.0, maximum),
        ),
    ]

    viewer_modifiers = Pair{Symbol,Any}[]
    viewer_parameters = Dict{Symbol,Any}()

    modifiers = Pair{Symbol,Any}[
        :ambient_space_size => SidebarSlider(;
            description = value -> @sprintf("Ambient space size: %.2e", value),
            range = ranges[:ambient_space_size],
        ),
        :count => SidebarSlider(;
            description = value -> @sprintf("Count: %i", value),
            range = ranges[:count],
        ),
        :algorithm => SidebarSelector(;
            description = describe,
        ),
        :temperature => SidebarSlider(;
            description = value -> @sprintf("Temperature: %.2e", value),
            range = ranges[:temperature],
            is_visible = p -> p[:algorithm] ∈ (algorithm_random_walk, algorithm_hmc),
        ),
        :rw_stepsize => SidebarSlider(;
            description = value -> @sprintf("Stepsize: %.2e", value),
            range = ranges[:rw_stepsize],
            is_visible = p -> p[:algorithm] == algorithm_random_walk,
        ),
        :hmc_stepsize => SidebarSlider(;
            description = value -> @sprintf("Stepsize: %.2e", value),
            range = ranges[:hmc_stepsize],
            is_visible = p -> p[:algorithm] == algorithm_hmc,
        ),
        :leapfrog_iteration_count => SidebarSlider(;
            description = value -> @sprintf("Leapfrog iteration count: %i", value),
            range = ranges[:leapfrog_iteration_count],
            is_visible = p -> p[:algorithm] == algorithm_hmc,
        ),
        :gradient_descent_stepsize => SidebarSlider(;
            description = value -> @sprintf("Stepsize: %.2e", value),
            range = ranges[:gradient_descent_stepsize],
            is_visible = p -> p[:algorithm] == algorithm_gradient_descent,
        ),
    ]

    return Sidebar(;
        state_info,
        viewer_modifiers,
        viewer_parameters,
        modifiers,
        parameters,
    )
end

# SimInteractExample.jl

An example GUI application built with https://github.com/cafaxo/SimInteract.jl.

The simulation shows the dynamics of stochastic descent methods (Metropolis-Hastings or hybrid Monte Carlo) applied to a system of balls with a simple pair-potential.

https://github.com/cafaxo/SimInteractExample.jl/assets/1753343/16123019-86af-4dab-bdba-612d8dab608c

## Installation

This package is not yet registered. It can be installed by running
```julia
pkg> add https://github.com/cafaxo/SimInteract.jl
pkg> add https://github.com/cafaxo/SimInteractExample.jl
```

## Usage

Since simulations are run in a separate thread, Julia needs to be launched with at least two threads (`julia -t2`).
The example app can then be launched as follows:
```julia
julia> using SimInteractExample
julia> SimInteractExample.launch_example()
```
Start and stop simulations by pressing `S`.
Reset the simulation by pressing `N`.
Playback simulations with `SPACE`.

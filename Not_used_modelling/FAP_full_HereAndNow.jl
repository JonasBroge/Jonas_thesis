cd("C:\\Users\\jonas\\Documents\\Jonas DTU\\MSc Thesis\\Modelling")
using JuMP
using HiGHS
using CSV
using DataFrames

### --------------------------------    Load data from excel files and transform into matrix form -------------------------
gen_df = CSV.read("Data_gen_scenarios.csv", DataFrame)
load_df = CSV.read("data_load.csv", DataFrame)

#Creating Maximum Generation matrix
P =  Array{Float64}(undef, maximum(gen_df.gen), maximum(gen_df.time),maximum(gen_df.scenario))
C =  Array{Float64}(undef, maximum(gen_df.gen), maximum(gen_df.time))
for i in 1:nrow(gen_df)
    P[gen_df.gen[i],gen_df.time[i],gen_df.scenario[i]] = gen_df.max[i]
    C[gen_df.gen[i],gen_df.time[i]] = gen_df.cost[i]
end
# Now we can acces parameters of generators as: max output = P[g,t,s],   Cost = C[g,t]

#Creating Maximum Consumption matrix
D = Array{Float64}(undef, maximum(load_df.load), maximum(load_df.time))
U = Array{Float64}(undef, maximum(load_df.load), maximum(load_df.time))
for i in 1:nrow(load_df)
    D[load_df.load[i],load_df.time[i]] = load_df.max[i]
    U[load_df.load[i],load_df.time[i]] = load_df.utility[i]
end
# Now we can acces parameters of loads as: max consumption = D[g,t],   Utility = U[g,t]

#Number of days
days = 2
#Hours per day
hours = 1
#Total time
time = days*hours
#Scenarios
scen = 2
#Probabilities
Pi = repeat([1/scen],scen)

## ----------------------------------  ## The Full Horizon Problem -----------------------------------------
# Sets
T = 1:size(D)[2]
L = 1:size(D)[1]
G = 1:size(P)[1]
S = 1:size(P)[3]

# Defining the sets of each day
T1 = 1:hours
T2 = hours+1:time

# Storage Parameters
S_up = 2.5; 
E_init = 0;

#Model 😺
full = Model(HiGHS.Optimizer)
set_silent(full)

### Variables
## Variables Market Clearing
@variable(full, b[T, S] )       # Energy Charged or discharged for t
@variable(full, d[L, T, S] >= 0)   # Consumption of l at t
@variable(full, p[G, T, S] >= 0)   # Production of g at t
@variable(full, e[T, S] >= 0)      # State of Energy at the end of T

####### Market Clearing Formulation
@objective(full, Max, sum( sum( sum(U[l,t]*d[l,t,s] for l in L) -  sum(C[g,t]*p[g,t,s] for g in G) for t in T) * Pi[s] for s in S) )
### Subject to
## Market Constraints (2b-2d)
@constraint(full, Balance[t in T, s in S], sum(d[l,t,s] for l in L) + b[t,s] - sum(p[g,t,s] for g in G)  == 0  ) # 2a
@constraint(full, Gen[g in G, t in T, s in S], 0 <= p[g,t,s] <= P[g,t,s])
@constraint(full, Load[l in L, t in T, s in S], 0 <= d[l,t,s] <= D[l,t]) 
## Storage Constraints (1a-1d)
@constraint(full, Stor1[t in T, s in S],   0 <= e[t, s] <= S_up)          #1a (v_low[t] , v_up[t])
@constraint(full, Stor2[s in S, t in T;t!=1],   e[t, s] == e[t-1, s]+b[t, s])     #1b (rho[t])
@constraint(full, Stor3[s in S], e[1, s] == E_init+b[1, s])                 #1c (rho[1])

## Non-anticipative constraints
@constraint(full, [t in T1, s1 in S, s2 in S; s1!=s2], b[t,s1] == b[t,s2])
@constraint(full, [l in L, t in T1, s1 in S, s2 in S; s1!=s2], d[l,t,s1] == d[l,t,s2])
@constraint(full, [g in G, t in T1, s1 in S, s2 in S; s1!=s2], p[g,t,s1] == p[g,t,s2])
@constraint(full, [t in T1, s1 in S, s2 in S; s1!=s2], e[t,s1] == e[t,s2])
# Solve
solution = optimize!(full)
println("")
println("------------------------------ Full horizon Solution ------------------------------------")
println("Termination status: $(termination_status(full))")
#************************************************************************

if termination_status(full) == MOI.OPTIMAL
    println("Optimal objective value: $(objective_value(full))")
    println("Solution:")
    for t in T
        println("In timestep t=",t)
        for s in S
            println("   For scenario s=",s)
            println("       The Market price is λ=" , dual(Balance[t,s]))
            println("       Storage level at end of t is e_t=", value(e[t,s]))
        end
    end
else
    println("No optimal solution available")
end

ρ_full = -dual(Stor2[H+1])
e_H_full = value(e[H])
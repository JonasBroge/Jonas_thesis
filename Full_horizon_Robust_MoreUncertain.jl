### WHat are we trying to do ?:
# We're trying to optimize the worst-case objective function, and have feasibility in all cases.

cd("C:\\Users\\jonas\\OneDrive - Danmarks Tekniske Universitet\\Dokumenter\\Jonas DTU\\MSc Thesis\\Modelling")

using JuMP
using HiGHS
using CSV
using DataFrames
using Plots

println("Starting Future-Aware-Plus procedure for example II")
### --------------------------------    Load data from excel files and transform into matrix form -------------------------
gen_df = CSV.read("data_gen.csv", DataFrame)
load_df = CSV.read("data_load.csv", DataFrame)

#Creating Maximum Generation matrix
P =  Array{Float64}(undef, maximum(gen_df.gen), maximum(gen_df.time))
C =  Array{Float64}(undef, maximum(gen_df.gen), maximum(gen_df.time))
for i in 1:nrow(gen_df)
    P[gen_df.gen[i],gen_df.time[i]] = gen_df.max[i]
    C[gen_df.gen[i],gen_df.time[i]] = gen_df.cost[i]
end
# Now we can acces parameters of generators as: max output = P[g,t],   Cost = C[g,t]

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
H=1

## ----------------------------------  ## The Full Horizon Problem -----------------------------------------
# Sets
T = 1:size(D)[2]
L = 1:size(D)[1]
G = 1:size(P)[1]

# Storage Parameters
S = 2.5; 
E_init = 0;


### Creating a robust version of full-horizon

#Change Prod matrix --- THIS IS USED FOR ROBUST
P_mean = P
P_var = [0 1; 0 0]
#Change Demand matrix  (Standard case)
D_mean = [0 3] 
D_var = [0 1]
U = [12 12]


### Using this for edge case only !!! 
D_mean = [0 3; 0 3]
D_var = [0 1; 0 1]
U = [12 4; 12 12]
L = 1:2

#Model 😺
full = Model(HiGHS.Optimizer)
set_silent(full)

### Variables
## Variables Market Clearing
@variable(full, b[T] )            # Energy Charged or discharged for t
@variable(full, d[L, T] >= 0)   # Demand of load l at t
@variable(full, p[G, T] >= 0)   # Production of g at t
@variable(full, e[T] >= 0)        # State of Energy at the end of T

#Robust variable
@variable(full, α[G,T] >= 0)
@variable(full, β[L,T] >= 0)

####### Market Clearing Formulation
@objective(full, Max, sum( sum(U[l,t]*d[l,t] for l in L) -  sum(C[g,t]*p[g,t] for g in G) for t in T) )
### Subject to
## Market Constraints
@constraint(full, Balance[t in T], sum(d[l,t] for l in L) + b[t] - sum(p[g,t] for g in G) == 0 )  # 2a
@constraint(full, Gen[g in G, t in T], p[g,t] <= P_mean[g,t] - α[g,t]) #Changed for robust
@constraint(full, Load[l in L, t in T], d[l,t] <= D_mean[l,t] - β[l,t]) #Changed for robust
## Storage Constraints (1a-1d)
@constraint(full, Stor1[t in T],   0 <= e[t] <= S)          #1a (v_low[t] , v_up[t])
@constraint(full, Stor2[t in T;t!=1],   e[t] == e[t-1]+b[t])     #1b (rho[t])
@constraint(full, Stor3, e[1] == E_init+b[1])                 #1c (rho[1])

#Robust constraints
@constraint(full, rob1[g in G, t in T], -α[g,t] <= P_var[g,t])
@constraint(full, rob2[g in G, t in T], P_var[g,t] <= α[g,t])
@constraint(full, rob3[l in L, t in T], -β[l,t] <= D_var[l,t])
@constraint(full, rob4[l in L, t in T], D_var[l,t] <= β[l,t])
#************************************************************************
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
        println("The Market price in t=", t," is λ=" , dual(Balance[t]))
        println("Storage level at end of t=", t, " is e=", value(e[t]))
    end
    ρ_full = -dual(Stor2[H+1])
    e_H_full = value(e[H])
    println("The value of ρ[H+1]*=" , ρ_full)
    println("The value of e[H]*=", e_H_full)
else
    println("No optimal solution available")
end





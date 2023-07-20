#import Pkg; Pkg.add("CSV")
#import Pkg; Pkg.add("DataFrames")
cd("C:\\Users\\jonas\\Documents\\Jonas DTU\\MSc Thesis\\Modelling")

using JuMP
using HiGHS
using CSV
using DataFrames


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

## ----------------------------------  ## The Full Horizon Problem -----------------------------------------
# Sets
T = 1:size(D)[2]
L = 1:size(D)[1]
G = 1:size(P)[1]

# Storage Parameters
S = 2.5; 
E_init = 0;

#Model 😺
full = Model(HiGHS.Optimizer)
set_silent(full)

### Variables
## Variables Market Clearing
@variable(full, b[T] )            # Energy Charged or discharged for t
@variable(full, d[L, T] >= 0)   # Demand of load l at t
@variable(full, p[G, T] >= 0)   # Production of g at t
@variable(full, e[T] >= 0)        # State of Energy at the end of T

####### Market Clearing Formulation
@objective(full, Max, sum( sum(U[l,t]*d[l,t] for l in L) -  sum(C[g,t]*p[g,t] for g in G) for t in T) )
### Subject to
## Market Constraints
@constraint(full, Balance[t in T], sum(d[l,t] for l in L) + b[t] - sum(p[g,t] for g in G) == 0 )  # 2a
@constraint(full, Gen[g in G, t in T], 0 <= p[g,t] <= P[g,t])
@constraint(full, Load[l in L, t in T], 0 <= d[l,t] <= D[l,t])
## Storage Constraints (1a-1d)
@constraint(full, Stor1[t in T],   0 <= e[t] <= S)          #1a (v_low[t] , v_up[t])
@constraint(full, Stor2[t in T;t!=1],   e[t] == e[t-1]+b[t])     #1b (rho[t])
@constraint(full, Stor3, e[1] == E_init+b[1])                 #1c (rho[1])


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




### -----------------------------  ## The Future-Aware-Plus method (FAP) --------------------------------------------
##### In this problem we use the solution attained in the full-horizon problem in our objective function etc.

## -------------------- Time Horizon 1 -----------------
#end of time horizon 1 
H = 1
# Sets
T = 1:H
L = 1:1
G = 1:2

# Storage Parameters
S = 2.5; 
E_init = 0;

#Model 😺
FAP1 = Model(HiGHS.Optimizer)
set_silent(FAP1)

### Variables
## Variables Market Clearing
@variable(FAP1, b[T] )          # Energy Charged or discharged for t
@variable(FAP1, d[L, T] >= 0)   # Demand of load l at t
@variable(FAP1, p[G, T] >= 0)   # Production of g at t
@variable(FAP1, e[T])      # State of Energy at the end of T    

####### Market Clearing Formulation
@objective(FAP1, Max, sum( sum(U[l,t]*d[l,t] for l in L) -  sum(C[g,t]*p[g,t] for g in G) for t in T) + e[H]*ρ_full ) # 2d 
### Subject to
## Market Constraints (2b-2d)
@constraint(FAP1, FAP1_Balance[t in T], sum(d[l,t] for l in L) + b[t] - sum(p[g,t] for g in G) == 0 )  # 2b (λ[t])
@constraint(FAP1, FAP1_Gen[g in G, t in T], 0 <= p[g,t] <= P[g,t])                                     # 2c (μ_low[g,t], μ_up[g,t])
@constraint(FAP1, FAP1_Load[l in L, t in T], 0 <= d[l,t] <= D[l,t])                                    # 2d (X_low[g,t], X_up[g,t])
## Storage Constraints (1a-1d)
@constraint(FAP1, FAP1_Stor1_low[t in T], 0 <= e[t] )             #1a (v_low[t])
@constraint(FAP1, FAP1_Stor1_up[t in T],   e[t] <= S)             #1a (v_up[t])
@constraint(FAP1, FAP1_Stor2[t in T;t!=1],   e[t] == e[t-1]+b[t])   #1b (rho[t])
@constraint(FAP1, FAP1_Stor3, e[1] == E_init+b[1])                  #1c (rho[1]) 
@constraint(FAP1, FAP1_Stor4, e[H] == e_H_full)                   # (xi)  


#************************************************************************
# Solve
solution = optimize!(FAP1)
println("")
println("------------------------------ Future-Aware-Plus Time horizon 1  ------------------------------------")
println("Termination status: $(termination_status(FAP1))")
#************************************************************************
if termination_status(FAP1) == MOI.OPTIMAL
    println("Optimal objective value: $(objective_value(FAP1))")
    println("Solution:")
    for t in T
        println("The Market price in t=", t," is λ=" , dual(FAP1_Balance[t]))
        println("Storage level at end of t=", t, " is e=", value(e[t]))
        println("Energy charged/discharged=", t, " is b=", value(b[t]))
        println("Consumption of con1 in t=", t, " is d=", value(d[1,t]))
        println("Production of gen1 in t=", t, " is p=", value(p[1,t]))
        println("Production of gen2 in t=", t, " is p=", value(p[2,t]))
        println("value of ρ_FAP1 in t=", t, " is p=", -dual(FAP1_Stor3))
        println("value of v_low in t=", t, " is p=", -dual(FAP1_Stor1_low[H]))
        println("value of v_up in t=", t, " is p=", -dual(FAP1_Stor1_up[H]))
    end
else
    println("No optimal solution available")
end

### ----------  Input for time horizon 2  -----------------
ρ_FAP1 = -dual(FAP1_Stor3)
v_low = -dual(FAP1_Stor1_low[H])
v_up = -dual(FAP1_Stor1_up[H])
xi = -dual(FAP1_Stor4)
e_H_FAP1 = value(e[H])


## -------------------- Time Horizon 2 -----------------

# Sets
T2 = (H+1):time
L = 1:1
G = 1:2

# Storage Parameters
S = 2.5; 
E_init = 0;

#Model 😺
FAP2 = Model(HiGHS.Optimizer)
set_silent(FAP2)

### Variables
## Variables Market Clearing
@variable(FAP2, b[T2] )          # Energy Charged or discharged for t (Positive when charging)
@variable(FAP2, d[L, T2] >= 0)   # Demand of load l at t
@variable(FAP2, p[G, T2] >= 0)   # Production of g at t
@variable(FAP2, e[H:time] >= 0)  # State of Energy at the end of each t

                 

####### Market Clearing Formulation
@objective(FAP2, Max, sum( sum(U[l,t]*d[l,t] for l in L) -  sum(C[g,t]*p[g,t] for g in G) for t in T2) - e[H]*(ρ_FAP1+xi-v_low+v_up) ) # 2A 
### Subject to
## Market Constraints
@constraint(FAP2, FAP2_Balance[t in T2], sum(d[l,t] for l in L) + b[t] - sum(p[g,t] for g in G) == 0 )  # 2b (λ[t])
@constraint(FAP2, FAP2_Gen[g in G, t in T2], 0 <= p[g,t] <= P[g,t])                                     # 2c (μ_low[g,t], μ_up[g,t])
@constraint(FAP2, FAP2_Load[l in L, t in T2], 0 <= d[l,t] <= D[l,t])                                    # 2d (X_low[g,t], X_up[g,t])
## Storage Constraints (1a-1d)
@constraint(FAP2, FAP2_Stor1[t in T2],   0 <= e[t] <= S)             #1a (v_low[t] , v_up[t])
@constraint(FAP2, FAP2_Stor2[t in T2;t!=H+1],   e[t] == e[t-1]+b[t])   #1b (rho[t])
@constraint(FAP2, FAP2_Stor3, e[H+1] == e[H]+b[H+1])                  #1c (rho[1])
@constraint(FAP2, FAP2_Stor4, e[H] == e_H_full)

#************************************************************************
# Solve
solution = optimize!(FAP2)
println("")
println("------------------------------ Future-Aware-Plus Time horizon 2  ------------------------------------")
println("Termination status: $(termination_status(FAP2))")
#************************************************************************
if termination_status(FAP2) == MOI.OPTIMAL
    println("Optimal objective value: $(objective_value(FAP2))")
    println("Solution:")
    println("The storage level at t=H was: ", e_H_FAP1)
    for t in T2
        println("The Market price in t=", t," is λ=" , dual(FAP2_Balance[t]))
        println("Storage level at end of t=", t, " is e=", value(e[t]))
        println("Energy charged/discharged in t=", t, " is b=", value(b[t]))
        println("Consumption of con1 in t=", t, " is d=", value(d[1,t]))
        println("Production of gen1 in t=", t, " is p=", value(p[1,t]))
        println("Production of gen2 in t=", t, " is p=", value(p[2,t]))
    end
else
    println("No optimal solution available")
end


### With this command you can print a file of the obj function and all the individual constraints and bounds 
### write_to_file(FAP1,"solution1.lp")

#import Pkg; Pkg.add("CSV")
#import Pkg; Pkg.add("DataFrames")
#cd("C:\\Users\\jonas\\Documents\\Jonas DTU\\MSc Thesis\\Modelling")

using JuMP
using HiGHS
using CSV
using DataFrames
using Plots

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

include("Functions.jl")

## ----------------------------------  ## The Full Horizon Problem -----------------------------------------
# Sets
T = 1:2
H = 1 
T1 = 1:H
T2 = H+1:2
L = 1:size(D)[1]
G = 1:size(P)[1]

# Storage Parameters
S = 2.5; 
E_init = 0;

##### THIS FUCNTION SOLVES THE FULL-HORIZON FOR A GIVEN MAX PRODUCTION OF P1
function FAP1(ρ_full, e_H_full)
    #Model 😺
    FAP1 = Model(HiGHS.Optimizer)
    set_silent(FAP1)

    ### Variables
    ## Variables Market Clearing
    @variable(FAP1, b[T1] )          # Energy Charged or discharged for t
    @variable(FAP1, d[L, T1] >= 0)   # Demand of load l at t
    @variable(FAP1, p[G, T1] >= 0)   # Production of g at t
    @variable(FAP1, e[T1])      # State of Energy at the end of T    

    ####### Market Clearing Formulation
    @objective(FAP1, Max, sum( sum(U[l,t]*d[l,t] for l in L) -  sum(C[g,t]*p[g,t] for g in G) for t in T1) + e[H]*ρ_full ) # 2d 
    ### Subject to
    ## Market Constraints (2b-2d)
    @constraint(FAP1, FAP1_Balance[t in T1], sum(d[l,t] for l in L) + b[t] - sum(p[g,t] for g in G) == 0 )  # 2b (λ[t])
    @constraint(FAP1, FAP1_Gen[g in G, t in T1], 0 <= p[g,t] <= P[g,t])                                     # 2c (μ_low[g,t], μ_up[g,t])
    @constraint(FAP1, FAP1_Load[l in L, t in T1], 0 <= d[l,t] <= D[l,t])                                    # 2d (X_low[g,t], X_up[g,t])
    ## Storage Constraints (1a-1d)
    @constraint(FAP1, FAP1_Stor1_low[t in T1], 0 <= e[t] )             #1a (v_low[t])
    @constraint(FAP1, FAP1_Stor1_up[t in T1],   e[t] <= S)             #1a (v_up[t])
    @constraint(FAP1, FAP1_Stor2[t in T1;t!=1],   e[t] == e[t-1]+b[t])   #1b (rho[t])
    @constraint(FAP1, FAP1_Stor3, e[1] == E_init+b[1])                  #1c (rho[1]) 
    @constraint(FAP1, FAP1_Stor4, e[H] == e_H_full) 
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
        ρ_FAP1 = 0.0
        SW_FAP1 = 0.0
        e_FAP1 = 0.0
        v_low_FAP1 = 0.0
        v_up_FAP1 = 0.0
        xi_FAP1 = 0.0
        for t in T1
            ρ_FAP1 = -dual(FAP1_Stor3)
            SW_FAP1 = objective_value(FAP1)
            e_FAP1 = value(e[t])
            v_low_FAP1 = -dual(FAP1_Stor1_low[H])
            v_up_FAP1 = -dual(FAP1_Stor1_up[H])
            xi_FAP1 = -dual(FAP1_Stor4)
        end
    else
        println("No optimal solution available")
    end
    return ρ_FAP1, SW_FAP1, e_FAP1, v_low_FAP1, v_up_FAP1, xi_FAP1
end

function FAP2(e_H_full, ρ_FAP1, v_low_FAP1, v_up_FAP1, xi_FAP1, print_stats)
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
    @objective(FAP2, Max, sum( sum(U[l,t]*d[l,t] for l in L) -  sum(C[g,t]*p[g,t] for g in G) for t in T2) - e[H]*(ρ_FAP1+xi_FAP1-v_low_FAP1+v_up_FAP1) ) # 2A 
    ### Subject to
    ## Market Constraints
    @constraint(FAP2, FAP2_Balance[t in T2], sum(d[l,t] for l in L) + b[t] - sum(p[g,t] for g in G) == 0 )  # 2b (λ[t])
    @constraint(FAP2, FAP2_Gen[g in G, t in T2], 0 <= p[g,t] <= P[g,t])                                     # 2c (μ_low[g,t], μ_up[g,t])
    @constraint(FAP2, FAP2_Load[l in L, t in T2], 0 <= d[l,t] <= D[l,t])                                    # 2d (X_low[g,t], X_up[g,t])
    ## Storage Constraints (1a-1d)
    @constraint(FAP2, FAP2_Stor1[t in T2],   0 <= e[t] <= S)             #1a (v_low[t] , v_up[t])
    @constraint(FAP2, FAP2_Stor2[t in T2],  e[t] == e[t-1]+b[t])   #1b (rho[t])
    #@constraint(FAP2, FAP2_Stor3, e[H+1] == e[H]+b[H+1])                  #1c (rho[1])
    @constraint(FAP2, FAP2_Stor4, e[H] == e_H_full)                     # (xi)

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
        ρ_FAP2 = 0
        SW_FAP2 = 0
        e_FAP2 = 0
        ξ_FAP2 = 0
        λ_FAP2 = 0
        for t in T2
            ρ_FAP2 = -dual(FAP2_Stor2[t])
            SW_FAP2 = objective_value(FAP2)
            e_FAP2 = value(e[t])
            ξ_FAP2 = dual(FAP2_Stor4)
            λ_FAP2 = -dual(FAP2_Balance[t])
            if print_stats == true
                println("The value of ρ₂ in t=", t," is ρ₂=" , ρ_FAP2)
                println("The value of ξ₂ in t=", t," is ξ₂=" , ξ_FAP2)
                println("The market price is ρ₂+ξ₂ =", ρ_FAP2+ξ_FAP2)
                println("Consumption of demands in t=", t, " is d=", value.(d))
                println("Energy charged/discharged in t=", t, " is b=", value(b[t]))
                println("Production of gen1 in t=", t, " is p=", value(p[1,t]))
                println("Production of gen2 in t=", t, " is p=", value(p[2,t]))
            end
        end
    else
        println("No optimal solution available")
    end

    return ρ_FAP2, ξ_FAP2, SW_FAP2
end


### Plotting FAP2 outcome over max_P range. 
#Input values from robust full-Horizon
e_H_full = 1
ρ_full = 5
#Solve FAP1 using Full_horizon_robust script solution - solution will not change when only P_12 is uncertain
ρ_FAP1, SW_FAP1, e_FAP1, v_low_FAP1, v_up_FAP1, xi_FAP1 = FAP1(ρ_full, e_H_full)

#Solve FAP2 using FAP1 solution input for a range of different values of P_12
span = range(1,step=0.1,stop=3)
n = length(span)
ρ = zeros(0)
SW = zeros(0)
ξ = zeros(0)

for i in 1:n
    P_max = span[i]
    #Change Prod matrix
    P[1,2] = P_max
    ρ_i, SW_i, ξ_i = FAP2(e_H_full, ρ_FAP1, v_low_FAP1, v_up_FAP1, xi_FAP1, false)
    append!(ρ, ρ_i)
    append!(SW, SW_i)
    append!(ξ, ξ_i)
end

plot1 = plot(span, ρ, label="ρ₂",color="red", ylabel="€")
plot2 = plot(span, ξ, label="ξ₂", color="blue", ylabel="€")
plot3 = plot(span, SW, label="SW₂", color="green", ylabel="€")

full_interval = plot(plot1,plot2,plot3,layout=(3,1), legend = true, xlabel="P̅₁₂ [Wh]",title="e*=1,ρ*=5,D̅₁₂=3")
display(full_interval)
#savefig("C:\\Users\\jonas\\Pictures\\FAP_Robust_uncertainP12D2.png")

### Now also varying demand, and making a heatmap
P_span = range(1,step=0.1,stop=3)
D_span = range(2,step=0.1,stop=4)
n_p = length(P_span)
n_d = length(D_span)
n = length(P_span)
ρ = Array{Float64}(undef, n, n)
SW = Array{Float64}(undef, n, n)
ξ = Array{Float64}(undef, n, n)

for i in 1:n_p
    P_max = P_span[i]
    #Change Prod matrix
    P[1,2] = P_max
    for j in 1:n_d
        D_max = D_span[j]
        #Change demand matrix
        D[1,2] = D_max
        ρ_ij, ξ_ij, SW_ij = FAP2(e_H_full, ρ_FAP1, v_low_FAP1, v_up_FAP1, xi_FAP1, false)
        ρ[i,j] = ρ_ij
        SW[i,j] = SW_ij
        ξ[i,j] = ξ_ij
    end
end

ρ_heat = heatmap(P_span,D_span,transpose(ρ) , c=cgrad([:blue, :white,:red, :yellow]),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="ρ₂ in realized scenarios")
SW_heat = heatmap(P_span,D_span,transpose(SW) , c=cgrad([:blue, :white,:red, :yellow]),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="SW₂ in realized scenarios")
mp_heat = heatmap(P_span,D_span,transpose(ρ+ξ) , c=:roma, clims=(2,12),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="market price(ρ₂+ζ) in t=2")
### New scenario where P = []
#savefig(ρ_heat,"C:\\Users\\jonas\\Pictures\\heatmap_rho2.png")
#savefig(SW_heat,"C:\\Users\\jonas\\Pictures\\heatmap_SW2.png")
#savefig(mp_heat,"C:\\Users\\jonas\\Pictures\\heatmap_mp2.png")


### Testing stuff
D = [0 4; 0 4]
P = [2 1; 2 2]
U = [12 4; 12 12]
L = 1:2
ρ_FAP1, SW_FAP1, e_FAP1, v_low_FAP1, v_up_FAP1, xi_FAP1 = FAP1(ρ_full, e_H_full)
FAP2(e_H_full, ρ_FAP1, v_low_FAP1, v_up_FAP1, xi_FAP1, true)

#import Pkg; Pkg.add("CSV")
#import Pkg; Pkg.add("DataFrames")
#cd("C:\\Users\\jonas\\Documents\\Jonas DTU\\MSc Thesis\\Modelling")
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


##### THIS FUCNTION SOLVES THE FULL-HORIZON FOR A GIVEN MAX PRODUCTION OF P1
function full_horizon(end_of_horizon=false)
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
    if end_of_horizon != false
        @constraint(full, Stor4, e[H] = end_of_horizon ) 
    end


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
        ρ_full = -dual(Stor2[H+1])
        b_full = value(b[H+1])
        e_H_full = value(e[H])
        obj = (objective_value(full))
        println(ρ_full)
    else
        println("No optimal solution available")
    end

    return ρ_full, e_H_full, obj, b_full
end


#Old plots - only one uncertain parameters
rho_old = zeros(0)
e_old = zeros(0)
SW_old = zeros(0)
#New plots - multiple uncertain parameteres
P_span = range(1,step=0.1,stop=3)
D_span = range(2,step=0.1,stop=4)
n_p = length(P_span)
n_d = length(D_span)
n = length(D_span)
ρ_mat = Array{Float64}(undef, n, n)
b_mat = Array{Float64}(undef, n, n)
e_mat = Array{Float64}(undef, n, n)
SW_mat = Array{Float64}(undef, n, n)

for i in 1:n_p
    P_max = P_span[i]
    #Change Prod matrix
    P[1,2] = P_max
    for j in 1:n_d
        D_max = D_span[j]
        #Change demand matrix
        D[1,2] = D_max
        ρ_ij, e_ij, SW_ij = full_horizon(true)
        ρ_mat[i,j] = ρ_ij
        e_mat[i,j] = e_ij
        SW_mat[i,j] = SW_ij
    end
    #To create the old plots still
    #D_max = 3
    #D[1,2] = D_max
    #ρ_full, e_H_full, obj= full_horizon()
    #append!(rho_old, ρ_full)
    #append!(e_old,e_H_full)
    #append!(SW_old,obj)
end


plot1 = plot(span,rho_old, label="ρ₂*",color="red", ylabel="€")
plot2 = plot(span,e_old, label="e₁*", color="blue", ylabel="Wh")
plot3 = plot(span,SW_old, label="SW*", color="green", ylabel="€")
full_interval = plot(plot1,plot2,plot3,layout=(3,1), legend = true, xlabel="P̅₁₂ [Wh]")
savefig("C:\\Users\\jonas\\Pictures\\solution_space.png")


λ_heat = heatmap(P_span,D_span,transpose(ρ_mat) , c=cgrad([:blue, :white,:red, :yellow]),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="λ₂ in realized scenarios")
SW_heat = heatmap(P_span,D_span,transpose(SW_mat) , c=cgrad([:blue, :white,:red, :yellow]),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="SW* in realized scenarios")
e_heat = heatmap(P_span,D_span,transpose(e_mat) , c=cgrad([:blue, :white,:red, :yellow]),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="optimal e* for t=H")
### New scenario where P = []
savefig(λ_heat,"C:\\Users\\jonas\\Pictures\\heatmap_full_rho.png")
savefig(SW_heat,"C:\\Users\\jonas\\Pictures\\heatmap_full_SW.png")
savefig(e_heat,"C:\\Users\\jonas\\Pictures\\heatmap_full_e.png")


#New plots - multiple uncertain parameteres, this time for robust input
P_span = range(1,step=0.1,stop=3)
D_span = range(2,step=0.1,stop=4)
n_p = length(P_span)
n_d = length(D_span)
ρ_mat = Array{Float64}(undef, n, n)
e_mat = Array{Float64}(undef, n, n)
SW_mat = Array{Float64}(undef, n, n)

for i in 1:n_p
    P_max = P_span[i]
    #Change Prod matrix
    P[1,2] = P_max
    for j in 1:n_d
        D_max = D_span[j]
        #Change demand matrix
        D[1,2] = D_max
        ρ_ij, e_ij, SW_ij = full_horizon()
        ρ_mat[i,j] = ρ_ij
        e_mat[i,j] = e_ij
        SW_mat[i,j] = SW_ij
    end
end
ρ_heat = heatmap(P_span,D_span,transpose(ρ_mat) , c=cgrad([:blue, :white,:red, :yellow]),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="ρ* in realized scenarios")
SW_heat = heatmap(P_span,D_span,transpose(SW_mat) , c=cgrad([:blue, :white,:red, :yellow]),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="SW* in realized scenarios")
e_heat = heatmap(P_span,D_span,transpose(e_mat) , c=cgrad([:blue, :white,:red, :yellow]),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="optimal e* for t=H")
### New scenario where P = []
savefig(ρ_heat,"C:\\Users\\jonas\\Pictures\\heatmap_full_rho.png")
savefig(SW_heat,"C:\\Users\\jonas\\Pictures\\heatmap_full_SW.png")
savefig(e_heat,"C:\\Users\\jonas\\Pictures\\heatmap_full_e.png")
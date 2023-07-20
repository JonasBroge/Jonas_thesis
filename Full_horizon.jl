using JuMP
using HiGHS
using CSV
using DataFrames
cd("C:\\Users\\jonas\\Documents\\Jonas DTU\\MSc Thesis\\Modelling")
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

# Storage Parameters
S = 0 
E_init = 0
#E_end - optionnal

T = 1:2
L = 1
G = 1:2

#Model 😺
model = Model(HiGHS.Optimizer)

### Variables
## Variables Market Clearing
@variable(model, b[T] )            # Energy Charged or discharged for t
@variable(model, d[L, T] >= 0)   # Demand of load l at t
@variable(model, p[G, T] >= 0)   # Production of g at t
@variable(model, e[T] >= 0)        # State of Energy at the end of T

### Constraints 
####### Market Clearing Formulation
@objective(model, Max, sum( sum(U[l,t]*d[l,t] for l in L) -  sum(C[g,t]*p[g,t] for g in G) for t in T) )
### Subject to
@constraint(model, Balance[t in T], sum(d[l,t] for l in L) + b[t] - sum(p[g,t] for g in G) == 0 )  # 2a
@constraint(model, Gen[g in G, t in T], 0 <= p[g,t] <= P[g,t])
@constraint(model, Load[l in L, t in T], 0 <= d[l,t] <= D[l,t])
## Storage Constraints (1a-1d)
@constraint(model, Stor1[t in T],   0 <= e[t] <= S)          #1a (v_low[t] , v_up[t])
@constraint(model, Stor2[t in T;t!=1],   e[t] == e[t-1]+b[t])     #1b (rho[t])
@constraint(model, Stor3, e[1] == E_init+b[1])                 #1c (rho[1])


#************************************************************************
# Solve
solution = optimize!(model)
println("Termination status: $(termination_status(model))")
#************************************************************************

if termination_status(model) == MOI.OPTIMAL
    println("Optimal objective value: $(objective_value(model))")
    println("Solution:")
    for t in T
        print(dual(Balance[t]))
    #for w=1:W
    #    print("in month: ", Months[m])
    #    for o=1:O
    #        println(" Purchase of oil / storage level ", Oils[o], " = ", value(p[o,m]), " / ", value(s[o,m]))
    #    end
    #println("vials in batches ", value(f[w]))
    #end
    end
else
    println("No optimal solution available")
end



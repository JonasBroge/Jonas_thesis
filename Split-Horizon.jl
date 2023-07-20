#Split-Horizon
using JuMP
using HiGHS
using CSV
using DataFrames
#cd("C:\\Users\\jonas\\OneDrive - Danmarks Tekniske Universitet\\Documents\\Jonas DTU\\MSc Thesis\\Modelling")
include("Functions.jl")

### Standard version of the split horizon model
function split_model(E_init, T, E_end = nothing)
    #Model 😺
    split = Model(HiGHS.Optimizer)
    set_silent(split)
    t1 = T[1]
    H =  last(T)
    ### Variables
    ## Variables Market Clearing
    @variable(split, b[T] )          # Energy Charged or discharged for t
    @variable(split, d[L, T] >= 0)   # Demand of load l at t
    @variable(split, p[G, T] >= 0)   # Production of g at t
    @variable(split, e[T])      # State of Energy at the end of T    

    ####### Market Clearing Formulation
    @objective(split, Max, sum( sum(U[l,t]*d[l,t] for l in L) -  sum(C[g,t]*p[g,t] for g in G) for t in T)) # 2d 
    ### Subject to
    ## Market Constraints (2b-2d)
    @constraint(split, split_Balance[t in T], sum(d[l,t] for l in L) + b[t] - sum(p[g,t] for g in G) == 0 )  # 2b (λ[t])
    @constraint(split, split_Gen[g in G, t in T], 0 <= p[g,t] <= P[g,t])                                     # 2c (μ_low[g,t], μ_up[g,t])
    @constraint(split, split_Load[l in L, t in T], 0 <= d[l,t] <= D[l,t])                                    # 2d (X_low[g,t], X_up[g,t])
    ## Storage Constraints (1a-1d)
    @constraint(split, split_Stor1_low[t in T], 0 <= e[t] )             #1a (v_low[t])
    @constraint(split, split_Stor1_up[t in T],   e[t] <= S)             #1a (v_up[t])
    @constraint(split, split_Stor2[t in T;t!=t1],   e[t] == e[t-1]+b[t])   #1b (rho[t])
    @constraint(split, split_Stor3, e[t1] == E_init+b[t1])                  #1c (rho[1]) 
    if E_end !== nothing
        @constraint(split, split_Stor4, e[H] >= E_end) 
    end

        #************************************************************************
    # Solve

    solution = optimize!(split)
    println("")
    println("Termination status: $(termination_status(split))")
    #************************************************************************
    if termination_status(split) == MOI.OPTIMAL
        println("Optimal objective value: $(objective_value(split))")
        println("Solution:")
        SW_split = objective_value(split)
        λ_split = Vector(-dual.(split_Balance))
        b_split = Vector(value.(b))
        p_split = Array(value.(p))
        d_split = Array(value.(d))
        e_split = Vector(value.(e))

    else
        println("No optimal solution available")
    end
    return λ_split, SW_split, b_split, p_split, d_split, e_split
end

### Split horizon model that considers value of Storage from previous horizons 
function split_model_VOS(S_all, T, V, λ_all, E_end = nothing)
    #Model 😺
    split = Model(HiGHS.Optimizer)
    set_silent(split)
    t1 = T[1]
    H =  last(T)
    E_init = 0 #the time-horizon storage should always start at 0 for this version
    ### Variables
    ## Variables Market Clearing
    @variable(split, d[L, T])   # Demand of load l at t
    @variable(split, p[G, T])   # Production of g at t
    @variable(split, b[T] )          # Energy Charged or discharged for t
    @variable(split, e[T])           # State of Energy at the end of T
    ## Changes to Variables for VoS implementation
    @variable(split, q[T,V] >= 0)         # Quantity discharged in time t of value v
    @variable(split, s[T,V])         # Remaining energy stored at value v at end of time t

   
    ####### Market Clearing Formulation
    @objective(split, Max, sum( sum(U[l,t]*d[l,t] for l in L) -  sum(C[g,t]*p[g,t] for g in G) - sum(q[t,v]*λ_all[v] for v in V) for t in T))# # 2d 
    ### Subject to
    ## Market Constraints (2b-2d)
    @constraint(split, split_Balance[t in T], sum(d[l,t] for l in L) + b[t] - sum(q[t,v] for v in V) - sum(p[g,t] for g in G) == 0 )  # 2b (λ[t])
    @constraint(split, split_Gen[g in G, t in T], 0 <= p[g,t] <= P[g,t])                                     # 2c (μ_low[g,t], μ_up[g,t])
    @constraint(split, split_Load[l in L, t in T], 0 <= d[l,t] <= D[l,t])                                    # 2d (X_low[g,t], X_up[g,t])
    ## Storage Constraints (1a-1d) ## These are the storage constraints within a time horizon (the old ones)
    @constraint(split, split_Stor1_low[t in T], 0 <= e[t] )               #1a (v_low[t])
    @constraint(split, split_Stor2[t in T;t!=t1],   e[t] == e[t-1]+b[t])  #1b (rho[t])
    @constraint(split, split_Stor3, e[t1] == E_init+b[t1])                #1c (rho[1]) 
    ## Total storage constraint
    @constraint(split, split_Stor1_up[t in T],   e[t]+sum(s[t,v] for v in V) <= S)             #1a (v_up[t])
    if E_end !== nothing
        @constraint(split, split_Stor4, e[H]+sum(s[H,v] for v in V) == E_end) 
    end
    ## Inter-temporal storage constraints ## Similar to the constraints inside time-horizon
    @constraint(split, split_s1_low[t in T, v in V], 0 <= s[t,v] )             #1a (v_low[t])
    @constraint(split, split_s2[v in V, t in T;t!=t1],   s[t,v] == s[t-1,v]-q[t,v])   #1b (rho[t])
    @constraint(split, split_s3[v in V], s[t1,v] == S_all[v]-q[t1,v])               #1c (rho[1])
    ### Constraints to avoid as many solutions as possible where q and b are both charging and discharging
    @constraint(split, split_s4[t in T;t!=t1], b[t] + sum(q[t,v] for v in V)  <= S - e[t-1] + sum(s[t-1,v] for v in V)) #1c (rho[1]) 
    @constraint(split, split_s5, b[t1] + sum(q[t1,v] for v in V)  <= S - E_init +  sum(S_all[v] for v in V)) #1c (rho[1]) 
    @constraint(split, split_s6[t in T;t!=t1], -S - e[t-1] + sum(s[t-1,v] for v in V) <= b[t] + sum(q[t,v] for v in V)) #1c (rho[1]) 
    @constraint(split, split_s7, -S - E_init +  sum(S_all[v] for v in V) <= b[t1] + sum(q[t1,v] for v in V)) #1c (rho[1]) 
    # And the final constraints that cut away undesirable solutions
    @constraint(split, split_s8[t in T], -S  <= b[t1] + sum(q[t1,v] for v in V)) #1c (rho[1]) 
    @constraint(split, split_s9[t in T], b[t1] + sum(q[t1,v] for v in V)  <= S ) #1c (rho[1]) 

    # Solve

    solution = optimize!(split)
    println("")
    println("Termination status: $(termination_status(split))")
    #************************************************************************
    if termination_status(split) == MOI.OPTIMAL

       println("Optimal objective value: $(objective_value(split))")
       println("Solution:")
       SW_split = objective_value(split) + sum(sum(value.(q)[t,v]*λ_all[v] for v in V) for t in T)
       λ_split = Vector(-dual.(split_Balance))
       b_split = Vector(value.(b))
       s_split = Array(value.(s))
       p_split = Array(value.(p))
       d_split = Array(value.(d))
       e_split = Vector(value.(e))
       q_split = Array(value.(q))

   else
        println("No optimal solution available")
   end
   return λ_split, SW_split, b_split, p_split, d_split, e_split, q_split, s_split
end

### For simple split-horizon function, no value of storage implemented
function clear_all_split()
    λ_all = zeros(0)
    e_all = zeros(0)
    SW_all = zeros(0)
    for ts in Ts
        println("------------------------------ Split Time horizon ",T_names[ts], " ------------------------------------")
        global λ_T,SW_T,e_T = split_model(E_init,ts, nothing) #if ts!=last(Ts) 1 end)  - Use this if you want to set end of horizon storage level.
        global λ_all = vcat(λ_all,λ_T)
        global e_all = vcat(e_all,e_T)
        global SW_all = vcat(SW_all,SW_T)

        global E_init = last(e_T)
    end 
end

#### Now implementing Value of storage (Currently Acccording to procedure 2)
function clear_all_split_vos()
    ## Variables to keep track of prices, and storage levels
    V = nothing
    λ_all = zeros(0)
    SW_all = zeros(0)
    S_all = zeros(0)
    p_all = zeros(length(G),0)
    d_all = zeros(length(L),0)
    b_all = zeros(0)
    e_all = zeros(0)
    s_all = zeros(0)
    q_all = zeros(0)
    i=1
    for ts in Ts
        println("------------------------------ Split Time horizon ",T_names[i], " ------------------------------------")
        if ts==Ts[1]
            λ_T, SW_T, b_T, p_T, d_T, e_T = split_model(E_init,ts, E_Hs[i])
            q_T = fill(NaN, length(e_T))
            s_T = fill(NaN, length(e_T))
        else 
            #### Last input in function depends on if we want to see cost-recovery or SW over time.
            λ_T, SW_T, b_T, p_T, d_T, e_T, q_T, s_T = split_model_VOS(S_all,ts, V, λ_all, E_Hs[i]) #if ts != last(Ts) E_Hs[i] end) ###Use this instead for cost-recovery
            S_all = s_T[end,:]
        end 
        SW_all = vcat(SW_all,SW_T)
        λ_all = vcat(λ_all,λ_T)
        p_all = hcat(p_all,p_T)
        d_all = hcat(d_all,d_T)
        b_all = vcat(b_all,b_T)
        e_all = vcat(e_all,e_T)
        s_all = vcat(s_all,sum(s_T, dims=2)[:, 1])
        q_all = vcat(q_all,sum(q_T, dims=2)[:, 1])
        #Change length of set V to same length as amount of previous prices
        V = 1:length(λ_all)
        S_addition = create_s(ts, b_T, λ_T)
        S_all = vcat(S_all,S_addition)
        println("Social Welfare was ", SW_T)

        ### Create a pretty_table
        #header = ["t", "λ", "p1", "p2","d","b","e", "s","q"]
        #data = hcat(ts,λ_T, p_T[1,:], p_T[2,:] , d_T[1,:], b_T,e_T,sum(s_T, dims=2)[:, 1],sum(q_T, dims=2)[:, 1])
        #pretty_table(data,header=header)

        #println("Prices were ", λ_T)
        #println("Production was ", p_T)
        #println("demand met was: ", d_T)
        #println("(dis)charging of b was ", b_T)
        #println("End Storage level (e) was ", e_T)
        #if ts!=Ts[1]
        #println("End Storage level (s) was ", sum(s_T, dims=2)[:, 1])
        #println("Previous storage discharged (q) was ")
        #display(q_T)
        #end
        #println("Storage available (s) for subsequent horizons", S_all)
        i+=1
    end
    println("------------------------------ Overall Results ------------------------------------")
    ### Results across all time-steps
    println("Sum of Social Welfare: ", sum(SW_all))

    header = ["t", "λ", "p1", "p2","d","e", "b", "s","q","e+s"]
    data = hcat(1:last(last(Ts)),λ_all, p_all[1,:], p_all[2,:] , d_all[1,:], e_all, b_all, sum(s_all, dims=2)[:, 1],sum(q_all, dims=2)[:, 1], vcat(e_all[Ts[1]],(e_all+sum(s_all, dims=2)[:, 1])[first(Ts[2]):last(T_all)]))
    pretty_table(data,header=header)

    return S_all, λ_all, SW_all, p_all, d_all, e_all
end



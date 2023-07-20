using HiGHS
using CSV
using DataFrames
using PrettyTables
#cd("C:\\Users\\jonas\\OneDrive - Danmarks Tekniske Universitet\\Documents\\Jonas DTU\\MSc Thesis\\Modelling")
#Functions 
function full_horizon()
    ## ----------------------------------  ## The Full Horizon Problem -----------------------------------------
    # Sets
    T = 1:last(T_all)

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
    @constraint(full, full_Balance[t in T], sum(d[l,t] for l in L) + b[t] - sum(p[g,t] for g in G) == 0 )  # 2a
    @constraint(full, full_Gen[g in G, t in T], 0 <= p[g,t] <= P[g,t])
    @constraint(full, full_Load[l in L, t in T], 0 <= d[l,t] <= D[l,t])
    ## Storage Constraints (1a-1d)
    @constraint(full, full_Stor1[t in T],   0 <= e[t] <= S)          #1a (v_low[t] , v_up[t])
    @constraint(full, full_Stor2[t in T;t!=1],   e[t] == e[t-1]+b[t])     #1b (rho[t])
    @constraint(full, full_Stor3, e[1] == E_init+b[1])                 #1c (rho[1])


    #************************************************************************
    # Solve
    solution = optimize!(full)
    println("")
    println("------------------------------ Full horizon Solution ------------------------------------")
    println("Termination status: $(termination_status(full))")
    #************************************************************************

    if termination_status(full) == MOI.OPTIMAL
        SW = objective_value(full)
        λ_T = Vector(-dual.(full_Balance))
        b_T = Vector(value.(b))
        p_T = Array(value.(p))
        d_T = Array(value.(d))
        e_T = Vector(value.(e))
        println("Optimal objective value: $(objective_value(full))")
        println("Solution:")
        println("Social Welfare was ", SW)

        ### Creating a table for solution
        header = ["t", "λ", "p1", "p2","d","b","e"]
        data = hcat(T,λ_T, p_T[1,:], p_T[2,:] , d_T[1,:], b_T,e_T)
        pretty_table(data,header=header)
    else
        println("No optimal solution available")
    end
    return e_T, SW
end



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


function FAP2(e_H_full, ρ_FAP1, v_low_FAP1, v_up_FAP1, xi_FAP1)
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
    @constraint(FAP2, FAP2_Stor2[t in T2],   e[t] == e[t-1]+b[t])   #1b (rho[t])
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
        for t in T2
            ρ_FAP2 = -dual(FAP2_Stor2[t])
            SW_FAP2 = objective_value(FAP2)
            e_FAP2 = value(e[t])
            ξ_FAP2 = dual(FAP2_Stor4)
#            println("The Market price in t=", t," is λ=" , dual(FAP2_Balance[t]))
#            println("Storage level at end of t=", t, " is e=", value(e[t]))
#            println("Energy charged/discharged in t=", t, " is b=", value(b[t]))
#            println("Consumption of con1 in t=", t, " is d=", value(d[1,t]))
#            println("Production of gen1 in t=", t, " is p=", value(p[1,t]))
#            println("Production of gen2 in t=", t, " is p=", value(p[2,t]))
        end
    else
        println("No optimal solution available")
    end

    return ρ_FAP2, SW_FAP2, ξ_FAP2
end

function create_s(ts,b_T,price)
    s = zeros(length(ts))
    st_idx = zeros(Int64,0)
    for i in 1:length(ts)
        #If b is positive add stored energy to s (and remember storage indexes)
        if b_T[i] > 0
            s[i] = b_T[i]
            st_idx = vcat(st_idx,i)
        end
        #If b is negative subtract from the cheapest s
        if b_T[i] < 0 
            discharge = -b_T[i]
            j=1
            #Use indexes to only look at previously stored stuff and it's price
            prev_charge = view(s,st_idx)
            prev_price  = view(price,st_idx)
            while discharge != 0
                #1)Find the lowest price, 2)discharge until s=0 or discharge=0, 3)if s=0 remove idx from st_idx 4)j+=1
                min_idx = findmin(prev_price)[2]
                if prev_charge[min_idx] < discharge
                    discharge -= prev_charge[min_idx]
                    prev_charge[min_idx] = 0
                    deleteat!(st_idx,min_idx)
                end
                if prev_charge[min_idx] > discharge
                    prev_charge[min_idx] -= discharge
                    discharge = 0 
                end
                if prev_charge[min_idx] == discharge
                    prev_charge[min_idx] = 0
                    discharge = 0 
                    deleteat!(st_idx,min_idx)
                end
            end     
        end
    end
    return s
end

function full_horizon_robust()
    # Sets
    T = 1:last(T_all)
    #Change Prod matrix --- THIS IS USED FOR ROBUST
    #deviation from mean
    dev = 1
    # Right now the variation is set to 1 to either side 
    P_mean = P
    P_var = similar(P_mean)
    for g in G
        for t in T
            if P_mean[g,t] < dev
                P_var[g,t] = 0
            else P_var[g,t] = dev
            end
        end
    end
    P_worst = P_mean - P_var
    #Change Demand matrix 
    D_mean = D
    D_var = similar(D_mean)
    for l in L
        for t in T
            if D_mean[l,t] < dev
                D_var[l,t] = 0
            else 
                D_var[l,t] = dev
            end
        end
    end
    D_worst = D_mean - D_var

    #Model 😺
    robust = Model(HiGHS.Optimizer)
    set_silent(robust)

    ### Variables
    ## Variables Market Clearing
    @variable(robust, b[T] )            # Energy Charged or discharged for t
    @variable(robust, d[L, T] >= 0)   # Demand of load l at t
    @variable(robust, p[G, T] >= 0)   # Production of g at t
    @variable(robust, e[T] >= 0)        # State of Energy at the end of T

    #Robust variable
    @variable(robust, α[G,T] >= 0)
    @variable(robust, β[L,T] >= 0)

    ####### Market Clearing Formulation
    @objective(robust, Max, sum( sum(U[l,t]*d[l,t] for l in L) -  sum(C[g,t]*p[g,t] for g in G) for t in T) )
    ### Subject to
    ## Market Constraints
    @constraint(robust, robust_Balance[t in T], sum(d[l,t] for l in L) + b[t] - sum(p[g,t] for g in G) == 0 )  # 2a
    @constraint(robust, robust_Gen[g in G, t in T], p[g,t] <= P_mean[g,t] - α[g,t]) #Changed for robust
    @constraint(robust, robust_Load[l in L, t in T], d[l,t] <= D_mean[l,t] - β[l,t]) #Changed for robust
    ## Storage Constraints (1a-1d)
    @constraint(robust, robust_Stor1[t in T],   0 <= e[t] <= S)          #1a (v_low[t] , v_up[t])
    @constraint(robust, robust_Stor2[t in T;t!=1],   e[t] == e[t-1]+b[t])     #1b (rho[t])
    @constraint(robust, robust_Stor3, e[1] == E_init+b[1])                 #1c (rho[1])

    #Robust constraints
    @constraint(robust, rob1[g in G, t in T], -α[g,t] <= P_var[g,t])
    @constraint(robust, rob2[g in G, t in T], P_var[g,t] <= α[g,t])
    @constraint(robust, rob3[l in L, t in T], -β[l,t] <= D_var[l,t])
    @constraint(robust, rob4[l in L, t in T], D_var[t] <= β[l,t])
    #************************************************************************
    # Solve
    solution = optimize!(robust)
    println("")
    println("------------------------------ Robust Full horizon Solution ------------------------------------")
    println("Termination status: $(termination_status(robust))")
    #************************************************************************
    if termination_status(robust) == MOI.OPTIMAL
        SW = objective_value(robust)
        λ_T = Vector(-dual.(robust_Balance))
        b_T = Vector(value.(b))
        p_T = Array(value.(p))
        d_T = Array(value.(d))
        e_T = Vector(value.(e))
        println("Optimal objective value: $(objective_value(robust))")
        println("Solution:")
        println("Social Welfare was ", SW)

        ### Creating a table for solution
        header = ["t", "λ", "p1", "p2","d","b","e"]
        data = hcat(T,λ_T, p_T[1,:], p_T[2,:] , d_T[1,:], b_T,e_T)
        pretty_table(data,header=header)
    else
        println("No optimal solution available")
    end
    print(e_T)
    return e_T, SW, P_worst, D_worst
end
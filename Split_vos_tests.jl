### Testing the split-horizon VOS for different cases
include("Split-Horizon.jl")
include("Functions.jl")
using Plots


# Sets 
T_all = 1:2
T1 = 1:1
T2 = 2:2
Ts = [T1,T2]
T_names = ["T1","T2"]
L = 1:1
G = 1:2
S = 2.5; 
E_init = 0 
### Default parameters for Example II 
P = [2 2;
     2 2]   # production of generator[g,t]
C = [5 2
     10 9]  # cost of generator [g,t] 
D = [0 3]   # demand[l,t]
U = [12 12] # utility[l,t]
S_all, λ_all, SW_all, p_all, d_all, e_all = clear_all_split_vos()
#([-0.0, 0.0], [5.0, 5.0], [-5.0, 27.0], [1.0 2.0; 0.0 0.0], [-0.0 3.0]) (marginal "generator" is the storage, this controls price)

### Example where utility of load is 4€ and P12=3(cheap energy), meaning that the storage should not be discharged. (It was with the old method)
P = [2 3;
     2 2]   # production of generator[g,t]
C = [5 2
     10 9]  # cost of generator [g,t] 
D = [0 3]   # demand[l,t]
U = [12 6] # utility[l,t]
S_all, λ_all, SW_all, p_all, d_all, e_all = clear_all_split_vos() 
#([1.0, 0.0], [5.0, 2.0], [-5.0, 6.0], [1.0 3.0; 0.0 0.0], [-0.0 3.0])  (Cost-recovery for load, generator, and battery not used)

### Example where utility of load is 4€ and P12=0(cheap energy),
P = [2 0;
     2 2]   # production of generator[g,t]
C = [5 2
     10 9]  # cost of generator [g,t] 
D = [0 3]   # demand[l,t]
U = [12 4] # utility[l,t]
S_all, λ_all, SW_all, p_all, d_all, e_all = clear_all_split_vos() 
#([1.0, 0.0], [5.0, 4.0], [-5.0, 0.0], [1.0 -0.0; 0.0 0.0], [-0.0 -0.0]) (none of the demand is met as all sources of generation too expensive)


### New examples with two timesteps in each time-horizon
include("Split-Horizon.jl")
T_all = 1:4
T1 = 1:2
T2 = 3:4
Ts = [T1,T2]
T_names = ["T1","T2"] 
T_length = length(T_all)
L = 1:1
G = 1:2
S = 2.5; 
E_init = 0 
#Example 1 
P = [2 0 2 2;
     2 2 2 2]   # production of generator[g,t]
C = [5 5 2 2
     10 10 9 9]  # cost of generator [g,t] 
D = [0 0 3 3]   # demand[l,t]
U = [12 12 4 4] # utility[l,t]
S_all, λ_all, SW_all, p_all, d_all, e_all = clear_all_split_vos()
#Example 2
S=2.5
P = [4 2 2 2;
     2 2 2 2]   # production of generator[g,t]
C = [5 5 2 2
    10 10 9 10]  # cost of generator [g,t] 
D = [1 5 7 4]   # demand[l,t]
U = [4 7 9 12] # utility[l,t]
S_all, λ_all, SW_all, p_all, d_all, e_all = clear_all_split_vos()


### Now we add an additional time horizon as well
include("Split-Horizon.jl")
T_all = 1:6
T1 = 1:2
T2 = 3:4
T3 = 5:6
Ts = [T1,T2,T3]
T_names = ["T1","T2","T3"]
L = 1:1
G = 1:2
S = 2.5; 
E_init = 0 
#Example 1 
P = [2 0 2 2 2 2;
     2 2 2 2 2 2]   # production of generator[g,t]
C = [5  5  2 2 11 11
     10 10 9 9 6 6]  # cost of generator [g,t]
D = [0 0 3 3 3 5]   # demand[l,t]
U = [6 7 4 5 8 9] # utility[l,t]
S_all, λ_all, SW_all, p_all, d_all, e_all = clear_all_split_vos()


### Now we add an additional time horizon as well (3x3)
include("Split-Horizon.jl")
T_all = 1:9
T1 = 1:3
T2 = 4:6
T3 = 7:9
Ts = [T1,T2,T3]
T_names = ["T1","T2","T3"]
L = 1:1
G = 1:2
S = 2.5; 
E_init = 0 
#Example 1 
print("Production is set to")
P = rand(0:5,(2,9))   # production of generator[g,t]
print("Cost is set to")
C = rand(0:9,(2,9))  # cost of generator [g,t]
print("Demand is set to")
D = rand(0:4,(1,9))   # demand[l,t]
print("Utility is set to")
U = rand(0:14,(1,9))   # utility[l,t]
S_all, λ_all, SW_all, p_all, d_all, e_all = clear_all_split_vos()

### An example with three time-horizons but 3 steps randomized
include("Split-Horizon.jl")
T_all = 1:9
T1 = 1:3
T2 = 4:6
T3 = 7:9
T_length = last(T_all)
Ts = [T1,T2,T3]
T_names = ["T1","T2","T3"]
L = 1:1
G = 1:2
S = 2.5; 
E_init = 0 
#Example 3 - Example discussed with Elea, and used in thesis 
P = [5 1 0 2 3 4 3 0 0; 0 4 5 5 0 4 0 2 3]
C = [4 3 9 0 2 8 5 3 2; 6 3 6 8 0 9 9 0 5]
D = [0 1 3 4 1 4 1 2 2]
U = [1 8 11 7 13 11 13 11 3]
## Solution where E_H = 1 for T1 and T2
E_Hs = [1,1,0];
S_all, λ_all, SW_all, p_all, d_all, e_all = clear_all_split_vos();
## Solution where E_H is determined by full-horizon solution
E_T, SW_full = full_horizon();
E_Hs = [E_T[last(T1)],E_T[last(T2)],0];
S_all, λ_all, SW_all, p_all, d_all, e_all = clear_all_split_vos();



### An example with three time-horizons but 5 timesteps, to incentivize using s and charging again before end-of-horizon (3x3)
T_names = ["T1","T2","T3"]
T_all = 1:15
T1 = 1:5
T2 = 6:10
T3 = 11:15
Ts = [T1,T2,T3]
T_length = last(T_all)



L = 1:1
G = 1:2
S = 2.5; 
E_init = 0 
### Found an example where Social welfare when using full-horizon solution is not equal... 
P = [1 1 3 1 4 2 1 1 3 3 0 2 5 3 5; 
     5 3 0 3 0 1 5 1 5 4 3 1 5 0 3]
C = [0 4 9 2 4 3 2 9 2 2 3 6 9 4 7;
     5 5 7 1 9 4 3 8 3 3 7 9 9 4 7]
D = [3  0  1  1  2  3  0  0  4  3  4  0  3  0  0]
U = [0 14 14 5 13 4 12 13 7 9 12 10 1 8 13]

## Solution where E_H is determined by full-horizon solution
include("Split-Horizon.jl")
E_T, SW = full_horizon();
E_Hs = [E_T[last(T1)],E_T[last(T2)], 0];
S_all, λ_all, SW_all, p_all, d_all, e_all = clear_all_split_vos();


### Let's try using Robust solution to guide VoS #(deviation set to 1) 
E_T, SW_full = full_horizon_robust();
E_Hs = [E_T[last(T1)],E_T[last(T2)]];
S_all, λ_all, SW_all, p_all, d_all, e_all = clear_all_split_vos();
# The equivalent "myopic" solution could be:
E_Hs = [0, 0] 
S_all, λ_all, SW_myopic, p_all, d_all, e_all = clear_all_split_vos();

### NOTE THAT THE SETS ABOVE NEED TO BE RUN FIRST
# We create a plot where we get the social welfare when e_H is perfect(future-horizon), the social welfare from future-aware foresight(Robust)
# , and finally the social welfare of myopic approach (e_H=0). This is done for 10 different examples
SW_full_all_exp = zeros(0)
SW_robust_all_exp = zeros(0)
SW_myopic_all_exp = zeros(0)
SW_full_all_worst = zeros(0)
SW_robust_all_worst = zeros(0)
SW_myopic_all_worst = zeros(0)
SW_full_all_exp_10 = zeros(0)
SW_robust_all_exp_10 = zeros(0)
SW_myopic_all_exp_10 = zeros(0)
SW_full_all_worst_10 = zeros(0)
SW_robust_all_worst_10 = zeros(0)
SW_myopic_all_worst_10 = zeros(0)
for i in 1:10
     ### Generate Data
     #print("Production is set to")
     global P = rand(0:5,(2,T_length))   # production of generator[g,t]
     global C = rand(0:9,(2,T_length))  # cost of generator [g,t]
     global D = rand(0:4,(1,T_length))   # demand[l,t]
     global U = rand(0:14,(1,T_length))   # utility[l,t]

     #### Using storage capacity 2.5Wh
     S=2.5
     ############### FINDING SW WHEN THE REALIZED OUTCOME IS THE EXPECTED OUTCOME (MEAN)
     ## Get SW of full_horizon
     E_T, SW_full = full_horizon();
     # Get SW of robust
     E_T, SW = full_horizon_robust();
     global E_Hs = [E_T[last(T1)],E_T[last(T2)],E_T[last(T3)],E_T[last(T4)], 0]; #change if more horizons
     S_all, λ_all, SW_T_robust, p_all, d_all, e_all = clear_all_split_vos();
     global SW_robust = sum(SW_T_robust)
     # Get SW of myopic
     global E_Hs = [0, 0, 0, 0, 0] #change if more time-horizons
     S_all, λ_all, SW_T_myopic, p_all, d_all, e_all = clear_all_split_vos();
     SW_myopic = sum(SW_T_myopic)
     ### Now concatenate them 
     SW_full_all_exp = vcat(SW_full_all_exp, SW_full)
     SW_robust_all_exp = vcat(SW_robust_all_exp, SW_robust)
     SW_myopic_all_exp = vcat(SW_myopic_all_exp, SW_myopic)

     ############### FINDING SW WHEN EXPECTED OUTCOME IS THE WORST CASE 
     copy_P = copy(P)
     copy_D = copy(D)
     #Use robust to find worst D and P (copy first so we can use them later)
     E_T, SW, P, D= full_horizon_robust();
     # Get SW of robust
     E_Hs = [E_T[last(T1)], E_T[last(T2)],E_T[last(T3)],E_T[last(T4)], 0]; #change if more horizons
     S_all, λ_all, SW_T_robust, p_all, d_all, e_all = clear_all_split_vos();
     SW_robust = sum(SW_T_robust)

     ## Get SW of full_horizon
     E_T, SW_full = full_horizon();

     # Get SW of myopic
     E_Hs = [0, 0, 0, 0, 0] #change if more time-horizons
     S_all, λ_all, SW_T_myopic, p_all, d_all, e_all = clear_all_split_vos();
     SW_myopic = sum(SW_T_myopic)
     ### Now concatenate them 
     SW_full_all_worst = vcat(SW_full_all_worst, SW_full)
     SW_robust_all_worst = vcat(SW_robust_all_worst, SW_robust)
     SW_myopic_all_worst = vcat(SW_myopic_all_worst, SW_myopic)

     ####################################### Changing the storage capacity to 10
     P = copy_P
     D = copy_D
     S = 10
     ############### FINDING SW WHEN THE REALIZED OUTCOME IS THE EXPECTED OUTCOME (MEAN)
     ## Get SW of full_horizon
     E_T, SW_full = full_horizon();
     # Get SW of robust
     E_T, SW = full_horizon_robust();
     global E_Hs = [E_T[last(T1)],E_T[last(T2)],E_T[last(T3)],E_T[last(T4)], 0]; #change if more horizons
     S_all, λ_all, SW_T_robust, p_all, d_all, e_all = clear_all_split_vos();
     global SW_robust = sum(SW_T_robust)
     # Get SW of myopic
     global E_Hs = [0, 0, 0, 0, 0] #change if more time-horizons
     S_all, λ_all, SW_T_myopic, p_all, d_all, e_all = clear_all_split_vos();
     SW_myopic = sum(SW_T_myopic)
     ### Now concatenate them 
     SW_full_all_exp_10 = vcat(SW_full_all_exp_10, SW_full)
     SW_robust_all_exp_10 = vcat(SW_robust_all_exp_10, SW_robust)
     SW_myopic_all_exp_10 = vcat(SW_myopic_all_exp_10, SW_myopic)

     ############### FINDING SW WHEN EXPECTED OUTCOME IS THE WORST CASE 
     #Use robust to find worst D and P 
     E_T, SW, P, D= full_horizon_robust();
     # Get SW of robust
     E_Hs = [E_T[last(T1)],E_T[last(T2)],E_T[last(T3)],E_T[last(T4)], 0]; #change if more horizons
     S_all, λ_all, SW_T_robust, p_all, d_all, e_all = clear_all_split_vos();
     SW_robust = sum(SW_T_robust)

     ## Get SW of full_horizon
     E_T, SW_full = full_horizon();

     # Get SW of myopic
     E_Hs = [0, 0, 0, 0, 0] #change if more time-horizons
     S_all, λ_all, SW_T_myopic, p_all, d_all, e_all = clear_all_split_vos();
     SW_myopic = sum(SW_T_myopic)
     ### Now concatenate them 
     SW_full_all_worst_10 = vcat(SW_full_all_worst_10, SW_full)
     SW_robust_all_worst_10 = vcat(SW_robust_all_worst_10, SW_robust)
     SW_myopic_all_worst_10 = vcat(SW_myopic_all_worst_10, SW_myopic)

     ### Change P and D back again
     P = copy_P
     D = copy_D
end

#### For storage capacity S=2.5Wh
exp = plot(1:10,SW_full_all_exp, seriestype=:scatter, shape=:rect, ms=6, label = "perfect", xlabel = "Example Number", ylabel = "SW [€]", linewidth=2, thickness_scaling = 1)
plot!(1:10,SW_robust_all_exp, seriestype=:scatter, shape=:circle, ms=6, label = "future-aware VOS", linewidth=2, thickness_scaling = 1)
plot!(1:10,SW_myopic_all_exp, seriestype=:scatter, markershape=:diamond, ms=6, label = "myopic", linewidth=2, thickness_scaling = 1)
savefig("C:\\Users\\jonas\\Pictures\\SW_expected_2Wh.png")
worst = plot(1:10,SW_full_all_worst, seriestype=:scatter, shape=:rect, ms=6, label = "perfect", xlabel = "Example Number", ylabel = "SW [€]",linewidth=2, thickness_scaling = 1)
plot!(1:10,SW_robust_all_worst, seriestype=:scatter, shape=:circle, ms=6, label = "future-aware VOS", linewidth=2, thickness_scaling = 1)
plot!(1:10,SW_myopic_all_worst, seriestype=:scatter, shape=:diamond, ms=6, label = "myopic", linewidth=2, thickness_scaling = 1)
savefig("C:\\Users\\jonas\\Pictures\\SW_worst_2Wh.png")
#### For storage capacity S=10Wh
exp_10 = plot(1:10,SW_full_all_exp_10, seriestype=:scatter, shape=:rect, ms=6, label = "perfect", xlabel = "Example Number", ylabel = "SW [€]", linewidth=2, thickness_scaling = 1)
plot!(1:10,SW_robust_all_exp_10, seriestype=:scatter, shape=:circle, ms=6, label = "future-aware VOS", linewidth=2, thickness_scaling = 1)
plot!(1:10,SW_myopic_all_exp_10, seriestype=:scatter, shape=:diamond, ms=6, label = "myopic", linewidth=2, thickness_scaling = 1)
savefig("C:\\Users\\jonas\\Pictures\\SW_expected_ten.png")
worst_10 = plot(1:10,SW_full_all_worst_10, seriestype=:scatter,shape=:rect, ms=6, label = "perfect", xlabel = "Example Number", ylabel = "SW [€]",linewidth=2, thickness_scaling = 1)
plot!(1:10,SW_robust_all_worst_10, seriestype=:scatter, shape=:circle, ms=6, label = "future-aware VOS", linewidth=2, thickness_scaling = 1)
plot!(1:10,SW_myopic_all_worst_10, seriestype=:scatter, shape=:diamond, ms=6, label = "myopic", linewidth=2, thickness_scaling = 1)
savefig("C:\\Users\\jonas\\Pictures\\SW_worst_ten.png")
#### WE ALSO CREATY TABLES WITH PERCENTAGE INCREASE
println("2.5Wh exp future-aware VoS increase from myopic")
println(round.(100*SW_robust_all_exp./SW_myopic_all_exp.-100, digits=2))
println("2.5Wh worst future-aware VoS increase from myopic")
println(round.(100*SW_robust_all_worst./SW_myopic_all_worst.-100, digits=2))
println("10Wh exp future-aware VoS increase from myopic")
println(round.(100*SW_robust_all_exp_10./SW_myopic_all_exp_10.-100, digits=2))
println("10Wh exp future-aware VoS increase from myopic")
println(round.(100*SW_robust_all_worst_10./SW_myopic_all_worst_10.-100, digits=2))

L = 1:1
G = 1:2 
E_init = 0 
T_all = 1:50
T1 = 1:10
T2 = 11:20
T3 = 21:30
T4 = 31:40
T5 = 41:50
Ts = [T1,T2,T3,T4,T5]
T_names = ["T1","T2","T3","T4","T5"]
T_length = last(T_all)
S = 2.5; 

##### EXAMPLE I FOUND WITH BIG DIFFERENCE WHERE S=10
SW_full_all_exp = [533.0, 637.0, 690.0, 448.0, 587.0, 644.0, 559.0, 582.0, 579.0, 566.0]
SW_robust_all_exp = [522.0, 615.0, 684.0, 443.0, 580.0, 629.0, 558.0, 576.0, 576.0, 557.0]
SW_myopic_all_exp = [507.0, 582.0, 617.0, 404.0, 494.0, 592.0, 505.0, 522.0, 535.0, 493.0]
SW_full_all_worst = [307.0, 368.0, 421.0, 266.0, 347.0, 397.0, 361.0, 375.0, 337.0, 363.0]
SW_robust_all_worst = [299.0, 360.0, 421.0, 261.0, 344.0, 397.0, 359.0, 360.0, 333.0, 351.0]
SW_myopic_all_worst = [287.0, 311.0, 354.0, 227.0, 249.0, 363.0, 298.0, 323.0, 304.0, 300.0]




##### TESTING TESTING
include("Functions.jl")
include("Split-Horizon.jl")
T_all = 1:25
T_length = last(T_all)
T1 = 1:5
T2 = 6:10
T3 = 11:15
T4 = 16:20
T5 = 21:25
Ts = [T1,T2,T3,T4,T5]
global P = rand(0:5,(2,T_length))   # production of generator[g,t]
global C = rand(0:9,(2,T_length))  # cost of generator [g,t]
global D = rand(0:4,(1,T_length))   # demand[l,t]
global U = rand(0:14,(1,T_length)) 
S = 10
E_T, SW_full = full_horizon();
E_Hs = [E_T[last(T1)],E_T[last(T2)],E_T[last(T3)],E_T[last(T4)], 0];
S_all, λ_all, SW_T, p_all, d_all, e_all = clear_all_split_vos();
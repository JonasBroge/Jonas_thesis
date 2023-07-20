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
P = [2.0 2.0;
     2.0 2.0]   # production of generator[g,t]
C = [5 2
     10 9]  # cost of generator [g,t] 
D = [0.0 3.0]   # demand[l,t]
U = [12 12] # utility[l,t]

# We know that the Robust solution to this example for the end-of-horizon storage levels was:
E_Hs = [1, 0];
#S_all, λ_all, SW_T, p_all, d_all, e_all = clear_all_split_vos();

### We make the clear_all_split_vos() function manually so that we can change the parameters
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
### Market-interval 1 :
ts = Ts[1]
println("------------------------------ Split Time horizon ",T_names[i], " ------------------------------------")
λ_T, SW_T, b_T, p_T, d_T, e_T = split_model(E_init,ts, E_Hs[i])
q_T = fill(NaN, length(e_T))
s_T = fill(NaN, length(e_T))
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
i+=1


#### We test for all outcomese of uncertainty:
### Now also varying demand, and making a heatmap
P_span = range(1,step=0.1,stop=3)
D_span = range(2,step=0.1,stop=4)
n_p = length(P_span)
n_d = length(D_span)
n = length(P_span)
λ_plot = Array{Float64}(undef, n, n)
SW_plot = Array{Float64}(undef, n, n)
q_plot = Array{Float64}(undef, n, n)
p1_plot = Array{Float64}(undef, n, n)
p2_plot = Array{Float64}(undef, n, n)
d_plot = Array{Float64}(undef, n, n)


for x in 1:n_p
    global P_max = P_span[x]
    #Change Prod matrix
    global P[1,2] = P_max
    for j in 1:n_d
        global D_max = D_span[j]
        #Change demand matrix
        global D[1,2] = D_max

        ## now run Market Interval 2 given outcome of uncertainty
        global ts = Ts[2]
        println("------------------------------ Split Time horizon ",T_names[i], " ------------------------------------")
        global λ_T, SW_T, b_T, p_T, d_T, e_T, q_T, s_T = split_model_VOS(S_all,ts, V, λ_all, if ts != last(Ts) E_Hs[i] end)

        println("YAAAAAAY")
        ### And save desired variables
        global λ_plot[x,j] = λ_T[1]
        global SW_plot[x,j] = SW_T[1]
        global q_plot[x,j] = q_T[1]
        global p1_plot[x,j] = p_T[1]
        global p2_plot[x,j] = p_T[2]
        global d_plot[x,j] = d_T[1]
    end
end
println("WE GOT HERE")
λ_heat = heatmap(P_span,D_span,transpose(λ_plot) , c=cgrad([:blue, :white,:red, :yellow]), clims=(2,12),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="λ₂ in realized scenarios")
q_heat = heatmap(P_span,D_span,transpose(q_plot) , c=cgrad([:blue, :white,:red, :yellow]),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="q₂ in realized scenarios")
p1_heat = heatmap(P_span,D_span,transpose(p1_plot) , c=cgrad([:blue, :white,:red, :yellow]),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="p₁₂ in realized scenarios")
p2_heat = heatmap(P_span,D_span,transpose(p2_plot) , c=cgrad([:blue, :white,:red, :yellow]),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="p₂₂ in realized scenarios")
d_heat = heatmap(P_span,D_span,transpose(d_plot) , c=cgrad([:blue, :white,:red, :yellow]),
xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="d₁₂ in realized scenarios")
#SW_heat = heatmap(P_span,D_span,transpose(SW_plot) , c=cgrad([:blue, :white,:red, :yellow]),
#xlabel="P̅₁₂ [Wh]", ylabel="D̅₁₂ [Wh]", title="SW₂ in realized scenarios")
### New scenario where P = []
savefig(λ_heat,"C:\\Users\\jonas\\Pictures\\VOS_heatmap_price.png")
savefig(q_heat,"C:\\Users\\jonas\\Pictures\\VOS_heatmap_discharge.png")
savefig(p2_heat,"C:\\Users\\jonas\\Pictures\\VOS_heatmap_prod2.png")



### Market-interval 2:
ts = Ts[2]
println("------------------------------ Split Time horizon ",T_names[i], " ------------------------------------")
λ_T, SW_T, b_T, p_T, d_T, e_T, q_T, s_T = split_model_VOS(S_all,ts, V, λ_all, if ts != last(Ts) E_Hs[i] end)



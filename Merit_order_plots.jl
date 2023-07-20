using Plots

#Example 1 from thesis
# Supply costs and available generation of the generator (And in this case the battery)
gen_costs1 = [0, 2]  # Costs in ascending order
gen_quant1 = cumsum([0, 2])
store_price = [last(gen_costs1), 5]  # Prices in descending order
store_quant = cumsum([last(gen_quant1), 1]) # Quantities of prices
gen_costs2 = [last(store_price), 9] # Costs in ascending order
gen_quant2 = cumsum([last(store_quant), 2])
# Price bids and quantities of the load 
bid_price = [12, 12, 0]  # Prices in descending order
bid_quant = cumsum([0, 3, 0]) # Quantities of prices

plot1 = plot(gen_quant1,gen_costs1,linetype=:steppre, label = "generation", color="blue",linestyle = :solid, xlabel = "Quantity [Wh]", ylabel = "Price [€/Wh]", linewidth=2, thickness_scaling = 1)
plot!(store_quant,store_price,linetype=:steppre, label = "storage", color="orange",linestyle = :dash,linewidth=2, thickness_scaling = 1)
plot!(gen_quant2,gen_costs2,linetype=:steppre, label = "", color="blue",linestyle = :solid, xlabel = "Quantity [Wh]", ylabel = "Price [€/Wh]", linewidth=2, thickness_scaling = 1)
plot!(bid_quant,bid_price,linetype=:steppre, label = "load", color="green3",linestyle = :solid,linewidth=2, thickness_scaling = 1)
display(plot1)
savefig("C:\\Users\\jonas\\Pictures\\VoS_merit_example1.png")


### ----------   Example 2 from thesis ---------------------
###  ----- Time horizon 1 --------
## ------------- t=1---------
# Supply costs and available generation of the generator
gen_costs = [0, 5, 10]  # Costs in ascending order
gen_quant = cumsum([0, 4, 2])
# Price bids and quantities of the load (And in this case the battery)
store_price = [7, 7]  # Prices in descending order
store_quant = cumsum([0, 2.5]) # Quantities of prices
bid_price = [last(store_price), 4, 0]  # Prices in descending order
bid_quant = cumsum([last(store_quant), 1, 0]) # Quantities of prices

plot2 = plot(gen_quant,gen_costs,linetype=:steppre, label = "generation", color="blue",linestyle = :solid, xlabel = "Quantity", ylabel = "Price", linewidth=2, thickness_scaling = 1)
plot!(store_quant,store_price,linetype=:steppre, label = "storage", color="orange",linestyle = :dash,linewidth=2, thickness_scaling = 1)
plot!(bid_quant,bid_price,linetype=:steppre, label = "load", color="green3",linestyle = :solid,linewidth=2, thickness_scaling = 1)
display(plot2)
savefig("C:\\Users\\jonas\\Pictures\\VoS_merit_example2_t=1.png")


##  ---------- t=2 ------------
store_price = [0, 5]  # Prices in descending order
store_quant = cumsum([0, 1.5]) # Quantities of prices
gen_costs2 = [last(store_price), 5, 10] # Costs in ascending order
gen_quant2 = cumsum([last(store_quant), 2, 2])

bid_price = [7, 7, 0]  # Prices in descending order
bid_quant = cumsum([0, 5, 0]) # Quantities of prices
plot3 = plot(store_quant,store_price,linetype=:steppre, label = "storage", color="orange",linestyle = :dash,linewidth=2, thickness_scaling = 1, xlabel = "Quantity [Wh]", ylabel = "Price [€/Wh]")
plot!(gen_quant2,gen_costs2,linetype=:steppre, label = "generation", color="blue",linestyle = :solid, xlabel = "Quantity [Wh]", ylabel = "Price [€/Wh]", linewidth=2, thickness_scaling = 1)
plot!(bid_quant,bid_price,linetype=:steppre, label = "load", color="green3",linestyle = :solid,linewidth=2, thickness_scaling = 1)
display(plot3)
savefig("C:\\Users\\jonas\\Pictures\\VoS_merit_example2_t=2.png")


###  ----- Time horizon 2 --------
gen_costs1 = [0, 2, 2]  # Costs in ascending order
gen_quant1 = cumsum([0, 2, 2])
store_price = [last(gen_costs1), 5]  # Prices in descending order
store_quant = cumsum([last(gen_quant1), 1]) # Quantities of prices
gen_costs2 = [last(store_price), 9] # Costs in ascending order
gen_quant2 = cumsum([last(store_quant), 2])
# Price bids and quantities of the load 
bid_price = [12, 12, 9, 0]  # Prices in descending order
bid_quant = cumsum([0, 4, 3, 0]) # Quantities of prices

plot4 = plot(gen_quant1,gen_costs1,linetype=:steppre, label = "generation", color="blue",linestyle = :solid, xlabel = "Quantity [Wh]", ylabel = "Price [€/Wh]", linewidth=2, thickness_scaling = 1)
plot!(store_quant,store_price,linetype=:steppre, label = "storage", color="orange",linestyle = :dash,linewidth=2, thickness_scaling = 1)
plot!(gen_quant2,gen_costs2,linetype=:steppre, label = "", color="blue",linestyle = :solid, xlabel = "Quantity [Wh]", ylabel = "Price [€/Wh]", linewidth=2, thickness_scaling = 1)
plot!(bid_quant,bid_price,linetype=:steppre, label = "load", color="green3",linestyle = :solid,linewidth=2, thickness_scaling = 1)
display(plot4)
savefig("C:\\Users\\jonas\\Pictures\\VoS_merit_example2_t=34.png")



### ----------   Example 3 from thesis (3x3) ---------------------
print(P)
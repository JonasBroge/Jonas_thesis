ts = [1,2,3,4,5,6]
# For testing purposes, expected outcome -> S_init = [0, 3, 0, 0, 1, 0]
b_T = [5, 3, -2, -3, 4, -3]
price = [4, 5, 7, 8, 2, 5]
s = zeros(length(b_T))
st_idx = zeros(Int64,0)
for i in 1:length(ts)
    #If b is positive add stored energy to s (and remember storage indexes)
    if b_T[i] > 0
        s[i] = b_T[i]
        global st_idx = vcat(st_idx,i)
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

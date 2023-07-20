maximize
obj: 12 d_1,1_ - 5 p_1,1_ - 10 p_2,1_ + 5 _e_1_
subject to
FAP_Stor1_low_1_: -1 _e_1_ <= 0
FAP_Stor1_up_1_: 1 _e_1_ <= 2.5
FAP_Stor3: 1 _e_1_ - 1 b_1_ = 0
FAP_Balance_1_: 1 d_1,1_ - 1 p_1,1_ - 1 p_2,1_ + 1 b_1_ = 0
FAP_Gen_1,1_: 0 <= 1 p_1,1_ <= 2
FAP_Gen_2,1_: 0 <= 1 p_2,1_ <= 2
FAP_Load_1,1_: 0 <= 1 d_1,1_ <= 0
Bounds
d_1,1_ >= 0
p_1,1_ >= 0
p_2,1_ >= 0
_e_1_ >= 0
b_1_ free
End

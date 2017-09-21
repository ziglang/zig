.global far_cond
.type far_cond,%function
far_cond = 0x110023
.global far_uncond
.type far_uncond,%function
far_uncond = 0x101001b

.global too_far1
.type too_far1,%function
too_far1 = 0x1020005
.global too_far2
.type too_far1,%function
too_far2 = 0x1020009
.global too_far3
.type too_far3,%function
too_far3 = 0x12000d

.global blx_far
.type   blx_far, %function
blx_far = 0x2010025

.global blx_far2
.type   blx_far2, %function
blx_far2 = 0x2010029

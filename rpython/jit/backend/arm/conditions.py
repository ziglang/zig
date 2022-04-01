EQ = 0x0
NE = 0x1
HS = CS = 0x2
LO = CC = 0x3
MI = 0x4
PL = 0x5
VS = 0x6
VC = 0x7
HI = 0x8
LS = 0x9
GE = 0xA
LT = 0xB
GT = 0xC
LE = 0xD
AL = 0xE
cond_none = -1

opposites = [NE, EQ, CC, CS, PL, MI, VC, VS, LS, HI, LT, GE, LE, GT, AL]


def get_opposite_of(operation):
    assert operation >= 0
    return opposites[operation]

# see mapping for floating poin according to
# http://blogs.arm.com/software-enablement/405-condition-codes-4-floating-point-comparisons-using-vfp/
VFP_LT = CC
VFP_LE = LS

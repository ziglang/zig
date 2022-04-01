from rpython.jit.backend.zarch.locations import (FloatRegisterLocation,
        RegisterLocation, VectorRegisterLocation)

registers = [RegisterLocation(i) for i in range(16)]
fpregisters = [FloatRegisterLocation(i) for i in range(16)]
vregisters = [VectorRegisterLocation(16+i) for i in range(16)]

[r0,r1,r2,r3,r4,r5,r6,r7,r8,
 r9,r10,r11,r12,r13,r14,r15] = registers

MANAGED_REGS = [r2,r3,r4,r5,r6,r7,r8,r9,r10,r11] # keep this list sorted (asc)!
MANAGED_REG_PAIRS = [(r2,r3), (r4,r5), (r6,r7), (r8,r9), (r10,r11)]
VOLATILES = [r2,r3,r4,r5,r6]
SP = r15
RETURN = r14
POOL = r13
SPP = r12
SCRATCH = r1
SCRATCH2 = r0
GPR_RETURN = r2
RES = r2
RSZ = r11 # do not use a volatile register

[f0,f1,f2,f3,f4,f5,f6,f7,f8,
 f9,f10,f11,f12,f13,f14,f15] = fpregisters

# there are 4 float returns, but we only care for the first!
FPR_RETURN = f0
FP_SCRATCH = f15

MANAGED_FP_REGS = fpregisters[:-1]
VOLATILES_FLOAT = [f0,f1,f2,f3,f4,f5,f6,f7]

MANAGED_VECTOR_REGS = vregisters

# The JITFRAME_FIXED_SIZE is measured in words, and should be the
# number of registers that need to be saved into the jitframe when
# failing a guard, for example.
ALL_REG_INDEXES = {}
for _r in MANAGED_REGS:
    ALL_REG_INDEXES[_r] = len(ALL_REG_INDEXES)
for _r in MANAGED_FP_REGS:
    ALL_REG_INDEXES[_r] = len(ALL_REG_INDEXES)
# NOT used, but keeps JITFRAME_FIXED_SIZE even
ALL_REG_INDEXES[f15] = len(ALL_REG_INDEXES)
JITFRAME_FIXED_SIZE = len(ALL_REG_INDEXES)

def odd_reg(r):
    assert r.value % 2 == 0
    return registers[r.value+1]

def even_reg(r):
    assert r.value % 2 == 1
    return registers[r.value-1]

from rpython.jit.backend.arm.locations import VFPRegisterLocation
from rpython.jit.backend.arm.locations import SVFPRegisterLocation
from rpython.jit.backend.arm.locations import RegisterLocation

registers = [RegisterLocation(i) for i in range(16)]
vfpregisters = [VFPRegisterLocation(i) for i in range(16)]
svfpregisters = [SVFPRegisterLocation(i) for i in range(32)]
[r0, r1, r2, r3, r4, r5, r6, r7,
    r8, r9, r10, r11, r12, r13, r14, r15] = registers

#vfp registers interpreted as 64-bit registers
[d0, d1, d2, d3, d4, d5, d6, d7,
    d8, d9, d10, d11, d12, d13, d14, d15] = vfpregisters

# single precission VFP registers, 32-bit
for i in range(32):
    globals()['s%d' % i] = svfpregisters[i]

# aliases for registers
fp = r11
ip = r12
sp = r13
lr = r14
pc = r15
vfp_ip = d15
svfp_ip = s31

all_regs = [r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10]
all_vfp_regs = vfpregisters[:-1]

argument_regs = caller_resp = [r0, r1, r2, r3]
callee_resp = [r4, r5, r6, r7, r8, r9, r10, fp]
callee_saved_registers = callee_resp + [lr]
callee_restored_registers = callee_resp + [pc]

vfp_argument_regs = caller_vfp_resp = [d0, d1, d2, d3, d4, d5, d6, d7]
svfp_argument_regs = [globals()['s%i' % i] for i in range(16)]
callee_vfp_resp = [d8, d9, d10, d11, d12, d13, d14, d15]

callee_saved_vfp_registers = callee_vfp_resp

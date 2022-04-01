
from rpython.jit.backend.aarch64.locations import (RegisterLocation,
    ZeroRegister, VFPRegisterLocation)


registers = [RegisterLocation(i) for i in range(31)]
sp = xzr = ZeroRegister()
[x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10,
 x11, x12, x13, x14, x15, x16, x17, x18, x19, x20,
 x21, x22, x23, x24, x25, x26, x27, x28, x29, x30] = registers

vfpregisters = [VFPRegisterLocation(i) for i in range(32)]
all_vfp_regs = vfpregisters[:8]
all_regs = registers[:14]+ [x19, x20] #, x21, x22]

lr = x30
fp = x29

# scratch registers that we use internally, but don't save them
# nor we use them for regalloc
ip1 = x17
ip0 = x16
ip2 = x15
ip3 = x14   # not used so far, but 'caller_resp' needs to be even-length anyway

callee_saved_registers = [x19, x20] # , x21, x22]
vfp_argument_regs = caller_vfp_resp = all_vfp_regs[:8]
[d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14,
 d15, d16, d17, d18, d19, d20, d21, d22, d23, d24, d25, d26, d27,
 d28, d29, d30, d31] = vfpregisters

vfp_ip = d15

argument_regs = [x0, x1, x2, x3, x4, x5, x6, x7]
callee_resp = [x19, x20] # ,x21, x22]
caller_resp = argument_regs + [x8, x9, x10, x11, x12, x13]

from rpython.jit.backend.ppc.locations import (RegisterLocation,
       FPRegisterLocation, VectorRegisterLocation)

ALL_REGS        = [RegisterLocation(i) for i in range(32)]
ALL_FLOAT_REGS  = [FPRegisterLocation(i) for i in range(32)]
ALL_INTEGER_VECTOR_REGS = [VectorRegisterLocation(i) for i in range(32)]
ALL_FLOAT_VECTOR_REGS = [VectorRegisterLocation(i) for i in range(32,64)]

r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, r16,\
    r17, r18, r19, r20, r21, r22, r23, r24, r25, r26, r27, r28, r29, r30, r31\
    = ALL_REGS

f0, f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14, f15, f16,\
    f17, f18, f19, f20, f21, f22, f23, f24, f25, f26, f27, f28, f29, f30, f31\
    = ALL_FLOAT_REGS

ivr0, ivr1, ivr2, ivr3, ivr4, ivr5, ivr6, ivr7, ivr8, ivr9, ivr10, ivr11, ivr12,\
    ivr13, ivr14, ivr15, ivr16, ivr17, ivr18, ivr19, ivr20, ivr21, ivr22, ivr23,\
    ivr24, ivr25, ivr26, ivr27, ivr28, ivr29, ivr30, ivr31\
    = ALL_FLOAT_REGS

# the first 32 vector register are partly shared with the normal floating point
# registers, since there are so many registers, we just take the upper 31 ones
vr32, vr33, vr34, vr35, vr36, vr37, \
      vr38, vr39, vr40, vr41, vr42, vr43, vr44, vr45, vr46, vr47, vr48, \
      vr49, vr50, vr51, vr52, vr53, vr54, vr55, vr56, vr57, vr58, vr59, vr60, \
      vr61, vr62, vr63 = ALL_FLOAT_VECTOR_REGS


NONVOLATILES        = [r14, r15, r16, r17, r18, r19, r20, r21, r22, r23,
                    r24, r25, r26, r27, r28, r29, r30, r31]
VOLATILES           = [r3, r4, r5, r6, r7, r8, r9, r10, r11, r12]
# volatiles r0 and r2 are special, and r13 should be fully ignored

# we don't use any non-volatile float register, to keep the frame header
# code short-ish
#NONVOLATILES_FLOAT  = [f14, f15, f16, f17, f18, f19, f20, f21, f22, f23,
#                    f24, f25, f26, f27, f28, f29, f30, f31]
VOLATILES_FLOAT  = [f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13]
# volatile f0 is special

SCRATCH    = r0
SCRATCH2   = r2
FP_SCRATCH = f0
SP         = r1     # stack pointer register
TOC        = r2     # the TOC, but unused inside the code we generated
RES        = r3     # the result of calls
SPP        = r31    # the frame pointer
RCS1       = r30    # a random managed non-volatile register
RCS2       = r29    # a random managed non-volatile register
RCS3       = r28    # a random managed non-volatile register
RCS4       = r27    # a random managed non-volatile register
RSZ        = r25    # size argument to malloc_slowpath

MANAGED_REGS = [r3, r4, r5, r6, r7, r8, r9, r10, r11, r12,
                r25, r26, r27, r28, r29, r30]
                # registers r14 to r24 are not touched, we have enough
                # registers already
                # XXX but there are still in NONVOLATILES and saved/restored
                # by _save_nonvolatiles(), is that necessary??

MANAGED_FP_REGS = VOLATILES_FLOAT #+ NONVOLATILES_FLOAT

MANAGED_FLOAT_VECTOR_REGS = ALL_FLOAT_VECTOR_REGS
MANAGED_INTEGER_VECTOR_REGS = ALL_INTEGER_VECTOR_REGS

assert RCS1 in MANAGED_REGS and RCS1 in NONVOLATILES
assert RCS2 in MANAGED_REGS and RCS2 in NONVOLATILES
assert RCS3 in MANAGED_REGS and RCS3 in NONVOLATILES
assert RCS4 in MANAGED_REGS and RCS4 in NONVOLATILES
assert RSZ in MANAGED_REGS


# The JITFRAME_FIXED_SIZE is measured in words, and should be the
# number of registers that need to be saved into the jitframe when
# failing a guard, for example.
ALL_REG_INDEXES = {}
for _r in MANAGED_REGS:
    ALL_REG_INDEXES[_r] = len(ALL_REG_INDEXES)
for _r in MANAGED_FP_REGS:
    ALL_REG_INDEXES[_r] = len(ALL_REG_INDEXES) + 1
    #       we leave a never-used hole for f0  ^^^  in the jitframe
    #       to simplify store_info_on_descr(), which assumes that the
    #       register number N is at offset N after the non-fp regs
JITFRAME_FIXED_SIZE = len(ALL_REG_INDEXES) + 1


PARAM_REGS = [r3, r4, r5, r6, r7, r8, r9, r10]
PARAM_FPREGS = [f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13]

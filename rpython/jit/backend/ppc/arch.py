# Constants that depend on whether we are on 32-bit or 64-bit

import sys
from rpython.jit.backend.ppc import register as r

import sys
if sys.maxint == (2**31 - 1):
    assert False, "the ppc backend only supports PPC-64 for now"
    WORD = 4
    #DWORD = 2 * WORD
    IS_PPC_32 = True
    #BACKCHAIN_SIZE = 2
    #FPR_SAVE_AREA = len(NONVOLATILES_FLOAT) * DWORD
else:
    WORD = 8
    #DWORD = 2 * WORD
    IS_PPC_32 = False
    #BACKCHAIN_SIZE = 6
    #FPR_SAVE_AREA = len(NONVOLATILES_FLOAT) * WORD

IS_PPC_64               = not IS_PPC_32
MY_COPY_OF_REGS         = 0

IS_BIG_ENDIAN           = sys.byteorder == 'big'
IS_LITTLE_ENDIAN        = sys.byteorder == 'little'
assert IS_BIG_ENDIAN ^ IS_LITTLE_ENDIAN

#FORCE_INDEX             = WORD
#GPR_SAVE_AREA           = len(NONVOLATILES) * WORD
#FLOAT_INT_CONVERSION    = WORD
MAX_REG_PARAMS          = 8
MAX_FREG_PARAMS         = 13
# we need at most 5 instructions to load a constant
# and one instruction to patch the stack pointer
#SIZE_LOAD_IMM_PATCH_SP  = 6

#FORCE_INDEX_OFS         = (len(MANAGED_REGS) + len(MANAGED_FP_REGS)) * WORD


#                                      BIG ENDIAN       LITTLE ENDIAN
#
#        +--------------------+     <-      SP + STD_FRAME_SIZE
#        |  general registers |
#        |  save area         |
#        +--------------------+     <-  SP + 120          SP + 104
#        |  Local vars        |
#        +--------------------+     <-  SP + 112          SP + 96
#        |  Parameter save    |
#        |  area (8 args max) |
#        +--------------------+     <-  SP + 48           SP + 32
#        |  TOC (unused)      |
#        +--------------------+     <-  SP + 40           SP + 24
#        |  link ed. (unused) |
#        +--------------------+     <-  SP + 32           absent
#        |  compiler (unused) |
#        +--------------------+     <-  SP + 24           absent
#        |  LR save area      |
#        +--------------------+     <-  SP + 16           SP + 16
#        |  CR save (unused)  |
#        +--------------------+     <-  SP + 8            SP + 8
#        |  SP back chain     |
#        +--------------------+     <-  SP                SP

# The local variables area contains only a copy of the 2nd argument
# passed to the machine code function, which is the ll_threadlocal_addr.
# The 1st argument, i.e. the GC-managed jitframe, is stored in the
# register r31.


LR_BC_OFFSET            = 16
_GAP                    = 0 if IS_BIG_ENDIAN else 16
PARAM_SAVE_AREA_OFFSET  = 48 - _GAP
LOCAL_VARS_OFFSET       = 112 - _GAP
THREADLOCAL_ADDR_OFFSET = LOCAL_VARS_OFFSET
GPR_SAVE_AREA_OFFSET    = 120 - _GAP

REGISTERS_SAVED         = [r.r25, r.r26, r.r27, r.r28, r.r29, r.r30, r.r31]
assert REGISTERS_SAVED == [_r for _r in r.NONVOLATILES
                              if _r in r.MANAGED_REGS or _r == r.r31]

STD_FRAME_SIZE_IN_BYTES = GPR_SAVE_AREA_OFFSET + len(REGISTERS_SAVED) * WORD
assert STD_FRAME_SIZE_IN_BYTES % 16 == 0

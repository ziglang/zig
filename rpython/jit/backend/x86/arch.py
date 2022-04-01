# Constants that depend on whether we are on 32-bit or 64-bit
# the frame is absolutely standard. Stores callee-saved registers,
# return address and some scratch space for arguments.

import sys
if sys.maxint == (2**31 - 1):
    WORD = 4
    IS_X86_32 = True
    IS_X86_64 = False
else:
    WORD = 8
    IS_X86_32 = False
    IS_X86_64 = True
WIN64 = sys.platform == "win32" and sys.maxint > 2**32

#
#        +--------------------+    <== aligned to 16 bytes
#        |   return address   |
#        +--------------------+           ----------------------.
#        |    saved regs      |                FRAME_FIXED_SIZE |
#        +--------------------+       --------------------.     |
#        |   scratch          |          PASS_ON_MY_FRAME |     |
#        |      space         |                           |     |
#        +--------------------+    <== aligned to 16 -----' ----'

# All the rest of the data is in a GC-managed variable-size "frame".
# This frame object's address is always stored in the register EBP/RBP.
# A frame is a jit.backend.llsupport.llmodel.JITFRAME = GcArray(Signed).

# The frame's fixed size gives the standard fixed part at the
# start of every frame: the saved value of some registers

if WORD == 4:
    # ebp + ebx + esi + edi + 15 extra words = 19 words
    FRAME_FIXED_SIZE = 19 + 4 # 4 for vmprof, XXX make more compact!
    PASS_ON_MY_FRAME = 15
    JITFRAME_FIXED_SIZE = 6 + 8 * 2 # 6 GPR + 8 XMM * 2 WORDS/float
    # 'threadlocal_addr' is passed as 2nd argument on the stack,
    # and it can be left here for when it is needed.
    THREADLOCAL_OFS = (FRAME_FIXED_SIZE + 2) * WORD
else:
    # rbp + rbx + r12 + r13 + r14 + r15 + threadlocal + 12 extra words = 19
    # win64: we save instead rbp + rbx + rsi + rdi + r12 + 12 extra words = 17
    # win64: and we save r14 + r15 in the shadow store, and never use r13
    if not WIN64:
        FRAME_FIXED_SIZE = 19 + 4 # 4 for vmprof, XXX make more compact!
    else:
        FRAME_FIXED_SIZE = 17 + 4 # 4 for vmprof, XXX make more compact!
    PASS_ON_MY_FRAME = 12
    JITFRAME_FIXED_SIZE = 28 # 13 GPR + 15 XMM
    if not WIN64:
        # 'threadlocal_addr' is passed as 2nd argument in %esi,
        # and is moved into this frame location.
        THREADLOCAL_OFS = (FRAME_FIXED_SIZE - 1) * WORD
    else:
        # 'threadlocal_addr' is passed as 2nd argument in %edx,
        # and is moved into its official shadow store location.
        THREADLOCAL_OFS = (FRAME_FIXED_SIZE + 2) * WORD
        SHADOWSTORE2_OFS = (FRAME_FIXED_SIZE + 3) * WORD
        SHADOWSTORE3_OFS = (FRAME_FIXED_SIZE + 4) * WORD

assert PASS_ON_MY_FRAME >= 12

# return address, followed by FRAME_FIXED_SIZE words
DEFAULT_FRAME_BYTES = (1 + FRAME_FIXED_SIZE) * WORD

WORD = 8 # well, we only support 64 bit
DOUBLE_WORD = 8

#
#                                         OFF SP      | towards 0xff
#     +------------------------------+                |
#     |          ....                |                |
#     |  previous stack frame        |                |
#     +------------------------------+                |
#     +------------------------------+                |
#     |          ....                |                |
#     |  spill and local variables   |                |
#     |  used by call release gil    |                |
#     |          ....                |                |
#     +------------------------------+                |
#     |          ....                |                |
#     |  parameter area              |                |
#     |          ....                |                |
#     +------------------------------+       174 + SP |
#     |          ....                |                |
#     |  gpr save area (16x int,     |                |
#     |  4x float, f0, f2, f4, f6)   |                |
#     |          ....                |                |
#     +------------------------------+        16 + SP |
#     |  thread local addr           |                |
#     +------------------------------+         8 + SP |
#     |  SP back chain               |                |
#     +------------------------------+ <- SP   0 + SP | towards 0x0
#
#

# THREADLOCAL_BYTES = 8

# in reverse order to SP

STD_FRAME_SIZE_IN_BYTES = 160
THREADLOCAL_ON_ENTER_JIT = 8
THREADLOCAL_ADDR_OFFSET = STD_FRAME_SIZE_IN_BYTES + THREADLOCAL_ON_ENTER_JIT

assert STD_FRAME_SIZE_IN_BYTES % 2 == 0



#
#     +------------------------------+ <- assembler begin
#     |  SAVE CONTEXT                |
#     +------------------------------+
#start|  ...                         |
# |   |  LITERAL POOL                | <---+
# |   |  ...                         | <-+ |
# +-->+------------------------------+   | |
#     |  ...                         | +-|-+
#     |  CODE                        |   |
#     |  ...                         |   |
# +--+|  Guard X                     |   |
# |   |  ...                         |   |
# |   +------------------------------+   |
# |   |  ...                         | +-+
# |   |  RECOVERY                    |
# +-->|  ...                         |
#     +------------------------------+
#
#     A recovery entry looks like this:
#
#     +------------------------------+
#     | LOAD POOL (r0, guard_offset +|
#     | RECOVERY_TARGET_OFFSET)      |
#     +------------------------------+
#     | LOAD POOL (r2, guard_offset +|  parameter 0
#     | RECOVERY_GCMAP_OFFSET)       |
#     +------------------------------+
#     | LOAD IMM (r3, fail_descr)    |  parameter 1
#     +------------------------------+
#     | BRANCH TO r0                 |
#     +------------------------------+
#    

RECOVERY_TARGET_POOL_OFFSET = 0
RECOVERY_GCMAP_POOL_OFFSET = 8

JUMPABS_TARGET_ADDR__POOL_OFFSET = 0
JUMPABS_POOL_ADDR_POOL_OFFSET = 8

# r8 through r15 are saved registers (= non volatile)
# thus when entering the jit, we do not know if those
# are overwritten in the jit. save them using some extra
# stack space!
JIT_ENTER_EXTRA_STACK_SPACE = 8*8


WORD = 8

# The stack contains the force_index and the, callee saved registers and
# ABI required information
# All the rest of the data is in a GC-managed variable-size "frame".
# This jitframe object's address is always stored in the register FP
# A jitframe is a jit.backend.llsupport.llmodel.jitframe.JITFRAME
# Stack frame fixed area
# Currently only the force_index
NUM_MANAGED_REGS = 16
NUM_VFP_REGS = 8
JITFRAME_FIXED_SIZE = NUM_MANAGED_REGS + NUM_VFP_REGS
# 16 GPR + 8 VFP Regs, for now

WORD = 4
DOUBLE_WORD = 8

# the number of registers that we need to save around malloc calls
N_REGISTERS_SAVED_BY_MALLOC = 9
# the offset from the FP where the list of the registers mentioned above starts
MY_COPY_OF_REGS = WORD
# The Address in the PC points two words befind the current instruction
PC_OFFSET = 8
FORCE_INDEX_OFS = 0

# The stack contains the force_index and the, callee saved registers and
# ABI required information
# All the rest of the data is in a GC-managed variable-size "frame".
# This jitframe object's address is always stored in the register FP
# A jitframe is a jit.backend.llsupport.llmodel.jitframe.JITFRAME
# Stack frame fixed area
# Currently only the force_index
JITFRAME_FIXED_SIZE = 11 + 16 * 2 + 1
# 11 GPR + 16 VFP Regs (64bit) + 1 word for alignment

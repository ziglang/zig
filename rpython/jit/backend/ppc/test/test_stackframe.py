"""

                PyPy PPC Stackframe

                                                                               OLD  FRAME
            |         BACK CHAIN      |                                        
  - - - - - --------------------------- - - - - -- - - - - - - - - - 
            |                         |          |                             CURRENT FRAME
            |      FPR SAVE AREA      |          |>> len(NONVOLATILES_FPR) * DOUBLEWORD
            |                         |          |
            ---------------------------         --
            |                         |          |
            |      GPR SAVE AREA      |          |>> len(NONVOLATILES) * WORD
            |                         |          |
            ---------------------------         --
            |                         |          |
            |   FLOAT/INT CONVERSION  |          |>> 1 * WORD
            |                         |          |
            ---------------------------         --
            |       FORCE  INDEX      | WORD     |>> 1 WORD
            ---------------------------         --
            |                         |          |
            |      ENCODING AREA      |          |>> len(MANAGED_REGS) * WORD
            |      (ALLOCA AREA)      |          |
    SPP ->  ---------------------------         --
            |                         |          |
            |       SPILLING AREA     |          |>> regalloc.frame_manager.frame_depth * WORD
            |  (LOCAL VARIABLE SPACE) |          |
            ---------------------------         --
            |                         |          |
            |  PARAMETER SAVE AREA    |          |>> max_stack_params * WORD
            |                         |          |
            ---------------------------         --
  (64 Bit)  |        TOC POINTER      | WORD     |
            ---------------------------         --
            |                         |          |
  (64 Bit)  |  RESERVED FOR COMPILER  |          |>> 2 * WORD
            |       AND LINKER        |          |  
            ---------------------------         --
            |         SAVED LR        | WORD     |
            ---------------------------          |>> 3 WORDS (64 Bit)
  (64 Bit)  |         SAVED CR        | WORD     |   2 WORDS (32 Bit)
            ---------------------------          |
            |        BACK CHAIN       | WORD     |
     SP ->  ---------------------------         --


Minimum PPC64 ABI stack frame:

                                                                               OLD  FRAME
            |         BACK CHAIN      |                                        
  - - - - - --------------------------- - - - - -- - - - - - - - - - 
            |                         |          |                             CURRENT FRAME
            |  PARAMETER SAVE AREA    |          |>> max_stack_params * WORD
            |                         |          |
            ---------------------------         --
  (64 Bit)  |        TOC POINTER      | WORD     |
            ---------------------------         --
            |                         |          |
  (64 Bit)  |  RESERVED FOR COMPILER  |          |>> 2 * WORD
            |       AND LINKER        |          |  
            ---------------------------         --
            |         SAVED LR        | WORD     |
            ---------------------------          |>> 3 WORDS (64 Bit)
  (64 Bit)  |         SAVED CR        | WORD     |   2 WORDS (32 Bit)
            ---------------------------          |
            |        BACK CHAIN       | WORD     |
     SP ->  ---------------------------         --

PARAM AREA = 8 doublewords = 64 bytes
FIXED AREA = 6 doublewords = 48 bytes
TOTAL      = 14 doublewords = 112 bytes

*ALL* of the locations may be left empty.  Some of the locations may be
written by child function.

TOC POINTER is used to restore addressibility of globals, but may be
restored independently.

SAVED LR is used to restore the return address, but the return address
link register may be preserved using another method or control transferred
in a different manner.

BACK CHAIN stores previous stack pointer to permit walking the stack frames,
but stack may be allocated and deallocated without storing it.

Decrementing the stack pointer by 112 bytes at the beginning of a function
and incrementing the stack pointer by the complementary amount is sufficient
to interact with other ABI-compliant functions.

"""

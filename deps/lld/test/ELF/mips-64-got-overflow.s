# REQUIRES: mips
# Check the primary GOT cannot be made to overflow

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux \
# RUN:         %p/Inputs/mips-64-got-load.s -o %t1.so.o
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t2.so.o
# RUN: ld.lld -shared -mips-got-size 32 %t1.so.o %t2.so.o -o %t-sgot.so
# RUN: ld.lld -shared -mips-got-size 24 %t1.so.o %t2.so.o -o %t-mgot.so
# RUN: llvm-readelf --mips-plt-got %t-sgot.so | FileCheck -check-prefix=SGOT %s
# RUN: llvm-readelf --mips-plt-got %t-mgot.so | FileCheck -check-prefix=MGOT %s

# SGOT:      Primary GOT:
# SGOT-NEXT:  Canonical gp value: 0000000000027ff0
# SGOT-EMPTY:
# SGOT-NEXT:  Reserved entries:
# SGOT-NEXT:            Address     Access          Initial Purpose
# SGOT-NEXT:   0000000000020000 -32752(gp) 0000000000000000 Lazy resolver
# SGOT-NEXT:   0000000000020008 -32744(gp) 8000000000000000 Module pointer (GNU extension)
# SGOT-EMPTY:
# SGOT-NEXT:  Local entries:
# SGOT-NEXT:            Address     Access          Initial
# SGOT-NEXT:   0000000000020010 -32736(gp) 0000000000020020
# SGOT-NEXT:   0000000000020018 -32728(gp) 0000000000020030

# MGOT:      Primary GOT:
# MGOT-NEXT:  Canonical gp value: 0000000000027ff0
# MGOT-EMPTY:
# MGOT-NEXT:  Reserved entries:
# MGOT-NEXT:            Address     Access          Initial Purpose
# MGOT-NEXT:   0000000000020000 -32752(gp) 0000000000000000 Lazy resolver
# MGOT-NEXT:   0000000000020008 -32744(gp) 8000000000000000 Module pointer (GNU extension)
# MGOT-EMPTY:
# MGOT-NEXT:  Local entries:
# MGOT-NEXT:            Address     Access          Initial
# MGOT-NEXT:   0000000000020010 -32736(gp) 0000000000020020
# MGOT-EMPTY:
# MGOT-NEXT:  Number of TLS and multi-GOT entries 1

  .text
  .global foo2
foo2:
  ld $2, %got_disp(local2)($gp)

  .bss
local2:
  .word 0

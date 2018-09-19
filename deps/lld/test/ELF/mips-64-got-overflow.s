# REQUIRES: mips
# Check the primary GOT cannot be made to overflow

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux \
# RUN:         %p/Inputs/mips-64-got-load.s -o %t1.so.o
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t2.so.o
# RUN: ld.lld -shared -mips-got-size 32 %t1.so.o %t2.so.o -o %t-sgot.so
# RUN: ld.lld -shared -mips-got-size 24 %t1.so.o %t2.so.o -o %t-mgot.so
# RUN: llvm-readobj -r -dt -mips-plt-got %t-sgot.so | FileCheck -check-prefix=SGOT %s
# RUN: llvm-readobj -r -dt -mips-plt-got %t-mgot.so | FileCheck -check-prefix=MGOT %s

# SGOT:      Primary GOT {
# SGOT-NEXT:   Canonical gp value: 0x27FF0
# SGOT-NEXT:   Reserved entries [
# SGOT-NEXT:     Entry {
# SGOT-NEXT:       Address:
# SGOT-NEXT:       Access: -32752
# SGOT-NEXT:       Initial: 0x0
# SGOT-NEXT:       Purpose: Lazy resolver
# SGOT-NEXT:     }
# SGOT-NEXT:     Entry {
# SGOT-NEXT:       Address:
# SGOT-NEXT:       Access: -32744
# SGOT-NEXT:       Initial: 0x80000000
# SGOT-NEXT:       Purpose: Module pointer (GNU extension)
# SGOT-NEXT:     }
# SGOT-NEXT:   ]
# SGOT-NEXT:   Local entries [
# SGOT-NEXT:     Entry {
# SGOT-NEXT:       Address:
# SGOT-NEXT:       Access: -32736
# SGOT-NEXT:       Initial: 0x20020
# SGOT-NEXT:     }
# SGOT-NEXT:     Entry {
# SGOT-NEXT:       Address:
# SGOT-NEXT:       Access: -32728
# SGOT-NEXT:       Initial: 0x20030
# SGOT-NEXT:     }
# SGOT-NEXT:   ]
# SGOT-NEXT:   Global entries [
# SGOT-NEXT:   ]
# SGOT-NEXT:   Number of TLS and multi-GOT entries: 0
# SGOT-NEXT: }

# MGOT:      Primary GOT {
# MGOT-NEXT:   Canonical gp value: 0x27FF0
# MGOT-NEXT:   Reserved entries [
# MGOT-NEXT:     Entry {
# MGOT-NEXT:       Address:
# MGOT-NEXT:       Access: -32752
# MGOT-NEXT:       Initial: 0x0
# MGOT-NEXT:       Purpose: Lazy resolver
# MGOT-NEXT:     }
# MGOT-NEXT:     Entry {
# MGOT-NEXT:       Address:
# MGOT-NEXT:       Access: -32744
# MGOT-NEXT:       Initial: 0x80000000
# MGOT-NEXT:       Purpose: Module pointer (GNU extension)
# MGOT-NEXT:     }
# MGOT-NEXT:   ]
# MGOT-NEXT:   Local entries [
# MGOT-NEXT:     Entry {
# MGOT-NEXT:       Address:
# MGOT-NEXT:       Access: -32736
# MGOT-NEXT:       Initial: 0x20020
# MGOT-NEXT:     }
# MGOT-NEXT:   ]
# MGOT-NEXT:   Global entries [
# MGOT-NEXT:   ]
# MGOT-NEXT:   Number of TLS and multi-GOT entries: 1
# MGOT-NEXT: }

  .text
  .global foo2
foo2:
  ld $2, %got_disp(local2)($gp)

  .bss
local2:
  .word 0

# Check MIPS N64 ABI GOT relocations

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux \
# RUN:         %p/Inputs/mips-pic.s -o %t.so.o
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t.exe.o
# RUN: ld.lld %t.so.o -shared -o %t.so
# RUN: ld.lld %t.exe.o %t.so -o %t.exe
# RUN: llvm-objdump -d -t %t.exe | FileCheck %s
# RUN: llvm-readobj -r -mips-plt-got %t.exe | FileCheck -check-prefix=GOT %s

# REQUIRES: mips

# CHECK:      __start:

# CHECK-NEXT:    20000:   df 82 80 20   ld      $2, -32736($gp)
# CHECK-NEXT:    20004:   64 42 00 18   daddiu  $2,  $2, 24
# CHECK-NEXT:    20008:   24 42 80 40   addiu   $2,  $2, -32704
# CHECK-NEXT:    2000c:   24 42 80 30   addiu   $2,  $2, -32720
# CHECK-NEXT:    20010:   24 42 80 38   addiu   $2,  $2, -32712

# CHECK: 0000000000020018   .text   00000000 foo
# CHECK: 0000000000020000   .text   00000000 __start
# CHECK: 0000000000020014   .text   00000000 bar

# GOT:      Relocations [
# GOT-NEXT: ]
# GOT-NEXT: Primary GOT {
# GOT-NEXT:   Canonical gp value:
# GOT-NEXT:   Reserved entries [
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32752
# GOT-NEXT:       Initial: 0x0
# GOT-NEXT:       Purpose: Lazy resolver
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32744
# GOT-NEXT:       Initial: 0x8000000000000000
# GOT-NEXT:       Purpose: Module pointer (GNU extension)
# GOT-NEXT:     }
# GOT-NEXT:   ]
# GOT-NEXT:   Local entries [
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32736
# GOT-NEXT:       Initial: 0x20000
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32728
# GOT-NEXT:       Initial: 0x30000
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32720
# GOT-NEXT:       Initial: 0x20014
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32712
# GOT-NEXT:       Initial: 0x20018
# GOT-NEXT:     }
# GOT-NEXT:   ]
# GOT-NEXT:   Global entries [
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32704
# GOT-NEXT:       Initial: 0x0
# GOT-NEXT:       Value: 0x0
# GOT-NEXT:       Type: Function
# GOT-NEXT:       Section: Undefined
# GOT-NEXT:       Name: foo1a
# GOT-NEXT:     }
# GOT-NEXT:   ]
# GOT-NEXT:   Number of TLS and multi-GOT entries: 0
# GOT-NEXT: }

  .text
  .global  __start, bar
__start:
  ld      $v0,%got_page(foo)($gp)             # R_MIPS_GOT_PAGE
  daddiu  $v0,$v0,%got_ofst(foo)              # R_MIPS_GOT_OFST
  addiu   $v0,$v0,%got_disp(foo1a)            # R_MIPS_GOT_DISP
  addiu   $v0,$v0,%got_disp(bar)              # R_MIPS_GOT_DISP
  addiu   $v0,$v0,%got_disp(foo)              # R_MIPS_GOT_DISP

bar:
  nop
foo:
  nop

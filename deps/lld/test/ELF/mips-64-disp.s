# REQUIRES: mips
# Check R_MIPS_GOT_DISP relocations against various kind of symbols.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux \
# RUN:         %p/Inputs/mips-pic.s -o %t.so.o
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t.exe.o
# RUN: ld.lld %t.so.o -shared -o %t.so
# RUN: ld.lld %t.exe.o %t.so -o %t.exe
# RUN: llvm-objdump -d -t %t.exe | FileCheck %s
# RUN: llvm-readelf -r --mips-plt-got %t.exe | FileCheck -check-prefix=GOT %s

# CHECK:      __start:
# CHECK-NEXT:    20000:   24 42 80 40   addiu   $2, $2, -32704
# CHECK-NEXT:    20004:   24 42 80 20   addiu   $2, $2, -32736
# CHECK-NEXT:    20008:   24 42 80 28   addiu   $2, $2, -32728
# CHECK-NEXT:    2000c:   24 42 80 30   addiu   $2, $2, -32720
# CHECK-NEXT:    20010:   24 42 80 38   addiu   $2, $2, -32712

# CHECK: 0000000000020014     .text   00000000 foo
# CHECK: 0000000000020000     .text   00000000 __start
# CHECK: 0000000000000000 g F *UND*   00000000 foo1a

# GOT:      Primary GOT:
# GOT-NEXT:  Canonical gp value: 0000000000038000
# GOT-EMPTY:
# GOT-NEXT:  Reserved entries:
# GOT-NEXT:            Address     Access          Initial Purpose
# GOT-NEXT:   0000000000030010 -32752(gp) 0000000000000000 Lazy resolver
# GOT-NEXT:   0000000000030018 -32744(gp) 8000000000000000 Module pointer (GNU extension)
# GOT-EMPTY:
# GOT-NEXT:  Local entries:
# GOT-NEXT:            Address     Access          Initial
# GOT-NEXT:   0000000000030020 -32736(gp) 0000000000020014
# GOT-NEXT:   0000000000030028 -32728(gp) 0000000000020004
# GOT-NEXT:   0000000000030030 -32720(gp) 0000000000020008
# GOT-NEXT:   0000000000030038 -32712(gp) 000000000002000c
# GOT-EMPTY:
# GOT-NEXT:  Global entries:
# GOT-NEXT:            Address     Access          Initial         Sym.Val. Type Ndx Name
# GOT-NEXT:   0000000000030040 -32704(gp) 0000000000000000 0000000000000000 FUNC UND foo1a

  .text
  .global  __start
__start:
  addiu   $v0,$v0,%got_disp(foo1a)            # R_MIPS_GOT_DISP
  addiu   $v0,$v0,%got_disp(foo)              # R_MIPS_GOT_DISP
  addiu   $v0,$v0,%got_disp(.text+4)          # R_MIPS_GOT_DISP
  addiu   $v0,$v0,%got_disp(.text+8)          # R_MIPS_GOT_DISP
  addiu   $v0,$v0,%got_disp(.text+12)         # R_MIPS_GOT_DISP

foo:
  nop

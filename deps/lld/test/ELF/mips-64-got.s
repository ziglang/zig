# REQUIRES: mips
# Check MIPS N64 ABI GOT relocations

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux \
# RUN:         %p/Inputs/mips-pic.s -o %t.so.o
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t.exe.o
# RUN: ld.lld %t.so.o -shared -o %t.so
# RUN: ld.lld %t.exe.o %t.so -o %t.exe
# RUN: llvm-objdump -d -t %t.exe | FileCheck %s
# RUN: llvm-readelf -r --mips-plt-got %t.exe | FileCheck -check-prefix=GOT %s

# CHECK:      __start:

# CHECK-NEXT:    20000:   df 82 80 20   ld      $2, -32736($gp)
# CHECK-NEXT:    20004:   64 42 00 18   daddiu  $2,  $2, 24
# CHECK-NEXT:    20008:   24 42 80 40   addiu   $2,  $2, -32704
# CHECK-NEXT:    2000c:   24 42 80 30   addiu   $2,  $2, -32720
# CHECK-NEXT:    20010:   24 42 80 38   addiu   $2,  $2, -32712

# CHECK: 0000000000020018   .text   00000000 foo
# CHECK: 0000000000020000   .text   00000000 __start
# CHECK: 0000000000020014   .text   00000000 bar

# GOT:      There are no relocations in this file.
# GOT-NEXT: Primary GOT:
# GOT-NEXT:  Canonical gp value: 0000000000038000
# GOT-EMPTY:
# GOT-NEXT:  Reserved entries:
# GOT-NEXT:            Address     Access          Initial Purpose
# GOT-NEXT:   0000000000030010 -32752(gp) 0000000000000000 Lazy resolver
# GOT-NEXT:   0000000000030018 -32744(gp) 8000000000000000 Module pointer (GNU extension)
# GOT-EMPTY:
# GOT-NEXT:  Local entries:
# GOT-NEXT:            Address     Access          Initial
# GOT-NEXT:   0000000000030020 -32736(gp) 0000000000020000
# GOT-NEXT:   0000000000030028 -32728(gp) 0000000000030000
# GOT-NEXT:   0000000000030030 -32720(gp) 0000000000020014
# GOT-NEXT:   0000000000030038 -32712(gp) 0000000000020018
# GOT-EMPTY:
# GOT-NEXT:  Global entries:
# GOT-NEXT:            Address     Access          Initial         Sym.Val. Type Ndx Name
# GOT-NEXT:   0000000000030040 -32704(gp) 0000000000000000 0000000000000000 FUNC UND foo1a

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

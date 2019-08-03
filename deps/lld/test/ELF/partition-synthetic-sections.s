// Test that synthetic sections are created correctly for each partition.

// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/verneed1.s -o %t1.o
// RUN: echo "v1 {}; v2 {}; v3 { local: *; };" > %t1.script
// RUN: ld.lld -shared %t1.o --version-script %t1.script -o %t1.so -soname verneed1.so.0

// RUN: llvm-mc %s -o %t.o -filetype=obj --triple=x86_64-unknown-linux
// RUN: echo "x1 { global: p0; }; x2 { global: p1; p1alias; };" > %t.script
// RUN: ld.lld %t.o %t1.so --version-script %t.script -o %t --shared --gc-sections --eh-frame-hdr -soname main.so

// RUN: llvm-objcopy --extract-main-partition %t %t0
// RUN: llvm-objcopy --extract-partition=part1 %t %t1

// RUN: llvm-readelf --all --unwind %t0 | FileCheck --check-prefixes=CHECK,PART0 %s
// RUN: llvm-readelf --all --unwind %t1 | FileCheck --check-prefixes=CHECK,PART1 %s

// FIXME: llvm-objcopy does not preserve padding (see pr42145) so for now we
// check the combined output file.
// RUN: od -Ax -x %t | FileCheck %s -check-prefix=FILL

// RUN: llvm-objdump -s -j .rodata -j .dynstr %t0 | FileCheck --check-prefix=PART-INDEX %s

// CHECK: Section Headers:
// CHECK-NEXT: Name
// CHECK-NEXT: NULL
// CHECK-NEXT: .dynsym           DYNSYM          {{0*}}[[DYNSYM_ADDR:[^ ]*]]
// CHECK-NEXT: .gnu.version      VERSYM          {{0*}}[[VERSYM_ADDR:[^ ]*]]
// CHECK-NEXT: .gnu.version_d    VERDEF          {{0*}}[[VERDEF_ADDR:[^ ]*]]
// CHECK-NEXT: .gnu.version_r    VERNEED         {{0*}}[[VERNEED_ADDR:[^ ]*]]
// CHECK-NEXT: .gnu.hash         GNU_HASH        {{0*}}[[GNU_HASH_ADDR:[^ ]*]]
// CHECK-NEXT: .hash             HASH            {{0*}}[[HASH_ADDR:[^ ]*]]
// CHECK-NEXT: .dynstr           STRTAB          {{0*}}[[DYNSTR_ADDR:[^ ]*]]
// CHECK-NEXT: .rela.dyn         RELA            {{0*}}[[RELA_DYN_ADDR:[^ ]*]]
// PART0-NEXT: .rela.plt         RELA            {{0*}}[[RELA_PLT_ADDR:[^ ]*]]
// CHECK-NEXT: .eh_frame_hdr     PROGBITS        {{0*}}[[EH_FRAME_HDR_ADDR:[^ ]*]]
// CHECK-NEXT: .eh_frame         PROGBITS        {{0*}}[[EH_FRAME_ADDR:[^ ]*]]
// PART0-NEXT: .rodata           PROGBITS
// CHECK-NEXT: .text             PROGBITS        {{0*}}[[TEXT_ADDR:[^ ]*]]
// PART0-NEXT: .plt              PROGBITS
// PART0-NEXT: .init_array       INIT_ARRAY      {{0*}}[[INIT_ARRAY_ADDR:[^ ]*]]
// CHECK-NEXT: .dynamic          DYNAMIC         {{0*}}[[DYNAMIC_ADDR:[^ ]*]]
// CHECK-NEXT: .data             PROGBITS        000000000000[[DATA_SEGMENT:.]]000
// PART0-NEXT: .got.plt          PROGBITS        {{0*}}[[GOT_PLT_ADDR:[^ ]*]]
// PART0-NEXT: .part.end         NOBITS          {{0*}}[[PART_END_ADDR:[^ ]*]]
// CHECK-NEXT: .comment          PROGBITS
// CHECK-NEXT: .symtab           SYMTAB
// CHECK-NEXT: .shstrtab         STRTAB
// CHECK-NEXT: .strtab           STRTAB
// CHECK-NEXT: Key to Flags

// CHECK: Relocation section '.rela.dyn'
// CHECK-NEXT: Offset
// PART0-NEXT: 000000000000[[DATA_SEGMENT]]000 {{.*}} R_X86_64_64 {{.*}} f1@v3 + 0
// PART0-NEXT: {{0*}}[[INIT_ARRAY_ADDR]]       {{.*}} R_X86_64_64 {{.*}} p0@@x1 + 0
// PART1-NEXT: 000000000000[[DATA_SEGMENT]]018 {{.*}} R_X86_64_RELATIVE 3000
// PART1-NEXT: 000000000000[[DATA_SEGMENT]]000 {{.*}} R_X86_64_64 {{.*}} f2@v2 + 0
// PART1-NEXT: 000000000000[[DATA_SEGMENT]]008 {{.*}} R_X86_64_64 {{.*}} p0@@x1 + 0
// PART1-NEXT: 000000000000[[DATA_SEGMENT]]010 {{.*}} R_X86_64_64 {{.*}} p0@@x1 + 0
// CHECK-EMPTY:

// PART0: Relocation section '.rela.plt'
// PART0-NEXT: Offset
// PART0-NEXT: 000000000000[[DATA_SEGMENT]]020 {{.*}} R_X86_64_JUMP_SLOT {{.*}} f1@v3 + 0
// PART0-NEXT: 000000000000[[DATA_SEGMENT]]028 {{.*}} R_X86_64_JUMP_SLOT {{.*}} f2@v2 + 0
// PART0-EMPTY:

// CHECK: Symbol table '.dynsym'
// PART0: 1: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND f1@v3
// PART0: 2: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND f2@v2
// PART0: 3: {{0*}}[[TEXT_ADDR]]  0 NOTYPE  GLOBAL DEFAULT {{.*}} p0@@x1
// PART1: 1: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND f2@v2
// PART1: 2: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND p0@@x1
// PART1: 3: {{0*}}[[TEXT_ADDR]]  0 NOTYPE  GLOBAL DEFAULT {{.*}} p1@@x2
// PART1: 4: {{0*}}[[TEXT_ADDR]]  0 NOTYPE  GLOBAL DEFAULT {{.*}} p1alias@@x2
// CHECK-EMPTY:

// PART0: Symbol table '.symtab'
// PART0: 000000000000048c     0 NOTYPE  LOCAL  HIDDEN    {{.*}} __part_index_begin
// PART0: 0000000000000498     0 NOTYPE  LOCAL  HIDDEN    {{.*}} __part_index_end

// PART-INDEX: Contents of section .dynstr:
// PART-INDEX-NEXT: 03a8 00663100 66320070 30007061 72743100  .f1.f2.p0.part1.
// PART-INDEX: Contents of section .rodata:
//                       0x48c + 0xffffff26 = 0x3b2
//                                0x490 + 0x3b70 = 0x4000
// PART-INDEX-NEXT: 048c 26ffffff 703b0000 00400000

// CHECK: {{.*}}EH_FRAME Header
// CHECK: Address: 0x[[EH_FRAME_HDR_ADDR]]
// CHECK: eh_frame_ptr: 0x[[EH_FRAME_ADDR]]
// CHECK: initial_location: 0x[[TEXT_ADDR]]
// CHECK: address: 0x[[FDE_ADDR:.*]]

// CHECK: .eh_frame section
// CHECK: 0x[[EH_FRAME_ADDR]]] CIE length=20
// CHECK-NOT: FDE
// CHECK: 0x[[FDE_ADDR]]] FDE length=20 cie={{.}}0x[[EH_FRAME_ADDR]]
// CHECK-NEXT: initial_location: 0x[[TEXT_ADDR]]
// CHECK-NOT: FDE
// CHECK: CIE length=0

// CHECK: Dynamic section
// CHECK-NEXT: Tag
// CHECK-NEXT: 0x0000000000000001 (NEEDED)             Shared library: [verneed1.so.0]
// PART0-NEXT: 0x000000000000000e (SONAME)             Library soname: [main.so]
// PART1-NEXT: 0x0000000000000001 (NEEDED)             Shared library: [main.so]
// PART1-NEXT: 0x000000000000000e (SONAME)             Library soname: [part1]
// CHECK-NEXT: 0x0000000000000007 (RELA)               0x[[RELA_DYN_ADDR]]
// CHECK-NEXT: 0x0000000000000008 (RELASZ)
// CHECK-NEXT: 0x0000000000000009 (RELAENT)            24 (bytes)
// PART1-NEXT: 0x000000006ffffff9 (RELACOUNT)          1
// PART0-NEXT: 0x0000000000000017 (JMPREL)             0x[[RELA_PLT_ADDR]]
// PART0-NEXT: 0x0000000000000002 (PLTRELSZ)           48 (bytes)
// PART0-NEXT: 0x0000000000000003 (PLTGOT)             0x[[GOT_PLT_ADDR]]
// PART0-NEXT: 0x0000000000000014 (PLTREL)             RELA
// CHECK-NEXT: 0x0000000000000006 (SYMTAB)             0x[[DYNSYM_ADDR]]
// CHECK-NEXT: 0x000000000000000b (SYMENT)             24 (bytes)
// CHECK-NEXT: 0x0000000000000005 (STRTAB)             0x[[DYNSTR_ADDR]]
// CHECK-NEXT: 0x000000000000000a (STRSZ)
// CHECK-NEXT: 0x000000006ffffef5 (GNU_HASH)           0x[[GNU_HASH_ADDR]]
// CHECK-NEXT: 0x0000000000000004 (HASH)               0x[[HASH_ADDR]]
// PART0-NEXT: 0x0000000000000019 (INIT_ARRAY)         0x[[INIT_ARRAY_ADDR]]
// PART0-NEXT: 0x000000000000001b (INIT_ARRAYSZ)       8 (bytes)
// CHECK-NEXT: 0x000000006ffffff0 (VERSYM)             0x[[VERSYM_ADDR]]
// CHECK-NEXT: 0x000000006ffffffc (VERDEF)             0x[[VERDEF_ADDR]]
// CHECK-NEXT: 0x000000006ffffffd (VERDEFNUM)          3
// CHECK-NEXT: 0x000000006ffffffe (VERNEED)            0x[[VERNEED_ADDR]]
// CHECK-NEXT: 0x000000006fffffff (VERNEEDNUM)         1
// PART0-NEXT: 0x0000000000000000 (NULL)               0x0

// CHECK: Program Headers:
// CHECK-NEXT: Type
// PART0-NEXT: PHDR           {{.*}} 0x000230 0x000230 R
// PART1-NEXT: PHDR           {{.*}} 0x0001f8 0x0001f8 R
// PART0-NEXT: LOAD           0x000000 0x0000000000000000 0x0000000000000000 {{.*}} R   0x1000
// PART0-NEXT: LOAD           0x001000 0x0000000000001000 0x0000000000001000 {{.*}} R E 0x1000
// PART0-NEXT: LOAD           0x002000 0x0000000000002000 0x0000000000002000 {{.*}} RW  0x1000
// PART0-NEXT: LOAD           0x003000 0x0000000000003000 0x0000000000003000 {{.*}} RW  0x1000
// PART0-NEXT: LOAD           0x004000 0x0000000000008000 0x0000000000008000 0x000000 0x001000 RW  0x1000
// PART1-NEXT: LOAD           0x000000 0x0000000000004000 0x0000000000004000 {{.*}} R   0x1000
// PART1-NEXT: LOAD           0x001000 0x0000000000005000 0x0000000000005000 {{.*}} R E 0x1000
// PART1-NEXT: LOAD           0x002000 0x0000000000006000 0x0000000000006000 {{.*}} RW  0x1000
// PART1-NEXT: LOAD           0x003000 0x0000000000007000 0x0000000000007000 {{.*}} RW  0x1000
// CHECK-NEXT: DYNAMIC        {{.*}} 0x{{0*}}[[DYNAMIC_ADDR]] 0x{{0*}}[[DYNAMIC_ADDR]] {{.*}} RW  0x8
// PART0-NEXT: GNU_RELRO      0x002000 0x0000000000002000 0x0000000000002000 {{.*}} R   0x1
// PART1-NEXT: GNU_RELRO      0x002000 0x0000000000006000 0x0000000000006000 {{.*}} R   0x1
// CHECK-NEXT: GNU_EH_FRAME   {{.*}} 0x{{0*}}[[EH_FRAME_HDR_ADDR]] 0x{{0*}}[[EH_FRAME_HDR_ADDR]] {{.*}} R   0x4
// CHECK-NEXT: GNU_STACK      0x000000 0x0000000000000000 0x0000000000000000 0x000000 0x000000 RW  0x0
// CHECK-EMPTY:

// CHECK: Version symbols section '.gnu.version'
// CHECK-NEXT: Addr:
// PART0-NEXT: 000:   0 (*local*)       4 (v3)            5 (v2)            2 (x1)
// PART1-NEXT: 000:   0 (*local*)       5 (v2)            2 (x1)            3 (x2)

// CHECK: Version definition section '.gnu.version_d'
// CHECK-NEXT: Addr:
// PART0-NEXT: 0x0000: Rev: 1  Flags: BASE  Index: 1  Cnt: 1  Name: main.so
// PART1-NEXT: 0x0000: Rev: 1  Flags: BASE  Index: 1  Cnt: 1  Name: part1
// CHECK-NEXT: 0x001c: Rev: 1  Flags: none  Index: 2  Cnt: 1  Name: x1
// CHECK-NEXT: 0x0038: Rev: 1  Flags: none  Index: 3  Cnt: 1  Name: x2

// CHECK: Version needs section '.gnu.version_r'
// CHECK-NEXT: Addr:
// CHECK-NEXT: 0x0000: Version: 1  File: verneed1.so.0  Cnt: 2
// CHECK-NEXT: 0x0010:   Name: v2  Flags: none  Version: 5
// CHECK-NEXT: 0x0020:   Name: v3  Flags: none  Version: 4

// PART0: Histogram for bucket list length (total of 4 buckets)
// PART0-NEXT:  Length  Number     % of total  Coverage
// PART0-NEXT:       0  1          ( 25.0%)       0.0%
// PART0-NEXT:       1  3          ( 75.0%)     100.0%
// PART0-NEXT: Histogram for `.gnu.hash' bucket list length (total of 1 buckets)
// PART0-NEXT:  Length  Number     % of total  Coverage
// PART0-NEXT:       0  0          (  0.0%)       0.0%
// PART0-NEXT:       1  1          (100.0%)     100.0%

// PART1: Histogram for bucket list length (total of 5 buckets)
// PART1-NEXT:  Length  Number     % of total  Coverage
// PART1-NEXT:       0  3          ( 60.0%)       0.0%
// PART1-NEXT:       1  2          ( 40.0%)     100.0%
// PART1-NEXT: Histogram for `.gnu.hash' bucket list length (total of 1 buckets)
// PART1-NEXT:  Length  Number     % of total  Coverage
// PART1-NEXT:       0  0          (  0.0%)       0.0%
// PART1-NEXT:       1  0          (  0.0%)       0.0%
// PART1-NEXT:       2  1          (100.0%)     100.0%

// FILL: 001040 cccc cccc cccc cccc cccc cccc cccc cccc
// FILL-NEXT: *
// FILL-NEXT: 002000

// FILL: 005010 cccc cccc cccc cccc cccc cccc cccc cccc
// FILL-NEXT: *
// FILL-NEXT: 006000

.section .llvm_sympart,"",@llvm_sympart
.asciz "part1"
.quad p1

.section .llvm_sympart2,"",@llvm_sympart
.asciz "part1"
.quad p1alias

.section .text.p0,"ax",@progbits
.globl p0
p0:
.cfi_startproc
lea d0(%rip), %rax
call f1
ret
.cfi_endproc

.section .data.d0,"aw",@progbits
d0:
.quad f1

.section .text.p1,"ax",@progbits
.globl p1
p1:
.globl p1alias
p1alias:
.cfi_startproc
lea d1(%rip), %rax
call f2
ret
.cfi_endproc

.section .data.d1,"aw",@progbits
d1:
.quad f2
.quad p0
.quad p0
.quad d0

.section .init_array,"aw",@init_array
.quad p0

.globl __part_index_begin
.globl __part_index_end

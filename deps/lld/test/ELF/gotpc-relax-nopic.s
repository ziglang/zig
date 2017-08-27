# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -relax-relocations -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t1
# RUN: llvm-readobj -symbols -r %t1 | FileCheck --check-prefix=SYMRELOC %s
# RUN: llvm-objdump -d %t1 | FileCheck --check-prefix=DISASM %s

## There is no relocations.
# SYMRELOC:      Relocations [
# SYMRELOC-NEXT: ]
# SYMRELOC:      Symbols [
# SYMRELOC:       Symbol {
# SYMRELOC:        Name: bar
# SYMRELOC-NEXT:   Value: 0x202000

## 2105344 = 0x202000 (bar)
# DISASM:      Disassembly of section .text:
# DISASM-NEXT: _start:
# DISASM-NEXT:   201000: {{.*}} adcq  $2105344, %rax
# DISASM-NEXT:   201007: {{.*}} addq  $2105344, %rbx
# DISASM-NEXT:   20100e: {{.*}} andq  $2105344, %rcx
# DISASM-NEXT:   201015: {{.*}} cmpq  $2105344, %rdx
# DISASM-NEXT:   20101c: {{.*}} orq   $2105344, %rdi
# DISASM-NEXT:   201023: {{.*}} sbbq  $2105344, %rsi
# DISASM-NEXT:   20102a: {{.*}} subq  $2105344, %rbp
# DISASM-NEXT:   201031: {{.*}} xorq  $2105344, %r8
# DISASM-NEXT:   201038: {{.*}} testq $2105344, %r15

# RUN: ld.lld -shared %t.o -o %t2
# RUN: llvm-readobj -s -r -d %t2 | FileCheck --check-prefix=SEC-PIC    %s
# RUN: llvm-objdump -d %t2 | FileCheck --check-prefix=DISASM-PIC %s
# SEC-PIC:      Section {
# SEC-PIC:        Index:
# SEC-PIC:        Name: .got
# SEC-PIC-NEXT:   Type: SHT_PROGBITS
# SEC-PIC-NEXT:   Flags [
# SEC-PIC-NEXT:     SHF_ALLOC
# SEC-PIC-NEXT:     SHF_WRITE
# SEC-PIC-NEXT:   ]
# SEC-PIC-NEXT:   Address: 0x30A0
# SEC-PIC-NEXT:   Offset: 0x30A0
# SEC-PIC-NEXT:   Size: 8
# SEC-PIC-NEXT:   Link:
# SEC-PIC-NEXT:   Info:
# SEC-PIC-NEXT:   AddressAlignment:
# SEC-PIC-NEXT:   EntrySize:
# SEC-PIC-NEXT: }
# SEC-PIC:      Relocations [
# SEC-PIC-NEXT:   Section ({{.*}}) .rela.dyn {
# SEC-PIC-NEXT:     0x30A0 R_X86_64_RELATIVE - 0x2000
# SEC-PIC-NEXT:   }
# SEC-PIC-NEXT: ]
# SEC-PIC:      0x000000006FFFFFF9 RELACOUNT            1

## Check that there was no relaxation performed. All values refer to got entry.
## Ex: 0x1000 + 4249 + 7 = 0x20A0
##     0x102a + 4207 + 7 = 0x20A0
# DISASM-PIC:      Disassembly of section .text:
# DISASM-PIC-NEXT: _start:
# DISASM-PIC-NEXT: 1000: {{.*}} adcq  8345(%rip), %rax
# DISASM-PIC-NEXT: 1007: {{.*}} addq  8338(%rip), %rbx
# DISASM-PIC-NEXT: 100e: {{.*}} andq  8331(%rip), %rcx
# DISASM-PIC-NEXT: 1015: {{.*}} cmpq  8324(%rip), %rdx
# DISASM-PIC-NEXT: 101c: {{.*}} orq   8317(%rip), %rdi
# DISASM-PIC-NEXT: 1023: {{.*}} sbbq  8310(%rip), %rsi
# DISASM-PIC-NEXT: 102a: {{.*}} subq  8303(%rip), %rbp
# DISASM-PIC-NEXT: 1031: {{.*}} xorq  8296(%rip), %r8
# DISASM-PIC-NEXT: 1038: {{.*}} testq 8289(%rip), %r15

.data
.type   bar, @object
bar:
 .byte   1
 .size   bar, .-bar

.text
.globl  _start
.type   _start, @function
_start:
  adcq    bar@GOTPCREL(%rip), %rax
  addq    bar@GOTPCREL(%rip), %rbx
  andq    bar@GOTPCREL(%rip), %rcx
  cmpq    bar@GOTPCREL(%rip), %rdx
  orq     bar@GOTPCREL(%rip), %rdi
  sbbq    bar@GOTPCREL(%rip), %rsi
  subq    bar@GOTPCREL(%rip), %rbp
  xorq    bar@GOTPCREL(%rip), %r8
  testq   %r15, bar@GOTPCREL(%rip)

# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc %s -o %t.o
# RUN: echo '.globl __tls_get_addr; __tls_get_addr:' | llvm-mc -filetype=obj -triple=powerpc - -o %tga.o

# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck --check-prefix=LD-REL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.so | FileCheck --check-prefix=LD %s

# RUN: ld.lld %t.o %tga.o -o %t
# RUN: llvm-readelf -r %t | FileCheck --check-prefix=NOREL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=LE %s

# LD-REL:      .rela.dyn {
# LD-REL-NEXT:   0x20078 R_PPC_DTPMOD32 - 0x0
# LD-REL-NEXT: }

## .got - _GLOBAL_OFFSET_TABLE_ = 0
# LD:      addi 3, 30, 0
# LD-NEXT: bl .+40
## a@dtprel = st_value(a)-0x8000 = 65540-0x8000 = 65536*1-32764
## b@dtprel = st_value(a)-0x8000 = 131080-0x8000 = 65536*2-32760
# LD-NEXT: addis 9, 3, 1
# LD-NEXT: addis 10, 3, 2
# LD-NEXT: addi 9, 9, -32764
# LD-NEXT: addi 10, 10, -32760
## small@dtprel = st_value(small)-0x8000 = 4-0x8000 = -32764
# LD-NEXT: addi 9, 3, -32764

## Check that b@got@tlsld does not allocate another GOT entry.
## It shares In.Got->TlsIndexOff allocated when processing a@got@tlsld.
## .got - _GLOBAL_OFFSET_TABLE_ = 0
# LD-NEXT: addi 3, 9, 0
# LD-NEXT: bl .+12
## b@dtprel = st_value(a)-0x8000 = 131080-0x8000 = 65536*2-32760
# LD-NEXT: addis 29, 3, 2
# LD-NEXT: addi 29, 29, -32760

## When producing an executable, the LD code sequence can be relaxed to LE.
## It is the same as GD->LE.
## tpoff(_TLS_MODULE_BASE_) = 0, tpoff(a) = -8, tpoff(b) = -4

# NOREL: no relocations

## Set r3 to r2+4096
# LE:      addis 3, 2, 0
# LE-NEXT: addi 3, 3, 4096
## a@tprel = 65540-0x7000 = 65536*1-32764
## b@tprel = 131080-0x7000 = 65536*2-32760
# LE-NEXT: addis 9, 3, 1
# LE-NEXT: addis 10, 3, 2
# LE-NEXT: addi 9, 9, -32764
# LE-NEXT: addi 10, 10, -32760
## small@tprel = 4-0x7000 = -32764
# LE-NEXT: addi 9, 3, -32764

## Set r3 to r2+4096
# LE-NEXT: addis 3, 2, 0
# LE-NEXT: addi 3, 3, 4096
## b@tprel = 131080-0x7000 = 65536*2-32760
# LE-NEXT: addis 29, 3, 2
# LE-NEXT: addi 29, 29, -32760

addi 3, 30, a@got@tlsld
bl __tls_get_addr(a@tlsld)
addis 9, 3, a@dtprel@ha
addis 10, 3, b@dtprel@ha
addi 9, 9, a@dtprel@l
addi 10, 10, b@dtprel@l
addi 9, 3, small@dtprel

addi 3, 9, b@got@tlsld
bl __tls_get_addr(b@tlsld)
addis 29, 3, b@dtprel@ha
addi 29, 29, b@dtprel@l

.section .tbss
.zero 4
small:
.zero 65536
a:
.zero 65540
b:

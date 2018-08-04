# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-objcopy %t1.o %t1copy.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/Inputs/icf-safe.s -o %t2.o
# RUN: ld.lld %t1.o %t2.o -o %t2 --icf=safe --print-icf-sections | FileCheck %s
# RUN: ld.lld %t1.o %t2.o -o %t3 --icf=safe --print-icf-sections -shared | FileCheck --check-prefix=EXPORT %s
# RUN: ld.lld %t1.o %t2.o -o %t3 --icf=safe --print-icf-sections --export-dynamic | FileCheck --check-prefix=EXPORT %s
# RUN: ld.lld %t1.o %t2.o -o %t2 --icf=all --print-icf-sections | FileCheck --check-prefix=ALL %s
# RUN: ld.lld %t1.o %t2.o -o %t2 --icf=all --print-icf-sections --export-dynamic | FileCheck --check-prefix=ALL-EXPORT %s
# RUN: ld.lld %t1copy.o -o %t4 --icf=safe 2>&1 | FileCheck --check-prefix=OBJCOPY %s

# CHECK-NOT: selected section {{.*}}:(.text.f1)
# CHECK: selected section {{.*}}:(.text.f3)
# CHECK:   removing identical section {{.*}}:(.text.f4)

# CHECK-NOT: selected section {{.*}}:(.rodata.h1)
# CHECK: selected section {{.*}}:(.rodata.h3)
# CHECK:   removing identical section {{.*}}:(.rodata.h4)

# CHECK-NOT: selected section {{.*}}:(.rodata.l1)
# CHECK: selected section {{.*}}:(.rodata.l3)
# CHECK:   removing identical section {{.*}}:(.rodata.l4)

# CHECK-NOT: selected section {{.*}}:(.rodata.g1)
# CHECK: selected section {{.*}}:(.rodata.g3)
# CHECK:   removing identical section {{.*}}:(.rodata.g4)

# CHECK-NOT: selected section {{.*}}:(.text.non_addrsig{{.}})

# With --icf=all address-significance implies keep-unique only for rodata, not
# text.
# ALL: selected section {{.*}}:(.text.f3)
# ALL:   removing identical section {{.*}}:(.text.f4)

# ALL-NOT: selected section {{.*}}:(.rodata.h1)
# ALL: selected section {{.*}}:(.rodata.h3)
# ALL:   removing identical section {{.*}}:(.rodata.h4)

# ALL-NOT: selected section {{.*}}:(.rodata.l1)
# ALL: selected section {{.*}}:(.rodata.l3)
# ALL:   removing identical section {{.*}}:(.rodata.l4)

# ALL-NOT: selected section {{.*}}:(.rodata.g1)
# ALL: selected section {{.*}}:(.rodata.g3)
# ALL:   removing identical section {{.*}}:(.rodata.g4)

# ALL: selected section {{.*}}:(.text.f1)
# ALL:   removing identical section {{.*}}:(.text.f2)
# ALL:   removing identical section {{.*}}:(.text.non_addrsig1)
# ALL:   removing identical section {{.*}}:(.text.non_addrsig2)

# llvm-mc normally emits an empty .text section into every object file. Since
# nothing actually refers to it via a relocation, it doesn't have any associated
# symbols (thus nor can anything refer to it via a relocation, making it safe to
# merge with the empty section in the other input file). Here we check that the
# only two sections merged are the two empty sections and the sections with only
# STB_LOCAL or STV_HIDDEN symbols. The dynsym entries should have prevented
# anything else from being merged.
# EXPORT-NOT: selected section
# EXPORT: selected section {{.*}}:(.rodata.h3)
# EXPORT:   removing identical section {{.*}}:(.rodata.h4)
# EXPORT-NOT: selected section
# EXPORT: selected section {{.*}}:(.text)
# EXPORT:   removing identical section {{.*}}:(.text)
# EXPORT-NOT: selected section
# EXPORT: selected section {{.*}}:(.rodata.l3)
# EXPORT:   removing identical section {{.*}}:(.rodata.l4)
# EXPORT-NOT: selected section

# If --icf=all is specified when exporting we can also merge the exported text
# sections, but not the exported rodata.
# ALL-EXPORT-NOT: selected section
# ALL-EXPORT: selected section {{.*}}:(.text.f3)
# ALL-EXPORT:   removing identical section {{.*}}:(.text.f4)
# ALL-EXPORT-NOT: selected section
# ALL-EXPORT: selected section {{.*}}:(.rodata.h3)
# ALL-EXPORT:   removing identical section {{.*}}:(.rodata.h4)
# ALL-EXPORT-NOT: selected section
# ALL-EXPORT: selected section {{.*}}:(.text)
# ALL-EXPORT:   removing identical section {{.*}}:(.text)
# ALL-EXPORT-NOT: selected section
# ALL-EXPORT: selected section {{.*}}:(.rodata.l3)
# ALL-EXPORT:   removing identical section {{.*}}:(.rodata.l4)
# ALL-EXPORT-NOT: selected section
# ALL-EXPORT: selected section {{.*}}:(.text.f1)
# ALL-EXPORT:   removing identical section {{.*}}:(.text.f2)
# ALL-EXPORT:   removing identical section {{.*}}:(.text.non_addrsig1)
# ALL-EXPORT:   removing identical section {{.*}}:(.text.non_addrsig2)
# ALL-EXPORT-NOT: selected section

# OBJCOPY: --icf=safe is incompatible with object files created using objcopy or ld -r

.section .text.f1,"ax",@progbits
.globl f1
f1:
ret

.section .text.f2,"ax",@progbits
.globl f2
f2:
ret

.section .text.f3,"ax",@progbits
.globl f3
f3:
ud2

.section .text.f4,"ax",@progbits
.globl f4
f4:
ud2

.section .rodata.g1,"a",@progbits
.globl g1
g1:
.byte 1

.section .rodata.g2,"a",@progbits
.globl g2
g2:
.byte 1

.section .rodata.g3,"a",@progbits
.globl g3
g3:
.byte 2

.section .rodata.g4,"a",@progbits
.globl g4
g4:
.byte 2

.section .rodata.l1,"a",@progbits
l1:
.byte 3

.section .rodata.l2,"a",@progbits
l2:
.byte 3

.section .rodata.l3,"a",@progbits
l3:
.byte 4

.section .rodata.l4,"a",@progbits
l4:
.byte 4

.section .rodata.h1,"a",@progbits
.globl h1
.hidden h1
h1:
.byte 5

.section .rodata.h2,"a",@progbits
.globl h2
.hidden h2
h2:
.byte 5

.section .rodata.h3,"a",@progbits
.globl h3
.hidden h3
h3:
.byte 6

.section .rodata.h4,"a",@progbits
.globl h4
.hidden h4
h4:
.byte 6

.addrsig
.addrsig_sym f1
.addrsig_sym f2
.addrsig_sym g1
.addrsig_sym g2
.addrsig_sym l1
.addrsig_sym l2
.addrsig_sym h1
.addrsig_sym h2

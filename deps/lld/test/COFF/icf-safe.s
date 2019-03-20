# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-win32 %s -o %t1.obj
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-win32 %S/Inputs/icf-safe.s -o %t2.obj
# RUN: lld-link /dll /noentry /out:%t.dll /verbose /opt:noref,icf %t1.obj %t2.obj 2>&1 | FileCheck %s
# RUN: lld-link /dll /noentry /out:%t.dll /verbose /opt:noref,icf /export:g3 /export:g4 %t1.obj %t2.obj 2>&1 | FileCheck --check-prefix=EXPORT %s

# CHECK-NOT: Selected
# CHECK: Selected g3
# CHECK-NEXT:   Removed g4
# CHECK-NOT: Removed
# CHECK-NOT: Selected

# EXPORT-NOT: Selected

.section .rdata,"dr",one_only,g1
.globl g1
g1:
.byte 1

.section .rdata,"dr",one_only,g2
.globl g2
g2:
.byte 1

.section .rdata,"dr",one_only,g3
.globl g3
g3:
.byte 2

.section .rdata,"dr",one_only,g4
.globl g4
g4:
.byte 2

.addrsig
.addrsig_sym g1
.addrsig_sym g2

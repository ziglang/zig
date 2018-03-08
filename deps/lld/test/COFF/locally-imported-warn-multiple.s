# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc -o %T/locally-imported-def.obj %S/Inputs/locally-imported-def.s
# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc -o %T/locally-imported-imp1.obj %S/Inputs/locally-imported-imp.s
# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc -o %T/locally-imported-imp2.obj %S/Inputs/locally-imported-imp.s
# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc -o %t.obj %s
# RUN: lld-link /entry:main %T/locally-imported-def.obj %T/locally-imported-imp1.obj %T/locally-imported-imp2.obj %t.obj 2>&1 | FileCheck %s

# CHECK: warning: [[TESTDIR:.+]]locally-imported-imp1.obj: locally defined symbol imported: f (defined in [[TESTDIR]]locally-imported-def.obj)
# CHECK-NEXT: warning: [[TESTDIR:.+]]locally-imported-imp2.obj: locally defined symbol imported: f (defined in [[TESTDIR]]locally-imported-def.obj)

.globl main
main:
	ret

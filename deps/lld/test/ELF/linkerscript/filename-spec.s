# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %tx.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %p/Inputs/filename-spec.s -o %ty.o

# RUN: echo "SECTIONS{.foo :{ KEEP(*x.o(.foo)) KEEP(*y.o(.foo)) }}" > %t1.script
# RUN: ld.lld -o %t1 --script %t1.script %tx.o %ty.o
# RUN: llvm-objdump -s %t1 | FileCheck --check-prefix=FIRSTY %s
# FIRSTY:      Contents of section .foo:
# FIRSTY-NEXT:   01000000 00000000 11000000 00000000

# RUN: echo "SECTIONS{.foo :{ KEEP(*y.o(.foo)) KEEP(*x.o(.foo)) }}" > %t2.script
# RUN: ld.lld -o %t2 --script %t2.script %tx.o %ty.o
# RUN: llvm-objdump -s %t2 | FileCheck --check-prefix=SECONDFIRST %s
# SECONDFIRST:      Contents of section .foo:
# SECONDFIRST-NEXT:   11000000 00000000 01000000 00000000

## Now the same tests but without KEEP. Checking that file name inside
## KEEP is parsed fine.
# RUN: echo "SECTIONS{.foo :{ *x.o(.foo) *y.o(.foo) }}" > %t3.script
# RUN: ld.lld -o %t3 --script %t3.script %tx.o %ty.o
# RUN: llvm-objdump -s %t3 | FileCheck --check-prefix=FIRSTY %s

# RUN: echo "SECTIONS{.foo :{ *y.o(.foo) *x.o(.foo) }}" > %t4.script
# RUN: ld.lld -o %t4 --script %t4.script %tx.o %ty.o
# RUN: llvm-objdump -s %t4 | FileCheck --check-prefix=SECONDFIRST %s

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %T/filename-spec1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %p/Inputs/filename-spec.s -o %T/filename-spec2.o

# RUN: echo "SECTIONS{.foo :{ %T/filename-spec2.o(.foo) %T/filename-spec1.o(.foo) }}" > %t5.script
# RUN: ld.lld -o %t5 --script %t5.script \
# RUN:   %T/filename-spec1.o %T/filename-spec2.o
# RUN: llvm-objdump -s %t5 | FileCheck --check-prefix=SECONDFIRST %s

# RUN: echo "SECTIONS{.foo :{ %T/filename-spec1.o(.foo) %T/filename-spec2.o(.foo) }}" > %t6.script
# RUN: ld.lld -o %t6 --script %t6.script \
# RUN:   %T/filename-spec1.o %T/filename-spec2.o
# RUN: llvm-objdump -s %t6 | FileCheck --check-prefix=FIRSTY %s

# RUN: mkdir -p %t.testdir1 %t.testdir2
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.testdir1/filename-spec1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %p/Inputs/filename-spec.s -o %t.testdir2/filename-spec2.o
# RUN: llvm-ar rsc %t.testdir1/lib1.a %t.testdir1/filename-spec1.o
# RUN: llvm-ar rsc %t.testdir2/lib2.a %t.testdir2/filename-spec2.o

# Verify matching of archive library names.
# RUN: echo "SECTIONS{.foo :{ *lib2*(.foo) *lib1*(.foo) }}" > %t7.script
# RUN: ld.lld -o %t7 --script %t7.script --whole-archive \
# RUN:   %t.testdir1/lib1.a %t.testdir2/lib2.a
# RUN: llvm-objdump -s %t7 | FileCheck --check-prefix=SECONDFIRST %s

# Verify matching directories.
# RUN: echo "SECTIONS{.foo :{  *testdir2*(.foo) *testdir1*(.foo) }}" > %t8.script
# RUN: ld.lld -o %t8 --script %t8.script --whole-archive \
# RUN:   %t.testdir1/lib1.a %t.testdir2/lib2.a
# RUN: llvm-objdump -s %t8 | FileCheck --check-prefix=SECONDFIRST %s

# Verify matching of archive library names in KEEP.
# RUN: echo "SECTIONS{.foo :{ KEEP(*lib2*(.foo)) KEEP(*lib1*(.foo)) }}" > %t9.script
# RUN: ld.lld -o %t9 --script %t9.script --whole-archive \
# RUN:   %t.testdir1/lib1.a %t.testdir2/lib2.a
# RUN: llvm-objdump -s %t9 | FileCheck --check-prefix=SECONDFIRST %s

# Verify matching directories in KEEP.
# RUN: echo "SECTIONS{.foo :{ KEEP(*testdir2*(.foo)) KEEP(*testdir1*(.foo)) }}" > %t10.script
# RUN: ld.lld -o %t10 --script %t10.script --whole-archive \
# RUN:   %t.testdir1/lib1.a %t.testdir2/lib2.a
# RUN: llvm-objdump -s %t10 | FileCheck --check-prefix=SECONDFIRST %s

.global _start
_start:
 nop

.section .foo,"a"
 .quad 1

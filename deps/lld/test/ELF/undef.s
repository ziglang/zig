# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/undef.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/undef-debug.s -o %t3.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/undef-bad-debug.s -o %t4.o
# RUN: rm -f %t2.a
# RUN: llvm-ar rc %t2.a %t2.o
# RUN: not ld.lld %t.o %t2.a %t3.o %t4.o -o %t.exe 2>&1 | FileCheck %s
# RUN: not ld.lld -pie %t.o %t2.a %t3.o %t4.o -o %t.exe 2>&1 | FileCheck %s

# CHECK: error: undefined symbol: foo
# CHECK: >>> referenced by undef.s
# CHECK:                   {{.*}}:(.text+0x1)

# CHECK: error: undefined symbol: bar
# CHECK: >>> referenced by undef.s
# CHECK: >>>               {{.*}}:(.text+0x6)

# CHECK: error: undefined symbol: foo(int)
# CHECK: >>> referenced by undef.s
# CHECK: >>>               {{.*}}:(.text+0x10)

# CHECK: error: undefined symbol: vtable for Foo
# CHECK: the vtable symbol may be undefined because the class is missing its key function (see https://lld.llvm.org/missingkeyfunction)

# CHECK: error: undefined symbol: zed2
# CHECK: >>> referenced by {{.*}}.o:(.text+0x0) in archive {{.*}}2.a

# CHECK: error: undefined symbol: zed3
# CHECK: >>> referenced by undef-debug.s:3 (dir{{/|\\}}undef-debug.s:3)
# CHECK: >>>               {{.*}}.o:(.text+0x0)

# CHECK: error: undefined symbol: zed4
# CHECK: >>> referenced by undef-debug.s:7 (dir{{/|\\}}undef-debug.s:7)
# CHECK: >>>               {{.*}}.o:(.text.1+0x0)

# CHECK: error: undefined symbol: zed5
# CHECK: >>> referenced by undef-debug.s:11 (dir{{/|\\}}undef-debug.s:11)
# CHECK: >>>               {{.*}}.o:(.text.2+0x0)

# Show that all line table problems are mentioned as soon as the object's line information
# is requested, even if that particular part of the line information is not currently required.
# CHECK: warning: parsing line table prologue at 0x00000000 should have ended at 0x00000038 but it ended at 0x00000037
# CHECK: warning: last sequence in debug line table is not terminated!
# CHECK: error: undefined symbol: zed6
# CHECK: >>> referenced by {{.*}}tmp4.o:(.text+0x0)

# Show that a problem with one line table's information doesn't affect getting information from
# a different one in the same object.
# CHECK: error: undefined symbol: zed7
# CHECK: >>> referenced by undef-bad-debug2.s:11 (dir2{{/|\\}}undef-bad-debug2.s:11)
# CHECK: >>>               {{.*}}tmp4.o:(.text+0x8)

# RUN: not ld.lld %t.o %t2.a -o %t.exe -no-demangle 2>&1 | \
# RUN:   FileCheck -check-prefix=NO-DEMANGLE %s
# NO-DEMANGLE: error: undefined symbol: _Z3fooi

.file "undef.s"

  .globl _start
_start:
  call foo
  call bar
  call zed1
  call _Z3fooi
  call _ZTV3Foo

// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
// RUN:   %p/Inputs/exclude-libs.s -o %t2.o
// RUN: mkdir -p %t.dir
// RUN: rm -f %t.dir/exc.a
// RUN: llvm-ar rcs %t.dir/exc.a %t2.o

// RUN: ld.lld -shared %t.o %t.dir/exc.a -o %t.exe
// RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck --check-prefix=DEFAULT %s

// RUN: ld.lld -shared %t.o %t.dir/exc.a -o %t.exe --exclude-libs=foo,bar
// RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck --check-prefix=DEFAULT %s

// RUN: ld.lld -shared %t.o %t.dir/exc.a -o %t.exe --exclude-libs foo,bar,exc.a
// RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck --check-prefix=EXCLUDE %s

// RUN: ld.lld -shared %t.o %t.dir/exc.a -o %t.exe --exclude-libs foo:bar:exc.a
// RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck --check-prefix=EXCLUDE %s

// RUN: ld.lld -shared %t.o %t.dir/exc.a -o %t.exe --exclude-libs=ALL
// RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck --check-prefix=EXCLUDE %s

// DEFAULT: Name: fn
// EXCLUDE-NOT: Name: fn

.globl fn
foo:
  call fn@PLT

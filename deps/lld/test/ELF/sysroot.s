// REQUIRES: x86
// RUN: mkdir -p %t/lib
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t/m.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
// RUN:     %p/Inputs/libsearch-st.s -o %t/st.o
// RUN: rm -f %t/lib/libls.a
// RUN: llvm-ar rcs %t/lib/libls.a %t/st.o

// Should not link because of undefined symbol _bar
// RUN: not ld.lld -o %t/r %t/m.o 2>&1 \
// RUN:     | FileCheck --check-prefix=UNDEFINED %s
// UNDEFINED: error: undefined symbol: _bar
// UNDEFINED: >>> referenced by {{.*}}:(.text+0x1)

// We need to be sure that there is no suitable library in the /lib directory
// RUN: not ld.lld -o %t/r %t/m.o -L/lib -l:libls.a 2>&1 \
// RUN:     | FileCheck --check-prefix=NOLIB %s
// NOLIB: unable to find library -l:libls.a

// Should just remove the '=' symbol if --sysroot is not specified.
// Case 1: relative path
// RUN: cd %t && ld.lld -o %t/r %t/m.o -L=lib -l:libls.a
// Case 2: absolute path
// RUN: cd %p && ld.lld -o %t/r %t/m.o -L=%t/lib -l:libls.a

// RUN: cd %p

// Should substitute SysRoot if specified
// RUN: ld.lld -o %t/r %t/m.o --sysroot=%t -L=lib -l:libls.a
// RUN: ld.lld -o %t/r %t/m.o --sysroot=%t -L=/lib -l:libls.a
// Check alias.
// RUN: ld.lld -o %t/r %t/m.o --sysroot %t -L=lib -l:libls.a

// Should not substitute SysRoot if the directory name does not start with '='
// RUN: not ld.lld -o %t/r %r/m.o --sysroot=%t -Llib -l:libls.a
// RUN: not ld.lld -o %t/r %r/m.o --sysroot=%t -L/lib -l:libls.a

.globl _start,_bar
_start:
  call _bar

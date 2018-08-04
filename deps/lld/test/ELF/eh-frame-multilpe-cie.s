// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld --eh-frame-hdr %t.o -o /dev/null -shared
// We would fail to parse multiple cies in the same file.

        .cfi_startproc
        .cfi_personality 0x9b, foo
        .cfi_endproc

        .cfi_startproc
        .cfi_endproc

foo:

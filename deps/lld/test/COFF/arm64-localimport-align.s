// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-windows %s -o %t.obj
// RUN: lld-link -entry:main -subsystem:console %t.obj -out:%t.exe
// Don't check the output, just make sure it links fine and doesn't
// error out due to a misaligned load.
    .text
    .globl main
    .globl myfunc
main:
    adrp x8, __imp_myfunc
    ldr  x0, [x8, :lo12:__imp_myfunc]
    br   x0
    ret
myfunc:
    ret

    .section .rdata, "dr"
    // Start the .rdata section with a 4 byte chunk, to expose the alignment
    // of the next chunk in the section.
mydata:
    .byte 42
    // The synthesized LocalImportChunk gets stored here in the .rdata
    // section, but needs to get proper 8 byte alignment since it is a
    // pointer, just like regular LookupChunks in the IAT.

// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-windows %s -o %t.obj
// RUN: lld-link -entry:main -subsystem:console %t.obj -out:%t.exe -verbose 2>&1 | FileCheck -check-prefix=VERBOSE %s
// RUN: llvm-objdump -d %t.exe | FileCheck -check-prefix=DISASM %s

// VERBOSE: Added 1 thunks with margin {{.*}} in 1 passes

    .globl main
    .globl func1
    .text
main:
    tbz w0, #0, func1
    ret
    .section .text$a, "xr"
    .space 0x8000
    .section .text$b, "xr"
func1:
    ret

// DISASM: 0000000140001000 .text:
// DISASM: 140001000:      40 00 00 36     tbz     w0, #0, #8 <.text+0x8>
// DISASM: 140001004:      c0 03 5f d6     ret
// DISASM: 140001008:      50 00 00 90     adrp    x16, #32768
// DISASM: 14000100c:      10 52 00 91     add     x16, x16, #20
// DISASM: 140001010:      00 02 1f d6     br      x16

// DISASM: 140009014:      c0 03 5f d6     ret

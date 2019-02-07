// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=thumbv7-windows %s -o %t.obj
// RUN: lld-link -entry:main -subsystem:console %t.obj -out:%t.exe -verbose 2>&1 | FileCheck -check-prefix=VERBOSE %s
// RUN: llvm-objdump -d %t.exe -start-address=0x401000 -stop-address=0x401022 | FileCheck -check-prefix=MAIN %s
// RUN: llvm-objdump -d %t.exe -start-address=0x501022 -stop-address=0x501032 | FileCheck -check-prefix=FUNC1 %s
// RUN: llvm-objdump -d %t.exe -start-address=0x601032 | FileCheck -check-prefix=FUNC2 %s

// VERBOSE: Added 3 thunks with margin {{.*}} in 1 passes

    .syntax unified
    .globl main
    .globl func1
    .text
main:
    bne func1
    bne func2
    // This should reuse the same thunk as func1 above
    bne func1_alias
    bx lr
    .section .text$a, "xr"
    .space 0x100000
    .section .text$b, "xr"
func1:
func1_alias:
    // This shouldn't reuse the func2 thunk from above, since it is out
    // of range.
    bne func2
    bx lr
    .section .text$c, "xr"
    .space 0x100000
    .section .text$d, "xr"
func2:
// Test using string tail merging. This is irrelevant to the thunking itself,
// but running multiple passes of assignAddresses() calls finalizeAddresses()
// multiple times; check that MergeChunk handles this correctly.
    movw r0, :lower16:"??_C@string1"
    movt r0, :upper16:"??_C@string1"
    movw r1, :lower16:"??_C@string2"
    movt r1, :upper16:"??_C@string2"
    bx lr

    .section .rdata,"dr",discard,"??_C@string1"
    .globl "??_C@string1"
"??_C@string1":
    .asciz "foobar"
    .section .rdata,"dr",discard,"??_C@string2"
    .globl "??_C@string2"
"??_C@string2":
    .asciz "bar"

// MAIN:    401000:       40 f0 05 80     bne.w   #10 <.text+0xe>
// MAIN:    401004:       40 f0 08 80     bne.w   #16 <.text+0x18>
// MAIN:    401008:       40 f0 01 80     bne.w   #2 <.text+0xe>
// MAIN:    40100c:       70 47           bx      lr
// func1 thunk
// MAIN:    40100e:       40 f2 08 0c     movw    r12, #8
// MAIN:    401012:       c0 f2 10 0c     movt    r12, #16
// MAIN:    401016:       e7 44           add     pc,  r12
// func2 thunk
// MAIN:    401018:       40 f2 0e 0c     movw    r12, #14
// MAIN:    40101c:       c0 f2 20 0c     movt    r12, #32
// MAIN:    401020:       e7 44           add     pc,  r12

// FUNC1:   501022:       40 f0 01 80     bne.w   #2 <.text+0x100028>
// FUNC1:   501026:       70 47           bx      lr
// func2 thunk
// FUNC1:   501028:       4f f6 fe 7c     movw    r12, #65534
// FUNC1:   50102c:       c0 f2 0f 0c     movt    r12, #15
// FUNC1:   501030:       e7 44           add     pc,  r12

// FUNC2:   601032:       42 f2 00 00     movw    r0, #8192
// FUNC2:   601036:       c0 f2 60 00     movt    r0, #96
// FUNC2:   60103a:       42 f2 03 01     movw    r1, #8195
// FUNC2:   60103e:       c0 f2 60 01     movt    r1, #96
// FUNC2:   601042:       70 47   bx      lr

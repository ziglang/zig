; REQUIRES: msp430
; RUN: llvm-mc -filetype=obj -triple=msp430-elf -o %t1.o %s
; RUN: echo -e '.global _start\n _start: nop' | llvm-mc -filetype=obj -triple=msp430-elf -o %t2.o -
; RUN: ld.lld -o %t.exe --Tdata=0x2000 --Ttext=0x8000 --defsym=_byte=0x21 %t2.o %t1.o
; RUN: llvm-objdump -s -d %t.exe | FileCheck %s

;; Check handling of basic msp430 relocation types.

  .text
  .global foo
foo:
;; R_MSP430_10_PCREL
  jmp _start

; CHECK:      Disassembly of section .text:
; CHECK-NEXT: _start:
; CHECK-NEXT: 8000: {{.*}} nop
; CHECK:      foo:
; CHECK-NEXT: 8004: {{.*}} jmp $-4

;; R_MSP430_16_BYTE
  call #_start

; CHECK:      call #32768

;; R_MSP430_16_PCREL_BYTE
  mov #-1, _start

; CHECK:      800a: {{.*}} mov #-1, -12

  .data
;; R_MSP430_8
  .byte _byte
;; R_MSP430_16
  .word _start
;; R_MSP430_32
  .long _start

; CHECK:      Contents of section .data:
; CHECK-NEXT: 2000 21008000 800000

; RUN: od -x %t.exe | FileCheck -check-prefix=TRAP %s
; TRAP: 4343 4343 4343 4343 4343 4343 4343 4343

// Functions that will generate a .ARM.exidx section with SHF_LINK_ORDER
// dependency on the progbits section containing the .cantunwind directive
 .syntax unified
 .section .func1, "ax",%progbits
 .globl func1
func1:
 .fnstart
 bx lr
 .cantunwind
 .fnend

 .section .func2, "ax", %progbits
 .globl func2
func2:
 .fnstart
 bx lr
 .cantunwind
 .fnend

 .section .func3, "ax",%progbits
 .globl func3
func3:
 .fnstart
 bx lr
 .cantunwind
 .fnend

 .section .text, "ax",%progbits
 .globl func4
func4:
 .fnstart
 bx lr
 .cantunwind
 .fnend
 .globl func5
func5:
 .fnstart
 bx lr
 .cantunwind
 .fnend

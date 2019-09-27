        .text
        .globl myfunc
        .globl func1
        .type func1, %function
func1:
        adrp x8, :got: myfunc
        ldr x8, [x8, :got_lo12: myfunc]
        ret

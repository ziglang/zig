        .section        .mysec,"aM",@progbits,4
        .align  4
        .long   0x42

        .text
        movl .mysec, %eax

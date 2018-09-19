        .section .rodata,"a"
        .global foo
        .protected foo
        .type foo, @object
        .size foo, 8
foo:
        .quad 42

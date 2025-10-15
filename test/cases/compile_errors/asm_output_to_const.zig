export fn foo() void {
    const f: i64 = 1000;

    asm volatile (
        \\ movq $10, %[f]
        : [f] "=r" (f),
    );
}

// error
//
// :6:21: error: asm cannot output to const local 'f'

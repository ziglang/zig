export fn foo() void {
    const f: i64 = 1000;

    asm volatile (
        \\ movq $10, %[f]
        : [f] "=r" (f),
    );
}

// error
// backend=llvm
// target=native
//
// :4:5: error: asm cannot output to const local 'f'

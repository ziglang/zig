export fn foo() void {
    const local: usize = 0;
    asm volatile (""
        : [_] "=r" (local),
    );
}

const global: usize = 0;
export fn bar() void {
    asm volatile (""
        : [_] "=r" (global),
    );
}

// error
//
// :4:21: error: asm cannot output to const '_'
// :11:21: error: asm cannot output to const '_'

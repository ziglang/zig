comptime {
    doSomeAsm();
}

fn doSomeAsm() void {
    asm volatile (
        \\.globl aoeu;
        \\.type aoeu, @function;
        \\.set aoeu, derp;
    );
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:5: error: unable to evaluate constant expression

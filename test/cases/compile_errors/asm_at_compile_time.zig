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
// backend=llvm
// target=native
//
// :6:5: error: unable to resolve comptime value
// :2:14: note: called from here

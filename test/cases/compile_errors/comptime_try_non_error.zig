comptime {
    foo();
}

fn foo() void {
    try bar();
}

pub fn bar() u8 {
    return 0;
}

// error
// backend=stage2
// target=native
//
// :6:12: error: expected error union type, found 'u8'
// :6:12: note: consider omitting 'try'
// :2:8: note: called from here

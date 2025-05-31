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
//
// :6:12: error: expected error union type, found 'u8'
// :2:8: note: called at comptime here

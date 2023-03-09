export fn foo() void {
    try bar();
}

pub fn bar() u8 {
    return 0;
}

// error
// backend=stage2
// target=native
//
// :2:12: error: expected error union type, found 'u8'

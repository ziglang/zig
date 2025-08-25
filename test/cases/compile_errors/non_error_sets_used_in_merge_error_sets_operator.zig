export fn foo() void {
    const Errors = u8 || u16;
    _ = Errors;
}
export fn bar() void {
    const Errors = error{} || u16;
    _ = Errors;
}

// error
// backend=stage2
// target=native
//
// :2:20: error: expected error set type, found 'u8'
// :6:31: error: expected error set type, found 'u16'

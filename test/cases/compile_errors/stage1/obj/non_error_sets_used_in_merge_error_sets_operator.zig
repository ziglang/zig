export fn foo() void {
    const Errors = u8 || u16;
    _ = Errors;
}
export fn bar() void {
    const Errors = error{} || u16;
    _ = Errors;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:20: error: expected error set type, found type 'u8'
// tmp.zig:2:23: note: `||` merges error sets; `or` performs boolean OR
// tmp.zig:6:31: error: expected error set type, found type 'u16'
// tmp.zig:6:28: note: `||` merges error sets; `or` performs boolean OR

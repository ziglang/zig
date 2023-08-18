var global_array: [10]i32 = undefined;
fn foo(param: []i32) void {
    _ = param;
}
export fn entry() void {
    foo(global_array);
}

// error
// backend=llvm
// target=native
//
// :6:9: error: array literal requires address-of operator (&) to coerce to slice type '[]i32'

var global_array: [10]i32 = undefined;
fn foo(param: []i32) void {_ = param;}
export fn entry() void {
    foo(global_array);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:9: error: expected type '[]i32', found '[10]i32'

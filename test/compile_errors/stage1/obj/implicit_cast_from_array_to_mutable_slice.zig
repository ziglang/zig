var global_array: [10]i32 = undefined;
fn foo(param: []i32) void {_ = param;}
export fn entry() void {
    foo(global_array);
}

// implicit cast from array to mutable slice
//
// tmp.zig:4:9: error: expected type '[]i32', found '[10]i32'

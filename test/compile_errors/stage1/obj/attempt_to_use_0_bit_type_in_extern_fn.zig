extern fn foo(ptr: fn(*void) callconv(.C) void) void;

export fn entry() void {
    foo(bar);
}

fn bar(x: *void) callconv(.C) void { _ = x; }
export fn entry2() void {
    bar(&{});
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:23: error: parameter of type '*void' has 0 bits; not allowed in function with calling convention 'C'
// tmp.zig:7:11: error: parameter of type '*void' has 0 bits; not allowed in function with calling convention 'C'

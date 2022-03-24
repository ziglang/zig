extern fn foo(comptime x: i32, y: i32) i32;
fn f() i32 {
    return foo(1, 2);
}
export fn entry() usize { return @sizeOf(@TypeOf(f)); }

// extern function with comptime parameter
//
// tmp.zig:1:15: error: comptime parameter not allowed in function with calling convention 'C'

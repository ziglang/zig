extern fn foo(comptime x: i32, y: i32) i32;
fn f() i32 {
    return foo(1, 2);
}
pub extern fn entry1(b: u32, comptime a: [2]u8, c: i32) void;
pub extern fn entry2(b: u32, noalias a: anytype, i43) void;
comptime { _ = f; }
comptime { _ = entry1; }
comptime { _ = entry2; }

// error
// backend=stage2
// target=native
//
// :5:12: error: extern function cannot be generic
// :5:30: note: function is generic because of this parameter
// :6:12: error: extern function cannot be generic
// :6:30: note: function is generic because of this parameter
// :1:8: error: extern function cannot be generic
// :1:15: note: function is generic because of this parameter

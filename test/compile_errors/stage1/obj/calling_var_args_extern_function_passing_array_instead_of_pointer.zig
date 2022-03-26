export fn entry() void {
    foo("hello".*,);
}
pub extern fn foo(format: *const u8, ...) void;

// calling var args extern function, passing array instead of pointer
//
// tmp.zig:2:16: error: expected type '*const u8', found '[5:0]u8'

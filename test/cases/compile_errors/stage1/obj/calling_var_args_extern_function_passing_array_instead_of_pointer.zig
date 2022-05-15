export fn entry() void {
    foo("hello".*,);
}
pub extern fn foo(format: *const u8, ...) void;

// error
// backend=stage1
// target=native
//
// tmp.zig:2:16: error: expected type '*const u8', found '[5:0]u8'

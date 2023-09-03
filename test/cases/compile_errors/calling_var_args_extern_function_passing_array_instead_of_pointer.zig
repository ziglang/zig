export fn entry() void {
    foo(
        "hello".*,
    );
}
pub extern fn foo(format: *const u8, ...) void;

// error
// backend=stage2
// target=native
//
// :3:16: error: expected type '*const u8', found '[5:0]u8'
// :6:27: note: parameter type declared here

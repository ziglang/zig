const fn_ty = ?fn ([*c]u8, ...) callconv(.C) void;
extern fn fn_decl(fmt: [*:0]u8, ...) void;

export fn main() void {
    const x: fn_ty = fn_decl;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :5:22: error: expected type '?fn ([*c]u8, ...) callconv(.C) void', found 'fn ([*:0]u8, ...) callconv(.C) void'
// :5:22: note: parameter 0 '[*:0]u8' cannot cast into '[*c]u8'
// :5:22: note: '[*c]u8' could have null values which are illegal in type '[*:0]u8'

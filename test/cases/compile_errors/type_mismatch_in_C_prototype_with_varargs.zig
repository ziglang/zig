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
// :5:22: error: expected type 'fn([*c]u8, ...) callconv(.C) void', found 'fn([*:0]u8, ...) callconv(.C) void'

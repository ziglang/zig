pub const fnty1 = ?fn (i8) void;
pub const fnty2 = ?fn (u64) void;
export fn entry() void {
    var a: fnty1 = undefined;
    var b: fnty2 = undefined;
    a = b;
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:6:9: error: expected type '?fn(i8) void', found '?fn(u64) void'
// tmp.zig:6:9: note: optional type child 'fn(u64) void' cannot cast into optional type child 'fn(i8) void'

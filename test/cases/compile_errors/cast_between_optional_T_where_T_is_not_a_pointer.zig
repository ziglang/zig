pub const fnty1 = ?*const fn (i8) void;
pub const fnty2 = ?*const fn (u64) void;
export fn entry1() void {
    var a: fnty1 = undefined;
    var b: fnty2 = undefined;
    a = b;
    _ = &b;
}

pub const fnty3 = ?*const fn (u63) void;
export fn entry2() void {
    var a: fnty3 = undefined;
    var b: fnty2 = undefined;
    a = b;
    _ = &b;
}

// error
// backend=stage2
// target=native
//
// :6:9: error: expected type '?*const fn (i8) void', found '?*const fn (u64) void'
// :6:9: note: pointer type child 'fn (u64) void' cannot cast into pointer type child 'fn (i8) void'
// :6:9: note: parameter 0 'u64' cannot cast into 'i8'
// :6:9: note: unsigned 64-bit int cannot represent all possible signed 8-bit values
// :14:9: error: expected type '?*const fn (u63) void', found '?*const fn (u64) void'
// :14:9: note: pointer type child 'fn (u64) void' cannot cast into pointer type child 'fn (u63) void'
// :14:9: note: parameter 0 'u64' cannot cast into 'u63'

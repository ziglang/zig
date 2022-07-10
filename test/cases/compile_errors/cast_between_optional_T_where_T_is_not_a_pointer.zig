pub const fnty1 = ?*const fn (i8) void;
pub const fnty2 = ?*const fn (u64) void;
export fn entry() void {
    var a: fnty1 = undefined;
    var b: fnty2 = undefined;
    a = b;
}

// error
// backend=stage2
// target=native
//
// :6:9: error: expected type '?*const fn(i8) void', found '?*const fn(u64) void'
// :6:9: note: pointer type child 'fn(u64) void' cannot cast into pointer type child 'fn(i8) void'
// :6:9: note: parameter 0 'u64' cannot cast into 'i8'
// :6:9: note: unsigned 64-bit int cannot represent all possible signed 8-bit values

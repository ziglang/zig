test "" {}

pub fn panic() void {}


// wrong panic signature, runtime function
//
// error: expected type 'fn([]const u8, ?*std.builtin.StackTrace) noreturn', found 'fn() void'

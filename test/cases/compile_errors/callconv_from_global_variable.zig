var cc: @import("std").builtin.CallingConvention = .c;
export fn foo() callconv(cc) void {}

// error
//
// :2:26: error: unable to resolve comptime value
// :2:26: note: calling convention must be comptime-known

var cc: @import("std").builtin.CallingConvention = .C;
export fn foo() callconv(cc) void {}

// error
// backend=stage2
// target=native
//
// :2:26: error: unable to resolve comptime value
// :2:26: note: calling convention must be comptime-known

export fn entry() callconv(.Vectorcall) void {}

// error
// backend=stage1
// target=x86_64-linux-none
//
// tmp.zig:1:28: error: callconv 'Vectorcall' is only available on x86 and AArch64, not x86_64

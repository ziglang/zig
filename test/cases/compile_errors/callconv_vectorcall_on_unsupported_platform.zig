export fn entry() callconv(.Vectorcall) void {}

// error
// backend=stage2
// target=x86_64-linux-none
//
// :1:29: error: callconv 'Vectorcall' is only available on x86 and AArch64, not x86_64

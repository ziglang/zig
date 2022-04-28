export fn entry() callconv(.Signal) void {}

// error
// backend=stage1
// target=x86_64-linux-none
//
// tmp.zig:1:28: error: callconv 'Signal' is only available on AVR, not x86_64

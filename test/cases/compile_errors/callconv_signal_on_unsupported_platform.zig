export fn entry() callconv(.Signal) void {}

// error
// backend=stage2
// target=x86_64-linux-none
//
// :1:29: error: callconv 'Signal' is only available on AVR, not x86_64

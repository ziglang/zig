export fn entry() callconv(.Interrupt) void {}

// error
// backend=stage1
// target=aarch64-linux-none
//
// tmp.zig:1:28: error: callconv 'Interrupt' is only available on x86, x86_64, AVR, and MSP430, not aarch64

export fn entry() callconv(.Interrupt) void {}

// error
// backend=stage2
// target=aarch64-linux-none
//
// :1:29: error: callconv 'Interrupt' is only available on x86, x86_64, AVR, and MSP430, not aarch64

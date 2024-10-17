export fn entry() callconv(.avr_signal) void {}

// error
// backend=stage2
// target=x86_64-linux-none
//
// :1:29: error: calling convention 'avr_signal' only available on architectures 'avr'

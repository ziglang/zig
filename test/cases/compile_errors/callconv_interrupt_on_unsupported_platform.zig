export fn entry1() callconv(.{ .x86_64_interrupt = .{} }) void {}
export fn entry2() callconv(.{ .x86_interrupt = .{} }) void {}
export fn entry3() callconv(.avr_interrupt) void {}

// error
// backend=stage2
// target=aarch64-linux-none
//
// :1:30: error: calling convention 'x86_64_interrupt' only available on architectures 'x86_64'
// :1:30: error: calling convention 'x86_interrupt' only available on architectures 'x86'
// :1:30: error: calling convention 'avr_interrupt' only available on architectures 'avr'

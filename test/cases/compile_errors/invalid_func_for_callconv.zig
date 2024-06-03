export fn interrupt_param1(_: u32) callconv(.Interrupt) void {}
export fn interrupt_param2(_: *anyopaque, _: u32) callconv(.Interrupt) void {}
export fn interrupt_param3(_: *anyopaque, _: u64, _: u32) callconv(.Interrupt) void {}
export fn interrupt_ret(_: *anyopaque, _: u64) callconv(.Interrupt) u32 {
    return 0;
}

export fn signal_param(_: u32) callconv(.Signal) void {}
export fn signal_ret() callconv(.Signal) noreturn {}

// error
// backend=stage2
// target=x86_64-linux
// 
// :1:28: error: first parameter of function with 'Interrupt' calling convention must be a pointer type
// :2:43: error: second parameter of function with 'Interrupt' calling convention must be a 64-bit integer
// :3:51: error: 'Interrupt' calling convention supports up to 2 parameters, found 3
// :4:69: error: function with calling convention 'Interrupt' must return 'void' or 'noreturn'
// :8:24: error: parameters are not allowed with 'Signal' calling convention
// :9:34: error: callconv 'Signal' is only available on AVR, not x86_64

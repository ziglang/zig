export fn entry1() callconv(.APCS) void {}
export fn entry2() callconv(.AAPCS) void {}
export fn entry3() callconv(.AAPCSVFP) void {}

// error
// backend=stage2
// target=x86_64-linux-none
//
// :1:30: error: callconv 'APCS' is only available on ARM, not x86_64
// :2:30: error: callconv 'AAPCS' is only available on ARM, not x86_64
// :3:30: error: callconv 'AAPCSVFP' is only available on ARM, not x86_64

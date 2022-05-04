export fn entry1() callconv(.APCS) void {}
export fn entry2() callconv(.AAPCS) void {}
export fn entry3() callconv(.AAPCSVFP) void {}

// error
// backend=stage1
// target=x86_64-linux-none
//
// tmp.zig:1:29: error: callconv 'APCS' is only available on ARM, not x86_64
// tmp.zig:2:29: error: callconv 'AAPCS' is only available on ARM, not x86_64
// tmp.zig:3:29: error: callconv 'AAPCSVFP' is only available on ARM, not x86_64

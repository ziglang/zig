export fn entry1() callconv(.Stdcall) void {}
export fn entry2() callconv(.Fastcall) void {}
export fn entry3() callconv(.Thiscall) void {}

// error
// backend=stage1
// target=x86_64-linux-none
//
// tmp.zig:1:29: error: callconv 'Stdcall' is only available on x86, not x86_64
// tmp.zig:2:29: error: callconv 'Fastcall' is only available on x86, not x86_64
// tmp.zig:3:29: error: callconv 'Thiscall' is only available on x86, not x86_64

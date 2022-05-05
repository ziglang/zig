const F1 = fn () callconv(.Stdcall) void;
const F2 = fn () callconv(.Fastcall) void;
const F3 = fn () callconv(.Thiscall) void;
export fn entry1() void {
    var a: F1 = undefined;
    _ = a;
}
export fn entry2() void {
    var a: F2 = undefined;
    _ = a;
}
export fn entry3() void {
    var a: F3 = undefined;
    _ = a;
}

// error
// backend=stage1
// target=x86_64-linux-none
//
// tmp.zig:1:27: error: callconv 'Stdcall' is only available on x86, not x86_64
// tmp.zig:2:27: error: callconv 'Fastcall' is only available on x86, not x86_64
// tmp.zig:3:27: error: callconv 'Thiscall' is only available on x86, not x86_64

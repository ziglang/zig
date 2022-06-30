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
// backend=stage2
// target=x86_64-linux-none
//
// :1:28: error: callconv 'Stdcall' is only available on i386, not x86_64
// :2:28: error: callconv 'Fastcall' is only available on i386, not x86_64
// :3:28: error: callconv 'Thiscall' is only available on i386, not x86_64

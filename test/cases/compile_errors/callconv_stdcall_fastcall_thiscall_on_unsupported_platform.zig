const F1 = fn () callconv(.{ .x86_stdcall = .{} }) void;
const F2 = fn () callconv(.{ .x86_fastcall = .{} }) void;
const F3 = fn () callconv(.{ .x86_thiscall = .{} }) void;
export fn entry1() void {
    const a: F1 = undefined;
    _ = a;
}
export fn entry2() void {
    const a: F2 = undefined;
    _ = a;
}
export fn entry3() void {
    const a: F3 = undefined;
    _ = a;
}

// error
// backend=stage2
// target=x86_64-linux-none
//
// :1:28: error: calling convention 'x86_stdcall' only available on architectures 'x86'
// :2:28: error: calling convention 'x86_fastcall' only available on architectures 'x86'
// :3:28: error: calling convention 'x86_thiscall' only available on architectures 'x86'

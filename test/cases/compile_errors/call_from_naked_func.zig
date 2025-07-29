export fn runtimeCall() callconv(.naked) void {
    f();
}

export fn runtimeBuiltinCall() callconv(.naked) void {
    @call(.auto, f, .{});
}

export fn comptimeCall() callconv(.naked) void {
    comptime f();
}

export fn comptimeBuiltinCall() callconv(.naked) void {
    @call(.compile_time, f, .{});
}

fn f() void {}

// error
// backend=stage2
// target=native
//
// :2:6: error: runtime call not allowed in naked function
// :6:5: error: runtime @call not allowed in naked function

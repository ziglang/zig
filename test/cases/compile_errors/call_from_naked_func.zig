export fn runtimeCall() callconv(.Naked) void {
    f();
}

export fn runtimeBuiltinCall() callconv(.Naked) void {
    @call(.auto, f, .{});
}

export fn comptimeCall() callconv(.Naked) void {
    comptime f();
}

export fn comptimeBuiltinCall() callconv(.Naked) void {
    @call(.compile_time, f, .{});
}

fn f() void {}

// error
// backend=llvm
// target=native
//
// :2:6: error: runtime call not allowed in naked function
// :6:5: error: runtime @call not allowed in naked function

fn runtimeSafetyDefault() callconv(.Naked) void {
    unreachable;
}

fn runtimeSafetyOn() callconv(.Naked) void {
    @setRuntimeSafety(true);
    unreachable;
}

fn runtimeSafetyOff() callconv(.Naked) void {
    @setRuntimeSafety(false);
    unreachable;
}

comptime {
    _ = &runtimeSafetyDefault;
    _ = &runtimeSafetyOn;
    _ = &runtimeSafetyOff;
}

// error
// backend=llvm
// target=native
//
// :2:5: error: runtime safety check not allowed in naked function
// :2:5: note: use @setRuntimeSafety to disable runtime safety
// :2:5: note: the end of a naked function is implicitly unreachable
// :7:5: error: runtime safety check not allowed in naked function
// :7:5: note: use @setRuntimeSafety to disable runtime safety
// :7:5: note: the end of a naked function is implicitly unreachable

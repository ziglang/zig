export fn callBoolMethodWithVoid() void {
    const s = S{};
    s.boolMethod({});
}

export fn callVoidMethodWithBool() void {
    const s = S{};
    s.voidMethod(false);
}

export fn callComptimeBoolMethodWithRuntimeBool() void {
    const s = S{};
    var arg = true;
    s.comptimeBoolMethod(arg);
}

const S = struct {
    fn boolMethod(comptime _: @This(), _: bool) void {}
    fn voidMethod(comptime _: @This(), _: void) void {}
    fn comptimeBoolMethod(comptime _: @This(), comptime _: bool) void {}
};

// error
// backend=stage2
// target=native
//
// :3:18: error: expected type 'bool', found 'void'
// :18:43: note: parameter type declared here
// :8:18: error: expected type 'void', found 'bool'
// :19:43: note: parameter type declared here
// :14:26: error: runtime-known argument passed to comptime parameter
// :20:57: note: declared comptime here

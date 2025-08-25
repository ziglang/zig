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
    _ = &arg;
    s.comptimeBoolMethod(arg);
}

const S = struct {
    fn boolMethod(comptime _: @This(), _: bool) void {}
    fn voidMethod(comptime _: @This(), _: void) void {}
    fn comptimeBoolMethod(comptime _: @This(), comptime _: bool) void {}
};

// error
//
// :3:18: error: expected type 'bool', found 'void'
// :19:43: note: parameter type declared here
// :8:18: error: expected type 'void', found 'bool'
// :20:43: note: parameter type declared here
// :15:26: error: unable to resolve comptime value
// :15:26: note: argument to comptime parameter must be comptime-known
// :21:48: note: parameter declared comptime here

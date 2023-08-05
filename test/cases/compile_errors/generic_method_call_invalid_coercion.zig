export fn callBoolMethod() void {
    const s = S{};
    s.boolMethod({});
}

export fn callVoidMethod() void {
    const s = S{};
    s.voidMethod(false);
}

const S = struct {
    fn boolMethod(comptime _: @This(), _: bool) void {}
    fn voidMethod(comptime _: @This(), _: void) void {}
};

// error
// backend=stage2
// target=native
//
// :3:18: error: expected type 'bool', found 'void'
// :8:18: error: expected type 'void', found 'bool'

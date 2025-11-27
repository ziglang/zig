pub const Y = enum {
    var foo: Y = .field;

    field,
    field2,
};

export fn entry() void {
    {
        const foo: Y = .foo;
        _ = foo;
    }
}
// error
//
// :10:25: error: decl literal must be comptime-known

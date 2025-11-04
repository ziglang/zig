pub const X = enum {
    var foo: X = .field;
    var undef: X = undefined;

    field,
};

pub const Y = enum {
    var undef: Y = undefined;

    field,
    field2,
};

export fn entry() void {
    {
        const foo: X = .foo; // works since X.foo is of type X (enum with only one field).
        _ = foo;
    }
    {
        const foo: X = .undef; // works since X.undef is of type X (enum with only one field).
        _ = foo;
    }
    {
        const foo: Y = .undef;
        _ = foo;
    }
}
// error
//
// :25:25: error: decl literal must be comptime-known

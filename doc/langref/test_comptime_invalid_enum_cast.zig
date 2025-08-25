const Foo = enum {
    a,
    b,
    c,
};
comptime {
    const a: u2 = 3;
    const b: Foo = @enumFromInt(a);
    _ = b;
}

// test_error=enum 'test_comptime_invalid_enum_cast.Foo' has no tag with value '3'

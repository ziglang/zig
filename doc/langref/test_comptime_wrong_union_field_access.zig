comptime {
    var f = Foo{ .int = 42 };
    f.float = 12.34;
}

const Foo = union {
    float: f32,
    int: u32,
};

// test_error=access of union field 'float' while field 'int' is active

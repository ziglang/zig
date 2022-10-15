test {
    comptime var st = .{
        .foo = &1,
        .bar = &2,
    };

    inline for (@typeInfo(@TypeOf(st)).Struct.fields) |field| {
        _ = field;
    }
}

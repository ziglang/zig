const builtin = @import("builtin");

test {
    comptime var st = .{
        .foo = &1,
        .bar = &2,
    };
    _ = &st;

    inline for (@typeInfo(@TypeOf(st)).Struct.fields) |field| {
        _ = field;
    }
}

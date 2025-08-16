const E = enum(u0) {
    the_only_possible_value,
};

const S = struct {};

const T = extern struct {
    foo: u0 = 0,
    bar: void = {},
    baz: struct {} = .{},
    ayy: E = .the_only_possible_value,
    arr: [0]u0 = .{},
    matey: [128]void = @splat({}),
    running_out_of_ideas: packed struct {} = .{},
    one_more: [256]S = @splat(.{}),
};

test {
    var t: T = .{};
    _ = &t;
}

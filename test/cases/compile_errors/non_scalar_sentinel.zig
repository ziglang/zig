const S = struct {};
const sentinel: S = .{};

comptime {
    _ = [0:sentinel]S;
}
comptime {
    _ = [:sentinel]S;
}
comptime {
    _ = [*:sentinel]S;
}

comptime {
    _ = @Type(.{ .array = .{ .child = S, .len = 0, .sentinel = &sentinel } });
}
comptime {
    _ = @Type(.{ .pointer = .{
        .size = .Many,
        .is_const = false,
        .is_volatile = false,
        .alignment = @alignOf(S),
        .address_space = .generic,
        .child = S,
        .is_allowzero = false,
        .sentinel = &sentinel,
    } });
}
comptime {
    _ = @Type(.{ .pointer = .{
        .size = .Many,
        .is_const = false,
        .is_volatile = false,
        .alignment = @alignOf(S),
        .address_space = .generic,
        .child = S,
        .is_allowzero = false,
        .sentinel = &sentinel,
    } });
}

// error
//
// :5:12: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
// :8:11: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
// :11:12: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
// :15:9: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
// :18:9: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
// :30:9: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here

fn Func(comptime Type: type) type {
    return struct { value: Type };
}

inline fn func(value: anytype) Func(@TypeOf(value)) {
    return .{ .value = value };
}

test {
    _ = func(type);
}

test {
    const S = struct { field: u32 };
    comptime var arr: [1]S = undefined;
    arr[0] = .{ .field = 0 };
}

test {
    const S = struct { u32 };
    comptime var arr: [1]S = undefined;
    arr[0] = .{0};
}

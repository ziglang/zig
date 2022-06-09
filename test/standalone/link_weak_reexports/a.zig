fn internal(x: i64) callconv(.C) i64 {
    return x * x;
}

comptime {
    @export(internal, .{ .name = "__pow", .linkage = .Weak });
    @export(internal, .{ .name = "powq", .linkage = .Weak });
}

pub export fn div2(x: i64) i64 {
    return @divExact(x, 2);
}

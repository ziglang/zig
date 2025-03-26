var internal_integer: usize = 2;
var obj2_integer: usize = 422;

comptime {
    @export(&internal_integer, .{ .name = "internal_integer", .linkage = .internal });
    @export(&obj2_integer, .{ .name = "obj2_integer", .linkage = .strong });
}

var internal_integer: usize = 1;
var obj1_integer: usize = 421;

comptime {
    @export(internal_integer, .{ .name = "internal_integer", .linkage = .internal });
    @export(obj1_integer, .{ .name = "obj1_integer", .linkage = .strong });
}

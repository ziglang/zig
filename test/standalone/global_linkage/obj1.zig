extern var internal_integer: usize = 1;
extern var obj1_integer: usize = 421;

comptime {
    @export(internal_integer, .{ .name = "internal_integer", .linkage = .Internal });
    @export(obj1_integer, .{ .name = "obj1_integer", .linkage = .Strong });
}

pub const A = extern struct {
    field: c_int,
};
export fn issue529(a: ?*A) void {
    _ = a;
}

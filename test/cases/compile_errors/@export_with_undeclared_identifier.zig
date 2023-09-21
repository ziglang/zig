export fn a() void {
    @export(bogus, .{ .name = "bogus_alias" });
}

// error
// backend=stage2
// target=native
//
// :2:13: error: use of undeclared identifier 'bogus'

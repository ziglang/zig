export fn entry() void {
    const UE = union(enum(comptime_int)) { a: f32, b: i32, c: void };
    var ue: UE = .{ .b = 1 };
    _ = &ue;
}

// error
// backend=stage2
// target=native
//
// :3:13: error: variable of type 'tmp.entry.UE' must be const or comptime
// :2:16: note: union requires comptime because of its tag

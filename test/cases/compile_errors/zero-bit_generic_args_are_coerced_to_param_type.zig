fn bar(a: anytype, _: @TypeOf(a)) void {}
pub export fn entry() void {
    bar(@as(u0, 0), "fooo");
}

// error
// backend=stage2
// target=native
//
// :3:21: error: expected type 'u0', found '*const [4:0]u8'
// :1:23: note: parameter type declared here

export fn a() void {
    c(1);
}
fn c(d: i32, e: i32, f: i32) void { _ = d; _ = e; _ = f; }

// wrong number of arguments
//
// tmp.zig:2:6: error: expected 3 argument(s), found 1

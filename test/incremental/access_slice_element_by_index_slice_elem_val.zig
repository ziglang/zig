var array = [_]usize{ 0, 42, 123, 34 };
var slice: []const usize = &array;

pub fn main() void {
    assert(slice[0] == 0);
    assert(slice[1] == 42);
    assert(slice[2] == 123);
    assert(slice[3] == 34);
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
// target=x86_64-linux,x86_64-macos
//

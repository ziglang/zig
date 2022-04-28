comptime {
    var x: i32 = 1;
    x += 1;
    if (x != 1) unreachable;
}
pub fn main() void {}

// error
//
// :4:17: error: unable to resolve comptime value

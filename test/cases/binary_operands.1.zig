pub fn main() void {
    var i: i32 = 2147483647;
    if (i +% 1 != -2147483648) unreachable;
    return;
}

// run
//

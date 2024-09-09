pub fn main() void {
    var cond = false;
    var res = if (cond) blk: {
        defer while (true) {};
        break :blk true;
    } else false;
    cond = undefined;
    res = undefined;
}

// compile
//

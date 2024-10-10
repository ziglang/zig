pub fn main() void {
    fnOne(1);
}

fn fnOne(choice: u32) void {
    switch (choice) {
        1 => fnTwo(2, .{ .flag1 = true }),
        else => fnTwo(2, .{ .flag1 = true }),
    }
}

pub fn fnTwo(comptime comp_val: usize, opts: struct { flag1: bool }) void {
    _ = comp_val;
    _ = opts;
}

// compile
//

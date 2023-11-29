pub fn main() void {
    const x = 1;
    const y, var z = .{ 2, 3 };
}

// error
//
// :3:18: error: unused local variable
// :3:11: error: unused local constant
// :2:11: error: unused local constant

const Example = struct { x: u8 };

pub fn main() u8 {
    var example: Example = .{ .x = 5 };
    example.x = 10;
    return example.x - 10;
}

// run
//

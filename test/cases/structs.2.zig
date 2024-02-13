const Example = struct { x: u8, y: u8 };

pub fn main() u8 {
    var example: Example = .{ .x = 5, .y = 10 };
    _ = &example;
    return example.y + example.x - 15;
}

// run
//

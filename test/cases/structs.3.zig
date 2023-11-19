const Example = struct { x: u8, y: u8 };

pub fn main() u8 {
    var example: Example = .{ .x = 5, .y = 10 };
    var example2: Example = .{ .x = 10, .y = 20 };
    _ = &example2;

    example = example2;
    return example.y + example.x - 30;
}

// run
//

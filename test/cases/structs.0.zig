const Example = struct { x: u8 };

pub fn main() u8 {
    var example: Example = .{ .x = 5 };
    _ = &example;
    return example.x - 5;
}

// run
// target=wasm32-wasi
//

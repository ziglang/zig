const U = packed union {
    x: f32,
    y: u8 align(10),
    z: u32,
};

// error
//
// :3:17: error: unable to override alignment of packed union fields

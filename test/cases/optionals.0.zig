pub fn main() u8 {
    var x: ?u8 = 5;
    _ = &x;
    var y: u8 = 0;
    if (x) |val| {
        y = val;
    }
    return y - 5;
}

// run
// target=wasm32-wasi
//

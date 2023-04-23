pub fn main() u8 {
    var i: u8 = 5;
    if (i > @as(u8, 4)) {
        i += 10;
    }
    return i - 15;
}

// run
// target=wasm32-wasi
//

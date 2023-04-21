pub fn main() u8 {
    var i: u8 = 0;
    while (i < @as(u8, 5)) {
        i += 1;
    }

    return i - 5;
}

// run
// target=wasm32-wasi
//

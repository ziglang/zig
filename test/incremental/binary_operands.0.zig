pub fn main() void {
    var i: u8 = 5;
    i += 20;
    if (i != 25) unreachable;
}

// run
// target=wasm32-wasi
//

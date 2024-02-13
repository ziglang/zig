pub fn main() void {
    var i: u8 = 5;
    var y: f32 = 42.0;
    var x: u8 = 10;
    if (false) {
        &y;
        &x / &i;
    }
    if (i != 5) unreachable;
}

// run
// target=wasm32-wasi
//

pub fn main() u8 {
    var x: u8 = 0;

    foo(&x);
    return x - 2;
}

fn foo(x: *u8) void {
    x.* = 2;
}

// run
// target=wasm32-wasi
//

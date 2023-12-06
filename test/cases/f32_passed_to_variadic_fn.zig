extern fn printf(format: [*:0]const u8, ...) c_int;
pub fn main() void {
    var a: f64 = 2.0;
    var b: f32 = 10.0;
    _ = printf("f64: %f\n", (&a).*);
    _ = printf("f32: %f\n", (&b).*);
}

// run
// backend=llvm
// target=x86_64-linux-gnu
// link_libc=true
//
// f64: 2.000000
// f32: 10.000000
//

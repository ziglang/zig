const std = @import("std");
const build_options = @import("build_options");

extern fn add_C(x: i32, a: i32) i32;
extern fn add_CXX(x: i32, a: i32) i32;
extern fn add_objc(x: i32, a: i32) i32;
extern fn add_asm_prep(x: i32, a: i32) i32;
extern fn add_asm(x: i32, a: i32) i32;
extern fn add_C_header(x: i32, a: i32) i32;
extern fn add_lib_zig(x: i32, a: i32) i32;

pub fn main() anyerror!void {
    var val: i32 = 0;
    var ref: i32 = 0;

    val = add_lib_zig(val, 1);
    ref = ref + 1;

    val = add_C(val, 10);
    ref = ref + 10;

    val = add_CXX(val, 100);
    ref = ref + 100;

    if (build_options.with_asm) {
        val = add_asm(val, 100);
        ref = ref + 100;
    }

    if (build_options.with_asm_prep) {
        val = add_asm_prep(val, 1000);
        ref = ref + 1000;
    }

    val = add_objc(val, 10000);
    ref = ref + 10000;

    val = add_C_header(val, 100000);
    ref = ref + 100000;

    //x = add_C_header(x, 10000);

    try std.testing.expectEqual(ref, val);
}

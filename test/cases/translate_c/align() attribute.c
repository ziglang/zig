__attribute__ ((aligned(128)))
extern char my_array[16];
__attribute__ ((aligned(128)))
void my_fn(void) { }
void other_fn(void) {
    char ARR[16] __attribute__ ((aligned (16)));
}

// translate-c
// c_frontend=clang
//
// pub extern var my_array: [16]u8 align(128);
// pub export fn my_fn() align(128) void {}
// pub export fn other_fn() void {
//     var ARR: [16]u8 align(16) = undefined;
//     _ = &ARR;
// }

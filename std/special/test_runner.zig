const io = @import("std").io;
const builtin = @import("builtin");
const test_fn_list = builtin.__zig_test_fn_slice;

pub fn main() -> %void {
    for (test_fn_list) |test_fn, i| {
        %%io.stderr.printf("Test {}/{} {}...", i + 1, test_fn_list.len, test_fn.name);

        test_fn.func();

        %%io.stderr.printf("OK\n");
    }
}

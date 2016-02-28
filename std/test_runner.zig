const io = @import("std").io;

struct TestFn {
    name: []u8,
    func: extern fn(),
}

extern var zig_test_fn_list: []TestFn;

pub fn run_tests() -> %void {
    for (zig_test_fn_list) |test_fn, i| {
        %%io.stderr.print_str("Test ");
        %%io.stderr.print_i64(i + 1);
        %%io.stderr.print_str("/");
        %%io.stderr.print_i64(zig_test_fn_list.len);
        %%io.stderr.print_str(" ");
        %%io.stderr.print_str(test_fn.name);
        %%io.stderr.print_str("...");
        %%io.stderr.flush();

        test_fn.func();


        %%io.stderr.print_str("OK\n");
        %%io.stderr.flush();
    }
}

const io = @import("std").io;

struct TestFn {
    name: []u8,
    func: extern fn(),
}

extern var zig_test_fn_list: []TestFn;

pub fn run_tests() -> %void {
    for (zig_test_fn_list) |test_fn, i| {
        // TODO: print var args
        %%io.stderr.write("Test ");
        %%io.stderr.print_i64(i + 1);
        %%io.stderr.write("/");
        %%io.stderr.print_i64(zig_test_fn_list.len);
        %%io.stderr.write(" ");
        %%io.stderr.write(test_fn.name);
        %%io.stderr.write("...");
        %%io.stderr.flush();

        test_fn.func();


        %%io.stderr.write("OK\n");
        %%io.stderr.flush();
    }
}

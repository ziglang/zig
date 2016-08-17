const io = @import("std").io;

struct TestFn {
    name: []u8,
    func: extern fn(),
}

extern var zig_test_fn_list: []TestFn;

pub fn runTests() -> %void {
    for (zig_test_fn_list) |testFn, i| {
        // TODO: print var args
        %%io.stderr.write("Test ");
        %%io.stderr.print_u64(i + 1);
        %%io.stderr.write("/");
        %%io.stderr.print_u64(zig_test_fn_list.len);
        %%io.stderr.write(" ");
        %%io.stderr.write(testFn.name);
        %%io.stderr.write("...");
        %%io.stderr.flush();

        testFn.func();


        %%io.stderr.write("OK\n");
        %%io.stderr.flush();
    }
}

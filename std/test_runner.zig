const io = @import("std").io;

const TestFn = struct {
    name: []u8,
    func: extern fn(),
};

extern var zig_test_fn_list: []TestFn;

pub fn runTests() -> %void {
    for (zig_test_fn_list) |testFn, i| {
        %%io.stderr.printf("Test {}/{} {}...", i + 1, zig_test_fn_list.len, testFn.name);

        testFn.func();

        %%io.stderr.printf("OK\n");
    }
}

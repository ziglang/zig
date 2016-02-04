import "std.zig";

struct TestFn {
    name: []u8,
    func: extern fn(),
}

extern var zig_test_fn_list: []TestFn;

pub fn main(args: [][]u8) -> %void {
    for (test_fn, zig_test_fn_list, i) {
        %%stderr.print_str("Test ");
        %%stderr.print_i64(i + 1);
        %%stderr.print_str("/");
        %%stderr.print_i64(zig_test_fn_list.len);
        %%stderr.print_str(" ");
        %%stderr.print_str(test_fn.name);
        %%stderr.print_str("...");

        test_fn.func();


        %%stderr.print_str("OK\n");
        %%stderr.flush();
    }
}

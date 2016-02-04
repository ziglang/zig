import "std.zig";

struct TestFn {
    name: []u8,
    func: extern fn(),
}

extern var zig_test_fn_list: []TestFn;

pub fn main(args: [][]u8) -> %void {
    for (test_fn, zig_test_fn_list, i) {
        %%stderr.print_str("Test ");
        // TODO get rid of the isize
        %%stderr.print_i64(i + isize(1));
        %%stderr.print_str("/");
        %%stderr.print_i64(zig_test_fn_list.len);
        %%stderr.print_str(" ");
        %%stderr.print_str(test_fn.name);
        %%stderr.print_str("...");

        // TODO support calling function pointers as fields directly
        const fn_ptr = test_fn.func;
        fn_ptr();


        %%stderr.print_str("OK\n");
        %%stderr.flush();
    }
}

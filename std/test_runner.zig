import "std.zig";

/*
struct TestFn {
    name: []u8,
    func: extern fn(),
}

extern var test_fn_list: []TestFn;
*/

extern var zig_test_fn_count: isize;

// TODO make this a slice of structs
extern var zig_test_fn_list: [99999999]extern fn();

pub fn main(args: [][]u8) -> %void {
    var i : isize = 0;
    while (i < zig_test_fn_count) {
        %%stderr.print_str("Test ");
        // TODO get rid of the isize
        %%stderr.print_i64(i + isize(1));
        %%stderr.print_str("/");
        %%stderr.print_i64(zig_test_fn_count);
        %%stderr.print_str(" ");
        /*
        %%stderr.print_str(test_fn.name);
        */
        %%stderr.print_str("...");

/*
        // TODO support calling function pointers as fields directly
        const fn_ptr = test_fn.func;
        fn_ptr();
        */

        const test_fn = zig_test_fn_list[i];
        test_fn();

        %%stderr.print_str("OK\n");
        %%stderr.flush();

        i += 1;
    }
}

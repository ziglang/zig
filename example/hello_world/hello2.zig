export executable "hello";

use "std.zig";

export fn main(argc : isize, argv : *mut *mut u8, env : *mut *mut u8) -> i32 {
    print_str("Hello, world!", 13 as isize);
    return 0;
}

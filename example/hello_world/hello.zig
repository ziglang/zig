export executable "hello";

use "std.zig";

export fn main(argc: isize, argv: &&u8, env: &&u8) -> i32 {
    // TODO implicit coercion from array to string
    print_str("Hello, world!\n" as string);
    return 0;
}

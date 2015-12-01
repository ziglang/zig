export executable "test";

use "libc.zig";
use "foo.zig";

export fn _start() -> unreachable {
    private_function();
}

fn private_function() -> unreachable {
    print_text();
    exit(0);
}

export executable "test";

use "libc.zig";
use "foo.zig";

fn _start() -> unreachable {
    print_text();
    exit(0);
}

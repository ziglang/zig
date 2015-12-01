use "libc.zig";

// purposefully conflicting function with main.zig
// but it's private so it should be OK
fn private_function() {
    puts("it works!");
}

pub fn print_text() {
    private_function();
}

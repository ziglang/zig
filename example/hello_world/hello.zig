const std = @import("std");

pub fn main() -> %void {
    // If this program is run without stdout attached, exit with an error.
    var stdout_file = %return std.io.getStdOut();
    // If this program encounters pipe failure when printing to stdout, exit
    // with an error.
    %return stdout_file.write("Hello, world!\n");
}

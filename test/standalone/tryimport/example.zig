pub fn main() !void {
    if (@tryImport("my_pkg")) |my_pkg| {
        try @import("std").io.getStdOut().writeAll("have my_pkg\n");
        try my_pkg.doSomething();
    } else {
        try @import("std").io.getStdOut().writeAll("my_pkg is missing\n");
    }
}

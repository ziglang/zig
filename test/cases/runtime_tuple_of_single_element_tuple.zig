pub fn main() anyerror!void {
    var someint: u16 = 0;
    var crashes = .{.{someint}};
    someint = undefined;
    crashes = undefined;
}

// run
//

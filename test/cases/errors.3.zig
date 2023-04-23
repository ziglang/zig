pub fn main() void {
    foo() catch unreachable;
}

fn foo() anyerror!void {
    try bar();
}

fn bar() anyerror!void {}

// run
//

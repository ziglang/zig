export fn foo(x: u32) u64 {
    return bar(x);
}

fn bar(x: u32) u64 {
    y();
    return x;
}

fn y() void {}

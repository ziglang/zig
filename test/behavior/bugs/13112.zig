fn nice(a: u32, b: u32) bool {
    return a == 5 or b == 2 or @panic("oh no");
}

test {
    _ = nice(2, 2);
}

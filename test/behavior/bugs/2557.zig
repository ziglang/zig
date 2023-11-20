test {
    var a = if (true) {
        return;
    } else true;
    _ = &a;
}

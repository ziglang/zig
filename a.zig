fn demo() void {
    @compileLog(@src());
}

comptime {
    _ = demo;
    @compileLog(@src());
}

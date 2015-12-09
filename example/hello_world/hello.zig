export executable "hello";

#link("c")
extern {
    fn printf(__format: *const u8, ...) -> i32;
    fn exit(__status: i32) -> unreachable;
}

export fn _start() -> unreachable {
    printf("Hello, world!\n");
    exit(0);
}

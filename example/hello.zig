export executable "hello";

#link("c")
extern {
    fn puts(s: *mut u8) -> i32;
    fn exit(code: i32) -> unreachable;
}

export fn _start() -> unreachable {
    puts("Hello, world!");
    exit(0);
}

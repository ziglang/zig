export executable "hello";

#link("c")
extern {
    fn puts(s: *const u8) -> i32;
    fn exit(code: i32) -> unreachable;
}

fn loop(a : i32) {
    if a == 0 {
        goto done;
    }
    puts("loop");
    loop(a - 1);

done:
    return;
}

export fn _start() -> unreachable {
    loop(3);
    exit(0);
}

#link("c")
extern {
    fn puts(s: *const u8) -> i32;
    fn exit(code: i32) -> unreachable;
}

export fn _start() -> unreachable {
    let a : i32 = 1;
    let b = 2;
    // let c : i32; // not yet support for const variables
    // let d; // parse error
    if (a + b == 3) {
        puts("OK");
    }
    exit(0);
}

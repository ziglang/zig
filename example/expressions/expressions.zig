#link("c")
extern {
    fn puts(s: *const u8) -> i32;
    fn exit(code: i32) -> unreachable;
}

fn other_exit() -> unreachable {
    if (true) { exit(0); }
    // the unreachable statement is the programmer assuring the compiler that this code is impossible to execute.
    unreachable;
}

export fn _start() -> unreachable {
    let a : i32 = 1;
    let b = 2;
    // let c : i32; // not yet support for const variables
    // let d; // parse error
    if (a + b == 3) {
        let no_conflict = 5;
        if (no_conflict == 5) { puts("OK 1"); }
    }

    let c = {
        let no_conflict = 10;
        no_conflict
    };
    if (c == 10) { puts("OK 2"); }
    other_exit();
}

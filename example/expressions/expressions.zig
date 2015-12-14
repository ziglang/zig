export executable "expressions";

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
    let b = 2 as i32;
    // let c : i32; // not yet support for const variables
    // let d; // parse error
    if (a + b == 3) {
        let no_conflict : i32 = 5;
        if (no_conflict == 5) { puts(c"OK 1"); }
    }

    let c = {
        let no_conflict : i32 = 10;
        no_conflict
    };
    if (c == 10) { puts(c"OK 2"); }

    void_fun(1, void, 2);

    test_mutable_vars();

    other_exit();
}

fn void_fun(a : i32, b : void, c : i32) -> void {
    let x = a + 1;    // i32
    let y = c + 1;    // i32
    let z = b;        // void
    let w : void = z; // void
    if (x + y == 4) { return w; }
}

fn test_mutable_vars() {
    let mut i : i32 = 0;
loop_start:
    if i == 3 {
        goto done;
    }
    puts(c"loop");
    i = i + 1;
    goto loop_start;
done:
}

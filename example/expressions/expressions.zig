export executable "expressions";

use "std.zig";

fn other_exit() -> unreachable {
    if (true) { exit(0); }
    // the unreachable statement is the programmer assuring the compiler that this code is impossible to execute.
    unreachable;
}

export fn main(argc: isize, argv: &&u8, env: &&u8) -> unreachable {
    const a : i32 = 1;
    const b = 2 as i32;
    // const c : i32; // not yet support for const variables
    // const d; // parse error
    if (a + b == 3) {
        const no_conflict : i32 = 5;
        if (no_conflict == 5) { print_str("OK 1\n" as string); }
    }

    const c = {
        const no_conflict : i32 = 10;
        no_conflict
    };
    if (c == 10) { print_str("OK 2\n" as string); }

    void_fun(1, void, 2);

    test_mutable_vars();

    other_exit();
}

fn void_fun(a : i32, b : void, c : i32) -> void {
    const x = a + 1;    // i32
    const y = c + 1;    // i32
    const z = b;        // void
    const w : void = z; // void
    if (x + y == 4) { return w; }
}

fn test_mutable_vars() {
    var i : i32 = 0;
loop_start:
    if i == 3 {
        goto done;
    }
    print_str("loop\n" as string);
    i = i + 1;
    goto loop_start;
done:
}

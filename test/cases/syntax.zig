// Test trailing comma syntax

const struct_trailing_comma = struct { x: i32, y: i32, };
const struct_no_comma = struct { x: i32, y: i32 };
const struct_no_comma_void_type = struct { x: i32, y };
const struct_fn_no_comma = struct { fn m() {} y: i32 };

const enum_no_comma = enum { A, B };
const enum_no_comma_type = enum { A, B: i32 };

fn container_init() {
    const S = struct { x: i32, y: i32 };
    _ = S { .x = 1, .y = 2 };
    _ = S { .x = 1, .y = 2, };
}

fn switch_cases(x: i32) {
    switch (x) {
        1,2,3 => {},
        4,5, => {},
        6...8, => {},
        else => {},
    }
}

fn switch_prongs(x: i32) {
    switch (x) {
        0 => {},
        else => {},
    }
    switch (x) {
        0 => {},
        else => {}
    }
}

const fn_no_comma = fn(i32, i32);
const fn_trailing_comma = fn(i32, i32,);
const fn_vararg_trailing_comma = fn(i32, i32, ...,);

fn fn_calls() {
    fn add(x: i32, y: i32,) -> i32 { x + y };
    _ = add(1, 2);
    _ = add(1, 2,);

    fn swallow(x: ...,) {};
    _ = swallow(1,2,3,);
    _ = swallow();
}

fn asm_lists() {
    if (false) { // Build AST but don't analyze
        asm ("not real assembly"
            :[a] "x" (x),);
        asm ("not real assembly"
            :[a] "x" (->i32),:[a] "x" (1),);
        asm ("still not real assembly"
            :::"a","b",);
    }
}

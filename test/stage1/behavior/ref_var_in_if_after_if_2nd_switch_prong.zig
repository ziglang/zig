const assertOrPanic = @import("std").debug.assertOrPanic;
const mem = @import("std").mem;

var ok: bool = false;
test "reference a variable in an if after an if in the 2nd switch prong" {
    foo(true, Num.Two, false, "aoeu");
    assertOrPanic(!ok);
    foo(false, Num.One, false, "aoeu");
    assertOrPanic(!ok);
    foo(true, Num.One, false, "aoeu");
    assertOrPanic(ok);
}

const Num = enum {
    One,
    Two,
};

fn foo(c: bool, k: Num, c2: bool, b: []const u8) void {
    switch (k) {
        Num.Two => {},
        Num.One => {
            if (c) {
                const output_path = b;

                if (c2) {}

                a(output_path);
            }
        },
    }
}

fn a(x: []const u8) void {
    assertOrPanic(mem.eql(u8, x, "aoeu"));
    ok = true;
}

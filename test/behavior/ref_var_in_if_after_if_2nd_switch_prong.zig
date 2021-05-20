const expect = @import("std").testing.expect;
const mem = @import("std").mem;

var ok: bool = false;
test "reference a variable in an if after an if in the 2nd switch prong" {
    try foo(true, Num.Two, false, "aoeu");
    try expect(!ok);
    try foo(false, Num.One, false, "aoeu");
    try expect(!ok);
    try foo(true, Num.One, false, "aoeu");
    try expect(ok);
}

const Num = enum {
    One,
    Two,
};

fn foo(c: bool, k: Num, c2: bool, b: []const u8) !void {
    switch (k) {
        Num.Two => {},
        Num.One => {
            if (c) {
                const output_path = b;

                if (c2) {}

                try a(output_path);
            }
        },
    }
}

fn a(x: []const u8) !void {
    try expect(mem.eql(u8, x, "aoeu"));
    ok = true;
}

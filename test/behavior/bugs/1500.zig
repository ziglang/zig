const builtin = @import("builtin");
const A = struct {
    b: B,
};

const B = *const fn (A) void;

test "allow these dependencies" {
    var a: A = undefined;
    var b: B = undefined;
    _ = .{ &a, &b };
    if (false) {
        a;
        b;
    }
}

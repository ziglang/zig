const P = struct {
    fn print() void {}
};

const print = P.print;

const S = struct {
    fn print(self: @This(), n: usize) void {
        // The first `print` definition in the scope hierarchy is this one, make
        // sure the compiler doesn't pick the toplevel variable `print`.
        if (n == 0) print(self, 1);
    }
};

test "bug 7140" {
    // The variable `print` is now bound.
    print();
    var s: S = undefined;
    s.print(0);
}

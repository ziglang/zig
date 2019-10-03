pub const Expect = enum {
    Likely,
    Unlikely,
};

test "@expect" {
    const S = struct {
        fn doTheTest(b: bool, c: u32, d: Expect) u32 {
            var sum: u32 = 0;
            if (@expect(b, true)) {
                sum += 4;
            }
            if (@expect(c, 5) == 5) {
                sum += 7;
            }
            if (@expect(d, .Likely) == .Likely) {
                sum += 1;
            }
            return sum;
        }
    };
    _ = S.doTheTest(true, 4, .Likely);
    _ = comptime S.doTheTest(false, 5, .Unlikely);
}

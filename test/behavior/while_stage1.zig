const std = @import("std");
const expect = std.testing.expect;

test "while error 2 break statements and an else" {
    const S = struct {
        fn entry(opt_t: anyerror!bool, f: bool) !void {
            var ok = false;
            ok = while (opt_t) |t| {
                if (f) break false;
                if (t) break true;
            } else |_| false;
            try expect(ok);
        }
    };
    try S.entry(true, false);
    comptime try S.entry(true, false);
}

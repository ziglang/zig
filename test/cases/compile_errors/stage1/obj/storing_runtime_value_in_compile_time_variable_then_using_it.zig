const Mode = @import("std").builtin.Mode;

fn Free(comptime filename: []const u8) TestCase {
    return TestCase {
        .filename = filename,
        .problem_type = ProblemType.Free,
    };
}

fn LibC(comptime filename: []const u8) TestCase {
    return TestCase {
        .filename = filename,
        .problem_type = ProblemType.LinkLibC,
    };
}

const TestCase = struct {
    filename: []const u8,
    problem_type: ProblemType,
};

const ProblemType = enum {
    Free,
    LinkLibC,
};

export fn entry() void {
    const tests = [_]TestCase {
        Free("001"),
        Free("002"),
        LibC("078"),
        Free("116"),
        Free("117"),
    };

    for ([_]Mode { Mode.Debug, Mode.ReleaseSafe, Mode.ReleaseFast }) |mode| {
        _ = mode;
        inline for (tests) |test_case| {
            const foo = test_case.filename ++ ".zig";
            _ = foo;
        }
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:38:29: error: cannot store runtime value in compile time variable

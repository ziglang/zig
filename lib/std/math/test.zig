const std = @import("../std.zig");
const print = std.debug.print;
const meta = std.meta;
const math = std.math;
const bitCount = meta.bitCount;
const nan = math.nan;

// Switch to 'true' to enable debug output.
var verbose = false;

// Include all tests.
comptime {
    _ = @import("test/exp.zig");
    _ = @import("test/exp2.zig");
    _ = @import("test/expm1.zig");
    // TODO: The implementation seems to be broken...
    // _ = @import("test/expo2.zig");
    _ = @import("test/ln.zig");
    _ = @import("test/log2.zig");
    _ = @import("test/log10.zig");
    _ = @import("test/log1p.zig");
}

/// Return negative infinity of the given float type.
///
/// Intended for use with 'genTests()'.
pub fn negInf(comptime T: type) T {
    return -math.inf(T);
}

// Used for the type signature.
fn genericFloatInFloatOut(x: anytype) @TypeOf(x) {
    return x;
}

/// Create a testcase struct type for a given function that takes in a generic
/// float value and outputs the same float type. Provides descriptive reporting
/// of errors.
pub fn Testcase(
    comptime func: anytype,
    comptime name: []const u8,
    comptime float_type: type,
) type {
    if (@typeInfo(float_type) != .Float) @compileError("Expected float type");

    return struct {
        pub const F: type = float_type;

        input: F,
        exp_output: F,

        const Self = @This();

        pub const bits = bitCount(F);
        const U: type = meta.Int(.unsigned, bits);

        pub fn init(input: F, exp_output: F) Self {
            return .{ .input = input, .exp_output = exp_output };
        }

        pub fn run(tc: Self) !void {
            const hex_bits_fmt_size = comptime std.fmt.comptimePrint("{d}", .{bits / 4});
            const hex_float_fmt_size = switch (bits) {
                16 => "10",
                32 => "16",
                64 => "24",
                128 => "40",
                else => unreachable,
            };
            const input_bits = @bitCast(U, tc.input);
            if (verbose) {
                print(
                    " IN:  0x{X:0>" ++ hex_bits_fmt_size ++ "}  " ++
                        "{[1]x:<" ++ hex_float_fmt_size ++ "}  {[1]e}\n",
                    .{ input_bits, tc.input },
                );
            }
            const output = func(tc.input);
            const output_bits = @bitCast(U, output);
            if (verbose) {
                print(
                    "OUT:  0x{X:0>" ++ hex_bits_fmt_size ++ "}  " ++
                        "{[1]x:<" ++ hex_float_fmt_size ++ "}  {[1]e}\n",
                    .{ output_bits, output },
                );
            }
            const exp_output_bits = @bitCast(U, tc.exp_output);
            // Compare bits rather than values so that NaN compares correctly.
            if (output_bits != exp_output_bits) {
                if (verbose) {
                    print(
                        "EXP:  0x{X:0>" ++ hex_bits_fmt_size ++ "}  " ++
                            "{[1]x:<" ++ hex_float_fmt_size ++ "}  {[1]e}\n",
                        .{ exp_output_bits, tc.exp_output },
                    );
                }
                print(
                    "FAILURE: expected {s}({x})->{x}, got {x} ({d}-bit)\n",
                    .{ name, tc.input, tc.exp_output, output, bits },
                );
                return error.TestExpectedEqual;
            }
        }
    };
}

/// Run all testcases in the given iterable, using the '.run()' method.
pub fn runTests(tests: anytype) !void {
    var failures: usize = 0;
    print("\n", .{});
    for (tests) |tc| {
        tc.run() catch {
            failures += 1;
        };
        if (verbose) print("\n", .{});
    }
    if (verbose) {
        print(
            "Subtest summary: {d} passed; {d} failed\n",
            .{ tests.len - failures, failures },
        );
    }
    if (failures > 0) return error.Failure;
}

/// Create a float of the given type using the unsigned integer bit representation.
pub fn floatFromBits(comptime T: type, bits: meta.Int(.unsigned, bitCount(T))) T {
    return @bitCast(T, bits);
}

/// Generate a comptime slice of testcases of the given type.
///
/// The input type should be an instance of 'Testcase'.
///
/// The input testcases should be a comptime iterable of 2-tuples containing
/// input and expected output for the testcase. These values may be any of:
///  - a comptime integer or float
///  - a regular float (to be cast to the destination float type)
///  - a function that takes a float type and returns the value, intended for
///    use with math.inf() and math.nan()
pub fn genTests(comptime T: type, comptime testcases: anytype) []const T {
    comptime var out_tests: []const T = &.{};
    inline for (testcases) |tc| {
        const input: T.F = switch (@typeInfo(@TypeOf(tc[0]))) {
            .ComptimeInt, .ComptimeFloat, .Float => tc[0],
            else => tc[0](T.F),
        };
        const exp_output: T.F = switch (@typeInfo(@TypeOf(tc[1]))) {
            .ComptimeInt, .ComptimeFloat, .Float => tc[1],
            else => tc[1](T.F),
        };
        out_tests = out_tests ++ &[_]T{T.init(input, exp_output)};
    }
    return out_tests;
}

/// A comptime slice of NaN testcases, applicable to all functions.
///
/// The input type should be an instance of 'Testcase'.
pub fn nanTests(comptime T: type) []const T {
    // NaNs should always be unchanged when passed through.
    switch (T.bits) {
        32 => return &.{
            T.init(nan(T.F), nan(T.F)),
            T.init(-nan(T.F), -nan(T.F)),
            T.init(floatFromBits(T.F, 0x7ff01234), floatFromBits(T.F, 0x7ff01234)),
            T.init(floatFromBits(T.F, 0xfff01234), floatFromBits(T.F, 0xfff01234)),
        },
        64 => return &.{
            T.init(nan(T.F), nan(T.F)),
            T.init(-nan(T.F), -nan(T.F)),
            T.init(floatFromBits(T.F, 0x7ff0123400000000), floatFromBits(T.F, 0x7ff0123400000000)),
            T.init(floatFromBits(T.F, 0xfff0123400000000), floatFromBits(T.F, 0xfff0123400000000)),
        },
        else => @compileError("Not yet implemented for " ++ @typeName(T.F)),
    }
}

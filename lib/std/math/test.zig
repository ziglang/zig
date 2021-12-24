const std = @import("../std.zig");
const print = std.debug.print;
const meta = std.meta;
const bitCount = meta.bitCount;

// Switch to 'true' to enable debug output.
var verbose = false;

// Include all tests.
comptime {
    _ = @import("test/exp.zig");
    _ = @import("test/exp2.zig");
    _ = @import("test/ln.zig");
    _ = @import("test/log2.zig");
    _ = @import("test/log10.zig");
}

// Used for the type signature.
fn genericFloatInFloatOut(x: anytype) @TypeOf(x) {
    return x;
}

pub fn Testcase(
    comptime func: @TypeOf(genericFloatInFloatOut),
    comptime name: []const u8,
    comptime float_type: type,
) type {
    if (@typeInfo(float_type) != .Float) @compileError("Expected float type");

    return struct {
        const F: type = float_type;

        input: F,
        exp_output: F,

        const Self = @This();

        const bits = bitCount(F);
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

pub fn floatFromBits(comptime T: type, bits: meta.Int(.unsigned, bitCount(T))) T {
    return @bitCast(T, bits);
}

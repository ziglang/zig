// transforms https://raw.githubusercontent.com/C2SP/wycheproof/cd27d6419bedd83cbd24611ec54b6d4bfdb0cdca/testvectors/ecdsa_secp256r1_sha256_test.json into [_]TestVector{}
const std = @import("std");

const path = "ecdsa_secp256r1_sha256_test.json";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const infile = try std.fs.cwd().openFile(path, .{});
    defer infile.close();

    const json_str = try infile.readToEndAlloc(allocator, 1 << 24);
    defer allocator.free(json_str);
    const T = struct {
        testGroups: []struct { key: struct { uncompressed: []const u8 }, tests: []struct {
            comment: []const u8,
            msg: []const u8,
            sig: []const u8,
            result: []const u8,
        } },
    };
    const Result = enum {
        valid,
        invalid,
        acceptable,
    };

    const parsed = try std.json.parseFromSlice(T, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const outfile = try std.fs.cwd().createFile("./ecdsa_secp256r1_sha256_wycheproof.zig", .{});
    defer outfile.close();

    var writer = outfile.writer();

    try writer.writeAll("// generated from " ++ path ++
        \\
        \\pub const Test = struct {
        \\    comment: []const u8,
        \\    msg: []const u8,
        \\    sig: []const u8,
        \\    result: enum {
        \\        valid,
        \\        invalid,
        \\        acceptable,
        \\    },
        \\};
        \\pub const TestGroup = struct {
        \\    key: []const u8,
        \\    tests: []const Test,
        \\};
        \\
        \\pub const test_groups = [_]TestGroup{
    );

    const value = parsed.value;
    for (value.testGroups) |group| {
        try writer.print(
            \\
            \\    .{{
            \\        .key = "{s}",
            \\        .tests = &[_]Test{{
        , .{group.key.uncompressed});
        for (group.tests) |t| {
            try writer.print(
                \\
                \\            .{{
                \\                .comment = "{s}",
                \\                .msg = "{s}",
                \\                .sig = "{s}",
                \\                .result = .{s},
                \\            }},
            , .{
                t.comment,
                t.msg,
                t.sig,
                @tagName(std.meta.stringToEnum(Result, t.result).?),
            });
        }
        try writer.writeAll(
            \\
            \\        },
            \\    },
        );
    }

    try outfile.writeAll(
        \\
        \\};
    );
}

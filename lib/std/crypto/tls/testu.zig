const std = @import("std");

pub fn bufPrint(var_name: []const u8, buf: []const u8) void {
    // std.debug.print("\nconst {s} = [_]u8{{\n", .{var_name});
    // for (buf, 1..) |b, i| {
    //     std.debug.print("0x{x:0>2}, ", .{b});
    //     if (i % 16 == 0)
    //         std.debug.print("\n", .{});
    // }
    // std.debug.print("}};\n", .{});

    std.debug.print("const {s} = \"", .{var_name});
    const charset = "0123456789abcdef";
    for (buf) |b| {
        const x = charset[b >> 4];
        const y = charset[b & 15];
        std.debug.print("{c}{c} ", .{ x, y });
    }
    std.debug.print("\"\n", .{});
}

const random_instance = std.Random{ .ptr = undefined, .fillFn = randomFillFn };
var random_seed: u8 = 0;

pub fn randomFillFn(_: *anyopaque, buf: []u8) void {
    for (buf) |*v| {
        v.* = random_seed;
        random_seed +%= 1;
    }
}

pub fn random(seed: u8) std.Random {
    random_seed = seed;
    return random_instance;
}

// Fill buf with 0,1,..ff,0,...
pub fn fill(buf: []u8) void {
    fillFrom(buf, 0);
}

pub fn fillFrom(buf: []u8, start: u8) void {
    var i: u8 = start;
    for (buf) |*v| {
        v.* = i;
        i +%= 1;
    }
}

pub const Stream = struct {
    output: std.io.FixedBufferStream([]u8) = undefined,
    input: std.io.FixedBufferStream([]const u8) = undefined,

    pub fn init(input: []const u8, output: []u8) Stream {
        return .{
            .input = std.io.fixedBufferStream(input),
            .output = std.io.fixedBufferStream(output),
        };
    }

    pub const ReadError = error{};
    pub const WriteError = error{NoSpaceLeft};

    pub fn write(self: *Stream, buf: []const u8) !usize {
        return try self.output.writer().write(buf);
    }

    pub fn writeAll(self: *Stream, buffer: []const u8) !void {
        var n: usize = 0;
        while (n < buffer.len) {
            n += try self.write(buffer[n..]);
        }
    }

    pub fn read(self: *Stream, buffer: []u8) !usize {
        return self.input.read(buffer);
    }
};

// Copied from: https://github.com/clickingbuttons/zig/blob/f1cea91624fd2deae28bfb2414a4fd9c7e246883/lib/std/crypto/rsa.zig#L791
/// For readable copy/pasting from hex viewers.
pub fn hexToBytes(comptime hex: []const u8) [removeNonHex(hex).len / 2]u8 {
    @setEvalBranchQuota(1000 * 100);
    const hex2 = comptime removeNonHex(hex);
    comptime var res: [hex2.len / 2]u8 = undefined;
    _ = comptime std.fmt.hexToBytes(&res, hex2) catch unreachable;
    return res;
}

fn removeNonHex(comptime hex: []const u8) []const u8 {
    @setEvalBranchQuota(1000 * 100);
    var res: [hex.len]u8 = undefined;
    var i: usize = 0;
    for (hex) |c| {
        if (std.ascii.isHex(c)) {
            res[i] = c;
            i += 1;
        }
    }
    return res[0..i];
}

test hexToBytes {
    const hex =
        \\e3b0c442 98fc1c14 9afbf4c8 996fb924
        \\27ae41e4 649b934c a495991b 7852b855
    ;
    try std.testing.expectEqual(
        [_]u8{
            0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14,
            0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
            0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
            0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55,
        },
        hexToBytes(hex),
    );
}

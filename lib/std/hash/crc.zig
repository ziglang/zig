const std = @import("../std.zig");

pub fn Generic(comptime W: type, comptime algorithm: Algorithm(W)) type {
    return struct {
        const Self = @This();
        const I = if (@bitSizeOf(W) < 8) u8 else W;
        const lookup_table = blk: {
            @setEvalBranchQuota(2500);

            const poly = if (algorithm.reflect_input)
                @bitReverse(@as(I, algorithm.polynomial)) >> (@bitSizeOf(I) - @bitSizeOf(W))
            else
                @as(I, algorithm.polynomial) << (@bitSizeOf(I) - @bitSizeOf(W));

            var table: [256]I = undefined;
            for (&table, 0..) |*e, i| {
                var crc: I = i;
                if (algorithm.reflect_input) {
                    var j: usize = 0;
                    while (j < 8) : (j += 1) {
                        crc = (crc >> 1) ^ ((crc & 1) * poly);
                    }
                } else {
                    crc <<= @bitSizeOf(I) - 8;
                    var j: usize = 0;
                    while (j < 8) : (j += 1) {
                        crc = (crc << 1) ^ (((crc >> (@bitSizeOf(I) - 1)) & 1) * poly);
                    }
                }
                e.* = crc;
            }
            break :blk table;
        };

        crc: I,

        pub fn init() Self {
            const initial = if (algorithm.reflect_input)
                @bitReverse(@as(I, algorithm.initial)) >> (@bitSizeOf(I) - @bitSizeOf(W))
            else
                @as(I, algorithm.initial) << (@bitSizeOf(I) - @bitSizeOf(W));
            return .{ .crc = initial };
        }

        inline fn tableEntry(index: I) I {
            return lookup_table[@as(u8, @intCast(index & 0xFF))];
        }

        pub fn updateByte(self: *Self, byte: u8) void {
            if (@bitSizeOf(I) <= 8) {
                self.crc = tableEntry(self.crc ^ byte);
            } else if (algorithm.reflect_input) {
                const table_index = self.crc ^ byte;
                self.crc = tableEntry(table_index) ^ (self.crc >> 8);
            } else {
                const table_index = (self.crc >> (@bitSizeOf(I) - 8)) ^ byte;
                self.crc = tableEntry(table_index) ^ (self.crc << 8);
            }
        }

        pub fn update(self: *Self, bytes: []const u8) void {
            for (bytes) |byte| updateByte(self, byte);
        }

        pub fn final(self: Self) W {
            var c = self.crc;
            if (algorithm.reflect_input != algorithm.reflect_output) {
                c = @bitReverse(c);
            }
            if (!algorithm.reflect_output) {
                c >>= @bitSizeOf(I) - @bitSizeOf(W);
            }
            return @intCast(c ^ algorithm.xor_output);
        }

        pub fn hash(bytes: []const u8) W {
            var c = Self.init();
            c.update(bytes);
            return c.final();
        }

        pub fn writable(self: *Self, buffer: []u8) std.io.BufferedWriter {
            return .{
                .unbuffered_writer = .{
                    .context = self,
                    .vtable = &.{
                        .writeSplat = writeSplat,
                        .writeFile = std.io.Writer.unimplementedWriteFile,
                    },
                },
                .buffer = buffer,
            };
        }

        fn writeSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) std.io.Writer.Error!usize {
            const self: *Self = @ptrCast(@alignCast(context));
            var n: usize = 0;
            for (data[0 .. data.len - 1]) |slice| {
                self.update(slice);
                n += slice.len;
            }
            const last = data[data.len - 1];
            if (last.len == 1) {
                for (0..splat) |_| self.updateByte(last[0]);
                return n + splat;
            } else {
                for (0..splat) |_| self.update(last);
                return n + last.len * splat;
            }
        }
    };
}

pub fn Algorithm(comptime W: type) type {
    return struct {
        polynomial: W,
        initial: W,
        reflect_input: bool,
        reflect_output: bool,
        xor_output: W,
    };
}

pub const Crc3Gsm = Generic(u3, .{
    .polynomial = 0x3,
    .initial = 0x0,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x7,
});

pub const Crc3Rohc = Generic(u3, .{
    .polynomial = 0x3,
    .initial = 0x7,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0,
});

pub const Crc4G704 = Generic(u4, .{
    .polynomial = 0x3,
    .initial = 0x0,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0,
});

pub const Crc4Interlaken = Generic(u4, .{
    .polynomial = 0x3,
    .initial = 0xf,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xf,
});

pub const Crc5EpcC1g2 = Generic(u5, .{
    .polynomial = 0x09,
    .initial = 0x09,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc5G704 = Generic(u5, .{
    .polynomial = 0x15,
    .initial = 0x00,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00,
});

pub const Crc5Usb = Generic(u5, .{
    .polynomial = 0x05,
    .initial = 0x1f,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x1f,
});

pub const Crc6Cdma2000A = Generic(u6, .{
    .polynomial = 0x27,
    .initial = 0x3f,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc6Cdma2000B = Generic(u6, .{
    .polynomial = 0x07,
    .initial = 0x3f,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc6Darc = Generic(u6, .{
    .polynomial = 0x19,
    .initial = 0x00,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00,
});

pub const Crc6G704 = Generic(u6, .{
    .polynomial = 0x03,
    .initial = 0x00,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00,
});

pub const Crc6Gsm = Generic(u6, .{
    .polynomial = 0x2f,
    .initial = 0x00,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x3f,
});

pub const Crc7Mmc = Generic(u7, .{
    .polynomial = 0x09,
    .initial = 0x00,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc7Rohc = Generic(u7, .{
    .polynomial = 0x4f,
    .initial = 0x7f,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00,
});

pub const Crc7Umts = Generic(u7, .{
    .polynomial = 0x45,
    .initial = 0x00,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc8Autosar = Generic(u8, .{
    .polynomial = 0x2f,
    .initial = 0xff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xff,
});

pub const Crc8Bluetooth = Generic(u8, .{
    .polynomial = 0xa7,
    .initial = 0x00,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00,
});

pub const Crc8Cdma2000 = Generic(u8, .{
    .polynomial = 0x9b,
    .initial = 0xff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc8Darc = Generic(u8, .{
    .polynomial = 0x39,
    .initial = 0x00,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00,
});

pub const Crc8DvbS2 = Generic(u8, .{
    .polynomial = 0xd5,
    .initial = 0x00,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc8GsmA = Generic(u8, .{
    .polynomial = 0x1d,
    .initial = 0x00,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc8GsmB = Generic(u8, .{
    .polynomial = 0x49,
    .initial = 0x00,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xff,
});

pub const Crc8Hitag = Generic(u8, .{
    .polynomial = 0x1d,
    .initial = 0xff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc8I4321 = Generic(u8, .{
    .polynomial = 0x07,
    .initial = 0x00,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x55,
});

pub const Crc8ICode = Generic(u8, .{
    .polynomial = 0x1d,
    .initial = 0xfd,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc8Lte = Generic(u8, .{
    .polynomial = 0x9b,
    .initial = 0x00,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc8MaximDow = Generic(u8, .{
    .polynomial = 0x31,
    .initial = 0x00,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00,
});

pub const Crc8MifareMad = Generic(u8, .{
    .polynomial = 0x1d,
    .initial = 0xc7,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc8Nrsc5 = Generic(u8, .{
    .polynomial = 0x31,
    .initial = 0xff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc8Opensafety = Generic(u8, .{
    .polynomial = 0x2f,
    .initial = 0x00,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc8Rohc = Generic(u8, .{
    .polynomial = 0x07,
    .initial = 0xff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00,
});

pub const Crc8SaeJ1850 = Generic(u8, .{
    .polynomial = 0x1d,
    .initial = 0xff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xff,
});

pub const Crc8Smbus = Generic(u8, .{
    .polynomial = 0x07,
    .initial = 0x00,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00,
});

pub const Crc8Tech3250 = Generic(u8, .{
    .polynomial = 0x1d,
    .initial = 0xff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00,
});

pub const Crc8Wcdma = Generic(u8, .{
    .polynomial = 0x9b,
    .initial = 0x00,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00,
});

pub const Crc10Atm = Generic(u10, .{
    .polynomial = 0x233,
    .initial = 0x000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x000,
});

pub const Crc10Cdma2000 = Generic(u10, .{
    .polynomial = 0x3d9,
    .initial = 0x3ff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x000,
});

pub const Crc10Gsm = Generic(u10, .{
    .polynomial = 0x175,
    .initial = 0x000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x3ff,
});

pub const Crc11Flexray = Generic(u11, .{
    .polynomial = 0x385,
    .initial = 0x01a,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x000,
});

pub const Crc11Umts = Generic(u11, .{
    .polynomial = 0x307,
    .initial = 0x000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x000,
});

pub const Crc12Cdma2000 = Generic(u12, .{
    .polynomial = 0xf13,
    .initial = 0xfff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x000,
});

pub const Crc12Dect = Generic(u12, .{
    .polynomial = 0x80f,
    .initial = 0x000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x000,
});

pub const Crc12Gsm = Generic(u12, .{
    .polynomial = 0xd31,
    .initial = 0x000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xfff,
});

pub const Crc12Umts = Generic(u12, .{
    .polynomial = 0x80f,
    .initial = 0x000,
    .reflect_input = false,
    .reflect_output = true,
    .xor_output = 0x000,
});

pub const Crc13Bbc = Generic(u13, .{
    .polynomial = 0x1cf5,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc14Darc = Generic(u14, .{
    .polynomial = 0x0805,
    .initial = 0x0000,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0000,
});

pub const Crc14Gsm = Generic(u14, .{
    .polynomial = 0x202d,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x3fff,
});

pub const Crc15Can = Generic(u15, .{
    .polynomial = 0x4599,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc15Mpt1327 = Generic(u15, .{
    .polynomial = 0x6815,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0001,
});

pub const Crc16Arc = Generic(u16, .{
    .polynomial = 0x8005,
    .initial = 0x0000,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0000,
});

pub const Crc16Cdma2000 = Generic(u16, .{
    .polynomial = 0xc867,
    .initial = 0xffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16Cms = Generic(u16, .{
    .polynomial = 0x8005,
    .initial = 0xffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16Dds110 = Generic(u16, .{
    .polynomial = 0x8005,
    .initial = 0x800d,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16DectR = Generic(u16, .{
    .polynomial = 0x0589,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0001,
});

pub const Crc16DectX = Generic(u16, .{
    .polynomial = 0x0589,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16Dnp = Generic(u16, .{
    .polynomial = 0x3d65,
    .initial = 0x0000,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffff,
});

pub const Crc16En13757 = Generic(u16, .{
    .polynomial = 0x3d65,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xffff,
});

pub const Crc16Genibus = Generic(u16, .{
    .polynomial = 0x1021,
    .initial = 0xffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xffff,
});

pub const Crc16Gsm = Generic(u16, .{
    .polynomial = 0x1021,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xffff,
});

pub const Crc16Ibm3740 = Generic(u16, .{
    .polynomial = 0x1021,
    .initial = 0xffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16IbmSdlc = Generic(u16, .{
    .polynomial = 0x1021,
    .initial = 0xffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffff,
});

pub const Crc16IsoIec144433A = Generic(u16, .{
    .polynomial = 0x1021,
    .initial = 0xc6c6,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0000,
});

pub const Crc16Kermit = Generic(u16, .{
    .polynomial = 0x1021,
    .initial = 0x0000,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0000,
});

pub const Crc16Lj1200 = Generic(u16, .{
    .polynomial = 0x6f63,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16M17 = Generic(u16, .{
    .polynomial = 0x5935,
    .initial = 0xffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16MaximDow = Generic(u16, .{
    .polynomial = 0x8005,
    .initial = 0x0000,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffff,
});

pub const Crc16Mcrf4xx = Generic(u16, .{
    .polynomial = 0x1021,
    .initial = 0xffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0000,
});

pub const Crc16Modbus = Generic(u16, .{
    .polynomial = 0x8005,
    .initial = 0xffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0000,
});

pub const Crc16Nrsc5 = Generic(u16, .{
    .polynomial = 0x080b,
    .initial = 0xffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0000,
});

pub const Crc16OpensafetyA = Generic(u16, .{
    .polynomial = 0x5935,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16OpensafetyB = Generic(u16, .{
    .polynomial = 0x755b,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16Profibus = Generic(u16, .{
    .polynomial = 0x1dcf,
    .initial = 0xffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xffff,
});

pub const Crc16Riello = Generic(u16, .{
    .polynomial = 0x1021,
    .initial = 0xb2aa,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0000,
});

pub const Crc16SpiFujitsu = Generic(u16, .{
    .polynomial = 0x1021,
    .initial = 0x1d0f,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16T10Dif = Generic(u16, .{
    .polynomial = 0x8bb7,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16Teledisk = Generic(u16, .{
    .polynomial = 0xa097,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16Tms37157 = Generic(u16, .{
    .polynomial = 0x1021,
    .initial = 0x89ec,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0000,
});

pub const Crc16Umts = Generic(u16, .{
    .polynomial = 0x8005,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc16Usb = Generic(u16, .{
    .polynomial = 0x8005,
    .initial = 0xffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffff,
});

pub const Crc16Xmodem = Generic(u16, .{
    .polynomial = 0x1021,
    .initial = 0x0000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000,
});

pub const Crc17CanFd = Generic(u17, .{
    .polynomial = 0x1685b,
    .initial = 0x00000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00000,
});

pub const Crc21CanFd = Generic(u21, .{
    .polynomial = 0x102899,
    .initial = 0x000000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x000000,
});

pub const Crc24Ble = Generic(u24, .{
    .polynomial = 0x00065b,
    .initial = 0x555555,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x000000,
});

pub const Crc24FlexrayA = Generic(u24, .{
    .polynomial = 0x5d6dcb,
    .initial = 0xfedcba,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x000000,
});

pub const Crc24FlexrayB = Generic(u24, .{
    .polynomial = 0x5d6dcb,
    .initial = 0xabcdef,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x000000,
});

pub const Crc24Interlaken = Generic(u24, .{
    .polynomial = 0x328b63,
    .initial = 0xffffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xffffff,
});

pub const Crc24LteA = Generic(u24, .{
    .polynomial = 0x864cfb,
    .initial = 0x000000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x000000,
});

pub const Crc24LteB = Generic(u24, .{
    .polynomial = 0x800063,
    .initial = 0x000000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x000000,
});

pub const Crc24Openpgp = Generic(u24, .{
    .polynomial = 0x864cfb,
    .initial = 0xb704ce,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x000000,
});

pub const Crc24Os9 = Generic(u24, .{
    .polynomial = 0x800063,
    .initial = 0xffffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xffffff,
});

pub const Crc30Cdma = Generic(u30, .{
    .polynomial = 0x2030b9c7,
    .initial = 0x3fffffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x3fffffff,
});

pub const Crc31Philips = Generic(u31, .{
    .polynomial = 0x04c11db7,
    .initial = 0x7fffffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x7fffffff,
});

pub const Crc32Aixm = Generic(u32, .{
    .polynomial = 0x814141ab,
    .initial = 0x00000000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00000000,
});

pub const Crc32Autosar = Generic(u32, .{
    .polynomial = 0xf4acfb13,
    .initial = 0xffffffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffffffff,
});

pub const Crc32Base91D = Generic(u32, .{
    .polynomial = 0xa833982b,
    .initial = 0xffffffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffffffff,
});

pub const Crc32Bzip2 = Generic(u32, .{
    .polynomial = 0x04c11db7,
    .initial = 0xffffffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xffffffff,
});

pub const Crc32CdRomEdc = Generic(u32, .{
    .polynomial = 0x8001801b,
    .initial = 0x00000000,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00000000,
});

pub const Crc32Cksum = Generic(u32, .{
    .polynomial = 0x04c11db7,
    .initial = 0x00000000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xffffffff,
});

pub const Crc32Iscsi = Generic(u32, .{
    .polynomial = 0x1edc6f41,
    .initial = 0xffffffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffffffff,
});

pub const Crc32IsoHdlc = Generic(u32, .{
    .polynomial = 0x04c11db7,
    .initial = 0xffffffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffffffff,
});

pub const Crc32Jamcrc = Generic(u32, .{
    .polynomial = 0x04c11db7,
    .initial = 0xffffffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00000000,
});

pub const Crc32Koopman = Generic(u32, .{
    .polynomial = 0x741b8cd7,
    .initial = 0xffffffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffffffff,
});

pub const Crc32Mef = Generic(u32, .{
    .polynomial = 0x741b8cd7,
    .initial = 0xffffffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x00000000,
});

pub const Crc32Mpeg2 = Generic(u32, .{
    .polynomial = 0x04c11db7,
    .initial = 0xffffffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00000000,
});

pub const Crc32Xfer = Generic(u32, .{
    .polynomial = 0x000000af,
    .initial = 0x00000000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x00000000,
});

pub const Crc40Gsm = Generic(u40, .{
    .polynomial = 0x0004820009,
    .initial = 0x0000000000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xffffffffff,
});

pub const Crc64Ecma182 = Generic(u64, .{
    .polynomial = 0x42f0e1eba9ea3693,
    .initial = 0x0000000000000000,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0x0000000000000000,
});

pub const Crc64GoIso = Generic(u64, .{
    .polynomial = 0x000000000000001b,
    .initial = 0xffffffffffffffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffffffffffffffff,
});

pub const Crc64Ms = Generic(u64, .{
    .polynomial = 0x259c84cba6426349,
    .initial = 0xffffffffffffffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0000000000000000,
});

pub const Crc64Redis = Generic(u64, .{
    .polynomial = 0xad93d23594c935a9,
    .initial = 0x0000000000000000,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x0000000000000000,
});

pub const Crc64We = Generic(u64, .{
    .polynomial = 0x42f0e1eba9ea3693,
    .initial = 0xffffffffffffffff,
    .reflect_input = false,
    .reflect_output = false,
    .xor_output = 0xffffffffffffffff,
});

pub const Crc64Xz = Generic(u64, .{
    .polynomial = 0x42f0e1eba9ea3693,
    .initial = 0xffffffffffffffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffffffffffffffff,
});

pub const Crc82Darc = Generic(u82, .{
    .polynomial = 0x0308c0111011401440411,
    .initial = 0x000000000000000000000,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0x000000000000000000000,
});

test {
    _ = @import("crc/test.zig");
}

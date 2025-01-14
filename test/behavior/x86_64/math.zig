fn testUnary(comptime op: anytype) !void {
    const testType = struct {
        fn testType(comptime Type: type, comptime imm_arg: Type) !void {
            const expected = op(Type, imm_arg);
            try struct {
                fn testOne(actual: @TypeOf(expected)) !void {
                    if (switch (@typeInfo(@TypeOf(expected))) {
                        else => actual != expected,
                        .vector => @reduce(.Or, actual != expected),
                    }) return error.Unexpected;
                }
                noinline fn testOps(mem_arg: Type) !void {
                    var reg_arg = mem_arg;
                    _ = .{&reg_arg};
                    try testOne(op(Type, reg_arg));
                    try testOne(op(Type, mem_arg));
                    try testOne(op(Type, imm_arg));
                }
            }.testOps(imm_arg);
        }
    }.testType;

    try testType(i0, 0);
    try testType(u0, 0);

    try testType(i1, -1);
    try testType(i1, 0);
    try testType(u1, 0);
    try testType(u1, 1 << 0);

    try testType(i2, -1 << 1);
    try testType(i2, -1);
    try testType(i2, 0);
    try testType(u2, 0);
    try testType(u2, 1 << 0);
    try testType(u2, 1 << 1);

    try testType(i3, -1 << 2);
    try testType(i3, -1);
    try testType(i3, 0);
    try testType(u3, 0);
    try testType(u3, 1 << 0);
    try testType(u3, 1 << 1);
    try testType(u3, 1 << 2);

    try testType(i4, -1 << 3);
    try testType(i4, -1);
    try testType(i4, 0);
    try testType(u4, 0);
    try testType(u4, 1 << 0);
    try testType(u4, 1 << 1);
    try testType(u4, 1 << 2);
    try testType(u4, 1 << 3);

    try testType(i5, -1 << 4);
    try testType(i5, -1);
    try testType(i5, 0);
    try testType(u5, 0);
    try testType(u5, 1 << 0);
    try testType(u5, 1 << 1);
    try testType(u5, 1 << 3);
    try testType(u5, 1 << 4);

    try testType(i7, -1 << 6);
    try testType(i7, -1);
    try testType(i7, 0);
    try testType(u7, 0);
    try testType(u7, 1 << 0);
    try testType(u7, 1 << 1);
    try testType(u7, 1 << 5);
    try testType(u7, 1 << 6);

    try testType(i8, -1 << 7);
    try testType(i8, -1);
    try testType(i8, 0);
    try testType(u8, 0);
    try testType(u8, 1 << 0);
    try testType(u8, 1 << 1);
    try testType(u8, 1 << 6);
    try testType(u8, 1 << 7);

    try testType(i9, -1 << 8);
    try testType(i9, -1);
    try testType(i9, 0);
    try testType(u9, 0);
    try testType(u9, 1 << 0);
    try testType(u9, 1 << 1);
    try testType(u9, 1 << 7);
    try testType(u9, 1 << 8);

    try testType(i15, -1 << 14);
    try testType(i15, -1);
    try testType(i15, 0);
    try testType(u15, 0);
    try testType(u15, 1 << 0);
    try testType(u15, 1 << 1);
    try testType(u15, 1 << 13);
    try testType(u15, 1 << 14);

    try testType(i16, -1 << 15);
    try testType(i16, -1);
    try testType(i16, 0);
    try testType(u16, 0);
    try testType(u16, 1 << 0);
    try testType(u16, 1 << 1);
    try testType(u16, 1 << 14);
    try testType(u16, 1 << 15);

    try testType(i17, -1 << 16);
    try testType(i17, -1);
    try testType(i17, 0);
    try testType(u17, 0);
    try testType(u17, 1 << 0);
    try testType(u17, 1 << 1);
    try testType(u17, 1 << 15);
    try testType(u17, 1 << 16);

    try testType(i31, -1 << 30);
    try testType(i31, -1);
    try testType(i31, 0);
    try testType(u31, 0);
    try testType(u31, 1 << 0);
    try testType(u31, 1 << 1);
    try testType(u31, 1 << 29);
    try testType(u31, 1 << 30);

    try testType(i32, -1 << 31);
    try testType(i32, -1);
    try testType(i32, 0);
    try testType(u32, 0);
    try testType(u32, 1 << 0);
    try testType(u32, 1 << 1);
    try testType(u32, 1 << 30);
    try testType(u32, 1 << 31);

    try testType(i33, -1 << 32);
    try testType(i33, -1);
    try testType(i33, 0);
    try testType(u33, 0);
    try testType(u33, 1 << 0);
    try testType(u33, 1 << 1);
    try testType(u33, 1 << 31);
    try testType(u33, 1 << 32);

    try testType(i63, -1 << 62);
    try testType(i63, -1);
    try testType(i63, 0);
    try testType(u63, 0);
    try testType(u63, 1 << 0);
    try testType(u63, 1 << 1);
    try testType(u63, 1 << 61);
    try testType(u63, 1 << 62);

    try testType(i64, -1 << 63);
    try testType(i64, -1);
    try testType(i64, 0);
    try testType(u64, 0);
    try testType(u64, 1 << 0);
    try testType(u64, 1 << 1);
    try testType(u64, 1 << 62);
    try testType(u64, 1 << 63);

    try testType(i65, -1 << 64);
    try testType(i65, -1);
    try testType(i65, 0);
    try testType(u65, 0);
    try testType(u65, 1 << 0);
    try testType(u65, 1 << 1);
    try testType(u65, 1 << 63);
    try testType(u65, 1 << 64);

    try testType(i95, -1 << 94);
    try testType(i95, -1);
    try testType(i95, 0);
    try testType(u95, 0);
    try testType(u95, 1 << 0);
    try testType(u95, 1 << 1);
    try testType(u95, 1 << 93);
    try testType(u95, 1 << 94);

    try testType(i96, -1 << 95);
    try testType(i96, -1);
    try testType(i96, 0);
    try testType(u96, 0);
    try testType(u96, 1 << 0);
    try testType(u96, 1 << 1);
    try testType(u96, 1 << 94);
    try testType(u96, 1 << 95);

    try testType(i97, -1 << 96);
    try testType(i97, -1);
    try testType(i97, 0);
    try testType(u97, 0);
    try testType(u97, 1 << 0);
    try testType(u97, 1 << 1);
    try testType(u97, 1 << 95);
    try testType(u97, 1 << 96);

    try testType(i127, -1 << 126);
    try testType(i127, -1);
    try testType(i127, 0);
    try testType(u127, 0);
    try testType(u127, 1 << 0);
    try testType(u127, 1 << 1);
    try testType(u127, 1 << 125);
    try testType(u127, 1 << 126);

    try testType(i128, -1 << 127);
    try testType(i128, -1);
    try testType(i128, 0);
    try testType(u128, 0);
    try testType(u128, 1 << 0);
    try testType(u128, 1 << 1);
    try testType(u128, 1 << 126);
    try testType(u128, 1 << 127);

    try testType(i129, -1 << 128);
    try testType(i129, -1);
    try testType(i129, 0);
    try testType(u129, 0);
    try testType(u129, 1 << 0);
    try testType(u129, 1 << 1);
    try testType(u129, 1 << 127);
    try testType(u129, 1 << 128);

    try testType(i159, -1 << 158);
    try testType(i159, -1);
    try testType(i159, 0);
    try testType(u159, 0);
    try testType(u159, 1 << 0);
    try testType(u159, 1 << 1);
    try testType(u159, 1 << 157);
    try testType(u159, 1 << 158);

    try testType(i160, -1 << 159);
    try testType(i160, -1);
    try testType(i160, 0);
    try testType(u160, 0);
    try testType(u160, 1 << 0);
    try testType(u160, 1 << 1);
    try testType(u160, 1 << 158);
    try testType(u160, 1 << 159);

    try testType(i161, -1 << 160);
    try testType(i161, -1);
    try testType(i161, 0);
    try testType(u161, 0);
    try testType(u161, 1 << 0);
    try testType(u161, 1 << 1);
    try testType(u161, 1 << 159);
    try testType(u161, 1 << 160);

    try testType(i191, -1 << 190);
    try testType(i191, -1);
    try testType(i191, 0);
    try testType(u191, 0);
    try testType(u191, 1 << 0);
    try testType(u191, 1 << 1);
    try testType(u191, 1 << 189);
    try testType(u191, 1 << 190);

    try testType(i192, -1 << 191);
    try testType(i192, -1);
    try testType(i192, 0);
    try testType(u192, 0);
    try testType(u192, 1 << 0);
    try testType(u192, 1 << 1);
    try testType(u192, 1 << 190);
    try testType(u192, 1 << 191);

    try testType(i193, -1 << 192);
    try testType(i193, -1);
    try testType(i193, 0);
    try testType(u193, 0);
    try testType(u193, 1 << 0);
    try testType(u193, 1 << 1);
    try testType(u193, 1 << 191);
    try testType(u193, 1 << 192);

    try testType(i223, -1 << 222);
    try testType(i223, -1);
    try testType(i223, 0);
    try testType(u223, 0);
    try testType(u223, 1 << 0);
    try testType(u223, 1 << 1);
    try testType(u223, 1 << 221);
    try testType(u223, 1 << 222);

    try testType(i224, -1 << 223);
    try testType(i224, -1);
    try testType(i224, 0);
    try testType(u224, 0);
    try testType(u224, 1 << 0);
    try testType(u224, 1 << 1);
    try testType(u224, 1 << 222);
    try testType(u224, 1 << 223);

    try testType(i225, -1 << 224);
    try testType(i225, -1);
    try testType(i225, 0);
    try testType(u225, 0);
    try testType(u225, 1 << 0);
    try testType(u225, 1 << 1);
    try testType(u225, 1 << 223);
    try testType(u225, 1 << 224);

    try testType(i255, -1 << 254);
    try testType(i255, -1);
    try testType(i255, 0);
    try testType(u255, 0);
    try testType(u255, 1 << 0);
    try testType(u255, 1 << 1);
    try testType(u255, 1 << 253);
    try testType(u255, 1 << 254);

    try testType(i256, -1 << 255);
    try testType(i256, -1);
    try testType(i256, 0);
    try testType(u256, 0);
    try testType(u256, 1 << 0);
    try testType(u256, 1 << 1);
    try testType(u256, 1 << 254);
    try testType(u256, 1 << 255);

    try testType(i257, -1 << 256);
    try testType(i257, -1);
    try testType(i257, 0);
    try testType(u257, 0);
    try testType(u257, 1 << 0);
    try testType(u257, 1 << 1);
    try testType(u257, 1 << 255);
    try testType(u257, 1 << 256);

    try testType(i511, -1 << 510);
    try testType(i511, -1);
    try testType(i511, 0);
    try testType(u511, 0);
    try testType(u511, 1 << 0);
    try testType(u511, 1 << 1);
    try testType(u511, 1 << 509);
    try testType(u511, 1 << 510);

    try testType(i512, -1 << 511);
    try testType(i512, -1);
    try testType(i512, 0);
    try testType(u512, 0);
    try testType(u512, 1 << 0);
    try testType(u512, 1 << 1);
    try testType(u512, 1 << 510);
    try testType(u512, 1 << 511);

    try testType(i513, -1 << 512);
    try testType(i513, -1);
    try testType(i513, 0);
    try testType(u513, 0);
    try testType(u513, 1 << 0);
    try testType(u513, 1 << 1);
    try testType(u513, 1 << 511);
    try testType(u513, 1 << 512);

    try testType(i1023, -1 << 1022);
    try testType(i1023, -1);
    try testType(i1023, 0);
    try testType(u1023, 0);
    try testType(u1023, 1 << 0);
    try testType(u1023, 1 << 1);
    try testType(u1023, 1 << 1021);
    try testType(u1023, 1 << 1022);

    try testType(i1024, -1 << 1023);
    try testType(i1024, -1);
    try testType(i1024, 0);
    try testType(u1024, 0);
    try testType(u1024, 1 << 0);
    try testType(u1024, 1 << 1);
    try testType(u1024, 1 << 1022);
    try testType(u1024, 1 << 1023);

    try testType(i1025, -1 << 1024);
    try testType(i1025, -1);
    try testType(i1025, 0);
    try testType(u1025, 0);
    try testType(u1025, 1 << 0);
    try testType(u1025, 1 << 1);
    try testType(u1025, 1 << 1023);
    try testType(u1025, 1 << 1024);

    try testType(@Vector(3, i0), .{ 0 << 0, 0, 0 });
    try testType(@Vector(3, u0), .{ 0, 0, 0 << 0 });

    try testType(@Vector(3, i1), .{ -1 << 0, -1, 0 });
    try testType(@Vector(3, u1), .{ 0, 1, 1 << 0 });

    try testType(@Vector(3, i2), .{ -1 << 1, -1, 0 });
    try testType(@Vector(3, u2), .{ 0, 1, 1 << 1 });

    try testType(@Vector(3, i3), .{ -1 << 2, -1, 0 });
    try testType(@Vector(3, u3), .{ 0, 1, 1 << 2 });

    try testType(@Vector(3, i4), .{ -1 << 3, -1, 0 });
    try testType(@Vector(3, u4), .{ 0, 1, 1 << 3 });
    try testType(@Vector(1, u4), .{
        0xb,
    });
    try testType(@Vector(2, u4), .{
        0x3, 0x4,
    });
    try testType(@Vector(4, u4), .{
        0x9, 0x2, 0xf, 0xe,
    });
    try testType(@Vector(8, u4), .{
        0x8, 0x1, 0xb, 0x1, 0xf, 0x5, 0x9, 0x6,
    });
    try testType(@Vector(16, u4), .{
        0xb, 0x6, 0x0, 0x7, 0x8, 0x5, 0x6, 0x9, 0xe, 0xb, 0x3, 0xa, 0xb, 0x5, 0x8, 0xc,
    });
    try testType(@Vector(32, u4), .{
        0xe, 0x6, 0xe, 0xa, 0xb, 0x4, 0xa, 0xb, 0x1, 0x3, 0xb, 0xc, 0x0, 0xb, 0x9, 0x4, 0xd, 0xa, 0xd, 0xd, 0x4, 0x8, 0x8, 0x6, 0xb, 0xe, 0x9, 0x6, 0xc, 0xd, 0x5, 0xd,
    });
    try testType(@Vector(64, u4), .{
        0x1, 0xc, 0xe, 0x9, 0x9, 0xf, 0x3, 0xf, 0x9, 0x9, 0x5, 0x3, 0xb, 0xd, 0xd, 0xf, 0x1, 0x2, 0xf, 0x9, 0x4, 0x4, 0x8, 0x9, 0x2, 0x9, 0x8, 0xe, 0x8, 0xa, 0x4, 0x3,
        0x4, 0xc, 0xb, 0x6, 0x4, 0x0, 0xa, 0x5, 0x1, 0xa, 0x4, 0xe, 0xa, 0x7, 0xd, 0x0, 0x4, 0xe, 0xe, 0x7, 0x7, 0xa, 0x4, 0x5, 0x6, 0xc, 0x6, 0x2, 0x6, 0xa, 0xe, 0xa,
    });
    try testType(@Vector(128, u4), .{
        0xd, 0x5, 0x6, 0xe, 0x3, 0x3, 0x3, 0xe, 0xd, 0xd, 0x9, 0x0, 0x0, 0xe, 0xa, 0x9, 0x8, 0x7, 0xb, 0x5, 0x7, 0xf, 0xb, 0x8, 0x0, 0xf, 0xb, 0x3, 0xa, 0x2, 0xb, 0xc,
        0x1, 0x1, 0xc, 0x8, 0x8, 0x6, 0x9, 0x1, 0xb, 0x0, 0x2, 0xb, 0x2, 0x2, 0x7, 0x6, 0x1, 0x1, 0xb, 0x4, 0x6, 0x4, 0x7, 0xc, 0xd, 0xc, 0xa, 0x8, 0x1, 0x7, 0x8, 0xa,
        0x9, 0xa, 0x1, 0x8, 0x1, 0x7, 0x9, 0x4, 0x5, 0x9, 0xd, 0x0, 0xa, 0xf, 0x3, 0x3, 0x9, 0x2, 0xf, 0x5, 0xb, 0x8, 0x6, 0xb, 0xf, 0x5, 0x8, 0x3, 0x9, 0xf, 0x6, 0x8,
        0xc, 0x8, 0x3, 0x4, 0xa, 0xe, 0xc, 0x1, 0xe, 0x9, 0x1, 0x8, 0xf, 0x6, 0xc, 0xc, 0x6, 0xf, 0x6, 0xd, 0xb, 0x9, 0xc, 0x3, 0xd, 0xa, 0x6, 0x8, 0x4, 0xa, 0x6, 0x9,
    });
    try testType(@Vector(256, u4), .{
        0x6, 0xc, 0xe, 0x3, 0x8, 0x2, 0xb, 0xd, 0x3, 0xa, 0x3, 0x8, 0xb, 0x8, 0x3, 0x0, 0xb, 0x5, 0x1, 0x3, 0x2, 0x2, 0xf, 0xc, 0x5, 0x1, 0x3, 0xb, 0x1, 0xc, 0x2, 0xd,
        0xa, 0x8, 0x1, 0xc, 0xb, 0xa, 0x3, 0x1, 0xe, 0x4, 0xf, 0xb, 0xd, 0x8, 0xf, 0xa, 0xc, 0xb, 0xb, 0x0, 0xa, 0xc, 0xf, 0xe, 0x8, 0xd, 0x9, 0x3, 0xa, 0xe, 0x8, 0x7,
        0x5, 0xa, 0x0, 0xe, 0x0, 0xd, 0x2, 0x2, 0x9, 0x4, 0x8, 0x9, 0x0, 0x4, 0x4, 0x8, 0xe, 0x1, 0xf, 0x1, 0x9, 0x3, 0xf, 0xc, 0xa, 0x0, 0x3, 0x2, 0x4, 0x1, 0x2, 0x3,
        0xf, 0x2, 0x7, 0xb, 0x5, 0x0, 0xd, 0x3, 0x4, 0xf, 0xa, 0x3, 0xc, 0x2, 0x5, 0xe, 0x7, 0x5, 0xd, 0x7, 0x9, 0x0, 0xd, 0x7, 0x9, 0xd, 0x5, 0x7, 0xf, 0xd, 0xb, 0x4,
        0x9, 0x6, 0xf, 0xb, 0x1, 0xb, 0x6, 0xb, 0xf, 0x7, 0xf, 0x0, 0x4, 0x7, 0x5, 0xa, 0x8, 0x1, 0xf, 0x9, 0x9, 0x0, 0x6, 0xb, 0x1, 0x2, 0x4, 0x3, 0x2, 0x0, 0x7, 0x0,
        0x6, 0x7, 0xf, 0x1, 0xe, 0xa, 0x8, 0x2, 0x9, 0xc, 0x1, 0x5, 0x7, 0x1, 0xb, 0x0, 0x1, 0x3, 0xd, 0x3, 0x0, 0x1, 0xa, 0x0, 0x3, 0x7, 0x1, 0x2, 0xb, 0xc, 0x2, 0x9,
        0x8, 0x8, 0x7, 0x0, 0xd, 0x5, 0x1, 0x5, 0x7, 0x7, 0x2, 0x3, 0x8, 0x7, 0xc, 0x8, 0xf, 0xa, 0xf, 0xf, 0x3, 0x2, 0x0, 0x4, 0x7, 0x5, 0x6, 0xd, 0x6, 0x3, 0xa, 0x4,
        0x1, 0x1, 0x2, 0xc, 0x3, 0xe, 0x2, 0xc, 0x7, 0x6, 0xe, 0xf, 0xb, 0x8, 0x6, 0x6, 0x9, 0x0, 0x4, 0xb, 0xe, 0x4, 0x2, 0x7, 0xf, 0xc, 0x0, 0x6, 0xd, 0xa, 0xe, 0xc,
    });

    try testType(@Vector(3, i5), .{ -1 << 4, -1, 0 });
    try testType(@Vector(3, u5), .{ 0, 1, 1 << 4 });

    try testType(@Vector(3, i7), .{ -1 << 6, -1, 0 });
    try testType(@Vector(3, u7), .{ 0, 1, 1 << 6 });

    try testType(@Vector(3, i8), .{ -1 << 7, -1, 0 });
    try testType(@Vector(3, u8), .{ 0, 1, 1 << 7 });
    try testType(@Vector(1, u8), .{
        0x33,
    });
    try testType(@Vector(2, u8), .{
        0x66, 0x87,
    });
    try testType(@Vector(4, u8), .{
        0x9d, 0xcb, 0x30, 0x7b,
    });
    try testType(@Vector(8, u8), .{
        0x4b, 0x35, 0x3f, 0x5c, 0xa5, 0x91, 0x23, 0x6d,
    });
    try testType(@Vector(16, u8), .{
        0xb7, 0x57, 0x27, 0x29, 0x58, 0xf8, 0xc9, 0x6c, 0xbe, 0x41, 0xf4, 0xd7, 0x4d, 0x01, 0xf0, 0x37,
    });
    try testType(@Vector(32, u8), .{
        0x5f, 0x61, 0x34, 0xe8, 0x37, 0x12, 0xba, 0x5a, 0x85, 0xf3, 0x3e, 0xa2, 0x0f, 0xd0, 0x65, 0xae,
        0xed, 0xf5, 0xe8, 0x65, 0x61, 0x28, 0x4a, 0x27, 0x2e, 0x01, 0x40, 0x8c, 0xe3, 0x36, 0x5d, 0xb6,
    });
    try testType(@Vector(64, u8), .{
        0xb0, 0x19, 0x5c, 0xc2, 0x3b, 0x16, 0x70, 0xad, 0x26, 0x45, 0xf2, 0xe1, 0x4f, 0x0f, 0x01, 0x72,
        0x7f, 0x1f, 0x07, 0x9e, 0xee, 0x9b, 0xb3, 0x38, 0x50, 0xf3, 0x56, 0x73, 0xd0, 0xd1, 0xee, 0xe3,
        0xeb, 0xf3, 0x1b, 0xe0, 0x77, 0x78, 0x75, 0xc6, 0x19, 0xe4, 0x69, 0xaa, 0x73, 0x08, 0xcd, 0x0c,
        0xf9, 0xed, 0x94, 0xf8, 0x79, 0x86, 0x63, 0x31, 0xbf, 0xd1, 0xe3, 0x17, 0x2b, 0xb9, 0xa1, 0x72,
    });
    try testType(@Vector(128, u8), .{
        0x2e, 0x93, 0x87, 0x09, 0x4f, 0x68, 0x14, 0xab, 0x3f, 0x04, 0x86, 0xc1, 0x95, 0xe8, 0x74, 0x11,
        0x57, 0x25, 0xe1, 0x88, 0xc0, 0x96, 0x33, 0x99, 0x15, 0x86, 0x2c, 0x84, 0x2e, 0xd7, 0x57, 0x21,
        0xd3, 0x18, 0xd5, 0x0e, 0xb4, 0x60, 0xe2, 0x08, 0xce, 0xbc, 0xd5, 0x4d, 0x8f, 0x59, 0x01, 0x67,
        0x71, 0x0a, 0x74, 0x48, 0xef, 0x39, 0x49, 0x7e, 0xa8, 0x39, 0x34, 0x75, 0x95, 0x3b, 0x38, 0xea,
        0x60, 0xd7, 0xed, 0x8f, 0xbb, 0xc0, 0x7d, 0xc2, 0x79, 0x2d, 0xbf, 0xa5, 0x64, 0xf4, 0x09, 0x86,
        0xfb, 0x29, 0xfe, 0xc7, 0xff, 0x62, 0x1a, 0x6f, 0xf8, 0xbd, 0xfe, 0xa4, 0xac, 0x24, 0xcf, 0x56,
        0x82, 0x69, 0x81, 0x0d, 0xc1, 0x51, 0x8d, 0x85, 0xf4, 0x00, 0xe7, 0x25, 0xab, 0xa5, 0x33, 0x45,
        0x66, 0x2e, 0x33, 0xc8, 0xf3, 0x35, 0x16, 0x7d, 0x1f, 0xc9, 0xf7, 0x44, 0xab, 0x66, 0x28, 0x0d,
    });

    try testType(@Vector(3, i9), .{ -1 << 8, -1, 0 });
    try testType(@Vector(3, u9), .{ 0, 1, 1 << 8 });

    try testType(@Vector(3, i15), .{ -1 << 14, -1, 0 });
    try testType(@Vector(3, u15), .{ 0, 1, 1 << 14 });

    try testType(@Vector(3, i16), .{ -1 << 15, -1, 0 });
    try testType(@Vector(3, u16), .{ 0, 1, 1 << 15 });
    try testType(@Vector(1, u16), .{
        0x4da6,
    });
    try testType(@Vector(2, u16), .{
        0x04d7, 0x50c6,
    });
    try testType(@Vector(4, u16), .{
        0x4c06, 0xd71f, 0x4d8f, 0xe0a4,
    });
    try testType(@Vector(8, u16), .{
        0xee9a, 0x881d, 0x31fb, 0xd3f7, 0x2c74, 0x6949, 0x4e04, 0x53d7,
    });
    try testType(@Vector(16, u16), .{
        0xeafe, 0x9a7b, 0x0d6f, 0x18cb, 0xaf8f, 0x8ee4, 0xa47e, 0xd39a,
        0x6572, 0x9c53, 0xf36e, 0x982e, 0x41c1, 0x8682, 0xf5dc, 0x7e01,
    });
    try testType(@Vector(32, u16), .{
        0xdfb3, 0x7de6, 0xd9ed, 0xb42e, 0x95ac, 0x9b5b, 0x0422, 0xdfcd,
        0x6196, 0x4dbe, 0x1818, 0x8816, 0x75e7, 0xc9b0, 0x92f7, 0x1f71,
        0xe584, 0x576c, 0x043a, 0x0f31, 0xfc4c, 0x2c87, 0x6b02, 0x0229,
        0x25b7, 0x53cd, 0x9bab, 0x866b, 0x9008, 0xf0f3, 0xeb21, 0x88e2,
    });
    try testType(@Vector(64, u16), .{
        0x084c, 0x445f, 0xce89, 0xd3ee, 0xb399, 0x315d, 0x8ef8, 0x4f6f,
        0xf9af, 0xcbc4, 0x0332, 0xcd55, 0xa4dc, 0xbc38, 0x6e33, 0x8ead,
        0xd15a, 0x5057, 0x58ef, 0x657a, 0xe9f0, 0x1418, 0x2b62, 0x3387,
        0x1c15, 0x04e1, 0x0276, 0x3783, 0xad9c, 0xea9a, 0x0e5e, 0xe803,
        0x2ee7, 0x0cf1, 0x30f1, 0xb12a, 0x381b, 0x353d, 0xf637, 0xf853,
        0x2ac1, 0x7ce8, 0x6a50, 0xcbb8, 0xc9b8, 0x9b25, 0xd1e9, 0xeff0,
        0xc0a2, 0x8e51, 0xde7a, 0x4e58, 0x5685, 0xeb3f, 0xd29b, 0x66ed,
        0x3dd5, 0xcb59, 0x6003, 0xf710, 0x943a, 0x7276, 0xe547, 0xe48f,
    });

    try testType(@Vector(3, i17), .{ -1 << 16, -1, 0 });
    try testType(@Vector(3, u17), .{ 0, 1, 1 << 16 });

    try testType(@Vector(3, i31), .{ -1 << 30, -1, 0 });
    try testType(@Vector(3, u31), .{ 0, 1, 1 << 30 });

    try testType(@Vector(3, i32), .{ -1 << 31, -1, 0 });
    try testType(@Vector(3, u32), .{ 0, 1, 1 << 31 });
    try testType(@Vector(1, u32), .{
        0x17e2805c,
    });
    try testType(@Vector(2, u32), .{
        0xdb6aadc5, 0xb1ff3754,
    });
    try testType(@Vector(4, u32), .{
        0xf7897b31, 0x342e1af9, 0x190fd76b, 0x283b5374,
    });
    try testType(@Vector(8, u32), .{
        0x81a0bd16, 0xc55da94e, 0x910f7e7c, 0x078d5ef7,
        0x0bdb1e4a, 0xf1a96e99, 0xcdd729b5, 0xe6966a1c,
    });
    try testType(@Vector(16, u32), .{
        0xfee812db, 0x29eacbed, 0xaed48136, 0x3053de13,
        0xbbda20df, 0x6faa274a, 0xe0b5ec3a, 0x1878b0dc,
        0x98204475, 0x810d8d05, 0x1e6996b6, 0xc543826a,
        0x53b47d8c, 0xc72c3142, 0x12f7e1f9, 0xf6782e54,
    });
    try testType(@Vector(32, u32), .{
        0xf0cf30d3, 0xe3c587b8, 0xcee44739, 0xe4a0bd72,
        0x41d44cce, 0x6d7c4259, 0xd85580a5, 0xec4b02d7,
        0xa366483d, 0x2d7b59d4, 0xe9c0ace4, 0x82cb441c,
        0xa23958ba, 0x04a70148, 0x3f0d20a3, 0xf9e21e37,
        0x009fce8b, 0x4a34a229, 0xf09c35cf, 0xc0977d4d,
        0xcc4d4647, 0xa30f1363, 0x27a65b14, 0xe572c785,
        0x8f42e320, 0x2b2cdeca, 0x11205bd4, 0x739d26aa,
        0xcbcc2df0, 0x5f7a3649, 0xbde1b7aa, 0x180a169f,
    });

    try testType(@Vector(3, i33), .{ -1 << 32, -1, 0 });
    try testType(@Vector(3, u33), .{ 0, 1, 1 << 32 });

    try testType(@Vector(3, i63), .{ -1 << 62, -1, 0 });
    try testType(@Vector(3, u63), .{ 0, 1, 1 << 62 });

    try testType(@Vector(3, i64), .{ -1 << 63, -1, 0 });
    try testType(@Vector(3, u64), .{ 0, 1, 1 << 63 });
    try testType(@Vector(1, u64), .{
        0x7d2e439abb0edba7,
    });
    try testType(@Vector(2, u64), .{
        0x3749ee5a2d237b9f, 0x6d8f4c3e1378f389,
    });
    try testType(@Vector(4, u64), .{
        0x03c127040e10d52b, 0xa86fe019072e27eb,
        0x0a554a47b709cdba, 0xf4342cc597e196c3,
    });
    try testType(@Vector(8, u64), .{
        0xea455c104375a055, 0x5c35d9d945edb2fa,
        0xc11b73d9d9d546fc, 0x2a9d63aae838dd5b,
        0xed6603f1f5d574b3, 0x2f37b354c81c1e56,
        0xbe7f5e2476bc76bd, 0xb0c88eacfffa9a8f,
    });
    try testType(@Vector(16, u64), .{
        0x2258fc04b31f8dbe, 0x3a2e5483003a10d8,
        0xebf24b31c0460510, 0x15d5b4c09b53ffa5,
        0x05abf6e744b17cc6, 0x9747b483f2d159fe,
        0x4616d8b2c8673125, 0x8ae3f91d422447eb,
        0x18da2f101a9e9776, 0x77a1197fb0441007,
        0x4ba480c8ec2dd10b, 0xeb99b9c0a1725278,
        0xd9d0acc5084ecdf0, 0xa0a23317fff4f515,
        0x0901c59a9a6a408b, 0x7c77ca72e25df033,
    });

    try testType(@Vector(3, i65), .{ -1 << 64, -1, 0 });
    try testType(@Vector(3, u65), .{ 0, 1, 1 << 64 });

    try testType(@Vector(3, i127), .{ -1 << 126, -1, 0 });
    try testType(@Vector(3, u127), .{ 0, 1, 1 << 126 });

    try testType(@Vector(3, i128), .{ -1 << 127, -1, 0 });
    try testType(@Vector(3, u128), .{ 0, 1, 1 << 127 });
    try testType(@Vector(1, u128), .{
        0x809f29e7fbafadc01145e1732590e7d9,
    });
    try testType(@Vector(2, u128), .{
        0x5150ac3438aacd0d51132cc2723b2995,
        0x151be9c47ad29cf719cf8358dd40165c,
    });
    try testType(@Vector(4, u128), .{
        0x4bae22df929f2f7cb9bd84deaad3e7a8,
        0x1ed46b2d6e1f3569f56b2ac33d8bc1cb,
        0xae93ea459d2ccfd5fb794e6d5c31aabb,
        0xb1177136acf099f550b70949ac202ec4,
    });
    try testType(@Vector(8, u128), .{
        0x7cd78db6baed6bfdf8c5265136c4e0fd,
        0xa41b8984c6bbde84640068194b7eba98,
        0xd33102778f2ae1a48d1e9bf8801bbbf0,
        0x0d59f6de003513a60055c86cbce2c200,
        0x825579d90012afddfbf04851c0748561,
        0xc2647c885e9d6f0ee1f5fac5da8ef7f5,
        0xcb4bbc1f81aa8ee68aa4dc140745687b,
        0x4ff10f914f74b46c694407f5bf7c7836,
    });

    try testType(@Vector(3, i129), .{ -1 << 128, -1, 0 });
    try testType(@Vector(3, u129), .{ 0, 1, 1 << 128 });

    try testType(@Vector(3, i191), .{ -1 << 190, -1, 0 });
    try testType(@Vector(3, u191), .{ 0, 1, 1 << 190 });

    try testType(@Vector(3, i192), .{ -1 << 191, -1, 0 });
    try testType(@Vector(3, u192), .{ 0, 1, 1 << 191 });
    try testType(@Vector(1, u192), .{
        0xe7baafcb9781626a77571b0539b9471a60c97d6c02106c8b,
    });
    try testType(@Vector(2, u192), .{
        0xbc9510913ed09e2c2aa50ffab9f1bc7b303a87f36e232a83,
        0x1f37bee446d7712d1ad457c47a66812cb926198d052aee65,
    });
    try testType(@Vector(4, u192), .{
        0xdca6a7cfc19c69efc34022062a8ca36f2569ab3dce001202,
        0xd25a4529e621c9084181fdb6917c6a32eccc58b63601b35d,
        0x0a258afd6debbaf8c158f1caa61fed63b31871d13f51b43d,
        0x6b40a178674fcb82c623ac322f851623d5e993dac97a219a,
    });

    try testType(@Vector(3, i193), .{ -1 << 192, -1, 0 });
    try testType(@Vector(3, u193), .{ 0, 1, 1 << 192 });

    try testType(@Vector(3, i255), .{ -1 << 254, -1, 0 });
    try testType(@Vector(3, u255), .{ 0, 1, 1 << 254 });

    try testType(@Vector(3, i256), .{ -1 << 255, -1, 0 });
    try testType(@Vector(3, u256), .{ 0, 1, 1 << 255 });
    try testType(@Vector(1, u256), .{
        0x230413bb481fa3a997796acf282010c560d1942e7339fd584a0f15a90c83fbda,
    });
    try testType(@Vector(2, u256), .{
        0x3ad569f8d91fdbc9da8ec0e933565919f2feb90b996c90c352b461aa0908e62d,
        0x0f109696d64647983f1f757042515510729ad1350e862cbf38cb73b5cf99f0f7,
    });
    try testType(@Vector(4, u256), .{
        0x1717c6ded4ac6de282d59f75f068da47d5a47a30f2c5053d2d59e715f9d28b97,
        0x3087189ce7540e2e0028b80af571ebc6353a00b2917f243a869ed29ecca0adaa,
        0x1507c6a9d104684bf503cdb08841cf91adab4644306bd67aafff5326604833ce,
        0x857e134ff9179733c871295b25f824bd3eb562977bad30890964fa0cdc15bb07,
    });

    try testType(@Vector(3, i257), .{ -1 << 256, -1, 0 });
    try testType(@Vector(3, u257), .{ 0, 1, 1 << 256 });

    try testType(@Vector(3, i511), .{ -1 << 510, -1, 0 });
    try testType(@Vector(3, u511), .{ 0, 1, 1 << 510 });

    try testType(@Vector(3, i512), .{ -1 << 511, -1, 0 });
    try testType(@Vector(3, u512), .{ 0, 1, 1 << 511 });
    try testType(@Vector(1, u512), .{
        0xa3ff51a609f1370e5eeb96b05169bf7469e465cf76ac5b4ea8ffd166c1ba3cd94f2dedf0d647a1fe424f3a06e6d7940f03e257f28100970b00bd5528c52b9ae6,
    });
    try testType(@Vector(2, u512), .{
        0xc6d43cd46ae31ab71f9468a895c83bf17516c6b2f1c9b04b9aa113bf7fe1b789eb7d95fcf951f12a9a6f2124589551efdd8c00f528b366a7bfb852faf8f3da53,
        0xc9099d2bdf8d1a0d30485ec6db4a24cbc0d89a863de30e18313ee1d66f71dd2d26235caaa703286cf4a2b51e1a12ef96d2d944c66c0bd3f0d72dd4cf0fc8100e,
    });

    try testType(@Vector(3, i513), .{ -1 << 512, -1, 0 });
    try testType(@Vector(3, u513), .{ 0, 1, 1 << 512 });

    try testType(@Vector(3, i1023), .{ -1 << 1022, -1, 0 });
    try testType(@Vector(3, u1023), .{ 0, 1, 1 << 1022 });

    try testType(@Vector(3, i1024), .{ -1 << 1023, -1, 0 });
    try testType(@Vector(3, u1024), .{ 0, 1, 1 << 1023 });
    try testType(@Vector(1, u1024), .{
        0xc6cfaa6571139552e1f067402dfc131d9b9a58aafda97198a78764b05138fb68cf26f085b7652f3d5ae0e56aa21732f296a581bb411d4a73795c213de793489fa49b173b9f5c089aa6295ff1fcdc14d491a05035b45d08fc35cd67a83d887a02b8db512f07518132e0ba56533c7d6fbe958255eddf5649bd8aba288c0dd84a25,
    });

    try testType(@Vector(3, i1025), .{ -1 << 1024, -1, 0 });
    try testType(@Vector(3, u1025), .{ 0, 1, 1 << 1024 });
}

fn testBinary(comptime op: anytype) !void {
    const testType = struct {
        fn testType(comptime Type: type, comptime imm_lhs: Type, comptime imm_rhs: Type) !void {
            const expected = op(Type, imm_lhs, imm_rhs);
            try struct {
                fn testOne(actual: @TypeOf(expected)) !void {
                    if (switch (@typeInfo(@TypeOf(expected))) {
                        else => actual != expected,
                        .vector => @reduce(.Or, actual != expected),
                    }) return error.Unexpected;
                }
                noinline fn testOps(mem_lhs: Type, mem_rhs: Type) !void {
                    var reg_lhs = mem_lhs;
                    var reg_rhs = mem_rhs;
                    _ = .{ &reg_lhs, &reg_rhs };
                    try testOne(op(Type, reg_lhs, reg_rhs));
                    try testOne(op(Type, reg_lhs, mem_rhs));
                    try testOne(op(Type, reg_lhs, imm_rhs));
                    try testOne(op(Type, mem_lhs, reg_rhs));
                    try testOne(op(Type, mem_lhs, mem_rhs));
                    try testOne(op(Type, mem_lhs, imm_rhs));
                    try testOne(op(Type, imm_lhs, reg_rhs));
                    try testOne(op(Type, imm_lhs, mem_rhs));
                }
            }.testOps(imm_lhs, imm_rhs);
        }
    }.testType;

    try testType(u8, 0xbb, 0x43);
    try testType(u16, 0xb8bf, 0x626d);
    try testType(u32, 0x80d7a2c6, 0xbff6a402);
    try testType(u64, 0x71138bc6b4a38898, 0x1bc4043de9438c7b);
    try testType(u128, 0xe05fc132ef2cd8affee00a907f0a851f, 0x29f912a72cfc6a7c6973426a9636da9a);
    try testType(
        u256,
        0xb7935f5c2f3b1ae7a422c0a7c446884294b7d5370bada307d2fe5a4c4284a999,
        0x310e6e196ba4f143b8d285ca6addf7f3bb3344224aff221b27607a31e148be08,
    );
    try testType(
        u258,
        0x186d5ddaab8cb8cb04e5b41e36f812e039d008baf49f12894c39e29a07796d800,
        0x2072daba6ffad168826163eb136f6d28ca4360c8e7e5e41e29755e19e4753a4f5,
    );
    try testType(
        u495,
        0x6eaf4e252b3bf74b75bac59e0b43ca5326bad2a25b3fdb74a67ef132ac5e47d72eebc3316fb2351ee66c50dc5afb92a75cea9b0e35160652c7db39eeb158,
        0x49fbed744a92b549d8c05bb3512c617d24dd824f3f69bdf3923bc326a75674b85f5b828d2566fab9c86f571d12c2a63c9164feb0d191d27905533d09622a,
    );
    try testType(
        u512,
        0xe5b1fedca3c77db765e517aabd05ffc524a3a8aff1784bbf67c45b894447ede32b65b9940e78173c591e56e078932d465f235aece7ad47b7f229df7ba8f12295,
        0x8b4bb7c2969e3b121cc1082c442f8b4330f0a50058438fed56447175bb10178607ecfe425cb54dacc25ef26810f3e04681de1844f1aa8d029aca75d658634806,
    );

    try testType(@Vector(1, u8), .{
        0x1f,
    }, .{
        0x06,
    });
    try testType(@Vector(2, u8), .{
        0x80, 0x63,
    }, .{
        0xe4, 0x28,
    });
    try testType(@Vector(4, u8), .{
        0x83, 0x9e, 0x1e, 0xc1,
    }, .{
        0xf0, 0x5c, 0x46, 0x85,
    });
    try testType(@Vector(8, u8), .{
        0x1e, 0x4d, 0x9d, 0x2a, 0x4c, 0x74, 0x0a, 0x83,
    }, .{
        0x28, 0x60, 0xa9, 0xb5, 0xd9, 0xa6, 0xf1, 0xb6,
    });
    try testType(@Vector(16, u8), .{
        0xea, 0x80, 0xbb, 0xe8, 0x74, 0x81, 0xc8, 0x66, 0x7b, 0x41, 0x90, 0xcb, 0x30, 0x70, 0x4b, 0x0f,
    }, .{
        0x61, 0x26, 0xbe, 0x47, 0x00, 0x9c, 0x55, 0xa5, 0x59, 0xf0, 0xb2, 0x20, 0x30, 0xaf, 0x82, 0x3e,
    });
    try testType(@Vector(32, u8), .{
        0xa1, 0x88, 0xc4, 0xf4, 0x77, 0x0b, 0xf5, 0xbb, 0x09, 0x03, 0xbf, 0xf5, 0xcc, 0x7f, 0x6b, 0x2a,
        0x4c, 0x05, 0x37, 0xc9, 0x8a, 0xcb, 0x91, 0x23, 0x09, 0x5f, 0xb8, 0x99, 0x4a, 0x75, 0x26, 0xe4,
    }, .{
        0xff, 0x0f, 0x99, 0x49, 0xa6, 0x25, 0xa7, 0xd4, 0xc9, 0x2f, 0x97, 0x6a, 0x01, 0xd6, 0x6e, 0x41,
        0xa4, 0xb5, 0x3c, 0x03, 0xea, 0x82, 0x9c, 0x5f, 0xac, 0x07, 0x16, 0x15, 0x1c, 0x64, 0x25, 0x2f,
    });
    try testType(@Vector(64, u8), .{
        0xaa, 0x08, 0xeb, 0xb2, 0xd7, 0x89, 0x0f, 0x98, 0xda, 0x9f, 0xa6, 0x4e, 0x3c, 0xce, 0x1b, 0x1b,
        0x9e, 0x5f, 0x2b, 0xd6, 0x59, 0x26, 0x47, 0x05, 0x2a, 0xb7, 0xd1, 0x10, 0xde, 0xd9, 0x84, 0x00,
        0x07, 0xc0, 0xaa, 0x6e, 0xfa, 0x3b, 0x97, 0x85, 0xa8, 0x42, 0xd7, 0xa5, 0x90, 0xe6, 0x10, 0x1a,
        0x47, 0x84, 0xe1, 0x3e, 0xb0, 0x70, 0x26, 0x3f, 0xea, 0x24, 0xb8, 0x5f, 0xe3, 0xe3, 0x4c, 0xed,
    }, .{
        0x3b, 0xc5, 0xe0, 0x3d, 0x4f, 0x2e, 0x1d, 0xa9, 0xf7, 0x7b, 0xc7, 0xc1, 0x48, 0xc6, 0xe5, 0x9e,
        0x4d, 0xa8, 0x21, 0x37, 0xa1, 0x1a, 0x95, 0x69, 0x89, 0x2f, 0x15, 0x07, 0x3d, 0x7b, 0x69, 0x89,
        0xea, 0x87, 0xf0, 0x94, 0x67, 0xf2, 0x3d, 0x04, 0x96, 0x8a, 0xd6, 0x70, 0x7c, 0x16, 0xe7, 0x62,
        0xf0, 0x8d, 0x96, 0x65, 0xd1, 0x4a, 0x35, 0x3e, 0x7a, 0x67, 0xa6, 0x1f, 0x37, 0x66, 0xe3, 0x45,
    });
    try testType(@Vector(128, u8), .{
        0xa1, 0xd0, 0x7b, 0xf9, 0x7b, 0x77, 0x7b, 0x3d, 0x2d, 0x68, 0xc2, 0x7b, 0xb0, 0xb8, 0xd4, 0x7c,
        0x1a, 0x1f, 0xd2, 0x92, 0x3e, 0xcb, 0xc1, 0x6b, 0xb9, 0x4d, 0xf1, 0x67, 0x58, 0x8e, 0x77, 0xa6,
        0xb9, 0xdf, 0x10, 0x6f, 0xbe, 0xe3, 0x33, 0xb6, 0x93, 0x77, 0x80, 0xef, 0x09, 0x9d, 0x61, 0x40,
        0xa2, 0xf4, 0x52, 0x18, 0x9d, 0xe4, 0xb0, 0xaf, 0x0a, 0xa7, 0x0b, 0x09, 0x67, 0x38, 0x71, 0x04,
        0x72, 0xa1, 0xd2, 0xfd, 0xf8, 0xf0, 0xa7, 0x23, 0x24, 0x5b, 0x7d, 0xfb, 0x43, 0xba, 0x6c, 0xc4,
        0x83, 0x46, 0x0e, 0x4d, 0x6c, 0x92, 0xab, 0x4f, 0xd2, 0x70, 0x9d, 0xfe, 0xce, 0xf8, 0x05, 0x9f,
        0x98, 0x36, 0x9c, 0x90, 0x9a, 0xd0, 0xb5, 0x76, 0x16, 0xe8, 0x25, 0xc2, 0xbd, 0x91, 0xab, 0xf9,
        0x6f, 0x6c, 0xc5, 0x60, 0xe5, 0x30, 0xf2, 0xb7, 0x59, 0xc4, 0x9c, 0xdd, 0xdf, 0x04, 0x65, 0xd9,
    }, .{
        0xed, 0xe1, 0x8a, 0xf6, 0xf3, 0x8b, 0xfd, 0x1d, 0x3c, 0x87, 0xbf, 0xfe, 0x04, 0x52, 0x15, 0x82,
        0x0b, 0xb0, 0xcf, 0xcf, 0xf8, 0x03, 0x9c, 0xef, 0xc1, 0x76, 0x7e, 0xe3, 0xe9, 0xa8, 0x18, 0x90,
        0xd4, 0xc4, 0x91, 0x15, 0x68, 0x7f, 0x65, 0xd8, 0xe1, 0xb3, 0x23, 0xc2, 0x7d, 0x84, 0x3b, 0xaf,
        0x74, 0x69, 0x07, 0x2a, 0x1b, 0x5f, 0x0e, 0x44, 0x0d, 0x2b, 0x9c, 0x82, 0x41, 0xf9, 0x7f, 0xb5,
        0xc4, 0xd9, 0xcb, 0xd3, 0xc5, 0x31, 0x8b, 0x5f, 0xda, 0x09, 0x9b, 0x29, 0xa3, 0xb7, 0x13, 0x0d,
        0x55, 0x9b, 0x59, 0x33, 0x2a, 0x59, 0x3a, 0x44, 0x1f, 0xd3, 0x40, 0x4e, 0xde, 0x2c, 0xe4, 0x16,
        0xfd, 0xc3, 0x02, 0x74, 0xaa, 0x65, 0xfd, 0xc8, 0x2a, 0x8a, 0xdb, 0xae, 0x44, 0x28, 0x62, 0xa4,
        0x56, 0x4f, 0xf1, 0xaa, 0x0a, 0x0f, 0xdb, 0x1b, 0xc8, 0x45, 0x9b, 0x12, 0xb4, 0x1a, 0xe4, 0xa3,
    });

    try testType(@Vector(1, u16), .{
        0x9d6f,
    }, .{
        0x44b1,
    });
    try testType(@Vector(2, u16), .{
        0xa0fa, 0xc365,
    }, .{
        0xe736, 0xc394,
    });
    try testType(@Vector(4, u16), .{
        0x9608, 0xa558, 0x161b, 0x206f,
    }, .{
        0x3088, 0xf25c, 0x7837, 0x9b3f,
    });
    try testType(@Vector(8, u16), .{
        0xcf61, 0xb121, 0x3cf1, 0x3e9f, 0x43a7, 0x8d69, 0x96f5, 0xc11e,
    }, .{
        0xee30, 0x82f0, 0x270b, 0x1498, 0x4c60, 0x6e72, 0x0b64, 0x02d4,
    });
    try testType(@Vector(16, u16), .{
        0x9191, 0xd23e, 0xf844, 0xd84a, 0xe907, 0xf1e8, 0x712d, 0x90af,
        0x6541, 0x3fa6, 0x92eb, 0xe35a, 0xc0c9, 0xcb47, 0xb790, 0x4453,
    }, .{
        0x21c3, 0x4039, 0x9b71, 0x60bd, 0xcd7f, 0x2ec8, 0x50ba, 0xe810,
        0xebd4, 0x06e5, 0xed18, 0x2f66, 0x7e31, 0xe282, 0xad63, 0xb25e,
    });
    try testType(@Vector(32, u16), .{
        0x6b6a, 0x30a9, 0xc267, 0x2231, 0xbf4c, 0x00bc, 0x9c2c, 0x2928,
        0xecad, 0x82df, 0xcfb0, 0xa4e5, 0x909b, 0x1b05, 0xaf40, 0x1fd9,
        0xcec6, 0xd8dc, 0xd4b5, 0x6d59, 0x8e3f, 0x4d8a, 0xb83a, 0x808e,
        0x47e2, 0x5782, 0x59bf, 0xcefc, 0x5179, 0x3f48, 0x93dc, 0x66d2,
    }, .{
        0x1be8, 0xe98c, 0xf9b3, 0xb008, 0x2f8d, 0xf087, 0xc9b9, 0x75aa,
        0xbd16, 0x9540, 0xc5bd, 0x2b2c, 0xd43f, 0x9394, 0x3e1d, 0xf695,
        0x167d, 0xff7a, 0xf09d, 0xdff8, 0xdfa2, 0xc779, 0x70b7, 0x01bd,
        0x46b3, 0x995a, 0xb7bc, 0xa79d, 0x5542, 0x961e, 0x37cd, 0x9c2a,
    });
    try testType(@Vector(64, u16), .{
        0x6b87, 0xfd84, 0x436b, 0xe345, 0xfb82, 0x81fc, 0x0992, 0x45f9,
        0x5527, 0x1f6d, 0xda46, 0x6a16, 0xf6e1, 0x8fb7, 0x3619, 0xdfe3,
        0x64ce, 0x8ac6, 0x3ae8, 0x30e3, 0xec3b, 0x4ba7, 0x02a4, 0xa694,
        0x8e68, 0x8f0c, 0x5e30, 0x0e55, 0x6538, 0x9852, 0xea35, 0x7be2,
        0xdabd, 0x57e6, 0x5b38, 0x0fb2, 0x2604, 0x85e7, 0x6595, 0x8de9,
        0x49b1, 0xe9a2, 0x3758, 0xa4d9, 0x505b, 0xc9d3, 0xddc5, 0x9a43,
        0xfd44, 0x50f5, 0x379e, 0x03b6, 0x6375, 0x692f, 0x5586, 0xc717,
        0x94dd, 0xee06, 0xb32d, 0x0bb9, 0x0e35, 0x5f8f, 0x0ba4, 0x19a8,
    }, .{
        0xbeeb, 0x3e54, 0x6486, 0x5167, 0xe432, 0x57cf, 0x9cac, 0x922e,
        0xd2f8, 0x5614, 0x2e7f, 0x19cf, 0x9a07, 0x0524, 0x168f, 0x4464,
        0x4def, 0x83ce, 0x97b4, 0xf269, 0xda5f, 0x28c1, 0x9cc3, 0xfa7c,
        0x25a0, 0x912d, 0x25b2, 0xd60d, 0xcd82, 0x0e03, 0x40cc, 0xc9dc,
        0x18eb, 0xc609, 0xb06d, 0x29e0, 0xf3c7, 0x997b, 0x8ca2, 0xa750,
        0xc9bc, 0x8f0e, 0x3916, 0xd905, 0x94f8, 0x397f, 0x98b5, 0xc61d,
        0x05db, 0x3e7a, 0xf750, 0xe8de, 0x3225, 0x81d9, 0x612e, 0x0a7e,
        0x2c02, 0xff5b, 0x19ca, 0xbbf5, 0x870e, 0xc9ca, 0x47bb, 0xcfcc,
    });

    try testType(@Vector(1, u32), .{
        0x1d0d9cc4,
    }, .{
        0xce2d0ab6,
    });
    try testType(@Vector(2, u32), .{
        0x5ab78c03, 0xd21bb513,
    }, .{
        0x8a6664eb, 0x79eac37d,
    });
    try testType(@Vector(4, u32), .{
        0x234d576e, 0x4151cc9c, 0x39f558e4, 0xba935a32,
    }, .{
        0x398f2a9d, 0x4540f093, 0x9225551c, 0x3bac865b,
    });
    try testType(@Vector(8, u32), .{
        0xb8336635, 0x2fc3182c, 0x27a00123, 0x71587fbe,
        0x9cbc65d2, 0x6f4bb0e6, 0x362594ce, 0x9971df38,
    }, .{
        0x5727e734, 0x972b0313, 0xff25f5dc, 0x924f8e55,
        0x04920a61, 0xa1c3b334, 0xf52df4b6, 0x5ef72ecc,
    });
    try testType(@Vector(16, u32), .{
        0xfb566f9e, 0x9ad4691a, 0x5b5f9ec0, 0x5a572d2a,
        0x8f2f226b, 0x2dfc7e33, 0x9fb07e32, 0x9d672a2e,
        0xbedc3cee, 0x6872428d, 0xbc73a9fd, 0xd4d5f055,
        0x69c1e9ee, 0x65038deb, 0x1449061a, 0x48412ec2,
    }, .{
        0x96cbe946, 0x3f24f60b, 0xaeacdc53, 0x7611a8b4,
        0x031a67a8, 0x52a26828, 0x75646f4b, 0xb75902c3,
        0x1f881f08, 0x834e02a4, 0x5e5b40eb, 0xc75c264d,
        0xa8251e09, 0x28e46bbd, 0x12cb1f31, 0x9a2af615,
    });
    try testType(@Vector(32, u32), .{
        0x131bbb7b, 0xa7311026, 0x9d5e59a0, 0x99b090d6,
        0xfe969e2e, 0x04547697, 0x357d3250, 0x43be6d7a,
        0x16ecf5c5, 0xf60febcc, 0x1d1e2602, 0x138a96d2,
        0x9117ba72, 0x9f185b32, 0xc10e23fd, 0x3e6b7fd8,
        0x4dc9be70, 0x2ee30047, 0xaffeab60, 0x7172d362,
        0x6154bfcf, 0x5388dc3e, 0xd6e5a76e, 0x8b782f2d,
        0xacbef4a2, 0x843aca71, 0x25d8ab5c, 0xe1a63a39,
        0xc26212e5, 0x0847b84b, 0xb53541e5, 0x0c8e44db,
    }, .{
        0x4ad92822, 0x715b623f, 0xa5bed8a7, 0x937447a9,
        0x7ecb38eb, 0x0a2f3dfc, 0x96f467a2, 0xec882793,
        0x41a8707f, 0xf7310656, 0x76217b80, 0x2058e5fc,
        0x26682154, 0x87313e31, 0x4bdc480a, 0x193572ff,
        0x60b03c75, 0x0fe45908, 0x56c73703, 0xdb86554c,
        0xdda2dd7d, 0x34371b27, 0xe4e6ad50, 0x422d1828,
        0x1de3801b, 0xdce268d3, 0x20af9ec8, 0x188a591f,
        0xf080e943, 0xc8718d14, 0x3f920382, 0x18d101b5,
    });

    try testType(@Vector(1, u64), .{
        0x333f593bf9d08546,
    }, .{
        0x6918bd767e730778,
    });
    try testType(@Vector(2, u64), .{
        0x4cd89a317b03d430, 0x28998f61842f63a9,
    }, .{
        0x6c34db64af0e217e, 0x57aa5d02cd45dceb,
    });
    try testType(@Vector(4, u64), .{
        0x946cf7e7484691c9, 0xf4fc5be2a762fcbf,
        0x71cc83bc25abaf14, 0xc69cef44c6f833a1,
    }, .{
        0x9f90cbd6c3ce1d4e, 0x182f65295dff4e84,
        0x4dfe62c59fed0040, 0x18402347c1db1999,
    });
    try testType(@Vector(8, u64), .{
        0x92c6281333943e2c, 0xa97750504668efb5,
        0x234be51057c0181f, 0xefbc1f407f3df4fb,
        0x8da6cc7c39cebb94, 0xb408f7e56feee497,
        0x2363f1f8821592ed, 0x01716e800c0619e1,
    }, .{
        0xa617426684147e7e, 0x7542da7ebe093a7b,
        0x3f21d99ac57606b7, 0x65cd36d697d22de4,
        0xed23d6bdf176c844, 0x2d4573f100ff7b58,
        0x4968f4d21b49f8ab, 0xf5d9a205d453e933,
    });
    try testType(@Vector(16, u64), .{
        0x2f61a4ee66177b4a, 0xf13b286b279f6a93,
        0x36b46beb63665318, 0x74294dbde0da98d2,
        0x3aa872ba60b936eb, 0xe8f698b36e62600b,
        0x9e8930c21a6a1a76, 0x876998b09b8eb03c,
        0xa0244771a2ec0adb, 0xb4c72bff3d3ac1a2,
        0xd70677210830eced, 0x6622abc1734dd72d,
        0x157e2bb0d57d6596, 0x2aac8192fb7ef973,
        0xc4a0ca92f34d7b13, 0x04300f8ad1845246,
    }, .{
        0xeaf71dcf0eb76f5d, 0x0e84b1b63dc97139,
        0x0f64cc38d23c94a1, 0x12775cf0816349b7,
        0xfdcf13387ba48d54, 0xf8d3c672cacd8779,
        0xe728c1f5eb56ab1e, 0x05931a34877f7a69,
        0x1861a763c8dafd1f, 0x4ac97573ecd5739f,
        0x3384414c9bf77b8c, 0x32c15bbd04a5ddc4,
        0xbfd88aee1d82ed32, 0x20e91c15b701059a,
        0xed533d18f8657f3f, 0x1ddd7cd7f6bab957,
    });

    try testType(@Vector(1, u128), .{
        0x5f11e16b0ca3392f907a857881455d2e,
    }, .{
        0xf9142d73b408fd6955922f9fc147f7d7,
    });
    try testType(@Vector(2, u128), .{
        0xee0fb41fabd805923fb21b5c658e3a87,
        0x2352e74aad6c58b3255ff0bba5aa6552,
    }, .{
        0x8d822f9fdd9cb9a5b43513b14419b224,
        0x1aef2a02704379e38ead4d53d69e4cc4,
    });
    try testType(@Vector(4, u128), .{
        0xc74437a4ea3bbbb193dbf0ea2f0c5281,
        0x039e4b1640868248780db1834a0027eb,
        0xb9e8bb34155b2b238da20331d08ff85b,
        0x863802d34a54c2e6aa71dd0f067c4904,
    }, .{
        0x7471bae24ff7b84ab107f86ba2b7d1e7,
        0x8f34c449d0576e682c20bda74aa6b6c9,
        0x1f34c3efa167b61c48c9d5ec01a1a93f,
        0x71c8318fcf3ddc7be058c73a52dce9e3,
    });
    try testType(@Vector(8, u128), .{
        0xbf2db71463037f55ee338431f902a906,
        0xb7ad317626655f38ab25ae30d8a1aa67,
        0x7d3c5a3ffaa607b5560d69ae3fcf7863,
        0x009a39a8badf8b628c686dc176aa1273,
        0x49dba3744c91304cc7bbbdab61b6c969,
        0x6ec664b624f7acf79ce69d80ed7bc85c,
        0xe02d7a303c0f00c39010f3b815547f1c,
        0xb13e1ee914616f58cffe6acd33d9b5c8,
    }, .{
        0x2f2d355a071942a7384f82ba72a945b8,
        0x61f151b3afec8cb7664f813cecf581d1,
        0x5bfbf5484f3a07f0eacc4739ff48af80,
        0x59c0abbf8d829cf525a87d5c9c41a38a,
        0xdad8b18eb680f0520ca49ebfb5842e22,
        0xa05adcaedd9057480b3ba0413d003cec,
        0x8b0b4a27fc94a0e90652d19bc755b63d,
        0xa858bce5ad0e48c13588a4e170e8667c,
    });

    try testType(@Vector(1, u256), .{
        0x28df37e1f57a56133ba3f5b5b2164ce24eb6c29a8973a597fd91fbee8ab4bafb,
    }, .{
        0x63f725028cab082b5b1e6cb474428c8c3655cf438f3bb05c7a87f8270198f357,
    });
    try testType(@Vector(2, u256), .{
        0xcc79740b85597ef411e6d7e92049dfaa2328781ea4911540a3dcb512b71c7f3c,
        0x51ae46d2f93cbecff1578481f6ddc633dacee94ecaf81597c752c5c5db0ae766,
    }, .{
        0x257f0107305cb71cef582a9a58612a019f335e390d7998f51f5898f245874a6e,
        0x0a95a17323a4d16a715720f122b752785e9877e3dd3d3f9b72cdac3d1139a81f,
    });
    try testType(@Vector(4, u256), .{
        0x19667a6e269342cba437a8904c7ba42a762358d32723723ae2637b01124e63c5,
        0x14f7d3599a7edc7bcc46874f68d4291793e6ef72bd1f3763bc5e923f54f2f781,
        0x1c939de0ae980b80de773a04088ba45813441336cdfdc281ee356c98d71f653b,
        0x39f5d755965382fe13d1b1d6690b8e3827f153f8166768c4ad8a28a963b781f2,
    }, .{
        0xbe03de37cdcb8126083b4e86cd8a9803121d31b186fd5ce555ad77ce624dd6c7,
        0xa0c0730f0d7f141cc959849d09730b049f00693361539f1bc4758270554a60c1,
        0x2664bdba8de4eaa36ecee72f6bfec5b4daa6b4e00272d8116f2cc532c29490cc,
        0xe47a122bd45d5e7d69722d864a6b795ddee965a0993094f8791dd309d692de8b,
    });

    try testType(@Vector(1, u512), .{
        0x651058c1d89a8f34cfc5e66b6d25294eecfcc4a7e1e4a356eb51ee7d7b2db25378e4afee51b7d18d16e520772a60c50a02d7966f40ced1870b32c658e5821397,
    }, .{
        0xd726e265ec80cb99510ba4f480ca64e959de5c528a7f54c386ecad22eeeefa845f0fd44b1bd64258a5f868197ee2d8fed59df9c9f0b72e74051a7ff20230880e,
    });
    try testType(@Vector(2, u512), .{
        0x22c8183c95cca8b09fdf541e431b73e9e4a1a5a00dff12381937fab52681d09d38ea25727d7025a2be08942cfa01535759e1644792e347c7901ec94b343c6337,
        0x292fdf644e75927e1aea9465ae2f60fb27550cd095f1afdea2cf7855286d26fbeed1c0b9c0474b73cb6b75621f7eadaa2f94ec358179ce2aaa0766df20da1ef3,
    }, .{
        0xe1cd8c0ca244c6626d4415e10b4ac43fa69e454c529c24fec4b13e6b945684d4ea833709c16c636ca78cffa5c5bf0fe945cd714a9ad695184a6bdad31dec9e31,
        0x8fa3d86099e9e2789d72f8e792290356d659ab20ac0414ff94745984c6ae7d986082197bb849889f912e896670aa2c1a11bd7e66e3f650710b0f0a18a1533f90,
    });

    try testType(@Vector(1, u1024), .{
        0x0ca1a0dfaf8bb1da714b457d23c71aef948e66c7cd45c0aa941498a796fb18502ec32f34e885d0a107d44ae81595f8b52c2f0fb38e584b7139903a0e8a823ae20d01ca0662722dd474e7efc40f32d74cc065d97d8a09d0447f1ab6107fa0a57f3f8c866ae872506627ce82f18add79cee8dc69837f4ead3ca770c4d622d7e544,
    }, .{
        0xf1e3bbe031d59351770a7a501b6e969b2c00d144f17648db3f944b69dfeb7be72e5ff933a061eba4eaa422f8ca09e5a97d0b0dd740fd4076eba8c72d7a278523f399202dc2d043c4e0eb58a2bcd4066e2146e321810b1ee4d3afdddb4f026bcc7905ce17e033a7727b4e08f33b53c63d8c9f763fc6c31d0523eb38c30d5e40bc,
    });
}

inline fn bitNot(comptime Type: type, rhs: Type) @TypeOf(~rhs) {
    return ~rhs;
}
test bitNot {
    try testUnary(bitNot);
}

inline fn clz(comptime Type: type, rhs: Type) @TypeOf(@clz(rhs)) {
    return @clz(rhs);
}
test clz {
    try testUnary(clz);
}

inline fn bitAnd(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs & rhs) {
    return lhs & rhs;
}
test bitAnd {
    try testBinary(bitAnd);
}

inline fn bitOr(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs | rhs) {
    return lhs | rhs;
}
test bitOr {
    try testBinary(bitOr);
}

inline fn bitXor(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs ^ rhs) {
    return lhs ^ rhs;
}
test bitXor {
    try testBinary(bitXor);
}

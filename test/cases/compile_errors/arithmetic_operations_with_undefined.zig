const U8Vec = @Vector(3, u8);
const FloatVec = @Vector(1, f32);

comptime {
    const a: U8Vec = .{ undefined, 0, undefined };
    const b: U8Vec = @splat(1);
    const c: FloatVec = .{undefined};
    @compileLog(a >> b);
    @compileLog(b >> a);
    @compileLog(a << b);
    @compileLog(b << a);
    @compileLog(@shlExact(a, b));
    @compileLog(@shlExact(b, a));
    @compileLog(@shlWithOverflow(a, b));
    @compileLog(@shlWithOverflow(b, a));
    @compileLog(@shrExact(a, b));
    @compileLog(@shrExact(b, a));
    @compileLog(@subWithOverflow(a, b));
    @compileLog(@sin(c));
    @compileLog(@cos(c));
    @compileLog(@tan(c));
    @compileLog(@exp(c));
    @compileLog(@exp2(c));
    @compileLog(@log(c));
    @compileLog(@log2(c));
    @compileLog(@log10(c));
    @compileLog(@abs(a));
    @compileLog(@abs(c));
    @compileLog(@floor(c));
    @compileLog(@ceil(c));
    @compileLog(@round(c));
    @compileLog(@trunc(c));
    @compileLog(@mod(a, b));
    @compileLog(@rem(a, b));
    @compileLog(@mulAdd(FloatVec, c, c, c));
    @compileLog(@byteSwap(a));
    @compileLog(@bitReverse(a));
    @compileLog(@clz(a));
    @compileLog(@ctz(a));
    @compileLog(@popCount(a));
}

// error
// backend=stage2
// target=native
//
// :8:5: error: found compile log statement
//
// Compile Log Output:
// @as(@Vector(3, u8), .{ undefined, 0, undefined })
// @as(@Vector(3, u8), .{ undefined, 1, undefined })
// @as(@Vector(3, u8), .{ undefined, 0, undefined })
// @as(@Vector(3, u8), .{ undefined, 1, undefined })
// @as(@Vector(3, u8), .{ undefined, 0, undefined })
// @as(@Vector(3, u8), .{ undefined, 1, undefined })
// @as(struct { @Vector(3, u8), @Vector(3, u1) }, .{ .{ undefined, 0, undefined }, .{ undefined, 0, undefined } })
// @as(struct { @Vector(3, u8), @Vector(3, u1) }, .{ .{ undefined, 1, undefined }, .{ undefined, 0, undefined } })
// @as(@Vector(3, u8), .{ undefined, 0, undefined })
// @as(@Vector(3, u8), .{ undefined, 1, undefined })
// @as(struct { @Vector(3, u8), @Vector(3, u1) }, .{ .{ undefined, 255, undefined }, .{ undefined, 1, undefined } })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(3, u8), .{ undefined, 0, undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(3, u8), .{ undefined, 0, undefined })
// @as(@Vector(3, u8), .{ undefined, 0, undefined })
// @as(@Vector(1, f32), .{ undefined })
// @as(@Vector(3, u8), .{ undefined, 0, undefined })
// @as(@Vector(3, u8), .{ undefined, 0, undefined })
// @as(@Vector(3, u4), .{ undefined, 8, undefined })
// @as(@Vector(3, u4), .{ undefined, 8, undefined })
// @as(@Vector(3, u4), .{ undefined, 0, undefined })

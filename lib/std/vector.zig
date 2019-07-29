const builtin = @import("builtin");

pub fn all(vector: var) bool {
    if (@typeId(@typeOf(vector)) != builtin.TypeId.Vector or @typeId(@typeOf(vector[0])) != builtin.TypeId.Bool) {
        @compileError("all() can only be used on vectors of bools, got '" + @typeName(vector) + "'");
    }
    comptime var len = @typeOf(vector).len;
    comptime var i: usize = 0;
    var result: bool = true;
    inline while (i < len) : (i += 1) {
        result = result and vector[i];
    }
    return result;
}

pub fn any(vector: var) bool {
    if (@typeId(@typeOf(vector)) != builtin.TypeId.Vector or @typeId(@typeOf(vector[0])) != builtin.TypeId.Bool) {
        @compileError("any() and none() can only be used on vectors of bools, got '" + @typeName(vector) + "'");
    }
    comptime var len = @typeOf(vector).len;
    comptime var i: usize = 0;
    var result: bool = false;
    inline while (i < len) : (i += 1) {
        result = result or vector[i];
    }
    return result;
}

pub fn none(vector: var) bool {
    return !any(vector);
}

test "std.vector.any,all,none" {
    const expect = @import("std").testing.expect;
    var a: @Vector(2, bool) = [_]bool{false, false};
    var b: @Vector(2, bool) = [_]bool{false, true};
    var c: @Vector(2, bool) = [_]bool{true, true};
    expect(none(a));
    expect(any(b));
    expect(all(c));
    expect(!none(b));
    expect(!any(a));
    expect(!all(b));
}

// TODO allow the type to be scalar, requires inferred return types
pub fn select(comptime T: type, a: T, b: T, mask: var) T {
    if (@typeId(@typeOf(mask)) != builtin.TypeId.Vector or @typeId(@typeOf(mask[0])) != builtin.TypeId.Bool) {
        @compileError("select mask must be a vector of bools, got '" + @typeName(mask) + "'");
    }
    comptime var vlen: usize = undefined;
    // FIXME comptime var for types
    comptime var v: bool = false;
    if (@typeId(T) == builtin.TypeId.Vector) {
        vlen = T.len;
        v = true;
    } else {
        vlen = mask.len;
    }
    if (@typeId(@typeOf(a)) != builtin.TypeId.Vector or (if (v) @typeInfo(T).Vector.child else T) != @typeOf(a[0]) or
        @typeId(@typeOf(b)) != builtin.TypeId.Vector or (if (v) @typeInfo(T).Vector.child else T) != @typeOf(b[0])) {
        @compileError("bad types to select");
    }
    comptime var bitWidth: usize = 0;
    if (@typeId(@typeOf(a[0])) == builtin.TypeId.Int) {
        bitWidth = @typeOf(a[0]).bit_count;
    } else if (@typeId(@typeOf(a[0])) == builtin.TypeId.Float) {
        bitWidth = @typeOf(a[0]).bit_count;
    } else if (@typeId(@typeOf(a[0])) == builtin.TypeId.Pointer) {
        bitWidth = @sizeOf(usize) * 8;
    } else if (@typeId(@typeOf(a[0])) == builtin.TypeId.Bool) {
        bitWidth = 1;
    }
    const signedScalarType = @IntType(true, bitWidth);
    var expandedMask = @intCast(signedScalarType, @bitCast(i1, @boolToInt(mask)));
    return @bitCast(@typeOf(a), ((@bitCast(signedScalarType, a) & ~expandedMask) | (@bitCast(signedScalarType, b) & expandedMask)));
}

test "std.vector.select" {
    const S = struct {
        fn doTheTest() void {
            const expect = @import("std").testing.expect;
            var mask: @Vector(4, bool) = [_]bool{false, true, false, true};
            var a: @Vector(4, u32) = [_]u32{1, 2, 3, 4};
            var b: @Vector(4, u32) = [_]u32{5, 6, 7, 8};
            var c = select(@Vector(4, u32), a, b, mask);
            expect(c[0] == 1);
            expect(c[1] == 6);
            expect(c[2] == 3);
            expect(c[3] == 8);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

const std = @import("std");

fn getIntShiftType(comptime T: type) type {
    const int = @typeInfo(T).Int;
    var bits = 1;
    while (int.bits > (1 << bits)) {
        bits += 1;
    }
    return @Type(std.builtin.Type {
        .Int = .{
            .bits = bits,
            .signedness = .signed
        }
    });
}

pub fn FixedPoint(comptime value_type: type) type {
    return struct {
        value: value_type,
        exponent: ShiftType,

        const ShiftType: type = getIntShiftType(value_type);

        pub fn shiftExponent(self: @This(), shift: ShiftType) @This() {
            const shiftAbs = @abs(shift);
            return .{
                .value = if (shift >= 0) self.value >> shiftAbs else self.value <<| shiftAbs,
                .exponent = self.exponent + shift
            };
        }
    };
}

test "Segfault when compiling Saturating Shift Left where lhs is of a computed type" {
    const FP = FixedPoint(i32);

    _ = (FP {
        .value = 1,
        .exponent = 1,
    }).shiftExponent(1);
}

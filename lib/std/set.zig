const std = @import("std");
const assert = std.debug.assert;
const warn = std.debug.warn;

pub fn Set(comptime ElemType: type) type {
    switch(@typeInfo(ElemType)) {
        .Int => |type_info| {
            if(type_info.bits > 16) {
                @compileError("Set element type cannot be larger than 16 bits");
            } else {
                if(type_info.is_signed == false) {
                    return struct {
                        const Self = @This();
                        // bit width of the set is the max value of ElemType, hard coded to 65535 for 16 bit integers
                        const InternalInt = @IntType(false, if(type_info.bits == 16) 65535 else 1 << type_info.bits);

                        raw: InternalInt,

                        fn initSlice(slice: []ElemType) Self {
                            var raw: InternalInt = 0;
                            for(slice) |index| {
                                raw |= InternalInt(1) << index;
                            }
                            return Self{ .raw = raw };
                        }

                        fn initInt(int: InternalInt) Self {
                            return Self{ .raw = int };
                        }

                        fn has(self: Self, index: ElemType) bool {
                            return if((self.raw >> index) & 1 == 1) true else false;
                        }
                    };
                } else {
                    return struct {
                        const Self = @This();
                        const InternalInt = @IntType(false, -std.math.minInt(ElemType) + std.math.maxInt(ElemType));
                        const ElemTypeUnsigned = @IntType(false, @typeInfo(ElemType).Int.bits);

                        raw: InternalInt,

                        fn initSlice(slice: []ElemType) Self {
                            var raw: InternalInt = 0;
                            for(slice) |index| {
                                raw |= InternalInt(1) << @intCast(ElemTypeUnsigned, @intCast(isize, index) + std.math.maxInt(ElemType));
                            }
                            return Self{ .raw = raw };
                        }

                        fn initInt(int: InternalInt) Self {
                            return Self{ .raw = int };
                        }

                        fn has(self: Self, index: ElemType) bool {
                            return if((self.raw >> @intCast(ElemTypeUnsigned, @intCast(isize, index) + std.math.maxInt(ElemType))) & 1 == 1) true else false;
                        }
                    };
                }
            }
        },
        else => @compileError("Type '" ++ @typeName(ElemType) ++ "' is not allowed as an element type for a set")
    }
}
// set union
pub fn uni(comptime T: type, set1: Set(T), set2: Set(T)) Set(T) {
    return Set(T).initInt(set1.raw | set2.raw);
}

// set intersection
pub fn inter(comptime T: type, set1: Set(T), set2: Set(T)) Set(T) {
    return Set(T).initInt(set1.raw & set2.raw);
}

// set complement
pub fn comp(comptime T: type, subject: Set(T)) Set(T) {
    return Set(T).initInt(~subject.raw);
}

// set equality
pub fn eql(comptime T: type, set1: Set(T), set2: Set(T)) bool {
    return set1.raw == set2.raw;
}

// checks whether set1 is a subset of set2
fn sub(comptime T: type, set1: Set(T), set2: Set(T)) bool {
    return set1.raw | set2.raw == set2.raw and !eql(T, set1, set2);
}

//set difference
pub fn dif(comptime T: type, set1: Set(T), set2: Set(T)) Set(T) {
    return Set(T).initInt(set1.raw ^ set2.raw);
}

test "max width set" {
    const set = Set(u16);
}

test "max width set signed" {
    const set = Set(i16);
}

test "set operations" {
    var data1 = [_]u1{0, 1};
    var set1 = Set(u1).initSlice(data1[0..]);
    var data2 = [_]u1{1};
    var set2 = Set(u1).initSlice(data2[0..]);
    assert(set1.has(0) == true and set2.has(1) == true);
    assert(set2.has(0) == false and set2.has(1) == true);
    assert(uni(u1, set1, set2).raw == 0b11);
    assert(inter(u1, set1, set2).raw == 0b10);
    assert(comp(u1, set1).raw == 0b00);
    assert(comp(u1, set2).raw == 0b01);
    assert(sub(u1, set2, set1) == true);
    assert(dif(u1, set1, set2).raw == 0b01);
}

test "signed base type sets" {
    var data = [_]i8{-1, 0, 1};
    var set = Set(i8).initSlice(data[0..]);   
    assert(set.has(-1) == true);
    assert(set.has(0) == true);
    assert(set.has(1) == true);
    assert(set.has(5) == false);
    assert(set.has(-5) == false);
}

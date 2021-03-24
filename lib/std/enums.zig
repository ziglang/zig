// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! This module contains utilities and data structures for working with enums.

const std = @import("std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const EnumField = std.builtin.TypeInfo.EnumField;

/// Returns a struct with a field matching each unique named enum element.
/// If the enum is extern and has multiple names for the same value, only
/// the first name is used.  Each field is of type Data and has the provided
/// default, which may be undefined.
pub fn EnumFieldStruct(comptime E: type, comptime Data: type, comptime field_default: ?Data) type {
    const StructField = std.builtin.TypeInfo.StructField;
    var fields: []const StructField = &[_]StructField{};
    for (uniqueFields(E)) |field, i| {
        fields = fields ++ &[_]StructField{.{
            .name = field.name,
            .field_type = Data,
            .default_value = field_default,
            .is_comptime = false,
            .alignment = if (@sizeOf(Data) > 0) @alignOf(Data) else 0,
        }};
    }
    return @Type(.{ .Struct = .{
        .layout = .Auto,
        .fields = fields,
        .decls = &[_]std.builtin.TypeInfo.Declaration{},
        .is_tuple = false,
    } });
}

/// Looks up the supplied fields in the given enum type.
/// Uses only the field names, field values are ignored.
/// The result array is in the same order as the input.
pub fn valuesFromFields(comptime E: type, comptime fields: []const EnumField) []const E {
    comptime {
        var result: [fields.len]E = undefined;
        for (fields) |f, i| {
            result[i] = @field(E, f.name);
        }
        return &result;
    }
}

test "std.enums.valuesFromFields" {
    const E = extern enum { a, b, c, d = 0 };
    const fields = valuesFromFields(E, &[_]EnumField{
        .{ .name = "b", .value = undefined },
        .{ .name = "a", .value = undefined },
        .{ .name = "a", .value = undefined },
        .{ .name = "d", .value = undefined },
    });
    testing.expectEqual(E.b, fields[0]);
    testing.expectEqual(E.a, fields[1]);
    testing.expectEqual(E.d, fields[2]); // a == d
    testing.expectEqual(E.d, fields[3]);
}

/// Returns the set of all named values in the given enum, in
/// declaration order.
pub fn values(comptime E: type) []const E {
    return comptime valuesFromFields(E, @typeInfo(E).Enum.fields);
}

test "std.enum.values" {
    const E = extern enum { a, b, c, d = 0 };
    testing.expectEqualSlices(E, &.{ .a, .b, .c, .d }, values(E));
}

/// Returns the set of all unique named values in the given enum, in
/// declaration order.  For repeated values in extern enums, only the
/// first name for each value is included.
pub fn uniqueValues(comptime E: type) []const E {
    return comptime valuesFromFields(E, uniqueFields(E));
}

test "std.enum.uniqueValues" {
    const E = extern enum { a, b, c, d = 0, e, f = 3 };
    testing.expectEqualSlices(E, &.{ .a, .b, .c, .f }, uniqueValues(E));

    const F = enum { a, b, c };
    testing.expectEqualSlices(F, &.{ .a, .b, .c }, uniqueValues(F));
}

/// Returns the set of all unique field values in the given enum, in
/// declaration order.  For repeated values in extern enums, only the
/// first name for each value is included.
pub fn uniqueFields(comptime E: type) []const EnumField {
    comptime {
        const info = @typeInfo(E).Enum;
        const raw_fields = info.fields;
        // Only extern enums can contain duplicates,
        // so fast path other types.
        if (info.layout != .Extern) {
            return raw_fields;
        }

        var unique_fields: []const EnumField = &[_]EnumField{};
        outer: for (raw_fields) |candidate| {
            for (unique_fields) |u| {
                if (u.value == candidate.value)
                    continue :outer;
            }
            unique_fields = unique_fields ++ &[_]EnumField{candidate};
        }

        return unique_fields;
    }
}

/// Determines the length of a direct-mapped enum array, indexed by
/// @intCast(usize, @enumToInt(enum_value)).
/// If the enum is non-exhaustive, the resulting length will only be enough
/// to hold all explicit fields.
/// If the enum contains any fields with values that cannot be represented
/// by usize, a compile error is issued.  The max_unused_slots parameter limits
/// the total number of items which have no matching enum key (holes in the enum
/// numbering).  So for example, if an enum has values 1, 2, 5, and 6, max_unused_slots
/// must be at least 3, to allow unused slots 0, 3, and 4.
fn directEnumArrayLen(comptime E: type, comptime max_unused_slots: comptime_int) comptime_int {
    var max_value: comptime_int = -1;
    const max_usize: comptime_int = ~@as(usize, 0);
    const fields = uniqueFields(E);
    for (fields) |f| {
        if (f.value < 0) {
            @compileError("Cannot create a direct enum array for " ++ @typeName(E) ++ ", field ." ++ f.name ++ " has a negative value.");
        }
        if (f.value > max_value) {
            if (f.value > max_usize) {
                @compileError("Cannot create a direct enum array for " ++ @typeName(E) ++ ", field ." ++ f.name ++ " is larger than the max value of usize.");
            }
            max_value = f.value;
        }
    }

    const unused_slots = max_value + 1 - fields.len;
    if (unused_slots > max_unused_slots) {
        const unused_str = std.fmt.comptimePrint("{d}", .{unused_slots});
        const allowed_str = std.fmt.comptimePrint("{d}", .{max_unused_slots});
        @compileError("Cannot create a direct enum array for " ++ @typeName(E) ++ ". It would have " ++ unused_str ++ " unused slots, but only " ++ allowed_str ++ " are allowed.");
    }

    return max_value + 1;
}

/// Initializes an array of Data which can be indexed by
/// @intCast(usize, @enumToInt(enum_value)).
/// If the enum is non-exhaustive, the resulting array will only be large enough
/// to hold all explicit fields.
/// If the enum contains any fields with values that cannot be represented
/// by usize, a compile error is issued.  The max_unused_slots parameter limits
/// the total number of items which have no matching enum key (holes in the enum
/// numbering).  So for example, if an enum has values 1, 2, 5, and 6, max_unused_slots
/// must be at least 3, to allow unused slots 0, 3, and 4.
/// The init_values parameter must be a struct with field names that match the enum values.
/// If the enum has multiple fields with the same value, the name of the first one must
/// be used.
pub fn directEnumArray(
    comptime E: type,
    comptime Data: type,
    comptime max_unused_slots: comptime_int,
    init_values: EnumFieldStruct(E, Data, null),
) [directEnumArrayLen(E, max_unused_slots)]Data {
    return directEnumArrayDefault(E, Data, null, max_unused_slots, init_values);
}

test "std.enums.directEnumArray" {
    const E = enum(i4) { a = 4, b = 6, c = 2 };
    var runtime_false: bool = false;
    const array = directEnumArray(E, bool, 4, .{
        .a = true,
        .b = runtime_false,
        .c = true,
    });

    testing.expectEqual([7]bool, @TypeOf(array));
    testing.expectEqual(true, array[4]);
    testing.expectEqual(false, array[6]);
    testing.expectEqual(true, array[2]);
}

/// Initializes an array of Data which can be indexed by
/// @intCast(usize, @enumToInt(enum_value)).  The enum must be exhaustive.
/// If the enum contains any fields with values that cannot be represented
/// by usize, a compile error is issued.  The max_unused_slots parameter limits
/// the total number of items which have no matching enum key (holes in the enum
/// numbering).  So for example, if an enum has values 1, 2, 5, and 6, max_unused_slots
/// must be at least 3, to allow unused slots 0, 3, and 4.
/// The init_values parameter must be a struct with field names that match the enum values.
/// If the enum has multiple fields with the same value, the name of the first one must
/// be used.
pub fn directEnumArrayDefault(
    comptime E: type,
    comptime Data: type,
    comptime default: ?Data,
    comptime max_unused_slots: comptime_int,
    init_values: EnumFieldStruct(E, Data, default),
) [directEnumArrayLen(E, max_unused_slots)]Data {
    const len = comptime directEnumArrayLen(E, max_unused_slots);
    var result: [len]Data = if (default) |d| [_]Data{d} ** len else undefined;
    inline for (@typeInfo(@TypeOf(init_values)).Struct.fields) |f, i| {
        const enum_value = @field(E, f.name);
        const index = @intCast(usize, @enumToInt(enum_value));
        result[index] = @field(init_values, f.name);
    }
    return result;
}

test "std.enums.directEnumArrayDefault" {
    const E = enum(i4) { a = 4, b = 6, c = 2 };
    var runtime_false: bool = false;
    const array = directEnumArrayDefault(E, bool, false, 4, .{
        .a = true,
        .b = runtime_false,
    });

    testing.expectEqual([7]bool, @TypeOf(array));
    testing.expectEqual(true, array[4]);
    testing.expectEqual(false, array[6]);
    testing.expectEqual(false, array[2]);
}

/// Cast an enum literal, value, or string to the enum value of type E
/// with the same name.
pub fn nameCast(comptime E: type, comptime value: anytype) E {
    comptime {
        const V = @TypeOf(value);
        if (V == E) return value;
        var name: ?[]const u8 = switch (@typeInfo(V)) {
            .EnumLiteral, .Enum => @tagName(value),
            .Pointer => if (std.meta.trait.isZigString(V)) value else null,
            else => null,
        };
        if (name) |n| {
            if (@hasField(E, n)) {
                return @field(E, n);
            }
            @compileError("Enum " ++ @typeName(E) ++ " has no field named " ++ n);
        }
        @compileError("Cannot cast from " ++ @typeName(@TypeOf(value)) ++ " to " ++ @typeName(E));
    }
}

test "std.enums.nameCast" {
    const A = enum { a = 0, b = 1 };
    const B = enum { a = 1, b = 0 };
    testing.expectEqual(A.a, nameCast(A, .a));
    testing.expectEqual(A.a, nameCast(A, A.a));
    testing.expectEqual(A.a, nameCast(A, B.a));
    testing.expectEqual(A.a, nameCast(A, "a"));
    testing.expectEqual(A.a, nameCast(A, @as(*const [1]u8, "a")));
    testing.expectEqual(A.a, nameCast(A, @as([:0]const u8, "a")));
    testing.expectEqual(A.a, nameCast(A, @as([]const u8, "a")));

    testing.expectEqual(B.a, nameCast(B, .a));
    testing.expectEqual(B.a, nameCast(B, A.a));
    testing.expectEqual(B.a, nameCast(B, B.a));
    testing.expectEqual(B.a, nameCast(B, "a"));

    testing.expectEqual(B.b, nameCast(B, .b));
    testing.expectEqual(B.b, nameCast(B, A.b));
    testing.expectEqual(B.b, nameCast(B, B.b));
    testing.expectEqual(B.b, nameCast(B, "b"));
}

/// A set of enum elements, backed by a bitfield.  If the enum
/// is not dense, a mapping will be constructed from enum values
/// to dense indices.  This type does no dynamic allocation and
/// can be copied by value.
pub fn EnumSet(comptime E: type) type {
    const mixin = struct {
        fn EnumSetExt(comptime Self: type) type {
            const Indexer = Self.Indexer;
            return struct {
                /// Initializes the set using a struct of bools
                pub fn init(init_values: EnumFieldStruct(E, bool, false)) Self {
                    var result = Self{};
                    comptime var i: usize = 0;
                    inline while (i < Self.len) : (i += 1) {
                        comptime const key = Indexer.keyForIndex(i);
                        comptime const tag = @tagName(key);
                        if (@field(init_values, tag)) {
                            result.bits.set(i);
                        }
                    }
                    return result;
                }
            };
        }
    };
    return IndexedSet(EnumIndexer(E), mixin.EnumSetExt);
}

/// A map keyed by an enum, backed by a bitfield and a dense array.
/// If the enum is not dense, a mapping will be constructed from
/// enum values to dense indices.  This type does no dynamic
/// allocation and can be copied by value.
pub fn EnumMap(comptime E: type, comptime V: type) type {
    const mixin = struct {
        fn EnumMapExt(comptime Self: type) type {
            const Indexer = Self.Indexer;
            return struct {
                /// Initializes the map using a sparse struct of optionals
                pub fn init(init_values: EnumFieldStruct(E, ?V, @as(?V, null))) Self {
                    var result = Self{};
                    comptime var i: usize = 0;
                    inline while (i < Self.len) : (i += 1) {
                        comptime const key = Indexer.keyForIndex(i);
                        comptime const tag = @tagName(key);
                        if (@field(init_values, tag)) |*v| {
                            result.bits.set(i);
                            result.values[i] = v.*;
                        }
                    }
                    return result;
                }
                /// Initializes a full mapping with all keys set to value.
                /// Consider using EnumArray instead if the map will remain full.
                pub fn initFull(value: V) Self {
                    var result = Self{
                        .bits = Self.BitSet.initFull(),
                        .values = undefined,
                    };
                    std.mem.set(V, &result.values, value);
                    return result;
                }
                /// Initializes a full mapping with supplied values.
                /// Consider using EnumArray instead if the map will remain full.
                pub fn initFullWith(init_values: EnumFieldStruct(E, V, @as(?V, null))) Self {
                    return initFullWithDefault(@as(?V, null), init_values);
                }
                /// Initializes a full mapping with a provided default.
                /// Consider using EnumArray instead if the map will remain full.
                pub fn initFullWithDefault(comptime default: ?V, init_values: EnumFieldStruct(E, V, default)) Self {
                    var result = Self{
                        .bits = Self.BitSet.initFull(),
                        .values = undefined,
                    };
                    comptime var i: usize = 0;
                    inline while (i < Self.len) : (i += 1) {
                        comptime const key = Indexer.keyForIndex(i);
                        comptime const tag = @tagName(key);
                        result.values[i] = @field(init_values, tag);
                    }
                    return result;
                }
            };
        }
    };
    return IndexedMap(EnumIndexer(E), V, mixin.EnumMapExt);
}

/// An array keyed by an enum, backed by a dense array.
/// If the enum is not dense, a mapping will be constructed from
/// enum values to dense indices.  This type does no dynamic
/// allocation and can be copied by value.
pub fn EnumArray(comptime E: type, comptime V: type) type {
    const mixin = struct {
        fn EnumArrayExt(comptime Self: type) type {
            const Indexer = Self.Indexer;
            return struct {
                /// Initializes all values in the enum array
                pub fn init(init_values: EnumFieldStruct(E, V, @as(?V, null))) Self {
                    return initDefault(@as(?V, null), init_values);
                }

                /// Initializes values in the enum array, with the specified default.
                pub fn initDefault(comptime default: ?V, init_values: EnumFieldStruct(E, V, default)) Self {
                    var result = Self{ .values = undefined };
                    comptime var i: usize = 0;
                    inline while (i < Self.len) : (i += 1) {
                        const key = comptime Indexer.keyForIndex(i);
                        const tag = @tagName(key);
                        result.values[i] = @field(init_values, tag);
                    }
                    return result;
                }
            };
        }
    };
    return IndexedArray(EnumIndexer(E), V, mixin.EnumArrayExt);
}

/// Pass this function as the Ext parameter to Indexed* if you
/// do not want to attach any extensions.  This parameter was
/// originally an optional, but optional generic functions
/// seem to be broken at the moment.
/// TODO: Once #8169 is fixed, consider switching this param
/// back to an optional.
pub fn NoExtension(comptime Self: type) type {
    return NoExt;
}
const NoExt = struct {};

/// A set type with an Indexer mapping from keys to indices.
/// Presence or absence is stored as a dense bitfield.  This
/// type does no allocation and can be copied by value.
pub fn IndexedSet(comptime I: type, comptime Ext: fn (type) type) type {
    comptime ensureIndexer(I);
    return struct {
        const Self = @This();

        pub usingnamespace Ext(Self);

        /// The indexing rules for converting between keys and indices.
        pub const Indexer = I;
        /// The element type for this set.
        pub const Key = Indexer.Key;

        const BitSet = std.StaticBitSet(Indexer.count);

        /// The maximum number of items in this set.
        pub const len = Indexer.count;

        bits: BitSet = BitSet.initEmpty(),

        /// Returns a set containing all possible keys.
        pub fn initFull() Self {
            return .{ .bits = BitSet.initFull() };
        }

        /// Returns the number of keys in the set.
        pub fn count(self: Self) usize {
            return self.bits.count();
        }

        /// Checks if a key is in the set.
        pub fn contains(self: Self, key: Key) bool {
            return self.bits.isSet(Indexer.indexOf(key));
        }

        /// Puts a key in the set.
        pub fn insert(self: *Self, key: Key) void {
            self.bits.set(Indexer.indexOf(key));
        }

        /// Removes a key from the set.
        pub fn remove(self: *Self, key: Key) void {
            self.bits.unset(Indexer.indexOf(key));
        }

        /// Changes the presence of a key in the set to match the passed bool.
        pub fn setPresent(self: *Self, key: Key, present: bool) void {
            self.bits.setValue(Indexer.indexOf(key), present);
        }

        /// Toggles the presence of a key in the set.  If the key is in
        /// the set, removes it.  Otherwise adds it.
        pub fn toggle(self: *Self, key: Key) void {
            self.bits.toggle(Indexer.indexOf(key));
        }

        /// Toggles the presence of all keys in the passed set.
        pub fn toggleSet(self: *Self, other: Self) void {
            self.bits.toggleSet(other.bits);
        }

        /// Toggles all possible keys in the set.
        pub fn toggleAll(self: *Self) void {
            self.bits.toggleAll();
        }

        /// Adds all keys in the passed set to this set.
        pub fn setUnion(self: *Self, other: Self) void {
            self.bits.setUnion(other.bits);
        }

        /// Removes all keys which are not in the passed set.
        pub fn setIntersection(self: *Self, other: Self) void {
            self.bits.setIntersection(other.bits);
        }

        /// Returns an iterator over this set, which iterates in
        /// index order.  Modifications to the set during iteration
        /// may or may not be observed by the iterator, but will
        /// not invalidate it.
        pub fn iterator(self: *Self) Iterator {
            return .{ .inner = self.bits.iterator(.{}) };
        }

        pub const Iterator = struct {
            inner: BitSet.Iterator(.{}),

            pub fn next(self: *Iterator) ?Key {
                return if (self.inner.next()) |index|
                    Indexer.keyForIndex(index)
                else
                    null;
            }
        };
    };
}

/// A map from keys to values, using an index lookup.  Uses a
/// bitfield to track presence and a dense array of values.
/// This type does no allocation and can be copied by value.
pub fn IndexedMap(comptime I: type, comptime V: type, comptime Ext: fn (type) type) type {
    comptime ensureIndexer(I);
    return struct {
        const Self = @This();

        pub usingnamespace Ext(Self);

        /// The index mapping for this map
        pub const Indexer = I;
        /// The key type used to index this map
        pub const Key = Indexer.Key;
        /// The value type stored in this map
        pub const Value = V;
        /// The number of possible keys in the map
        pub const len = Indexer.count;

        const BitSet = std.StaticBitSet(Indexer.count);

        /// Bits determining whether items are in the map
        bits: BitSet = BitSet.initEmpty(),
        /// Values of items in the map.  If the associated
        /// bit is zero, the value is undefined.
        values: [Indexer.count]Value = undefined,

        /// The number of items in the map.
        pub fn count(self: Self) usize {
            return self.bits.count();
        }

        /// Checks if the map contains an item.
        pub fn contains(self: Self, key: Key) bool {
            return self.bits.isSet(Indexer.indexOf(key));
        }

        /// Gets the value associated with a key.
        /// If the key is not in the map, returns null.
        pub fn get(self: Self, key: Key) ?Value {
            const index = Indexer.indexOf(key);
            return if (self.bits.isSet(index)) self.values[index] else null;
        }

        /// Gets the value associated with a key, which must
        /// exist in the map.
        pub fn getAssertContains(self: Self, key: Key) Value {
            const index = Indexer.indexOf(key);
            assert(self.bits.isSet(index));
            return self.values[index];
        }

        /// Gets the address of the value associated with a key.
        /// If the key is not in the map, returns null.
        pub fn getPtr(self: *Self, key: Key) ?*Value {
            const index = Indexer.indexOf(key);
            return if (self.bits.isSet(index)) &self.values[index] else null;
        }

        /// Gets the address of the const value associated with a key.
        /// If the key is not in the map, returns null.
        pub fn getPtrConst(self: *const Self, key: Key) ?*const Value {
            const index = Indexer.indexOf(key);
            return if (self.bits.isSet(index)) &self.values[index] else null;
        }

        /// Gets the address of the value associated with a key.
        /// The key must be present in the map.
        pub fn getPtrAssertContains(self: *Self, key: Key) *Value {
            const index = Indexer.indexOf(key);
            assert(self.bits.isSet(index));
            return &self.values[index];
        }

        /// Adds the key to the map with the supplied value.
        /// If the key is already in the map, overwrites the value.
        pub fn put(self: *Self, key: Key, value: Value) void {
            const index = Indexer.indexOf(key);
            self.bits.set(index);
            self.values[index] = value;
        }

        /// Adds the key to the map with an undefined value.
        /// If the key is already in the map, the value becomes undefined.
        /// A pointer to the value is returned, which should be
        /// used to initialize the value.
        pub fn putUninitialized(self: *Self, key: Key) *Value {
            const index = Indexer.indexOf(key);
            self.bits.set(index);
            self.values[index] = undefined;
            return &self.values[index];
        }

        /// Sets the value associated with the key in the map,
        /// and returns the old value.  If the key was not in
        /// the map, returns null.
        pub fn fetchPut(self: *Self, key: Key, value: Value) ?Value {
            const index = Indexer.indexOf(key);
            const result: ?Value = if (self.bits.isSet(index)) self.values[index] else null;
            self.bits.set(index);
            self.values[index] = value;
            return result;
        }

        /// Removes a key from the map.  If the key was not in the map,
        /// does nothing.
        pub fn remove(self: *Self, key: Key) void {
            const index = Indexer.indexOf(key);
            self.bits.unset(index);
            self.values[index] = undefined;
        }

        /// Removes a key from the map, and returns the old value.
        /// If the key was not in the map, returns null.
        pub fn fetchRemove(self: *Self, key: Key) ?Value {
            const index = Indexer.indexOf(key);
            const result: ?Value = if (self.bits.isSet(index)) self.values[index] else null;
            self.bits.unset(index);
            self.values[index] = undefined;
            return result;
        }

        /// Returns an iterator over the map, which visits items in index order.
        /// Modifications to the underlying map may or may not be observed by
        /// the iterator, but will not invalidate it.
        pub fn iterator(self: *Self) Iterator {
            return .{
                .inner = self.bits.iterator(.{}),
                .values = &self.values,
            };
        }

        /// An entry in the map.
        pub const Entry = struct {
            /// The key associated with this entry.
            /// Modifying this key will not change the map.
            key: Key,

            /// A pointer to the value in the map associated
            /// with this key.  Modifications through this
            /// pointer will modify the underlying data.
            value: *Value,
        };

        pub const Iterator = struct {
            inner: BitSet.Iterator(.{}),
            values: *[Indexer.count]Value,

            pub fn next(self: *Iterator) ?Entry {
                return if (self.inner.next()) |index|
                    Entry{
                        .key = Indexer.keyForIndex(index),
                        .value = &self.values[index],
                    }
                else
                    null;
            }
        };
    };
}

/// A dense array of values, using an indexed lookup.
/// This type does no allocation and can be copied by value.
pub fn IndexedArray(comptime I: type, comptime V: type, comptime Ext: fn (type) type) type {
    comptime ensureIndexer(I);
    return struct {
        const Self = @This();

        pub usingnamespace Ext(Self);

        /// The index mapping for this map
        pub const Indexer = I;
        /// The key type used to index this map
        pub const Key = Indexer.Key;
        /// The value type stored in this map
        pub const Value = V;
        /// The number of possible keys in the map
        pub const len = Indexer.count;

        values: [Indexer.count]Value,

        pub fn initUndefined() Self {
            return Self{ .values = undefined };
        }

        pub fn initFill(v: Value) Self {
            var self: Self = undefined;
            std.mem.set(Value, &self.values, v);
            return self;
        }

        /// Returns the value in the array associated with a key.
        pub fn get(self: Self, key: Key) Value {
            return self.values[Indexer.indexOf(key)];
        }

        /// Returns a pointer to the slot in the array associated with a key.
        pub fn getPtr(self: *Self, key: Key) *Value {
            return &self.values[Indexer.indexOf(key)];
        }

        /// Returns a const pointer to the slot in the array associated with a key.
        pub fn getPtrConst(self: *const Self, key: Key) *const Value {
            return &self.values[Indexer.indexOf(key)];
        }

        /// Sets the value in the slot associated with a key.
        pub fn set(self: *Self, key: Key, value: Value) void {
            self.values[Indexer.indexOf(key)] = value;
        }

        /// Iterates over the items in the array, in index order.
        pub fn iterator(self: *Self) Iterator {
            return .{
                .values = &self.values,
            };
        }

        /// An entry in the array.
        pub const Entry = struct {
            /// The key associated with this entry.
            /// Modifying this key will not change the array.
            key: Key,

            /// A pointer to the value in the array associated
            /// with this key.  Modifications through this
            /// pointer will modify the underlying data.
            value: *Value,
        };

        pub const Iterator = struct {
            index: usize = 0,
            values: *[Indexer.count]Value,

            pub fn next(self: *Iterator) ?Entry {
                const index = self.index;
                if (index < Indexer.count) {
                    self.index += 1;
                    return Entry{
                        .key = Indexer.keyForIndex(index),
                        .value = &self.values[index],
                    };
                }
                return null;
            }
        };
    };
}

/// Verifies that a type is a valid Indexer, providing a helpful
/// compile error if not.  An Indexer maps a comptime known set
/// of keys to a dense set of zero-based indices.
/// The indexer interface must look like this:
/// ```
/// struct {
///     /// The key type which this indexer converts to indices
///     pub const Key: type,
///     /// The number of indexes in the dense mapping
///     pub const count: usize,
///     /// Converts from a key to an index
///     pub fn indexOf(Key) usize;
///     /// Converts from an index to a key
///     pub fn keyForIndex(usize) Key;
/// }
/// ```
pub fn ensureIndexer(comptime T: type) void {
    comptime {
        if (!@hasDecl(T, "Key")) @compileError("Indexer must have decl Key: type.");
        if (@TypeOf(T.Key) != type) @compileError("Indexer.Key must be a type.");
        if (!@hasDecl(T, "count")) @compileError("Indexer must have decl count: usize.");
        if (@TypeOf(T.count) != usize) @compileError("Indexer.count must be a usize.");
        if (!@hasDecl(T, "indexOf")) @compileError("Indexer.indexOf must be a fn(Key)usize.");
        if (@TypeOf(T.indexOf) != fn (T.Key) usize) @compileError("Indexer must have decl indexOf: fn(Key)usize.");
        if (!@hasDecl(T, "keyForIndex")) @compileError("Indexer must have decl keyForIndex: fn(usize)Key.");
        if (@TypeOf(T.keyForIndex) != fn (usize) T.Key) @compileError("Indexer.keyForIndex must be a fn(usize)Key.");
    }
}

test "std.enums.ensureIndexer" {
    ensureIndexer(struct {
        pub const Key = u32;
        pub const count: usize = 8;
        pub fn indexOf(k: Key) usize {
            return @intCast(usize, k);
        }
        pub fn keyForIndex(index: usize) Key {
            return @intCast(Key, index);
        }
    });
}

fn ascByValue(ctx: void, comptime a: EnumField, comptime b: EnumField) bool {
    return a.value < b.value;
}
pub fn EnumIndexer(comptime E: type) type {
    if (!@typeInfo(E).Enum.is_exhaustive) {
        @compileError("Cannot create an enum indexer for a non-exhaustive enum.");
    }

    const const_fields = uniqueFields(E);
    var fields = const_fields[0..const_fields.len].*;
    if (fields.len == 0) {
        return struct {
            pub const Key = E;
            pub const count: usize = 0;
            pub fn indexOf(e: E) usize {
                unreachable;
            }
            pub fn keyForIndex(i: usize) E {
                unreachable;
            }
        };
    }
    std.sort.sort(EnumField, &fields, {}, ascByValue);
    const min = fields[0].value;
    const max = fields[fields.len - 1].value;
    if (max - min == fields.len - 1) {
        return struct {
            pub const Key = E;
            pub const count = fields.len;
            pub fn indexOf(e: E) usize {
                return @intCast(usize, @enumToInt(e) - min);
            }
            pub fn keyForIndex(i: usize) E {
                // TODO fix addition semantics.  This calculation
                // gives up some safety to avoid artificially limiting
                // the range of signed enum values to max_isize.
                const enum_value = if (min < 0) @bitCast(isize, i) +% min else i + min;
                return @intToEnum(E, @intCast(std.meta.Tag(E), enum_value));
            }
        };
    }

    const keys = valuesFromFields(E, &fields);

    return struct {
        pub const Key = E;
        pub const count = fields.len;
        pub fn indexOf(e: E) usize {
            for (keys) |k, i| {
                if (k == e) return i;
            }
            unreachable;
        }
        pub fn keyForIndex(i: usize) E {
            return keys[i];
        }
    };
}

test "std.enums.EnumIndexer dense zeroed" {
    const E = enum { b = 1, a = 0, c = 2 };
    const Indexer = EnumIndexer(E);
    ensureIndexer(Indexer);
    testing.expectEqual(E, Indexer.Key);
    testing.expectEqual(@as(usize, 3), Indexer.count);

    testing.expectEqual(@as(usize, 0), Indexer.indexOf(.a));
    testing.expectEqual(@as(usize, 1), Indexer.indexOf(.b));
    testing.expectEqual(@as(usize, 2), Indexer.indexOf(.c));

    testing.expectEqual(E.a, Indexer.keyForIndex(0));
    testing.expectEqual(E.b, Indexer.keyForIndex(1));
    testing.expectEqual(E.c, Indexer.keyForIndex(2));
}

test "std.enums.EnumIndexer dense positive" {
    const E = enum(u4) { c = 6, a = 4, b = 5 };
    const Indexer = EnumIndexer(E);
    ensureIndexer(Indexer);
    testing.expectEqual(E, Indexer.Key);
    testing.expectEqual(@as(usize, 3), Indexer.count);

    testing.expectEqual(@as(usize, 0), Indexer.indexOf(.a));
    testing.expectEqual(@as(usize, 1), Indexer.indexOf(.b));
    testing.expectEqual(@as(usize, 2), Indexer.indexOf(.c));

    testing.expectEqual(E.a, Indexer.keyForIndex(0));
    testing.expectEqual(E.b, Indexer.keyForIndex(1));
    testing.expectEqual(E.c, Indexer.keyForIndex(2));
}

test "std.enums.EnumIndexer dense negative" {
    const E = enum(i4) { a = -6, c = -4, b = -5 };
    const Indexer = EnumIndexer(E);
    ensureIndexer(Indexer);
    testing.expectEqual(E, Indexer.Key);
    testing.expectEqual(@as(usize, 3), Indexer.count);

    testing.expectEqual(@as(usize, 0), Indexer.indexOf(.a));
    testing.expectEqual(@as(usize, 1), Indexer.indexOf(.b));
    testing.expectEqual(@as(usize, 2), Indexer.indexOf(.c));

    testing.expectEqual(E.a, Indexer.keyForIndex(0));
    testing.expectEqual(E.b, Indexer.keyForIndex(1));
    testing.expectEqual(E.c, Indexer.keyForIndex(2));
}

test "std.enums.EnumIndexer sparse" {
    const E = enum(i4) { a = -2, c = 6, b = 4 };
    const Indexer = EnumIndexer(E);
    ensureIndexer(Indexer);
    testing.expectEqual(E, Indexer.Key);
    testing.expectEqual(@as(usize, 3), Indexer.count);

    testing.expectEqual(@as(usize, 0), Indexer.indexOf(.a));
    testing.expectEqual(@as(usize, 1), Indexer.indexOf(.b));
    testing.expectEqual(@as(usize, 2), Indexer.indexOf(.c));

    testing.expectEqual(E.a, Indexer.keyForIndex(0));
    testing.expectEqual(E.b, Indexer.keyForIndex(1));
    testing.expectEqual(E.c, Indexer.keyForIndex(2));
}

test "std.enums.EnumIndexer repeats" {
    const E = extern enum { a = -2, c = 6, b = 4, b2 = 4 };
    const Indexer = EnumIndexer(E);
    ensureIndexer(Indexer);
    testing.expectEqual(E, Indexer.Key);
    testing.expectEqual(@as(usize, 3), Indexer.count);

    testing.expectEqual(@as(usize, 0), Indexer.indexOf(.a));
    testing.expectEqual(@as(usize, 1), Indexer.indexOf(.b));
    testing.expectEqual(@as(usize, 2), Indexer.indexOf(.c));

    testing.expectEqual(E.a, Indexer.keyForIndex(0));
    testing.expectEqual(E.b, Indexer.keyForIndex(1));
    testing.expectEqual(E.c, Indexer.keyForIndex(2));
}

test "std.enums.EnumSet" {
    const E = extern enum { a, b, c, d, e = 0 };
    const Set = EnumSet(E);
    testing.expectEqual(E, Set.Key);
    testing.expectEqual(EnumIndexer(E), Set.Indexer);
    testing.expectEqual(@as(usize, 4), Set.len);

    // Empty sets
    const empty = Set{};
    comptime testing.expect(empty.count() == 0);

    var empty_b = Set.init(.{});
    testing.expect(empty_b.count() == 0);

    const empty_c = comptime Set.init(.{});
    comptime testing.expect(empty_c.count() == 0);

    const full = Set.initFull();
    testing.expect(full.count() == Set.len);

    const full_b = comptime Set.initFull();
    comptime testing.expect(full_b.count() == Set.len);

    testing.expectEqual(false, empty.contains(.a));
    testing.expectEqual(false, empty.contains(.b));
    testing.expectEqual(false, empty.contains(.c));
    testing.expectEqual(false, empty.contains(.d));
    testing.expectEqual(false, empty.contains(.e));
    {
        var iter = empty_b.iterator();
        testing.expectEqual(@as(?E, null), iter.next());
    }

    var mut = Set.init(.{
        .a = true,
        .c = true,
    });
    testing.expectEqual(@as(usize, 2), mut.count());
    testing.expectEqual(true, mut.contains(.a));
    testing.expectEqual(false, mut.contains(.b));
    testing.expectEqual(true, mut.contains(.c));
    testing.expectEqual(false, mut.contains(.d));
    testing.expectEqual(true, mut.contains(.e)); // aliases a
    {
        var it = mut.iterator();
        testing.expectEqual(@as(?E, .a), it.next());
        testing.expectEqual(@as(?E, .c), it.next());
        testing.expectEqual(@as(?E, null), it.next());
    }

    mut.toggleAll();
    testing.expectEqual(@as(usize, 2), mut.count());
    testing.expectEqual(false, mut.contains(.a));
    testing.expectEqual(true, mut.contains(.b));
    testing.expectEqual(false, mut.contains(.c));
    testing.expectEqual(true, mut.contains(.d));
    testing.expectEqual(false, mut.contains(.e)); // aliases a
    {
        var it = mut.iterator();
        testing.expectEqual(@as(?E, .b), it.next());
        testing.expectEqual(@as(?E, .d), it.next());
        testing.expectEqual(@as(?E, null), it.next());
    }

    mut.toggleSet(Set.init(.{ .a = true, .b = true }));
    testing.expectEqual(@as(usize, 2), mut.count());
    testing.expectEqual(true, mut.contains(.a));
    testing.expectEqual(false, mut.contains(.b));
    testing.expectEqual(false, mut.contains(.c));
    testing.expectEqual(true, mut.contains(.d));
    testing.expectEqual(true, mut.contains(.e)); // aliases a

    mut.setUnion(Set.init(.{ .a = true, .b = true }));
    testing.expectEqual(@as(usize, 3), mut.count());
    testing.expectEqual(true, mut.contains(.a));
    testing.expectEqual(true, mut.contains(.b));
    testing.expectEqual(false, mut.contains(.c));
    testing.expectEqual(true, mut.contains(.d));

    mut.remove(.c);
    mut.remove(.b);
    testing.expectEqual(@as(usize, 2), mut.count());
    testing.expectEqual(true, mut.contains(.a));
    testing.expectEqual(false, mut.contains(.b));
    testing.expectEqual(false, mut.contains(.c));
    testing.expectEqual(true, mut.contains(.d));

    mut.setIntersection(Set.init(.{ .a = true, .b = true }));
    testing.expectEqual(@as(usize, 1), mut.count());
    testing.expectEqual(true, mut.contains(.a));
    testing.expectEqual(false, mut.contains(.b));
    testing.expectEqual(false, mut.contains(.c));
    testing.expectEqual(false, mut.contains(.d));

    mut.insert(.a);
    mut.insert(.b);
    testing.expectEqual(@as(usize, 2), mut.count());
    testing.expectEqual(true, mut.contains(.a));
    testing.expectEqual(true, mut.contains(.b));
    testing.expectEqual(false, mut.contains(.c));
    testing.expectEqual(false, mut.contains(.d));

    mut.setPresent(.a, false);
    mut.toggle(.b);
    mut.toggle(.c);
    mut.setPresent(.d, true);
    testing.expectEqual(@as(usize, 2), mut.count());
    testing.expectEqual(false, mut.contains(.a));
    testing.expectEqual(false, mut.contains(.b));
    testing.expectEqual(true, mut.contains(.c));
    testing.expectEqual(true, mut.contains(.d));
}

test "std.enums.EnumArray void" {
    const E = extern enum { a, b, c, d, e = 0 };
    const ArrayVoid = EnumArray(E, void);
    testing.expectEqual(E, ArrayVoid.Key);
    testing.expectEqual(EnumIndexer(E), ArrayVoid.Indexer);
    testing.expectEqual(void, ArrayVoid.Value);
    testing.expectEqual(@as(usize, 4), ArrayVoid.len);

    const undef = ArrayVoid.initUndefined();
    var inst = ArrayVoid.initFill({});
    const inst2 = ArrayVoid.init(.{ .a = {}, .b = {}, .c = {}, .d = {} });
    const inst3 = ArrayVoid.initDefault({}, .{});

    _ = inst.get(.a);
    _ = inst.getPtr(.b);
    _ = inst.getPtrConst(.c);
    inst.set(.a, {});

    var it = inst.iterator();
    testing.expectEqual(E.a, it.next().?.key);
    testing.expectEqual(E.b, it.next().?.key);
    testing.expectEqual(E.c, it.next().?.key);
    testing.expectEqual(E.d, it.next().?.key);
    testing.expect(it.next() == null);
}

test "std.enums.EnumArray sized" {
    const E = extern enum { a, b, c, d, e = 0 };
    const Array = EnumArray(E, usize);
    testing.expectEqual(E, Array.Key);
    testing.expectEqual(EnumIndexer(E), Array.Indexer);
    testing.expectEqual(usize, Array.Value);
    testing.expectEqual(@as(usize, 4), Array.len);

    const undef = Array.initUndefined();
    var inst = Array.initFill(5);
    const inst2 = Array.init(.{ .a = 1, .b = 2, .c = 3, .d = 4 });
    const inst3 = Array.initDefault(6, .{ .b = 4, .c = 2 });

    testing.expectEqual(@as(usize, 5), inst.get(.a));
    testing.expectEqual(@as(usize, 5), inst.get(.b));
    testing.expectEqual(@as(usize, 5), inst.get(.c));
    testing.expectEqual(@as(usize, 5), inst.get(.d));

    testing.expectEqual(@as(usize, 1), inst2.get(.a));
    testing.expectEqual(@as(usize, 2), inst2.get(.b));
    testing.expectEqual(@as(usize, 3), inst2.get(.c));
    testing.expectEqual(@as(usize, 4), inst2.get(.d));

    testing.expectEqual(@as(usize, 6), inst3.get(.a));
    testing.expectEqual(@as(usize, 4), inst3.get(.b));
    testing.expectEqual(@as(usize, 2), inst3.get(.c));
    testing.expectEqual(@as(usize, 6), inst3.get(.d));

    testing.expectEqual(&inst.values[0], inst.getPtr(.a));
    testing.expectEqual(&inst.values[1], inst.getPtr(.b));
    testing.expectEqual(&inst.values[2], inst.getPtr(.c));
    testing.expectEqual(&inst.values[3], inst.getPtr(.d));

    testing.expectEqual(@as(*const usize, &inst.values[0]), inst.getPtrConst(.a));
    testing.expectEqual(@as(*const usize, &inst.values[1]), inst.getPtrConst(.b));
    testing.expectEqual(@as(*const usize, &inst.values[2]), inst.getPtrConst(.c));
    testing.expectEqual(@as(*const usize, &inst.values[3]), inst.getPtrConst(.d));

    inst.set(.c, 8);
    testing.expectEqual(@as(usize, 5), inst.get(.a));
    testing.expectEqual(@as(usize, 5), inst.get(.b));
    testing.expectEqual(@as(usize, 8), inst.get(.c));
    testing.expectEqual(@as(usize, 5), inst.get(.d));

    var it = inst.iterator();
    const Entry = Array.Entry;
    testing.expectEqual(@as(?Entry, Entry{
        .key = .a,
        .value = &inst.values[0],
    }), it.next());
    testing.expectEqual(@as(?Entry, Entry{
        .key = .b,
        .value = &inst.values[1],
    }), it.next());
    testing.expectEqual(@as(?Entry, Entry{
        .key = .c,
        .value = &inst.values[2],
    }), it.next());
    testing.expectEqual(@as(?Entry, Entry{
        .key = .d,
        .value = &inst.values[3],
    }), it.next());
    testing.expectEqual(@as(?Entry, null), it.next());
}

test "std.enums.EnumMap void" {
    const E = extern enum { a, b, c, d, e = 0 };
    const Map = EnumMap(E, void);
    testing.expectEqual(E, Map.Key);
    testing.expectEqual(EnumIndexer(E), Map.Indexer);
    testing.expectEqual(void, Map.Value);
    testing.expectEqual(@as(usize, 4), Map.len);

    const b = Map.initFull({});
    testing.expectEqual(@as(usize, 4), b.count());

    const c = Map.initFullWith(.{ .a = {}, .b = {}, .c = {}, .d = {} });
    testing.expectEqual(@as(usize, 4), c.count());

    const d = Map.initFullWithDefault({}, .{ .b = {} });
    testing.expectEqual(@as(usize, 4), d.count());

    var a = Map.init(.{ .b = {}, .d = {} });
    testing.expectEqual(@as(usize, 2), a.count());
    testing.expectEqual(false, a.contains(.a));
    testing.expectEqual(true, a.contains(.b));
    testing.expectEqual(false, a.contains(.c));
    testing.expectEqual(true, a.contains(.d));
    testing.expect(a.get(.a) == null);
    testing.expect(a.get(.b) != null);
    testing.expect(a.get(.c) == null);
    testing.expect(a.get(.d) != null);
    testing.expect(a.getPtr(.a) == null);
    testing.expect(a.getPtr(.b) != null);
    testing.expect(a.getPtr(.c) == null);
    testing.expect(a.getPtr(.d) != null);
    testing.expect(a.getPtrConst(.a) == null);
    testing.expect(a.getPtrConst(.b) != null);
    testing.expect(a.getPtrConst(.c) == null);
    testing.expect(a.getPtrConst(.d) != null);
    _ = a.getPtrAssertContains(.b);
    _ = a.getAssertContains(.d);

    a.put(.a, {});
    a.put(.a, {});
    a.putUninitialized(.c).* = {};
    a.putUninitialized(.c).* = {};

    testing.expectEqual(@as(usize, 4), a.count());
    testing.expect(a.get(.a) != null);
    testing.expect(a.get(.b) != null);
    testing.expect(a.get(.c) != null);
    testing.expect(a.get(.d) != null);

    a.remove(.a);
    _ = a.fetchRemove(.c);

    var iter = a.iterator();
    const Entry = Map.Entry;
    testing.expectEqual(E.b, iter.next().?.key);
    testing.expectEqual(E.d, iter.next().?.key);
    testing.expect(iter.next() == null);
}

test "std.enums.EnumMap sized" {
    const E = extern enum { a, b, c, d, e = 0 };
    const Map = EnumMap(E, usize);
    testing.expectEqual(E, Map.Key);
    testing.expectEqual(EnumIndexer(E), Map.Indexer);
    testing.expectEqual(usize, Map.Value);
    testing.expectEqual(@as(usize, 4), Map.len);

    const b = Map.initFull(5);
    testing.expectEqual(@as(usize, 4), b.count());
    testing.expect(b.contains(.a));
    testing.expect(b.contains(.b));
    testing.expect(b.contains(.c));
    testing.expect(b.contains(.d));
    testing.expectEqual(@as(?usize, 5), b.get(.a));
    testing.expectEqual(@as(?usize, 5), b.get(.b));
    testing.expectEqual(@as(?usize, 5), b.get(.c));
    testing.expectEqual(@as(?usize, 5), b.get(.d));

    const c = Map.initFullWith(.{ .a = 1, .b = 2, .c = 3, .d = 4 });
    testing.expectEqual(@as(usize, 4), c.count());
    testing.expect(c.contains(.a));
    testing.expect(c.contains(.b));
    testing.expect(c.contains(.c));
    testing.expect(c.contains(.d));
    testing.expectEqual(@as(?usize, 1), c.get(.a));
    testing.expectEqual(@as(?usize, 2), c.get(.b));
    testing.expectEqual(@as(?usize, 3), c.get(.c));
    testing.expectEqual(@as(?usize, 4), c.get(.d));

    const d = Map.initFullWithDefault(6, .{ .b = 2, .c = 4 });
    testing.expectEqual(@as(usize, 4), d.count());
    testing.expect(d.contains(.a));
    testing.expect(d.contains(.b));
    testing.expect(d.contains(.c));
    testing.expect(d.contains(.d));
    testing.expectEqual(@as(?usize, 6), d.get(.a));
    testing.expectEqual(@as(?usize, 2), d.get(.b));
    testing.expectEqual(@as(?usize, 4), d.get(.c));
    testing.expectEqual(@as(?usize, 6), d.get(.d));

    var a = Map.init(.{ .b = 2, .d = 4 });
    testing.expectEqual(@as(usize, 2), a.count());
    testing.expectEqual(false, a.contains(.a));
    testing.expectEqual(true, a.contains(.b));
    testing.expectEqual(false, a.contains(.c));
    testing.expectEqual(true, a.contains(.d));

    testing.expectEqual(@as(?usize, null), a.get(.a));
    testing.expectEqual(@as(?usize, 2), a.get(.b));
    testing.expectEqual(@as(?usize, null), a.get(.c));
    testing.expectEqual(@as(?usize, 4), a.get(.d));

    testing.expectEqual(@as(?*usize, null), a.getPtr(.a));
    testing.expectEqual(@as(?*usize, &a.values[1]), a.getPtr(.b));
    testing.expectEqual(@as(?*usize, null), a.getPtr(.c));
    testing.expectEqual(@as(?*usize, &a.values[3]), a.getPtr(.d));

    testing.expectEqual(@as(?*const usize, null), a.getPtrConst(.a));
    testing.expectEqual(@as(?*const usize, &a.values[1]), a.getPtrConst(.b));
    testing.expectEqual(@as(?*const usize, null), a.getPtrConst(.c));
    testing.expectEqual(@as(?*const usize, &a.values[3]), a.getPtrConst(.d));

    testing.expectEqual(@as(*const usize, &a.values[1]), a.getPtrAssertContains(.b));
    testing.expectEqual(@as(*const usize, &a.values[3]), a.getPtrAssertContains(.d));
    testing.expectEqual(@as(usize, 2), a.getAssertContains(.b));
    testing.expectEqual(@as(usize, 4), a.getAssertContains(.d));

    a.put(.a, 3);
    a.put(.a, 5);
    a.putUninitialized(.c).* = 7;
    a.putUninitialized(.c).* = 9;

    testing.expectEqual(@as(usize, 4), a.count());
    testing.expectEqual(@as(?usize, 5), a.get(.a));
    testing.expectEqual(@as(?usize, 2), a.get(.b));
    testing.expectEqual(@as(?usize, 9), a.get(.c));
    testing.expectEqual(@as(?usize, 4), a.get(.d));

    a.remove(.a);
    testing.expectEqual(@as(?usize, null), a.fetchRemove(.a));
    testing.expectEqual(@as(?usize, 9), a.fetchRemove(.c));
    a.remove(.c);

    var iter = a.iterator();
    const Entry = Map.Entry;
    testing.expectEqual(@as(?Entry, Entry{
        .key = .b,
        .value = &a.values[1],
    }), iter.next());
    testing.expectEqual(@as(?Entry, Entry{
        .key = .d,
        .value = &a.values[3],
    }), iter.next());
    testing.expectEqual(@as(?Entry, null), iter.next());
}

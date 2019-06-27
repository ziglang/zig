const builtin = @import("builtin");
const std = @import("std");
const meta = std.meta;
const debug = std.debug;

const SliceType = meta.SliceType;
const ArrayPointerType = meta.ArrayPointerType;

fn ArrayIterator(comptime T: type) type {
    comptime {
        if (ArrayPointerType(T) != T) {
            @compileError("ArrayIterator only accepts array pointer types (i.e. [*]u8) but got " ++ @typeName(T));
        }
    }
    return struct {
        ptr: T,
        limit: T,
        pub fn initPointers(ptr: T, limit: T) @This() {
            return @This() {
                .ptr = ptr,
                .limit = limit,
            };
        }
        pub fn initSlice(array: SliceType(T)) @This() {
            return initPointers(array.ptr, array.ptr + array.len);
        }
        pub fn next(self: *@This()) ?T.Child {
            if (self.ptr != self.limit) {
                self.ptr += 1;
                return (self.ptr - 1)[0];
            }
            return null;
        }
    };
}
fn arrayIterator(array: var) ArrayIterator(ArrayPointerType(@typeOf(array))) {
    return switch (@typeInfo(@typeOf(array))) {
        builtin.TypeId.Array => ArrayIterator(ArrayPointerType(@typeOf(array))).initSlice(array[0..]),
        builtin.TypeId.Pointer => ArrayIterator(ArrayPointerType(@typeOf(array))).initSlice(array),
        else => @compileError("arrayIterator does not accept this type"),
    };
}

// `expected` is an array of the expected items that will be enumerated by `iterator`
fn testIterator(expected: var, iterator: var) void {
    var expectedIndex : usize = 0;
    var mutableIterator = iterator;
    while (mutableIterator.next()) |actual| {
        debug.assert(expectedIndex < expected.len);
        debug.assert(expected[expectedIndex] == actual);
        expectedIndex += 1;
    }
    debug.assert(expectedIndex == expected.len);
}

test "ArrayIterator" {
    testIterator("a", arrayIterator("a"));
    testIterator("abcd", arrayIterator("abcd"));
    testIterator([_]u8 {9,1,4}, arrayIterator([_]u8 {9,1,4}));
}

// TODO: accept multiple arguments when language supports it
fn ArgsIterator(comptime T: type) type {
    return struct {
        arg: T,
        nextIndex: usize,
        pub fn init(arg: T) @This() {
            return @This() {
                .arg = arg,
                .nextIndex = 0,
            };
        }
        pub fn next(self: *@This()) ?T {
            if (self.nextIndex < 1) {
                self.nextIndex += 1;
                //return self.arg[self.nextIndex - 1];
                return self.arg;
            }
            return null;
        }
    };
}

/// Return an iterator that loops through the given arguments.
/// TODO: accept multiple arguments when language supports it
pub fn argsIterator(arg: var) ArgsIterator(@typeOf(arg)) {
    return ArgsIterator(@typeOf(arg)).init(arg);
}

test "argsIterator" {
    testIterator("a", argsIterator(@intCast(u8, 'a')));
    testIterator([_]usize {0}, argsIterator(@intCast(usize, 0)));

    // TODO: add support later when the language really supports some form
    //       of varargs/tuples/anon structs
    //testIterator("ab", argsIterator(@intCast(u8, 'a'), @intCast(u8, 'b')));
}

// TODO: accept more than 2 iterators once the language supports anon structs
fn ChainIterator(comptime T: type, comptime U: type) type {
    return struct {
        t: T,
        u: U,
        onU: bool,
        pub fn init(t: T, u: U) @This() {
            return @This() {
                .t = t,
                .u = u,
                .onU = false,
            };
        }
        pub fn next(self: *@This()) @typeOf(T.next).ReturnType {
            if (!self.onU) {
                if (self.t.next()) |tvalue| {
                    return tvalue;
                }
                self.onU = true;
            }
            return self.u.next();
        }
    };
}

/// Chain multiple iterators into one.
// TODO: accept more than 2 iterators once the language supports anon structs
pub fn chain(a: var, b: var) ChainIterator(@typeOf(a), @typeOf(b)) {
    return ChainIterator(@typeOf(a), @typeOf(b)).init(a, b);
}

test "chain" {
    testIterator("ab", chain(argsIterator(@intCast(u8, 'a')), argsIterator(@intCast(u8, 'b'))));
    testIterator([_]usize {0, 1}, chain(argsIterator(@intCast(usize, 0)), argsIterator(@intCast(usize, 1))));
}

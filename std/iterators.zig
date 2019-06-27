const builtin = @import("builtin");
const std = @import("std");
const debug = std.debug;

/// Given a pointer/array type, return the pointer type `[*]` variation.
fn ArrayPointerType(comptime T: type) type {
    const typeInfo = @typeInfo(T);
    switch (typeInfo) {
        builtin.TypeId.Array => {
            return [*]const typeInfo.Array.child;
        },
        builtin.TypeId.Pointer => {
            if (typeInfo.Pointer.is_const)
                return [*]const typeInfo.Pointer.child;
            return [*]typeInfo.Pointer.child;
        },
        else => @compileError("Can't interpret this type as an ArrayPointerType"),
    }
}




fn ArrayIterator(comptime T: type) type {
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
            return @This() {
                .ptr = array.ptr,
                .limit = array.ptr + array.len,
            };
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
    const typeInfo = @typeInfo(@typeOf(array));
    switch (typeInfo) {
        builtin.TypeId.Array => {
            //@compileError("not implemented");
            return ArrayIterator([*]const typeInfo.Array.child).initSlice(array[0..]);
        },
        builtin.TypeId.Pointer => {
            if (typeInfo.Pointer.is_const)
                return ArrayIterator([*]const typeInfo.Pointer.child).initSlice(array);
            return ArrayIterator([*]typeInfo.Pointer.child).initSlice(array);
        },
        else => @compileError("arrayIterator does not accept this type"),
    }
}

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
    testIterator([_]usize {0}, argsIterator(@intCast(usize, 0)));
}

// TODO: accept 2 or more iterators once the language can support it
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
/// TODO: accept 2 or more iterators once the language can support it
pub fn chain(a: var, b: var) ChainIterator(@typeOf(a), @typeOf(b)) {
    return ChainIterator(@typeOf(a), @typeOf(b)).init(a, b);
}

test "chain" {
//    testIterator(
//    {
//        var nextExpected : usize = 0;
//        var it = chain(argsIterator(@intCast(usize, 0)), argsIterator(@intCast(usize, 1)));
//        while (it.next()) |nextActual| {
//            debug.assert(nextExpected == nextActual);
//            nextExpected += 1;
//        }
//    }
//    {
//        var nextExpected : usize = 0;
//        var it = chain([_]usize {0,1,2}, argsIterator(@intCast(usize, 3)));
//        while (it.next()) |nextActual| {
//            debug.assert(nextExpected == nextActual);
//            nextExpected += 1;
//        }
//    }
}

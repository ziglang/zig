const std = @import("std");

pub export fn entry() void {
    var ohnoes: *usize = undefined;
    _ = sliceAsBytes(ohnoes);
    _ = &ohnoes;
}
fn sliceAsBytes(slice: anytype) isPtrTo(.array)(@TypeOf(slice)) {}

pub const TraitFn = fn (type) bool;

pub fn isPtrTo(comptime id: std.builtin.TypeId) TraitFn {
    const Closure = struct {
        pub fn trait(comptime T: type) bool {
            if (!comptime isSingleItemPtr(T)) return false;
            return id == @typeInfo(std.meta.Child(T));
        }
    };
    return Closure.trait;
}

pub fn isSingleItemPtr(comptime T: type) bool {
    if (comptime is(.pointer)(T)) {
        return @typeInfo(T).pointer.size == .One;
    }
    return false;
}

pub fn is(comptime id: std.builtin.TypeId) TraitFn {
    const Closure = struct {
        pub fn trait(comptime T: type) bool {
            return id == @typeInfo(T);
        }
    };
    return Closure.trait;
}

// error
// backend=llvm
// target=native
//
// :8:48: error: expected type 'type', found 'bool'

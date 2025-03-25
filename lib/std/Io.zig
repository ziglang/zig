const std = @import("std.zig");
const Io = @This();

userdata: ?*anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// If it returns `null` it means `result` has been already populated and
    /// `await` will be a no-op.
    @"async": *const fn (
        /// Corresponds to `Io.userdata`.
        userdata: ?*anyopaque,
        /// The pointer of this slice is an "eager" result value.
        /// The length is the size in bytes of the result type.
        eager_result: []u8,
        /// Passed to `start`.
        context: ?*anyopaque,
        start: *const fn (context: ?*anyopaque, result: *anyopaque) void,
    ) ?*AnyFuture,

    /// This function is only called when `async` returns a non-null value.
    @"await": *const fn (
        /// Corresponds to `Io.userdata`.
        userdata: ?*anyopaque,
        /// The same value that was returned from `async`.
        any_future: *AnyFuture,
        /// Points to a buffer where the result is written.
        /// The length is equal to size in bytes of result type.
        result: []u8,
    ) void,
};

pub const AnyFuture = opaque {};

pub fn Future(Result: type) type {
    return struct {
        any_future: ?*AnyFuture,
        result: Result,

        pub fn @"await"(f: *@This(), io: Io) Result {
            const any_future = f.any_future orelse return f.result;
            io.vtable.@"await"(io.userdata, any_future, @ptrCast((&f.result)[0..1]));
            f.any_future = null;
            return f.result;
        }
    };
}

/// `s` is a struct instance that contains a function like this:
/// ```
/// struct {
///     pub fn start(s: S) Result { ... }
/// }
/// ```
/// where `Result` is any type.
pub fn @"async"(io: Io, s: anytype) Future(@typeInfo(@TypeOf(@TypeOf(s).start)).@"fn".return_type.?) {
    const S = @TypeOf(s);
    const Result = @typeInfo(@TypeOf(S.start)).@"fn".return_type.?;
    const TypeErased = struct {
        fn start(context: ?*anyopaque, result: *anyopaque) void {
            const context_casted: *const S = @alignCast(@ptrCast(context));
            const result_casted: *Result = @ptrCast(@alignCast(result));
            result_casted.* = S.start(context_casted.*);
        }
    };
    var future: Future(Result) = undefined;
    future.any_future = io.vtable.@"async"(io.userdata, @ptrCast((&future.result)[0..1]), @constCast(&s), TypeErased.start);
    return future;
}

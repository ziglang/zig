const std = @import("std.zig");
const Io = @This();
const fs = std.fs;

pub const EventLoop = @import("Io/EventLoop.zig");

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
        /// This pointer's lifetime expires directly after the call to this function.
        result: []u8,
        result_alignment: std.mem.Alignment,
        /// Copied and then passed to `start`.
        context: []const u8,
        context_alignment: std.mem.Alignment,
        start: *const fn (context: *const anyopaque, result: *anyopaque) void,
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

    createFile: *const fn (?*anyopaque, dir: fs.Dir, sub_path: []const u8, flags: fs.File.CreateFlags) fs.File.OpenError!fs.File,
    openFile: *const fn (?*anyopaque, dir: fs.Dir, sub_path: []const u8, flags: fs.File.OpenFlags) fs.File.OpenError!fs.File,
    closeFile: *const fn (?*anyopaque, fs.File) void,
    read: *const fn (?*anyopaque, file: fs.File, buffer: []u8) fs.File.ReadError!usize,
    write: *const fn (?*anyopaque, file: fs.File, buffer: []const u8) fs.File.WriteError!usize,
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
pub fn @"async"(io: Io, S: type, s: S) Future(@typeInfo(@TypeOf(S.start)).@"fn".return_type.?) {
    const Result = @typeInfo(@TypeOf(S.start)).@"fn".return_type.?;
    const TypeErased = struct {
        fn start(context: *const anyopaque, result: *anyopaque) void {
            const context_casted: *const S = @alignCast(@ptrCast(context));
            const result_casted: *Result = @ptrCast(@alignCast(result));
            result_casted.* = S.start(context_casted.*);
        }
    };
    var future: Future(Result) = undefined;
    future.any_future = io.vtable.@"async"(
        io.userdata,
        @ptrCast((&future.result)[0..1]),
        .fromByteUnits(@alignOf(Result)),
        if (@sizeOf(S) == 0) &.{} else @ptrCast((&s)[0..1]), // work around compiler bug
        .fromByteUnits(@alignOf(S)),
        TypeErased.start,
    );
    return future;
}

pub fn openFile(io: Io, dir: fs.Dir, sub_path: []const u8, flags: fs.File.OpenFlags) fs.File.OpenError!fs.File {
    return io.vtable.openFile(io.userdata, dir, sub_path, flags);
}

pub fn createFile(io: Io, dir: fs.Dir, sub_path: []const u8, flags: fs.File.CreateFlags) fs.File.OpenError!fs.File {
    return io.vtable.createFile(io.userdata, dir, sub_path, flags);
}

pub fn closeFile(io: Io, file: fs.File) void {
    return io.vtable.closeFile(io.userdata, file);
}

pub fn read(io: Io, file: fs.File, buffer: []u8) fs.File.ReadError!usize {
    return io.vtable.read(io.userdata, file, buffer);
}

pub fn write(io: Io, file: fs.File, buffer: []const u8) fs.File.WriteError!usize {
    return io.vtable.write(io.userdata, file, buffer);
}

pub fn writeAll(io: Io, file: fs.File, bytes: []const u8) fs.File.WriteError!void {
    var index: usize = 0;
    while (index < bytes.len) {
        index += try io.write(file, bytes[index..]);
    }
}

pub fn readAll(io: Io, file: fs.File, buffer: []u8) fs.File.ReadError!usize {
    var index: usize = 0;
    while (index != buffer.len) {
        const amt = try io.read(file, buffer[index..]);
        if (amt == 0) break;
        index += amt;
    }
    return index;
}

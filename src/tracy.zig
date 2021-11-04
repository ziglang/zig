const std = @import("std");
const builtin = @import("builtin");

pub const enable = if (builtin.is_test) false else @import("build_options").enable_tracy;
pub const enable_allocation = enable and @import("build_options").enable_tracy_allocation;
pub const enable_callstack = enable and @import("build_options").enable_tracy_callstack;

// TODO: make this configurable
const callstack_depth = 10;

const ___tracy_c_zone_context = extern struct {
    id: u32,
    active: c_int,

    pub inline fn end(self: @This()) void {
        ___tracy_emit_zone_end(self);
    }

    pub inline fn addText(self: @This(), text: []const u8) void {
        ___tracy_emit_zone_text(self, text.ptr, text.len);
    }

    pub inline fn setName(self: @This(), name: []const u8) void {
        ___tracy_emit_zone_name(self, name.ptr, name.len);
    }

    pub inline fn setColor(self: @This(), color: u32) void {
        ___tracy_emit_zone_color(self, color);
    }

    pub inline fn setValue(self: @This(), value: u64) void {
        ___tracy_emit_zone_value(self, value);
    }
};

pub const Ctx = if (enable) ___tracy_c_zone_context else struct {
    pub inline fn end(self: @This()) void {
        _ = self;
    }

    pub inline fn addText(self: @This(), text: []const u8) void {
        _ = self;
        _ = text;
    }

    pub inline fn setName(self: @This(), name: []const u8) void {
        _ = self;
        _ = name;
    }

    pub inline fn setColor(self: @This(), color: u32) void {
        _ = self;
        _ = color;
    }

    pub inline fn setValue(self: @This(), value: u64) void {
        _ = self;
        _ = value;
    }
};

pub inline fn trace(comptime src: std.builtin.SourceLocation) Ctx {
    if (!enable) return .{};

    if (enable_callstack) {
        return ___tracy_emit_zone_begin_callstack(&.{
            .name = null,
            .function = src.fn_name.ptr,
            .file = src.file.ptr,
            .line = src.line,
            .color = 0,
        }, callstack_depth, 1);
    } else {
        return ___tracy_emit_zone_begin(&.{
            .name = null,
            .function = src.fn_name.ptr,
            .file = src.file.ptr,
            .line = src.line,
            .color = 0,
        }, 1);
    }
}

pub inline fn traceNamed(comptime src: std.builtin.SourceLocation, comptime name: [:0]const u8) Ctx {
    if (!enable) return .{};

    if (enable_callstack) {
        return ___tracy_emit_zone_begin_callstack(&.{
            .name = name.ptr,
            .function = src.fn_name.ptr,
            .file = src.file.ptr,
            .line = src.line,
            .color = 0,
        }, callstack_depth, 1);
    } else {
        return ___tracy_emit_zone_begin(&.{
            .name = name.ptr,
            .function = src.fn_name.ptr,
            .file = src.file.ptr,
            .line = src.line,
            .color = 0,
        }, 1);
    }
}

pub fn tracyAllocator(allocator: *std.mem.Allocator) TracyAllocator(null) {
    return TracyAllocator(null).init(allocator);
}

pub fn TracyAllocator(comptime name: ?[:0]const u8) type {
    return struct {
        allocator: std.mem.Allocator,
        parent_allocator: *std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: *std.mem.Allocator) Self {
            return .{
                .parent_allocator = allocator,
                .allocator = .{
                    .allocFn = allocFn,
                    .resizeFn = resizeFn,
                },
            };
        }

        fn allocFn(allocator: *std.mem.Allocator, len: usize, ptr_align: u29, len_align: u29, ret_addr: usize) std.mem.Allocator.Error![]u8 {
            const self = @fieldParentPtr(Self, "allocator", allocator);
            const result = self.parent_allocator.allocFn(self.parent_allocator, len, ptr_align, len_align, ret_addr);
            if (result) |data| {
                if (data.len != 0) {
                    if (name) |n| {
                        allocNamed(data.ptr, data.len, n);
                    } else {
                        alloc(data.ptr, data.len);
                    }
                }
            } else |_| {
                messageColor("allocation failed", 0xFF0000);
            }
            return result;
        }

        fn resizeFn(allocator: *std.mem.Allocator, buf: []u8, buf_align: u29, new_len: usize, len_align: u29, ret_addr: usize) std.mem.Allocator.Error!usize {
            const self = @fieldParentPtr(Self, "allocator", allocator);

            if (self.parent_allocator.resizeFn(self.parent_allocator, buf, buf_align, new_len, len_align, ret_addr)) |resized_len| {
                // this condition is to handle free being called on an empty slice that was never even allocated
                // example case: `std.process.getSelfExeSharedLibPaths` can return `&[_][:0]u8{}`
                if (buf.len != 0) {
                    if (name) |n| {
                        freeNamed(buf.ptr, n);
                    } else {
                        free(buf.ptr);
                    }
                }

                if (resized_len != 0) {
                    // this was a shrink or a resize
                    if (name) |n| {
                        allocNamed(buf.ptr, resized_len, n);
                    } else {
                        alloc(buf.ptr, resized_len);
                    }
                }

                return resized_len;
            } else |err| {
                // this is not really an error condition, during normal operation the compiler hits this case thousands of times
                // due to this emitting messages for it is both slow and causes clutter
                // messageColor("allocation resize failed", 0xFF0000);
                return err;
            }
        }
    };
}

// This function only accepts comptime known strings, see `messageCopy` for runtime strings
pub inline fn message(comptime msg: [:0]const u8) void {
    if (!enable) return;
    ___tracy_emit_messageL(msg.ptr, if (enable_callstack) callstack_depth else 0);
}

// This function only accepts comptime known strings, see `messageColorCopy` for runtime strings
pub inline fn messageColor(comptime msg: [:0]const u8, color: u32) void {
    if (!enable) return;
    ___tracy_emit_messageLC(msg.ptr, color, if (enable_callstack) callstack_depth else 0);
}

pub inline fn messageCopy(msg: []const u8) void {
    if (!enable) return;
    ___tracy_emit_message(msg.ptr, msg.len, if (enable_callstack) callstack_depth else 0);
}

pub inline fn messageColorCopy(msg: [:0]const u8, color: u32) void {
    if (!enable) return;
    ___tracy_emit_messageC(msg.ptr, msg.len, color, if (enable_callstack) callstack_depth else 0);
}

pub inline fn frameMark() void {
    if (!enable) return;
    ___tracy_emit_frame_mark(null);
}

pub inline fn frameMarkNamed(comptime name: [:0]const u8) void {
    if (!enable) return;
    ___tracy_emit_frame_mark(name.ptr);
}

pub inline fn namedFrame(comptime name: [:0]const u8) Frame(name) {
    frameMarkStart(name);
    return .{};
}

pub fn Frame(comptime name: [:0]const u8) type {
    return struct {
        pub fn end(_: @This()) void {
            frameMarkEnd(name);
        }
    };
}

inline fn frameMarkStart(comptime name: [:0]const u8) void {
    if (!enable) return;
    ___tracy_emit_frame_mark_start(name.ptr);
}

inline fn frameMarkEnd(comptime name: [:0]const u8) void {
    if (!enable) return;
    ___tracy_emit_frame_mark_end(name.ptr);
}

extern fn ___tracy_emit_frame_mark_start(name: [*:0]const u8) void;
extern fn ___tracy_emit_frame_mark_end(name: [*:0]const u8) void;

inline fn alloc(ptr: [*]u8, len: usize) void {
    if (!enable) return;

    if (enable_callstack) {
        ___tracy_emit_memory_alloc_callstack(ptr, len, callstack_depth, 0);
    } else {
        ___tracy_emit_memory_alloc(ptr, len, 0);
    }
}

inline fn allocNamed(ptr: [*]u8, len: usize, comptime name: [:0]const u8) void {
    if (!enable) return;

    if (enable_callstack) {
        ___tracy_emit_memory_alloc_callstack_named(ptr, len, callstack_depth, 0, name.ptr);
    } else {
        ___tracy_emit_memory_alloc_named(ptr, len, 0, name.ptr);
    }
}

inline fn free(ptr: [*]u8) void {
    if (!enable) return;

    if (enable_callstack) {
        ___tracy_emit_memory_free_callstack(ptr, callstack_depth, 0);
    } else {
        ___tracy_emit_memory_free(ptr, 0);
    }
}

inline fn freeNamed(ptr: [*]u8, comptime name: [:0]const u8) void {
    if (!enable) return;

    if (enable_callstack) {
        ___tracy_emit_memory_free_callstack_named(ptr, callstack_depth, 0, name.ptr);
    } else {
        ___tracy_emit_memory_free_named(ptr, 0, name.ptr);
    }
}

extern fn ___tracy_emit_zone_begin(
    srcloc: *const ___tracy_source_location_data,
    active: c_int,
) ___tracy_c_zone_context;
extern fn ___tracy_emit_zone_begin_callstack(
    srcloc: *const ___tracy_source_location_data,
    depth: c_int,
    active: c_int,
) ___tracy_c_zone_context;
extern fn ___tracy_emit_zone_text(ctx: ___tracy_c_zone_context, txt: [*]const u8, size: usize) void;
extern fn ___tracy_emit_zone_name(ctx: ___tracy_c_zone_context, txt: [*]const u8, size: usize) void;
extern fn ___tracy_emit_zone_color(ctx: ___tracy_c_zone_context, color: u32) void;
extern fn ___tracy_emit_zone_value(ctx: ___tracy_c_zone_context, value: u64) void;
extern fn ___tracy_emit_zone_end(ctx: ___tracy_c_zone_context) void;
extern fn ___tracy_emit_memory_alloc(ptr: *const c_void, size: usize, secure: c_int) void;
extern fn ___tracy_emit_memory_alloc_callstack(ptr: *const c_void, size: usize, depth: c_int, secure: c_int) void;
extern fn ___tracy_emit_memory_free(ptr: *const c_void, secure: c_int) void;
extern fn ___tracy_emit_memory_free_callstack(ptr: *const c_void, depth: c_int, secure: c_int) void;
extern fn ___tracy_emit_memory_alloc_named(ptr: *const c_void, size: usize, secure: c_int, name: [*:0]const u8) void;
extern fn ___tracy_emit_memory_alloc_callstack_named(ptr: *const c_void, size: usize, depth: c_int, secure: c_int, name: [*:0]const u8) void;
extern fn ___tracy_emit_memory_free_named(ptr: *const c_void, secure: c_int, name: [*:0]const u8) void;
extern fn ___tracy_emit_memory_free_callstack_named(ptr: *const c_void, depth: c_int, secure: c_int, name: [*:0]const u8) void;
extern fn ___tracy_emit_message(txt: [*]const u8, size: usize, callstack: c_int) void;
extern fn ___tracy_emit_messageL(txt: [*:0]const u8, callstack: c_int) void;
extern fn ___tracy_emit_messageC(txt: [*]const u8, size: usize, color: u32, callstack: c_int) void;
extern fn ___tracy_emit_messageLC(txt: [*:0]const u8, color: u32, callstack: c_int) void;
extern fn ___tracy_emit_frame_mark(name: ?[*:0]const u8) void;

const ___tracy_source_location_data = extern struct {
    name: ?[*:0]const u8,
    function: [*:0]const u8,
    file: [*:0]const u8,
    line: u32,
    color: u32,
};

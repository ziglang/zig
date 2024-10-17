const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const otel = std.otel;

pub const enable = build_options.enable_tracy;
pub const enable_allocation = enable and build_options.enable_tracy_allocation;
pub const enable_callstack = enable and build_options.enable_tracy_callstack;

// TODO: make this configurable
const callstack_depth = 10;

pub const SPAN_TYPE = if (enable)
    ___tracy_c_zone_context
else
    otel.trace.NULL_SPAN_TYPE;

pub const TRACE_FUNCTIONS: otel.trace.Functions = if (enable) .{
    .tracer_enabled = tracerEnabled,
    .tracer_create_span = tracerCreateSpan,
    .tracer_create_span_source_location = tracerCreateSpanSourceLocation,

    .context_extract_span = contextExtractSpan,
    .context_with_span = contextWithSpan,

    .span_get_context = ___tracy_c_zone_context.getContext,
    .span_is_recording = ___tracy_c_zone_context.isRecording,
    .span_set_attribute = ___tracy_c_zone_context.setAttribute,
    .span_add_event = ___tracy_c_zone_context.addEvent,
    .span_add_link = ___tracy_c_zone_context.addLink,
    .span_set_status = ___tracy_c_zone_context.setStatus,
    .span_update_name = ___tracy_c_zone_context.updateName,
    .span_end = ___tracy_c_zone_context.end,
    .span_record_exception = ___tracy_c_zone_context.recordException,
} else otel.trace.NULL_FUNCTIONS;

pub fn tracerEnabled(comptime scope: otel.InstrumentationScope) bool {
    _ = scope;
    return build_options.enable;
}

pub fn tracerCreateSpan(
    comptime scope: otel.InstrumentationScope,
    comptime name: [:0]const u8,
    comptime src: ?std.builtin.SourceLocation,
    options: otel.trace.CreateSpanOptions,
) ___tracy_c_zone_context {
    _ = scope;
    _ = options;
    if (!enable) return;

    if (src == null) @compileError("error for trace \"" ++ name ++ "\": tracy requires source location");

    const global = struct {
        const loc: ___tracy_source_location_data = .{
            .name = name.ptr,
            .function = src.?.fn_name.ptr,
            .file = src.?.file.ptr,
            .line = src.?.line,
            .color = 0,
        };
    };

    if (enable_callstack) {
        return ___tracy_emit_zone_begin_callstack(&global.loc, callstack_depth, 1);
    } else {
        return ___tracy_emit_zone_begin(&global.loc, 1);
    }
}

pub fn tracerCreateSpanSourceLocation(
    comptime scope: otel.InstrumentationScope,
    comptime src: std.builtin.SourceLocation,
    options: otel.trace.CreateSpanOptions,
) ___tracy_c_zone_context {
    _ = scope;
    _ = options;
    if (!enable) return;

    const global = struct {
        const loc: ___tracy_source_location_data = .{
            .name = null,
            .function = src.fn_name.ptr,
            .file = src.file.ptr,
            .line = src.line,
            .color = 0,
        };
    };

    if (enable_callstack) {
        return ___tracy_emit_zone_begin_callstack(&global.loc, callstack_depth, 1);
    } else {
        return ___tracy_emit_zone_begin(&global.loc, 1);
    }
}

pub fn contextExtractSpan(context: otel.Context) ___tracy_c_zone_context {
    const ctx = otel.Context.getValue(context, ___tracy_c_zone_context) orelse return .NULL;
    return ctx;
}

pub fn contextWithSpan(context: otel.Context, zone_ctx: ___tracy_c_zone_context) otel.Context {
    return otel.Context.withValue(context, ___tracy_c_zone_context, zone_ctx);
}

const ___tracy_c_zone_context = extern struct {
    id: u32,
    active: c_int,

    pub const NULL = ___tracy_c_zone_context{ .id = 0, .active = 0 };

    pub fn getContext(self: @This()) otel.trace.SpanContext {
        _ = self;
        return otel.trace.SpanContext.INVALID;
    }

    pub fn isRecording(self: @This()) bool {
        if (!enable) return false;
        return self.active != 0;
    }

    pub fn setAttribute(self: @This(), attribute: otel.Attribute) void {
        _ = self;
        _ = attribute;
    }

    pub fn addEvent(self: @This(), options: otel.trace.AddEventOptions) void {
        _ = self;
        _ = options;
    }

    pub fn addLink(self: @This(), link: otel.trace.Link) void {
        _ = self;
        _ = link;
    }

    pub fn setStatus(self: @This(), status: otel.trace.Status) void {
        _ = self;
        _ = status;
    }

    pub fn updateName(self: @This(), name: []const u8) void {
        if (!enable) return false;
        ___tracy_emit_zone_name(self, name.ptr, name.len);
    }

    pub fn recordException(self: @This(), err: anyerror, stack_trace: ?std.builtin.StackTrace) void {
        _ = self;
        err catch {};
        _ = stack_trace;
    }

    pub fn end(self: @This(), end_timestamp: ?i128) void {
        _ = end_timestamp;
        ___tracy_emit_zone_end(self);
    }

    pub inline fn addText(self: @This(), text: []const u8) void {
        if (!enable) return false;
        ___tracy_emit_zone_text(self, text.ptr, text.len);
    }

    pub inline fn setColor(self: @This(), color: u32) void {
        if (!enable) return false;
        ___tracy_emit_zone_color(self, color);
    }

    pub inline fn setValue(self: @This(), value: u64) void {
        if (!enable) return false;
        ___tracy_emit_zone_value(self, value);
    }
};

pub fn tracyAllocator(allocator: std.mem.Allocator) TracyAllocator(null) {
    return TracyAllocator(null).init(allocator);
}

pub fn TracyAllocator(comptime name: ?[:0]const u8) type {
    return struct {
        parent_allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(parent_allocator: std.mem.Allocator) Self {
            return .{
                .parent_allocator = parent_allocator,
            };
        }

        pub fn allocator(self: *Self) std.mem.Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = allocFn,
                    .resize = resizeFn,
                    .free = freeFn,
                },
            };
        }

        fn allocFn(ptr: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ptr));
            const result = self.parent_allocator.rawAlloc(len, ptr_align, ret_addr);
            if (result) |data| {
                if (len != 0) {
                    if (name) |n| {
                        allocNamed(data, len, n);
                    } else {
                        alloc(data, len);
                    }
                }
            } else {
                messageColor("allocation failed", 0xFF0000);
            }
            return result;
        }

        fn resizeFn(ptr: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
            const self: *Self = @ptrCast(@alignCast(ptr));
            if (self.parent_allocator.rawResize(buf, buf_align, new_len, ret_addr)) {
                if (name) |n| {
                    freeNamed(buf.ptr, n);
                    allocNamed(buf.ptr, new_len, n);
                } else {
                    free(buf.ptr);
                    alloc(buf.ptr, new_len);
                }

                return true;
            }

            // during normal operation the compiler hits this case thousands of times due to this
            // emitting messages for it is both slow and causes clutter
            return false;
        }

        fn freeFn(ptr: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.parent_allocator.rawFree(buf, buf_align, ret_addr);
            // this condition is to handle free being called on an empty slice that was never even allocated
            // example case: `std.process.getSelfExeSharedLibPaths` can return `&[_][:0]u8{}`
            if (buf.len != 0) {
                if (name) |n| {
                    freeNamed(buf.ptr, n);
                } else {
                    free(buf.ptr);
                }
            }
        }
    };
}

// This function only accepts comptime-known strings, see `messageCopy` for runtime strings
pub inline fn message(comptime msg: [:0]const u8) void {
    if (!enable) return;
    ___tracy_emit_messageL(msg.ptr, if (enable_callstack) callstack_depth else 0);
}

// This function only accepts comptime-known strings, see `messageColorCopy` for runtime strings
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
extern fn ___tracy_emit_memory_alloc(ptr: *const anyopaque, size: usize, secure: c_int) void;
extern fn ___tracy_emit_memory_alloc_callstack(ptr: *const anyopaque, size: usize, depth: c_int, secure: c_int) void;
extern fn ___tracy_emit_memory_free(ptr: *const anyopaque, secure: c_int) void;
extern fn ___tracy_emit_memory_free_callstack(ptr: *const anyopaque, depth: c_int, secure: c_int) void;
extern fn ___tracy_emit_memory_alloc_named(ptr: *const anyopaque, size: usize, secure: c_int, name: [*:0]const u8) void;
extern fn ___tracy_emit_memory_alloc_callstack_named(ptr: *const anyopaque, size: usize, depth: c_int, secure: c_int, name: [*:0]const u8) void;
extern fn ___tracy_emit_memory_free_named(ptr: *const anyopaque, secure: c_int, name: [*:0]const u8) void;
extern fn ___tracy_emit_memory_free_callstack_named(ptr: *const anyopaque, depth: c_int, secure: c_int, name: [*:0]const u8) void;
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

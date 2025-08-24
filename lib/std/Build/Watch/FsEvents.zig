//! An implementation of file-system watching based on the `FSEventStream` API in macOS.
//! While macOS supports kqueue, it does not allow detecting changes to files without
//! placing watches on each individual file, meaning FD limits are reached incredibly
//! quickly. The File System Events API works differently: it implements *recursive*
//! directory watches, managed by a system service. Rather than being in libc, the API is
//! exposed by the CoreServices framework. To avoid a compile dependency on the framework
//! bundle, we dynamically load CoreServices with `std.DynLib`.
//!
//! While the logic in this file *is* specialized to `std.Build.Watch`, efforts have been
//! made to keep that specialization to a minimum. Other use cases could be served with
//! relatively minimal modifications to the `watch_paths` field and its usages (in
//! particular the `setPaths` function). We avoid using the global GCD dispatch queue in
//! favour of creating our own and synchronizing with an explicit semaphore, meaning this
//! logic is thread-safe and does not affect process-global state.
//!
//! In theory, this API is quite good at avoiding filesystem race conditions. In practice,
//! the logic that would avoid them is currently disabled, because the build system kind
//! of relies on them at the time of writing to avoid redundant work -- see the comment at
//! the top of `wait` for details.

const enable_debug_logs = false;

core_services: std.DynLib,
resolved_symbols: ResolvedSymbols,

paths_arena: std.heap.ArenaAllocator.State,
/// The roots of the recursive watches. FSEvents has relatively small limits on the number
/// of watched paths, so this slice must not be too long. The paths themselves are allocated
/// into `paths_arena`, but this slice is allocated into the GPA.
watch_roots: [][:0]const u8,
/// All of the paths being watched. Value is the set of steps which depend on the file/directory.
/// Keys and values are in `paths_arena`, but this map is allocated into the GPA.
watch_paths: std.StringArrayHashMapUnmanaged([]const *std.Build.Step),

/// The semaphore we use to block the thread calling `wait` until the callback determines a relevant
/// event has occurred. This is retained across `wait` calls for simplicity and efficiency.
waiting_semaphore: dispatch_semaphore_t,
/// This dispatch queue is created by us and executes serially. It exists exclusively to trigger the
/// callbacks of the FSEventStream we create. This is not in use outside of `wait`, but is retained
/// across `wait` calls for simplicity and efficiency.
dispatch_queue: dispatch_queue_t,
/// In theory, this field avoids race conditions. In practice, it is essentially unused at the time
/// of writing. See the comment at the start of `wait` for details.
since_event: FSEventStreamEventId,

/// All of the symbols we pull from the `dlopen`ed CoreServices framework. If any of these symbols
/// is not present, `init` will close the framework and return an error.
const ResolvedSymbols = struct {
    FSEventStreamCreate: *const fn (
        allocator: CFAllocatorRef,
        callback: FSEventStreamCallback,
        ctx: ?*const FSEventStreamContext,
        paths_to_watch: CFArrayRef,
        since_when: FSEventStreamEventId,
        latency: CFTimeInterval,
        flags: FSEventStreamCreateFlags,
    ) callconv(.c) FSEventStreamRef,
    FSEventStreamSetDispatchQueue: *const fn (stream: FSEventStreamRef, queue: dispatch_queue_t) callconv(.c) void,
    FSEventStreamStart: *const fn (stream: FSEventStreamRef) callconv(.c) bool,
    FSEventStreamStop: *const fn (stream: FSEventStreamRef) callconv(.c) void,
    FSEventStreamInvalidate: *const fn (stream: FSEventStreamRef) callconv(.c) void,
    FSEventStreamRelease: *const fn (stream: FSEventStreamRef) callconv(.c) void,
    FSEventStreamGetLatestEventId: *const fn (stream: ConstFSEventStreamRef) callconv(.c) FSEventStreamEventId,
    FSEventsGetCurrentEventId: *const fn () callconv(.c) FSEventStreamEventId,
    CFRelease: *const fn (cf: *const anyopaque) callconv(.c) void,
    CFArrayCreate: *const fn (
        allocator: CFAllocatorRef,
        values: [*]const usize,
        num_values: CFIndex,
        call_backs: ?*const CFArrayCallBacks,
    ) callconv(.c) CFArrayRef,
    CFStringCreateWithCString: *const fn (
        alloc: CFAllocatorRef,
        c_str: [*:0]const u8,
        encoding: CFStringEncoding,
    ) callconv(.c) CFStringRef,
    CFAllocatorCreate: *const fn (allocator: CFAllocatorRef, context: *const CFAllocatorContext) callconv(.c) CFAllocatorRef,
    kCFAllocatorUseContext: *const CFAllocatorRef,
};

pub fn init() error{ OpenFrameworkFailed, MissingCoreServicesSymbol }!FsEvents {
    var core_services = std.DynLib.open("/System/Library/Frameworks/CoreServices.framework/CoreServices") catch
        return error.OpenFrameworkFailed;
    errdefer core_services.close();

    var resolved_symbols: ResolvedSymbols = undefined;
    inline for (@typeInfo(ResolvedSymbols).@"struct".fields) |f| {
        @field(resolved_symbols, f.name) = core_services.lookup(f.type, f.name) orelse return error.MissingCoreServicesSymbol;
    }

    return .{
        .core_services = core_services,
        .resolved_symbols = resolved_symbols,
        .paths_arena = .{},
        .watch_roots = &.{},
        .watch_paths = .empty,
        .waiting_semaphore = dispatch_semaphore_create(0),
        .dispatch_queue = dispatch_queue_create("zig-watch", .SERIAL),
        // Not `.since_now`, because this means we can init `FsEvents` *before* we do work in order
        // to notice any changes which happened during said work.
        .since_event = resolved_symbols.FSEventsGetCurrentEventId(),
    };
}

pub fn deinit(fse: *FsEvents, gpa: Allocator) void {
    dispatch_release(fse.waiting_semaphore);
    dispatch_release(fse.dispatch_queue);
    fse.core_services.close();

    gpa.free(fse.watch_roots);
    fse.watch_paths.deinit(gpa);
    {
        var paths_arena = fse.paths_arena.promote(gpa);
        paths_arena.deinit();
    }
}

pub fn setPaths(fse: *FsEvents, gpa: Allocator, steps: []const *std.Build.Step) !void {
    var paths_arena_instance = fse.paths_arena.promote(gpa);
    defer fse.paths_arena = paths_arena_instance.state;
    const paths_arena = paths_arena_instance.allocator();

    const cwd_path = try std.process.getCwdAlloc(gpa);
    defer gpa.free(cwd_path);

    var need_dirs: std.StringArrayHashMapUnmanaged(void) = .empty;
    defer need_dirs.deinit(gpa);

    fse.watch_paths.clearRetainingCapacity();

    // We take `step` by pointer for a slight memory optimization in a moment.
    for (steps) |*step| {
        for (step.*.inputs.table.keys(), step.*.inputs.table.values()) |path, *files| {
            const resolved_dir = try std.fs.path.resolvePosix(paths_arena, &.{ cwd_path, path.root_dir.path orelse ".", path.sub_path });
            try need_dirs.put(gpa, resolved_dir, {});
            for (files.items) |file_name| {
                const watch_path = if (std.mem.eql(u8, file_name, "."))
                    resolved_dir
                else
                    try std.fs.path.join(paths_arena, &.{ resolved_dir, file_name });
                const gop = try fse.watch_paths.getOrPut(gpa, watch_path);
                if (gop.found_existing) {
                    const old_steps = gop.value_ptr.*;
                    const new_steps = try paths_arena.alloc(*std.Build.Step, old_steps.len + 1);
                    @memcpy(new_steps[0..old_steps.len], old_steps);
                    new_steps[old_steps.len] = step.*;
                    gop.value_ptr.* = new_steps;
                } else {
                    // This is why we captured `step` by pointer! We can avoid allocating a slice of one
                    // step in the arena in the common case where a file is referenced by only one step.
                    gop.value_ptr.* = step[0..1];
                }
            }
        }
    }

    {
        // There's no point looking at directories inside other ones (e.g. "/foo" and "/foo/bar").
        // To eliminate these, we'll re-add directories in order of path length with a redundancy check.
        const old_dirs = try gpa.dupe([]const u8, need_dirs.keys());
        defer gpa.free(old_dirs);
        std.mem.sort([]const u8, old_dirs, {}, struct {
            fn lessThan(ctx: void, a: []const u8, b: []const u8) bool {
                ctx;
                return std.mem.lessThan(u8, a, b);
            }
        }.lessThan);
        need_dirs.clearRetainingCapacity();
        for (old_dirs) |dir_path| {
            var it: std.fs.path.ComponentIterator(.posix, u8) = try .init(dir_path);
            while (it.next()) |component| {
                if (need_dirs.contains(component.path)) {
                    // this path is '/foo/bar/qux', but '/foo' or '/foo/bar' was already added
                    break;
                }
            } else {
                need_dirs.putAssumeCapacityNoClobber(dir_path, {});
            }
        }
    }

    // `need_dirs` is now a set of directories to watch with no redundancy. In practice, this is very
    // likely to have reduced it to a quite small set (e.g. it'll typically coalesce a full `src/`
    // directory into one entry). However, the FSEventStream API has a fairly low undocumented limit
    // on total watches (supposedly 4096), so we should handle the case where we exceed it. To be
    // safe, because this API can be a little unpredictable, we'll cap ourselves a little *below*
    // that known limit.
    if (need_dirs.count() > 2048) {
        // Fallback: watch the whole filesystem. This is excessive, but... it *works* :P
        if (enable_debug_logs) watch_log.debug("too many dirs; recursively watching root", .{});
        fse.watch_roots = try gpa.realloc(fse.watch_roots, 1);
        fse.watch_roots[0] = "/";
    } else {
        fse.watch_roots = try gpa.realloc(fse.watch_roots, need_dirs.count());
        for (fse.watch_roots, need_dirs.keys()) |*out, in| {
            out.* = try paths_arena.dupeZ(u8, in);
        }
    }
    if (enable_debug_logs) {
        watch_log.debug("watching {d} paths using {d} recursive watches:", .{ fse.watch_paths.count(), fse.watch_roots.len });
        for (fse.watch_roots) |dir_path| {
            watch_log.debug("- '{s}'", .{dir_path});
        }
    }
}

pub fn wait(fse: *FsEvents, gpa: Allocator, timeout_ns: ?u64) error{ OutOfMemory, StartFailed }!std.Build.Watch.WaitResult {
    if (fse.watch_roots.len == 0) @panic("nothing to watch");

    const rs = fse.resolved_symbols;

    // At the time of writing, using `since_event` in the obvious way causes redundant rebuilds
    // to occur, because one step modifies a file which is an input to another step. The solution
    // to this problem will probably be either:
    //
    // a) Don't include the output of one step as a watch input of another; only mark external
    //    files as watch inputs. Or...
    //
    // b) Note the current event ID when a step begins, and disregard events preceding that ID
    //    when considering whether to dirty that step in `eventCallback`.
    //
    // For now, to avoid the redundant rebuilds, we bypass this `since_event` mechanism. This does
    // introduce race conditions, but the other `std.Build.Watch` implementations suffer from those
    // too at the time of writing, so this is kind of expected.
    fse.since_event = .since_now;

    const cf_allocator = rs.CFAllocatorCreate(rs.kCFAllocatorUseContext.*, &.{
        .version = 0,
        .info = @constCast(&gpa),
        .retain = null,
        .release = null,
        .copy_description = null,
        .allocate = &cf_alloc_callbacks.allocate,
        .reallocate = &cf_alloc_callbacks.reallocate,
        .deallocate = &cf_alloc_callbacks.deallocate,
        .preferred_size = null,
    }) orelse return error.OutOfMemory;
    defer rs.CFRelease(cf_allocator);

    const cf_paths = try gpa.alloc(?CFStringRef, fse.watch_roots.len);
    @memset(cf_paths, null);
    defer {
        for (cf_paths) |o| if (o) |p| rs.CFRelease(p);
        gpa.free(cf_paths);
    }
    for (fse.watch_roots, cf_paths) |raw_path, *cf_path| {
        cf_path.* = rs.CFStringCreateWithCString(cf_allocator, raw_path, .utf8);
    }
    const cf_paths_array = rs.CFArrayCreate(cf_allocator, @ptrCast(cf_paths), @intCast(cf_paths.len), null);
    defer rs.CFRelease(cf_paths_array);

    const callback_ctx: EventCallbackCtx = .{
        .fse = fse,
        .gpa = gpa,
    };
    const event_stream = rs.FSEventStreamCreate(
        null,
        &eventCallback,
        &.{
            .version = 0,
            .info = @constCast(&callback_ctx),
            .retain = null,
            .release = null,
            .copy_description = null,
        },
        cf_paths_array,
        fse.since_event,
        0.05, // 0.05s latency; higher values increase efficiency by coalescing more events
        .{ .watch_root = true, .file_events = true },
    );
    defer rs.FSEventStreamRelease(event_stream);
    rs.FSEventStreamSetDispatchQueue(event_stream, fse.dispatch_queue);
    defer rs.FSEventStreamInvalidate(event_stream);
    if (!rs.FSEventStreamStart(event_stream)) return error.StartFailed;
    defer rs.FSEventStreamStop(event_stream);
    const result = dispatch_semaphore_wait(fse.waiting_semaphore, timeout: {
        const ns = timeout_ns orelse break :timeout .forever;
        break :timeout dispatch_time(.now, @intCast(ns));
    });
    return switch (result) {
        0 => .dirty,
        else => .timeout,
    };
}

const cf_alloc_callbacks = struct {
    const log = std.log.scoped(.cf_alloc);
    fn allocate(size: CFIndex, hint: CFOptionFlags, info: ?*const anyopaque) callconv(.c) ?*const anyopaque {
        if (enable_debug_logs) log.debug("allocate {d}", .{size});
        _ = hint;
        const gpa: *const Allocator = @ptrCast(@alignCast(info));
        const mem = gpa.alignedAlloc(u8, .of(usize), @intCast(size + @sizeOf(usize))) catch return null;
        const metadata: *usize = @ptrCast(mem);
        metadata.* = @intCast(size);
        return mem[@sizeOf(usize)..].ptr;
    }
    fn reallocate(ptr: ?*anyopaque, new_size: CFIndex, hint: CFOptionFlags, info: ?*const anyopaque) callconv(.c) ?*const anyopaque {
        if (enable_debug_logs) log.debug("reallocate @{*} {d}", .{ ptr, new_size });
        _ = hint;
        if (ptr == null or new_size == 0) return null; // not a bug: documentation explicitly states that realloc on NULL should return NULL
        const gpa: *const Allocator = @ptrCast(@alignCast(info));
        const old_base: [*]align(@alignOf(usize)) u8 = @alignCast(@as([*]u8, @ptrCast(ptr)) - @sizeOf(usize));
        const old_size = @as(*const usize, @ptrCast(old_base)).*;
        const old_mem = old_base[0 .. old_size + @sizeOf(usize)];
        const new_mem = gpa.realloc(old_mem, @intCast(new_size + @sizeOf(usize))) catch return null;
        const metadata: *usize = @ptrCast(new_mem);
        metadata.* = @intCast(new_size);
        return new_mem[@sizeOf(usize)..].ptr;
    }
    fn deallocate(ptr: *anyopaque, info: ?*const anyopaque) callconv(.c) void {
        if (enable_debug_logs) log.debug("deallocate @{*}", .{ptr});
        const gpa: *const Allocator = @ptrCast(@alignCast(info));
        const old_base: [*]align(@alignOf(usize)) u8 = @alignCast(@as([*]u8, @ptrCast(ptr)) - @sizeOf(usize));
        const old_size = @as(*const usize, @ptrCast(old_base)).*;
        const old_mem = old_base[0 .. old_size + @sizeOf(usize)];
        gpa.free(old_mem);
    }
};

const EventCallbackCtx = struct {
    fse: *FsEvents,
    gpa: Allocator,
};

fn eventCallback(
    stream: ConstFSEventStreamRef,
    client_callback_info: ?*anyopaque,
    num_events: usize,
    events_paths_ptr: *anyopaque,
    events_flags_ptr: [*]const FSEventStreamEventFlags,
    events_ids_ptr: [*]const FSEventStreamEventId,
) callconv(.c) void {
    const ctx: *const EventCallbackCtx = @ptrCast(@alignCast(client_callback_info));
    const fse = ctx.fse;
    const gpa = ctx.gpa;
    const rs = fse.resolved_symbols;
    const events_paths_ptr_casted: [*]const [*:0]const u8 = @ptrCast(@alignCast(events_paths_ptr));
    const events_paths = events_paths_ptr_casted[0..num_events];
    const events_ids = events_ids_ptr[0..num_events];
    const events_flags = events_flags_ptr[0..num_events];
    var any_dirty = false;
    for (events_paths, events_ids, events_flags) |event_path_nts, event_id, event_flags| {
        _ = event_id;
        if (event_flags.history_done) continue; // sentinel
        const event_path = std.mem.span(event_path_nts);
        switch (event_flags.must_scan_sub_dirs) {
            false => {
                if (fse.watch_paths.get(event_path)) |steps| {
                    assert(steps.len > 0);
                    for (steps) |s| dirtyStep(s, gpa, &any_dirty);
                }
                if (std.fs.path.dirname(event_path)) |event_dirname| {
                    // Modifying '/foo/bar' triggers the watch on '/foo'.
                    if (fse.watch_paths.get(event_dirname)) |steps| {
                        assert(steps.len > 0);
                        for (steps) |s| dirtyStep(s, gpa, &any_dirty);
                    }
                }
            },
            true => {
                // This is unlikely, but can occasionally happen when bottlenecked: events have been
                // coalesced into one. We want to see if any of these events are actually relevant
                // to us. The only way we can reasonably do that in this rare edge case is iterate
                // the watch paths and see if any is under this directory. That's acceptable because
                // we would otherwise kick off a rebuild which would be clearing those paths anyway.
                const changed_path = std.fs.path.dirname(event_path) orelse event_path;
                for (fse.watch_paths.keys(), fse.watch_paths.values()) |watching_path, steps| {
                    if (dirStartsWith(watching_path, changed_path)) {
                        for (steps) |s| dirtyStep(s, gpa, &any_dirty);
                    }
                }
            },
        }
    }
    if (any_dirty) {
        fse.since_event = rs.FSEventStreamGetLatestEventId(stream);
        _ = dispatch_semaphore_signal(fse.waiting_semaphore);
    }
}
fn dirtyStep(s: *std.Build.Step, gpa: Allocator, any_dirty: *bool) void {
    if (s.state == .precheck_done) return;
    s.recursiveReset(gpa);
    any_dirty.* = true;
}
fn dirStartsWith(path: []const u8, prefix: []const u8) bool {
    if (std.mem.eql(u8, path, prefix)) return true;
    if (!std.mem.startsWith(u8, path, prefix)) return false;
    if (path[prefix.len] != '/') return false; // `path` is `/foo/barx`, `prefix` is `/foo/bar`
    return true; // `path` is `/foo/bar/...`, `prefix` is `/foo/bar`
}

const dispatch_time_t = enum(u64) {
    now = 0,
    forever = std.math.maxInt(u64),
    _,
};
extern fn dispatch_time(base: dispatch_time_t, delta_ns: i64) dispatch_time_t;

const dispatch_semaphore_t = *opaque {};
extern fn dispatch_semaphore_create(value: isize) dispatch_semaphore_t;
extern fn dispatch_semaphore_wait(dsema: dispatch_semaphore_t, timeout: dispatch_time_t) isize;
extern fn dispatch_semaphore_signal(dsema: dispatch_semaphore_t) isize;

const dispatch_queue_t = *opaque {};
const dispatch_queue_attr_t = ?*opaque {
    const SERIAL: dispatch_queue_attr_t = null;
};
extern fn dispatch_queue_create(label: [*:0]const u8, attr: dispatch_queue_attr_t) dispatch_queue_t;
extern fn dispatch_release(object: *anyopaque) void;

const CFAllocatorRef = ?*const opaque {};
const CFArrayRef = *const opaque {};
const CFStringRef = *const opaque {};
const CFTimeInterval = f64;
const CFIndex = i32;
const CFOptionFlags = enum(u32) { _ };
const CFAllocatorRetainCallBack = *const fn (info: ?*const anyopaque) callconv(.c) *const anyopaque;
const CFAllocatorReleaseCallBack = *const fn (info: ?*const anyopaque) callconv(.c) void;
const CFAllocatorCopyDescriptionCallBack = *const fn (info: ?*const anyopaque) callconv(.c) CFStringRef;
const CFAllocatorAllocateCallBack = *const fn (alloc_size: CFIndex, hint: CFOptionFlags, info: ?*const anyopaque) callconv(.c) ?*const anyopaque;
const CFAllocatorReallocateCallBack = *const fn (ptr: ?*anyopaque, new_size: CFIndex, hint: CFOptionFlags, info: ?*const anyopaque) callconv(.c) ?*const anyopaque;
const CFAllocatorDeallocateCallBack = *const fn (ptr: *anyopaque, info: ?*const anyopaque) callconv(.c) void;
const CFAllocatorPreferredSizeCallBack = *const fn (size: CFIndex, hint: CFOptionFlags, info: ?*const anyopaque) callconv(.c) CFIndex;
const CFAllocatorContext = extern struct {
    version: CFIndex,
    info: ?*anyopaque,
    retain: ?CFAllocatorRetainCallBack,
    release: ?CFAllocatorReleaseCallBack,
    copy_description: ?CFAllocatorCopyDescriptionCallBack,
    allocate: CFAllocatorAllocateCallBack,
    reallocate: ?CFAllocatorReallocateCallBack,
    deallocate: ?CFAllocatorDeallocateCallBack,
    preferred_size: ?CFAllocatorPreferredSizeCallBack,
};
const CFArrayCallBacks = opaque {};
const CFStringEncoding = enum(u32) {
    invalid_id = std.math.maxInt(u32),
    mac_roman = 0,
    windows_latin_1 = 0x500,
    iso_latin_1 = 0x201,
    next_step_latin = 0xB01,
    ascii = 0x600,
    unicode = 0x100,
    utf8 = 0x8000100,
    non_lossy_ascii = 0xBFF,
};

const FSEventStreamRef = *opaque {};
const ConstFSEventStreamRef = *const @typeInfo(FSEventStreamRef).pointer.child;
const FSEventStreamCallback = *const fn (
    stream: ConstFSEventStreamRef,
    client_callback_info: ?*anyopaque,
    num_events: usize,
    event_paths: *anyopaque,
    event_flags: [*]const FSEventStreamEventFlags,
    event_ids: [*]const FSEventStreamEventId,
) callconv(.c) void;
const FSEventStreamContext = extern struct {
    version: CFIndex,
    info: ?*anyopaque,
    retain: ?CFAllocatorRetainCallBack,
    release: ?CFAllocatorReleaseCallBack,
    copy_description: ?CFAllocatorCopyDescriptionCallBack,
};
const FSEventStreamEventId = enum(u64) {
    since_now = std.math.maxInt(u64),
    _,
};
const FSEventStreamCreateFlags = packed struct(u32) {
    use_cf_types: bool = false,
    no_defer: bool = false,
    watch_root: bool = false,
    ignore_self: bool = false,
    file_events: bool = false,
    _: u27 = 0,
};
const FSEventStreamEventFlags = packed struct(u32) {
    must_scan_sub_dirs: bool,
    user_dropped: bool,
    kernel_dropped: bool,
    event_ids_wrapped: bool,
    history_done: bool,
    root_changed: bool,
    mount: bool,
    unmount: bool,
    _: u24 = 0,
};

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const watch_log = std.log.scoped(.watch);
const FsEvents = @This();

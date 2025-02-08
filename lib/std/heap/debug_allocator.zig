//! An allocator that is intended to be used in Debug mode.
//!
//! ## Features
//!
//! * Captures stack traces on allocation, free, and optionally resize.
//! * Double free detection, which prints all three traces (first alloc, first
//!   free, second free).
//! * Leak detection, with stack traces.
//! * Never reuses memory addresses, making it easier for Zig to detect branch
//!   on undefined values in case of dangling pointers. This relies on
//!   the backing allocator to also not reuse addresses.
//! * Uses a minimum backing allocation size to avoid operating system errors
//!   from having too many active memory mappings.
//! * When a page of memory is no longer needed, give it back to resident
//!   memory as soon as possible, so that it causes page faults when used.
//! * Cross platform. Operates based on a backing allocator which makes it work
//!   everywhere, even freestanding.
//! * Compile-time configuration.
//!
//! These features require the allocator to be quite slow and wasteful. For
//! example, when allocating a single byte, the efficiency is less than 1%;
//! it requires more than 100 bytes of overhead to manage the allocation for
//! one byte. The efficiency gets better with larger allocations.
//!
//! ## Basic Design
//!
//! Allocations are divided into two categories, small and large.
//!
//! Small allocations are divided into buckets based on `page_size`:
//!
//! ```
//! index obj_size
//! 0     1
//! 1     2
//! 2     4
//! 3     8
//! 4     16
//! 5     32
//! 6     64
//! 7     128
//! 8     256
//! 9     512
//! 10    1024
//! 11    2048
//! ...
//! ```
//!
//! This goes on for `small_bucket_count` indexes.
//!
//! Allocations are grouped into an object size based on max(len, alignment),
//! rounded up to the next power of two.
//!
//! The main allocator state has an array of all the "current" buckets for each
//! size class. Each slot in the array can be null, meaning the bucket for that
//! size class is not allocated. When the first object is allocated for a given
//! size class, it makes one `page_size` allocation from the backing allocator.
//! This allocation is divided into "slots" - one per allocated object, leaving
//! room for the allocation metadata (starting with `BucketHeader`), which is
//! located at the very end of the "page".
//!
//! The allocation metadata includes "used bits" - 1 bit per slot representing
//! whether the slot is used. Allocations always take the next available slot
//! from the current bucket, setting the corresponding used bit, as well as
//! incrementing `allocated_count`.
//!
//! Frees recover the allocation metadata based on the address, length, and
//! alignment, relying on the backing allocation's large alignment, combined
//! with the fact that allocations are never moved from small to large, or vice
//! versa.
//!
//! When a bucket is full, a new one is allocated, containing a pointer to the
//! previous one. This singly-linked list is iterated during leak detection.
//!
//! Resizing and remapping work the same on small allocations: if the size
//! class would not change, then the operation succeeds, and the address is
//! unchanged. Otherwise, the request is rejected.
//!
//! Large objects are allocated directly using the backing allocator. Metadata
//! is stored separately in a `std.HashMap` using the backing allocator.
//!
//! Resizing and remapping are forwarded directly to the backing allocator,
//! except where such operations would change the category from large to small.

const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.gpa);
const math = std.math;
const assert = std.debug.assert;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const StackTrace = std.builtin.StackTrace;

const default_page_size: usize = @max(std.heap.page_size_max, switch (builtin.os.tag) {
    .windows => 64 * 1024, // Makes `std.heap.PageAllocator` take the happy path.
    .wasi => 64 * 1024, // Max alignment supported by `std.heap.WasmAllocator`.
    else => 128 * 1024, // Avoids too many active mappings when `page_size_max` is low.
});

const Log2USize = std.math.Log2Int(usize);

const default_sys_stack_trace_frames: usize = if (std.debug.sys_can_stack_trace) 6 else 0;
const default_stack_trace_frames: usize = switch (builtin.mode) {
    .Debug => default_sys_stack_trace_frames,
    else => 0,
};

pub const Config = struct {
    /// Number of stack frames to capture.
    stack_trace_frames: usize = default_stack_trace_frames,

    /// If true, the allocator will have two fields:
    ///  * `total_requested_bytes` which tracks the total allocated bytes of memory requested.
    ///  * `requested_memory_limit` which causes allocations to return `error.OutOfMemory`
    ///    when the `total_requested_bytes` exceeds this limit.
    /// If false, these fields will be `void`.
    enable_memory_limit: bool = false,

    /// Whether to enable safety checks.
    safety: bool = std.debug.runtime_safety,

    /// Whether the allocator may be used simultaneously from multiple threads.
    thread_safe: bool = !builtin.single_threaded,

    /// What type of mutex you'd like to use, for thread safety.
    /// when specified, the mutex type must have the same shape as `std.Thread.Mutex` and
    /// `DummyMutex`, and have no required fields. Specifying this field causes
    /// the `thread_safe` field to be ignored.
    ///
    /// when null (default):
    /// * the mutex type defaults to `std.Thread.Mutex` when thread_safe is enabled.
    /// * the mutex type defaults to `DummyMutex` otherwise.
    MutexType: ?type = null,

    /// This is a temporary debugging trick you can use to turn segfaults into more helpful
    /// logged error messages with stack trace details. The downside is that every allocation
    /// will be leaked, unless used with retain_metadata!
    never_unmap: bool = false,

    /// This is a temporary debugging aid that retains metadata about allocations indefinitely.
    /// This allows a greater range of double frees to be reported. All metadata is freed when
    /// deinit is called. When used with never_unmap, deliberately leaked memory is also freed
    /// during deinit. Currently should be used with never_unmap to avoid segfaults.
    /// TODO https://github.com/ziglang/zig/issues/4298 will allow use without never_unmap
    retain_metadata: bool = false,

    /// Enables emitting info messages with the size and address of every allocation.
    verbose_log: bool = false,

    /// Tell whether the backing allocator returns already-zeroed memory.
    backing_allocator_zeroes: bool = true,

    /// When resizing an allocation, refresh the stack trace with the resize
    /// callsite. Comes with a performance penalty.
    resize_stack_traces: bool = false,

    /// Magic value that distinguishes allocations owned by this allocator from
    /// other regions of memory.
    canary: usize = @truncate(0x9232a6ff85dff10f),

    /// The size of allocations requested from the backing allocator for
    /// subdividing into slots for small allocations.
    ///
    /// Must be a power of two.
    page_size: usize = default_page_size,
};

/// Default initialization of this struct is deprecated; use `.init` instead.
pub fn DebugAllocator(comptime config: Config) type {
    return struct {
        backing_allocator: Allocator = std.heap.page_allocator,
        /// Tracks the active bucket, which is the one that has free slots in it.
        buckets: [small_bucket_count]?*BucketHeader = [1]?*BucketHeader{null} ** small_bucket_count,
        large_allocations: LargeAllocTable = .empty,
        total_requested_bytes: @TypeOf(total_requested_bytes_init) = total_requested_bytes_init,
        requested_memory_limit: @TypeOf(requested_memory_limit_init) = requested_memory_limit_init,
        mutex: @TypeOf(mutex_init) = mutex_init,

        const Self = @This();

        pub const init: Self = .{};

        /// These can be derived from size_class_index but the calculation is nontrivial.
        const slot_counts: [small_bucket_count]SlotIndex = init: {
            @setEvalBranchQuota(10000);
            var result: [small_bucket_count]SlotIndex = undefined;
            for (&result, 0..) |*elem, i| elem.* = calculateSlotCount(i);
            break :init result;
        };

        comptime {
            assert(math.isPowerOfTwo(page_size));
        }

        const page_size = config.page_size;
        const page_align: mem.Alignment = .fromByteUnits(page_size);
        /// Integer type for pointing to slots in a small allocation
        const SlotIndex = std.meta.Int(.unsigned, math.log2(page_size) + 1);

        const total_requested_bytes_init = if (config.enable_memory_limit) @as(usize, 0) else {};
        const requested_memory_limit_init = if (config.enable_memory_limit) @as(usize, math.maxInt(usize)) else {};

        const mutex_init = if (config.MutexType) |T|
            T{}
        else if (config.thread_safe)
            std.Thread.Mutex{}
        else
            DummyMutex{};

        const DummyMutex = struct {
            inline fn lock(_: *DummyMutex) void {}
            inline fn unlock(_: *DummyMutex) void {}
        };

        const stack_n = config.stack_trace_frames;
        const one_trace_size = @sizeOf(usize) * stack_n;
        const traces_per_slot = 2;

        pub const Error = mem.Allocator.Error;

        /// Avoids creating buckets that would only be able to store a small
        /// number of slots. Value of 1 means 2 is the minimum slot count.
        const minimum_slots_per_bucket_log2 = 1;
        const small_bucket_count = math.log2(page_size) - minimum_slots_per_bucket_log2;
        const largest_bucket_object_size = 1 << (small_bucket_count - 1);
        const LargestSizeClassInt = std.math.IntFittingRange(0, largest_bucket_object_size);

        const bucketCompare = struct {
            fn compare(a: *BucketHeader, b: *BucketHeader) std.math.Order {
                return std.math.order(@intFromPtr(a.page), @intFromPtr(b.page));
            }
        }.compare;

        const LargeAlloc = struct {
            bytes: []u8,
            requested_size: if (config.enable_memory_limit) usize else void,
            stack_addresses: [trace_n][stack_n]usize,
            freed: if (config.retain_metadata) bool else void,
            alignment: if (config.never_unmap and config.retain_metadata) mem.Alignment else void,

            const trace_n = if (config.retain_metadata) traces_per_slot else 1;

            fn dumpStackTrace(self: *LargeAlloc, trace_kind: TraceKind) void {
                std.debug.dumpStackTrace(self.getStackTrace(trace_kind));
            }

            fn getStackTrace(self: *LargeAlloc, trace_kind: TraceKind) std.builtin.StackTrace {
                assert(@intFromEnum(trace_kind) < trace_n);
                const stack_addresses = &self.stack_addresses[@intFromEnum(trace_kind)];
                var len: usize = 0;
                while (len < stack_n and stack_addresses[len] != 0) {
                    len += 1;
                }
                return .{
                    .instruction_addresses = stack_addresses,
                    .index = len,
                };
            }

            fn captureStackTrace(self: *LargeAlloc, ret_addr: usize, trace_kind: TraceKind) void {
                assert(@intFromEnum(trace_kind) < trace_n);
                const stack_addresses = &self.stack_addresses[@intFromEnum(trace_kind)];
                collectStackTrace(ret_addr, stack_addresses);
            }
        };
        const LargeAllocTable = std.AutoHashMapUnmanaged(usize, LargeAlloc);

        /// Bucket: In memory, in order:
        /// * BucketHeader
        /// * bucket_used_bits: [N]usize, // 1 bit for every slot
        /// -- below only exists when config.safety is true --
        /// * requested_sizes: [N]LargestSizeClassInt // 1 int for every slot
        /// * log2_ptr_aligns: [N]u8 // 1 byte for every slot
        /// -- above only exists when config.safety is true --
        /// * stack_trace_addresses: [N]usize, // traces_per_slot for every allocation
        const BucketHeader = struct {
            allocated_count: SlotIndex,
            freed_count: SlotIndex,
            prev: ?*BucketHeader,
            canary: usize = config.canary,

            fn fromPage(page_addr: usize, slot_count: usize) *BucketHeader {
                const unaligned = page_addr + page_size - bucketSize(slot_count);
                return @ptrFromInt(unaligned & ~(@as(usize, @alignOf(BucketHeader)) - 1));
            }

            fn usedBits(bucket: *BucketHeader, index: usize) *usize {
                const ptr: [*]u8 = @ptrCast(bucket);
                const bits: [*]usize = @alignCast(@ptrCast(ptr + @sizeOf(BucketHeader)));
                return &bits[index];
            }

            fn requestedSizes(bucket: *BucketHeader, slot_count: usize) []LargestSizeClassInt {
                if (!config.safety) @compileError("requested size is only stored when safety is enabled");
                const start_ptr = @as([*]u8, @ptrCast(bucket)) + bucketRequestedSizesStart(slot_count);
                const sizes = @as([*]LargestSizeClassInt, @ptrCast(@alignCast(start_ptr)));
                return sizes[0..slot_count];
            }

            fn log2PtrAligns(bucket: *BucketHeader, slot_count: usize) []mem.Alignment {
                if (!config.safety) @compileError("requested size is only stored when safety is enabled");
                const aligns_ptr = @as([*]u8, @ptrCast(bucket)) + bucketAlignsStart(slot_count);
                return @ptrCast(aligns_ptr[0..slot_count]);
            }

            fn stackTracePtr(
                bucket: *BucketHeader,
                slot_count: usize,
                slot_index: SlotIndex,
                trace_kind: TraceKind,
            ) *[stack_n]usize {
                const start_ptr = @as([*]u8, @ptrCast(bucket)) + bucketStackFramesStart(slot_count);
                const addr = start_ptr + one_trace_size * traces_per_slot * slot_index +
                    @intFromEnum(trace_kind) * @as(usize, one_trace_size);
                return @ptrCast(@alignCast(addr));
            }

            fn captureStackTrace(
                bucket: *BucketHeader,
                ret_addr: usize,
                slot_count: usize,
                slot_index: SlotIndex,
                trace_kind: TraceKind,
            ) void {
                // Initialize them to 0. When determining the count we must look
                // for non zero addresses.
                const stack_addresses = bucket.stackTracePtr(slot_count, slot_index, trace_kind);
                collectStackTrace(ret_addr, stack_addresses);
            }
        };

        pub fn allocator(self: *Self) Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .remap = remap,
                    .free = free,
                },
            };
        }

        fn bucketStackTrace(
            bucket: *BucketHeader,
            slot_count: usize,
            slot_index: SlotIndex,
            trace_kind: TraceKind,
        ) StackTrace {
            const stack_addresses = bucket.stackTracePtr(slot_count, slot_index, trace_kind);
            var len: usize = 0;
            while (len < stack_n and stack_addresses[len] != 0) {
                len += 1;
            }
            return .{
                .instruction_addresses = stack_addresses,
                .index = len,
            };
        }

        fn bucketRequestedSizesStart(slot_count: usize) usize {
            if (!config.safety) @compileError("requested sizes are not stored unless safety is enabled");
            return mem.alignForward(
                usize,
                @sizeOf(BucketHeader) + usedBitsSize(slot_count),
                @alignOf(LargestSizeClassInt),
            );
        }

        fn bucketAlignsStart(slot_count: usize) usize {
            if (!config.safety) @compileError("requested sizes are not stored unless safety is enabled");
            return bucketRequestedSizesStart(slot_count) + (@sizeOf(LargestSizeClassInt) * slot_count);
        }

        fn bucketStackFramesStart(slot_count: usize) usize {
            const unaligned_start = if (config.safety)
                bucketAlignsStart(slot_count) + slot_count
            else
                @sizeOf(BucketHeader) + usedBitsSize(slot_count);
            return mem.alignForward(usize, unaligned_start, @alignOf(usize));
        }

        fn bucketSize(slot_count: usize) usize {
            return bucketStackFramesStart(slot_count) + one_trace_size * traces_per_slot * slot_count;
        }

        /// This is executed only at compile-time to prepopulate a lookup table.
        fn calculateSlotCount(size_class_index: usize) SlotIndex {
            const size_class = @as(usize, 1) << @as(Log2USize, @intCast(size_class_index));
            var lower: usize = 1 << minimum_slots_per_bucket_log2;
            var upper: usize = (page_size - bucketSize(lower)) / size_class;
            while (upper > lower) {
                const proposed: usize = lower + (upper - lower) / 2;
                if (proposed == lower) return lower;
                const slots_end = proposed * size_class;
                const header_begin = mem.alignForward(usize, slots_end, @alignOf(BucketHeader));
                const end = header_begin + bucketSize(proposed);
                if (end > page_size) {
                    upper = proposed - 1;
                } else {
                    lower = proposed;
                }
            }
            const slots_end = lower * size_class;
            const header_begin = mem.alignForward(usize, slots_end, @alignOf(BucketHeader));
            const end = header_begin + bucketSize(lower);
            assert(end <= page_size);
            return lower;
        }

        fn usedBitsCount(slot_count: usize) usize {
            return (slot_count + (@bitSizeOf(usize) - 1)) / @bitSizeOf(usize);
        }

        fn usedBitsSize(slot_count: usize) usize {
            return usedBitsCount(slot_count) * @sizeOf(usize);
        }

        fn detectLeaksInBucket(bucket: *BucketHeader, size_class_index: usize, used_bits_count: usize) bool {
            const size_class = @as(usize, 1) << @as(Log2USize, @intCast(size_class_index));
            const slot_count = slot_counts[size_class_index];
            var leaks = false;
            for (0..used_bits_count) |used_bits_byte| {
                const used_int = bucket.usedBits(used_bits_byte).*;
                if (used_int != 0) {
                    for (0..@bitSizeOf(usize)) |bit_index_usize| {
                        const bit_index: Log2USize = @intCast(bit_index_usize);
                        const is_used = @as(u1, @truncate(used_int >> bit_index)) != 0;
                        if (is_used) {
                            const slot_index: SlotIndex = @intCast(used_bits_byte * @bitSizeOf(usize) + bit_index);
                            const stack_trace = bucketStackTrace(bucket, slot_count, slot_index, .alloc);
                            const page_addr = @intFromPtr(bucket) & ~(page_size - 1);
                            const addr = page_addr + slot_index * size_class;
                            log.err("memory address 0x{x} leaked: {}", .{ addr, stack_trace });
                            leaks = true;
                        }
                    }
                }
            }
            return leaks;
        }

        /// Emits log messages for leaks and then returns whether there were any leaks.
        pub fn detectLeaks(self: *Self) bool {
            var leaks = false;

            for (self.buckets, 0..) |init_optional_bucket, size_class_index| {
                var optional_bucket = init_optional_bucket;
                const slot_count = slot_counts[size_class_index];
                const used_bits_count = usedBitsCount(slot_count);
                while (optional_bucket) |bucket| {
                    leaks = detectLeaksInBucket(bucket, size_class_index, used_bits_count) or leaks;
                    optional_bucket = bucket.prev;
                }
            }

            var it = self.large_allocations.valueIterator();
            while (it.next()) |large_alloc| {
                if (config.retain_metadata and large_alloc.freed) continue;
                const stack_trace = large_alloc.getStackTrace(.alloc);
                log.err("memory address 0x{x} leaked: {}", .{
                    @intFromPtr(large_alloc.bytes.ptr), stack_trace,
                });
                leaks = true;
            }
            return leaks;
        }

        fn freeRetainedMetadata(self: *Self) void {
            comptime assert(config.retain_metadata);
            if (config.never_unmap) {
                // free large allocations that were intentionally leaked by never_unmap
                var it = self.large_allocations.iterator();
                while (it.next()) |large| {
                    if (large.value_ptr.freed) {
                        self.backing_allocator.rawFree(large.value_ptr.bytes, large.value_ptr.alignment, @returnAddress());
                    }
                }
            }
        }

        pub fn flushRetainedMetadata(self: *Self) void {
            comptime assert(config.retain_metadata);
            self.freeRetainedMetadata();
            // also remove entries from large_allocations
            var it = self.large_allocations.iterator();
            while (it.next()) |large| {
                if (large.value_ptr.freed) {
                    _ = self.large_allocations.remove(@intFromPtr(large.value_ptr.bytes.ptr));
                }
            }
        }

        /// Returns `std.heap.Check.leak` if there were leaks; `std.heap.Check.ok` otherwise.
        pub fn deinit(self: *Self) std.heap.Check {
            const leaks = if (config.safety) self.detectLeaks() else false;
            if (config.retain_metadata) self.freeRetainedMetadata();
            self.large_allocations.deinit(self.backing_allocator);
            self.* = undefined;
            return if (leaks) .leak else .ok;
        }

        fn collectStackTrace(first_trace_addr: usize, addresses: *[stack_n]usize) void {
            if (stack_n == 0) return;
            @memset(addresses, 0);
            var stack_trace: StackTrace = .{
                .instruction_addresses = addresses,
                .index = 0,
            };
            std.debug.captureStackTrace(first_trace_addr, &stack_trace);
        }

        fn reportDoubleFree(ret_addr: usize, alloc_stack_trace: StackTrace, free_stack_trace: StackTrace) void {
            var addresses: [stack_n]usize = @splat(0);
            var second_free_stack_trace: StackTrace = .{
                .instruction_addresses = &addresses,
                .index = 0,
            };
            std.debug.captureStackTrace(ret_addr, &second_free_stack_trace);
            log.err("Double free detected. Allocation: {} First free: {} Second free: {}", .{
                alloc_stack_trace, free_stack_trace, second_free_stack_trace,
            });
        }

        /// This function assumes the object is in the large object storage regardless
        /// of the parameters.
        fn resizeLarge(
            self: *Self,
            old_mem: []u8,
            alignment: mem.Alignment,
            new_size: usize,
            ret_addr: usize,
            may_move: bool,
        ) ?[*]u8 {
            if (config.retain_metadata and may_move) {
                // Before looking up the entry (since this could invalidate
                // it), we must reserve space for the new entry in case the
                // allocation is relocated.
                self.large_allocations.ensureUnusedCapacity(self.backing_allocator, 1) catch return null;
            }

            const entry = self.large_allocations.getEntry(@intFromPtr(old_mem.ptr)) orelse {
                if (config.safety) {
                    @panic("Invalid free");
                } else {
                    unreachable;
                }
            };

            if (config.retain_metadata and entry.value_ptr.freed) {
                if (config.safety) {
                    reportDoubleFree(ret_addr, entry.value_ptr.getStackTrace(.alloc), entry.value_ptr.getStackTrace(.free));
                    @panic("Unrecoverable double free");
                } else {
                    unreachable;
                }
            }

            if (config.safety and old_mem.len != entry.value_ptr.bytes.len) {
                var addresses: [stack_n]usize = [1]usize{0} ** stack_n;
                var free_stack_trace: StackTrace = .{
                    .instruction_addresses = &addresses,
                    .index = 0,
                };
                std.debug.captureStackTrace(ret_addr, &free_stack_trace);
                log.err("Allocation size {d} bytes does not match free size {d}. Allocation: {} Free: {}", .{
                    entry.value_ptr.bytes.len,
                    old_mem.len,
                    entry.value_ptr.getStackTrace(.alloc),
                    free_stack_trace,
                });
            }

            // If this would move the allocation into a small size class,
            // refuse the request, because it would require creating small
            // allocation metadata.
            const new_size_class_index: usize = @max(@bitSizeOf(usize) - @clz(new_size - 1), @intFromEnum(alignment));
            if (new_size_class_index < self.buckets.len) return null;

            // Do memory limit accounting with requested sizes rather than what
            // backing_allocator returns because if we want to return
            // error.OutOfMemory, we have to leave allocation untouched, and
            // that is impossible to guarantee after calling
            // backing_allocator.rawResize.
            const prev_req_bytes = self.total_requested_bytes;
            if (config.enable_memory_limit) {
                const new_req_bytes = prev_req_bytes + new_size - entry.value_ptr.requested_size;
                if (new_req_bytes > prev_req_bytes and new_req_bytes > self.requested_memory_limit) {
                    return null;
                }
                self.total_requested_bytes = new_req_bytes;
            }

            const opt_resized_ptr = if (may_move)
                self.backing_allocator.rawRemap(old_mem, alignment, new_size, ret_addr)
            else if (self.backing_allocator.rawResize(old_mem, alignment, new_size, ret_addr))
                old_mem.ptr
            else
                null;

            const resized_ptr = opt_resized_ptr orelse {
                if (config.enable_memory_limit) {
                    self.total_requested_bytes = prev_req_bytes;
                }
                return null;
            };

            if (config.enable_memory_limit) {
                entry.value_ptr.requested_size = new_size;
            }

            if (config.verbose_log) {
                log.info("large resize {d} bytes at {*} to {d} at {*}", .{
                    old_mem.len, old_mem.ptr, new_size, resized_ptr,
                });
            }
            entry.value_ptr.bytes = resized_ptr[0..new_size];
            if (config.resize_stack_traces)
                entry.value_ptr.captureStackTrace(ret_addr, .alloc);

            // Update the key of the hash map if the memory was relocated.
            if (resized_ptr != old_mem.ptr) {
                const large_alloc = entry.value_ptr.*;
                if (config.retain_metadata) {
                    entry.value_ptr.freed = true;
                    entry.value_ptr.captureStackTrace(ret_addr, .free);
                } else {
                    self.large_allocations.removeByPtr(entry.key_ptr);
                }

                const gop = self.large_allocations.getOrPutAssumeCapacity(@intFromPtr(resized_ptr));
                if (config.retain_metadata and !config.never_unmap) {
                    // Backing allocator may be reusing memory that we're retaining metadata for
                    assert(!gop.found_existing or gop.value_ptr.freed);
                } else {
                    assert(!gop.found_existing); // This would mean the kernel double-mapped pages.
                }
                gop.value_ptr.* = large_alloc;
            }

            return resized_ptr;
        }

        /// This function assumes the object is in the large object storage regardless
        /// of the parameters.
        fn freeLarge(
            self: *Self,
            old_mem: []u8,
            alignment: mem.Alignment,
            ret_addr: usize,
        ) void {
            const entry = self.large_allocations.getEntry(@intFromPtr(old_mem.ptr)) orelse {
                if (config.safety) {
                    @panic("Invalid free");
                } else {
                    unreachable;
                }
            };

            if (config.retain_metadata and entry.value_ptr.freed) {
                if (config.safety) {
                    reportDoubleFree(ret_addr, entry.value_ptr.getStackTrace(.alloc), entry.value_ptr.getStackTrace(.free));
                    return;
                } else {
                    unreachable;
                }
            }

            if (config.safety and old_mem.len != entry.value_ptr.bytes.len) {
                var addresses: [stack_n]usize = [1]usize{0} ** stack_n;
                var free_stack_trace = StackTrace{
                    .instruction_addresses = &addresses,
                    .index = 0,
                };
                std.debug.captureStackTrace(ret_addr, &free_stack_trace);
                log.err("Allocation size {d} bytes does not match free size {d}. Allocation: {} Free: {}", .{
                    entry.value_ptr.bytes.len,
                    old_mem.len,
                    entry.value_ptr.getStackTrace(.alloc),
                    free_stack_trace,
                });
            }

            if (!config.never_unmap) {
                self.backing_allocator.rawFree(old_mem, alignment, ret_addr);
            }

            if (config.enable_memory_limit) {
                self.total_requested_bytes -= entry.value_ptr.requested_size;
            }

            if (config.verbose_log) {
                log.info("large free {d} bytes at {*}", .{ old_mem.len, old_mem.ptr });
            }

            if (!config.retain_metadata) {
                assert(self.large_allocations.remove(@intFromPtr(old_mem.ptr)));
            } else {
                entry.value_ptr.freed = true;
                entry.value_ptr.captureStackTrace(ret_addr, .free);
            }
        }

        fn alloc(context: *anyopaque, len: usize, alignment: mem.Alignment, ret_addr: usize) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(context));
            self.mutex.lock();
            defer self.mutex.unlock();

            if (config.enable_memory_limit) {
                const new_req_bytes = self.total_requested_bytes + len;
                if (new_req_bytes > self.requested_memory_limit) return null;
                self.total_requested_bytes = new_req_bytes;
            }

            const size_class_index: usize = @max(@bitSizeOf(usize) - @clz(len - 1), @intFromEnum(alignment));
            if (size_class_index >= self.buckets.len) {
                @branchHint(.unlikely);
                self.large_allocations.ensureUnusedCapacity(self.backing_allocator, 1) catch return null;
                const ptr = self.backing_allocator.rawAlloc(len, alignment, ret_addr) orelse return null;
                const slice = ptr[0..len];

                const gop = self.large_allocations.getOrPutAssumeCapacity(@intFromPtr(slice.ptr));
                if (config.retain_metadata and !config.never_unmap) {
                    // Backing allocator may be reusing memory that we're retaining metadata for
                    assert(!gop.found_existing or gop.value_ptr.freed);
                } else {
                    assert(!gop.found_existing); // This would mean the kernel double-mapped pages.
                }
                gop.value_ptr.bytes = slice;
                if (config.enable_memory_limit)
                    gop.value_ptr.requested_size = len;
                gop.value_ptr.captureStackTrace(ret_addr, .alloc);
                if (config.retain_metadata) {
                    gop.value_ptr.freed = false;
                    if (config.never_unmap) {
                        gop.value_ptr.alignment = alignment;
                    }
                }

                if (config.verbose_log) {
                    log.info("large alloc {d} bytes at {*}", .{ slice.len, slice.ptr });
                }
                return slice.ptr;
            }

            const slot_count = slot_counts[size_class_index];

            if (self.buckets[size_class_index]) |bucket| {
                @branchHint(.likely);
                const slot_index = bucket.allocated_count;
                if (slot_index < slot_count) {
                    @branchHint(.likely);
                    bucket.allocated_count = slot_index + 1;
                    const used_bits_byte = bucket.usedBits(slot_index / @bitSizeOf(usize));
                    const used_bit_index: Log2USize = @intCast(slot_index % @bitSizeOf(usize));
                    used_bits_byte.* |= (@as(usize, 1) << used_bit_index);
                    const size_class = @as(usize, 1) << @as(Log2USize, @intCast(size_class_index));
                    if (config.stack_trace_frames > 0) {
                        bucket.captureStackTrace(ret_addr, slot_count, slot_index, .alloc);
                    }
                    if (config.safety) {
                        bucket.requestedSizes(slot_count)[slot_index] = @intCast(len);
                        bucket.log2PtrAligns(slot_count)[slot_index] = alignment;
                    }
                    const page_addr = @intFromPtr(bucket) & ~(page_size - 1);
                    const addr = page_addr + slot_index * size_class;
                    if (config.verbose_log) {
                        log.info("small alloc {d} bytes at 0x{x}", .{ len, addr });
                    }
                    return @ptrFromInt(addr);
                }
            }

            const page = self.backing_allocator.rawAlloc(page_size, page_align, @returnAddress()) orelse
                return null;
            const bucket: *BucketHeader = .fromPage(@intFromPtr(page), slot_count);
            bucket.* = .{
                .allocated_count = 1,
                .freed_count = 0,
                .prev = self.buckets[size_class_index],
            };
            self.buckets[size_class_index] = bucket;

            if (!config.backing_allocator_zeroes) {
                @memset(@as([*]usize, @as(*[1]usize, bucket.usedBits(0)))[0..usedBitsCount(slot_count)], 0);
                if (config.safety) @memset(bucket.requestedSizes(slot_count), 0);
            }

            bucket.usedBits(0).* = 0b1;

            if (config.stack_trace_frames > 0) {
                bucket.captureStackTrace(ret_addr, slot_count, 0, .alloc);
            }

            if (config.safety) {
                bucket.requestedSizes(slot_count)[0] = @intCast(len);
                bucket.log2PtrAligns(slot_count)[0] = alignment;
            }

            if (config.verbose_log) {
                log.info("small alloc {d} bytes at 0x{x}", .{ len, @intFromPtr(page) });
            }

            return page;
        }

        fn resize(
            context: *anyopaque,
            memory: []u8,
            alignment: mem.Alignment,
            new_len: usize,
            return_address: usize,
        ) bool {
            const self: *Self = @ptrCast(@alignCast(context));
            self.mutex.lock();
            defer self.mutex.unlock();

            const size_class_index: usize = @max(@bitSizeOf(usize) - @clz(memory.len - 1), @intFromEnum(alignment));
            if (size_class_index >= self.buckets.len) {
                return self.resizeLarge(memory, alignment, new_len, return_address, false) != null;
            } else {
                return resizeSmall(self, memory, alignment, new_len, return_address, size_class_index);
            }
        }

        fn remap(
            context: *anyopaque,
            memory: []u8,
            alignment: mem.Alignment,
            new_len: usize,
            return_address: usize,
        ) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(context));
            self.mutex.lock();
            defer self.mutex.unlock();

            const size_class_index: usize = @max(@bitSizeOf(usize) - @clz(memory.len - 1), @intFromEnum(alignment));
            if (size_class_index >= self.buckets.len) {
                return self.resizeLarge(memory, alignment, new_len, return_address, true);
            } else {
                return if (resizeSmall(self, memory, alignment, new_len, return_address, size_class_index)) memory.ptr else null;
            }
        }

        fn free(
            context: *anyopaque,
            old_memory: []u8,
            alignment: mem.Alignment,
            return_address: usize,
        ) void {
            const self: *Self = @ptrCast(@alignCast(context));
            self.mutex.lock();
            defer self.mutex.unlock();

            const size_class_index: usize = @max(@bitSizeOf(usize) - @clz(old_memory.len - 1), @intFromEnum(alignment));
            if (size_class_index >= self.buckets.len) {
                @branchHint(.unlikely);
                self.freeLarge(old_memory, alignment, return_address);
                return;
            }

            const slot_count = slot_counts[size_class_index];
            const freed_addr = @intFromPtr(old_memory.ptr);
            const page_addr = freed_addr & ~(page_size - 1);
            const bucket: *BucketHeader = .fromPage(page_addr, slot_count);
            if (bucket.canary != config.canary) @panic("Invalid free");
            const page_offset = freed_addr - page_addr;
            const size_class = @as(usize, 1) << @as(Log2USize, @intCast(size_class_index));
            const slot_index: SlotIndex = @intCast(page_offset / size_class);
            const used_byte_index = slot_index / @bitSizeOf(usize);
            const used_bit_index: Log2USize = @intCast(slot_index % @bitSizeOf(usize));
            const used_byte = bucket.usedBits(used_byte_index);
            const is_used = @as(u1, @truncate(used_byte.* >> used_bit_index)) != 0;
            if (!is_used) {
                if (config.safety) {
                    reportDoubleFree(
                        return_address,
                        bucketStackTrace(bucket, slot_count, slot_index, .alloc),
                        bucketStackTrace(bucket, slot_count, slot_index, .free),
                    );
                    // Recoverable since this is a free.
                    return;
                } else {
                    unreachable;
                }
            }

            // Definitely an in-use small alloc now.
            if (config.safety) {
                const requested_size = bucket.requestedSizes(slot_count)[slot_index];
                if (requested_size == 0) @panic("Invalid free");
                const slot_alignment = bucket.log2PtrAligns(slot_count)[slot_index];
                if (old_memory.len != requested_size or alignment != slot_alignment) {
                    var addresses: [stack_n]usize = [1]usize{0} ** stack_n;
                    var free_stack_trace: StackTrace = .{
                        .instruction_addresses = &addresses,
                        .index = 0,
                    };
                    std.debug.captureStackTrace(return_address, &free_stack_trace);
                    if (old_memory.len != requested_size) {
                        log.err("Allocation size {d} bytes does not match free size {d}. Allocation: {} Free: {}", .{
                            requested_size,
                            old_memory.len,
                            bucketStackTrace(bucket, slot_count, slot_index, .alloc),
                            free_stack_trace,
                        });
                    }
                    if (alignment != slot_alignment) {
                        log.err("Allocation alignment {d} does not match free alignment {d}. Allocation: {} Free: {}", .{
                            slot_alignment.toByteUnits(),
                            alignment.toByteUnits(),
                            bucketStackTrace(bucket, slot_count, slot_index, .alloc),
                            free_stack_trace,
                        });
                    }
                }
            }

            if (config.enable_memory_limit) {
                self.total_requested_bytes -= old_memory.len;
            }

            if (config.stack_trace_frames > 0) {
                // Capture stack trace to be the "first free", in case a double free happens.
                bucket.captureStackTrace(return_address, slot_count, slot_index, .free);
            }

            used_byte.* &= ~(@as(usize, 1) << used_bit_index);
            if (config.safety) {
                bucket.requestedSizes(slot_count)[slot_index] = 0;
            }
            bucket.freed_count += 1;
            if (bucket.freed_count == bucket.allocated_count) {
                if (self.buckets[size_class_index] == bucket) {
                    self.buckets[size_class_index] = null;
                }
                if (!config.never_unmap) {
                    const page: [*]align(page_size) u8 = @ptrFromInt(page_addr);
                    self.backing_allocator.rawFree(page[0..page_size], page_align, @returnAddress());
                }
            }
            if (config.verbose_log) {
                log.info("small free {d} bytes at {*}", .{ old_memory.len, old_memory.ptr });
            }
        }

        fn resizeSmall(
            self: *Self,
            memory: []u8,
            alignment: mem.Alignment,
            new_len: usize,
            return_address: usize,
            size_class_index: usize,
        ) bool {
            const new_size_class_index: usize = @max(@bitSizeOf(usize) - @clz(new_len - 1), @intFromEnum(alignment));
            if (!config.safety) return new_size_class_index == size_class_index;
            const slot_count = slot_counts[size_class_index];
            const memory_addr = @intFromPtr(memory.ptr);
            const page_addr = memory_addr & ~(page_size - 1);
            const bucket: *BucketHeader = .fromPage(page_addr, slot_count);
            if (bucket.canary != config.canary) @panic("Invalid free");
            const page_offset = memory_addr - page_addr;
            const size_class = @as(usize, 1) << @as(Log2USize, @intCast(size_class_index));
            const slot_index: SlotIndex = @intCast(page_offset / size_class);
            const used_byte_index = slot_index / @bitSizeOf(usize);
            const used_bit_index: Log2USize = @intCast(slot_index % @bitSizeOf(usize));
            const used_byte = bucket.usedBits(used_byte_index);
            const is_used = @as(u1, @truncate(used_byte.* >> used_bit_index)) != 0;
            if (!is_used) {
                reportDoubleFree(
                    return_address,
                    bucketStackTrace(bucket, slot_count, slot_index, .alloc),
                    bucketStackTrace(bucket, slot_count, slot_index, .free),
                );
                // Recoverable since this is a free.
                return false;
            }

            // Definitely an in-use small alloc now.
            const requested_size = bucket.requestedSizes(slot_count)[slot_index];
            if (requested_size == 0) @panic("Invalid free");
            const slot_alignment = bucket.log2PtrAligns(slot_count)[slot_index];
            if (memory.len != requested_size or alignment != slot_alignment) {
                var addresses: [stack_n]usize = [1]usize{0} ** stack_n;
                var free_stack_trace: StackTrace = .{
                    .instruction_addresses = &addresses,
                    .index = 0,
                };
                std.debug.captureStackTrace(return_address, &free_stack_trace);
                if (memory.len != requested_size) {
                    log.err("Allocation size {d} bytes does not match free size {d}. Allocation: {} Free: {}", .{
                        requested_size,
                        memory.len,
                        bucketStackTrace(bucket, slot_count, slot_index, .alloc),
                        free_stack_trace,
                    });
                }
                if (alignment != slot_alignment) {
                    log.err("Allocation alignment {d} does not match free alignment {d}. Allocation: {} Free: {}", .{
                        slot_alignment.toByteUnits(),
                        alignment.toByteUnits(),
                        bucketStackTrace(bucket, slot_count, slot_index, .alloc),
                        free_stack_trace,
                    });
                }
            }

            if (new_size_class_index != size_class_index) return false;

            const prev_req_bytes = self.total_requested_bytes;
            if (config.enable_memory_limit) {
                const new_req_bytes = prev_req_bytes - memory.len + new_len;
                if (new_req_bytes > prev_req_bytes and new_req_bytes > self.requested_memory_limit) {
                    return false;
                }
                self.total_requested_bytes = new_req_bytes;
            }

            if (memory.len > new_len) @memset(memory[new_len..], undefined);
            if (config.verbose_log)
                log.info("small resize {d} bytes at {*} to {d}", .{ memory.len, memory.ptr, new_len });

            if (config.safety)
                bucket.requestedSizes(slot_count)[slot_index] = @intCast(new_len);

            if (config.resize_stack_traces)
                bucket.captureStackTrace(return_address, slot_count, slot_index, .alloc);

            return true;
        }
    };
}

const TraceKind = enum {
    alloc,
    free,
};

const test_config = Config{};

test "small allocations - free in same order" {
    var gpa = DebugAllocator(test_config){};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var list = std.ArrayList(*u64).init(std.testing.allocator);
    defer list.deinit();

    var i: usize = 0;
    while (i < 513) : (i += 1) {
        const ptr = try allocator.create(u64);
        try list.append(ptr);
    }

    for (list.items) |ptr| {
        allocator.destroy(ptr);
    }
}

test "small allocations - free in reverse order" {
    var gpa = DebugAllocator(test_config){};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var list = std.ArrayList(*u64).init(std.testing.allocator);
    defer list.deinit();

    var i: usize = 0;
    while (i < 513) : (i += 1) {
        const ptr = try allocator.create(u64);
        try list.append(ptr);
    }

    while (list.popOrNull()) |ptr| {
        allocator.destroy(ptr);
    }
}

test "large allocations" {
    var gpa = DebugAllocator(test_config){};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    const ptr1 = try allocator.alloc(u64, 42768);
    const ptr2 = try allocator.alloc(u64, 52768);
    allocator.free(ptr1);
    const ptr3 = try allocator.alloc(u64, 62768);
    allocator.free(ptr3);
    allocator.free(ptr2);
}

test "very large allocation" {
    var gpa = DebugAllocator(test_config){};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, math.maxInt(usize)));
}

test "realloc" {
    var gpa = DebugAllocator(test_config){};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var slice = try allocator.alignedAlloc(u8, @alignOf(u32), 1);
    defer allocator.free(slice);
    slice[0] = 0x12;

    // This reallocation should keep its pointer address.
    const old_slice = slice;
    slice = try allocator.realloc(slice, 2);
    try std.testing.expect(old_slice.ptr == slice.ptr);
    try std.testing.expect(slice[0] == 0x12);
    slice[1] = 0x34;

    // This requires upgrading to a larger size class
    slice = try allocator.realloc(slice, 17);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[1] == 0x34);
}

test "shrink" {
    var gpa: DebugAllocator(test_config) = .{};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var slice = try allocator.alloc(u8, 20);
    defer allocator.free(slice);

    @memset(slice, 0x11);

    try std.testing.expect(allocator.resize(slice, 17));
    slice = slice[0..17];

    for (slice) |b| {
        try std.testing.expect(b == 0x11);
    }

    // Does not cross size class boundaries when shrinking.
    try std.testing.expect(!allocator.resize(slice, 16));
}

test "large object - grow" {
    if (builtin.target.isWasm()) {
        // Not expected to pass on targets that do not have memory mapping.
        return error.SkipZigTest;
    }
    var gpa: DebugAllocator(test_config) = .{};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var slice1 = try allocator.alloc(u8, default_page_size * 2 - 20);
    defer allocator.free(slice1);

    const old = slice1;
    slice1 = try allocator.realloc(slice1, default_page_size * 2 - 10);
    try std.testing.expect(slice1.ptr == old.ptr);

    slice1 = try allocator.realloc(slice1, default_page_size * 2);
    try std.testing.expect(slice1.ptr == old.ptr);

    slice1 = try allocator.realloc(slice1, default_page_size * 2 + 1);
}

test "realloc small object to large object" {
    var gpa = DebugAllocator(test_config){};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var slice = try allocator.alloc(u8, 70);
    defer allocator.free(slice);
    slice[0] = 0x12;
    slice[60] = 0x34;

    // This requires upgrading to a large object
    const large_object_size = default_page_size * 2 + 50;
    slice = try allocator.realloc(slice, large_object_size);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[60] == 0x34);
}

test "shrink large object to large object" {
    var gpa: DebugAllocator(test_config) = .{};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var slice = try allocator.alloc(u8, default_page_size * 2 + 50);
    defer allocator.free(slice);
    slice[0] = 0x12;
    slice[60] = 0x34;

    if (!allocator.resize(slice, default_page_size * 2 + 1)) return;
    slice = slice.ptr[0 .. default_page_size * 2 + 1];
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[60] == 0x34);

    try std.testing.expect(allocator.resize(slice, default_page_size * 2 + 1));
    slice = slice[0 .. default_page_size * 2 + 1];
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[60] == 0x34);

    slice = try allocator.realloc(slice, default_page_size * 2);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[60] == 0x34);
}

test "shrink large object to large object with larger alignment" {
    if (!builtin.link_libc and builtin.os.tag == .wasi) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/22731

    var gpa = DebugAllocator(test_config){};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var debug_buffer: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&debug_buffer);
    const debug_allocator = fba.allocator();

    const alloc_size = default_page_size * 2 + 50;
    var slice = try allocator.alignedAlloc(u8, 16, alloc_size);
    defer allocator.free(slice);

    const big_alignment: usize = default_page_size * 2;
    // This loop allocates until we find a page that is not aligned to the big
    // alignment. Then we shrink the allocation after the loop, but increase the
    // alignment to the higher one, that we know will force it to realloc.
    var stuff_to_free = std.ArrayList([]align(16) u8).init(debug_allocator);
    while (mem.isAligned(@intFromPtr(slice.ptr), big_alignment)) {
        try stuff_to_free.append(slice);
        slice = try allocator.alignedAlloc(u8, 16, alloc_size);
    }
    while (stuff_to_free.popOrNull()) |item| {
        allocator.free(item);
    }
    slice[0] = 0x12;
    slice[60] = 0x34;

    slice = try allocator.reallocAdvanced(slice, big_alignment, alloc_size / 2);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[60] == 0x34);
}

test "realloc large object to small object" {
    var gpa = DebugAllocator(test_config){};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var slice = try allocator.alloc(u8, default_page_size * 2 + 50);
    defer allocator.free(slice);
    slice[0] = 0x12;
    slice[16] = 0x34;

    slice = try allocator.realloc(slice, 19);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[16] == 0x34);
}

test "overridable mutexes" {
    var gpa = DebugAllocator(.{ .MutexType = std.Thread.Mutex }){
        .backing_allocator = std.testing.allocator,
        .mutex = std.Thread.Mutex{},
    };
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    const ptr = try allocator.create(i32);
    defer allocator.destroy(ptr);
}

test "non-page-allocator backing allocator" {
    var gpa: DebugAllocator(.{
        .backing_allocator_zeroes = false,
    }) = .{
        .backing_allocator = std.testing.allocator,
    };
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    const ptr = try allocator.create(i32);
    defer allocator.destroy(ptr);
}

test "realloc large object to larger alignment" {
    if (!builtin.link_libc and builtin.os.tag == .wasi) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/22731

    var gpa = DebugAllocator(test_config){};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var debug_buffer: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&debug_buffer);
    const debug_allocator = fba.allocator();

    var slice = try allocator.alignedAlloc(u8, 16, default_page_size * 2 + 50);
    defer allocator.free(slice);

    const big_alignment: usize = default_page_size * 2;
    // This loop allocates until we find a page that is not aligned to the big alignment.
    var stuff_to_free = std.ArrayList([]align(16) u8).init(debug_allocator);
    while (mem.isAligned(@intFromPtr(slice.ptr), big_alignment)) {
        try stuff_to_free.append(slice);
        slice = try allocator.alignedAlloc(u8, 16, default_page_size * 2 + 50);
    }
    while (stuff_to_free.popOrNull()) |item| {
        allocator.free(item);
    }
    slice[0] = 0x12;
    slice[16] = 0x34;

    slice = try allocator.reallocAdvanced(slice, 32, default_page_size * 2 + 100);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[16] == 0x34);

    slice = try allocator.reallocAdvanced(slice, 32, default_page_size * 2 + 25);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[16] == 0x34);

    slice = try allocator.reallocAdvanced(slice, big_alignment, default_page_size * 2 + 100);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[16] == 0x34);
}

test "large object rejects shrinking to small" {
    if (builtin.target.isWasm()) {
        // Not expected to pass on targets that do not have memory mapping.
        return error.SkipZigTest;
    }

    var failing_allocator = std.testing.FailingAllocator.init(std.heap.page_allocator, .{ .fail_index = 3 });
    var gpa: DebugAllocator(.{}) = .{
        .backing_allocator = failing_allocator.allocator(),
    };
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var slice = try allocator.alloc(u8, default_page_size * 2 + 50);
    defer allocator.free(slice);
    slice[0] = 0x12;
    slice[3] = 0x34;

    try std.testing.expect(!allocator.resize(slice, 4));
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[3] == 0x34);
}

test "objects of size 1024 and 2048" {
    var gpa = DebugAllocator(test_config){};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    const slice = try allocator.alloc(u8, 1025);
    const slice2 = try allocator.alloc(u8, 3000);

    allocator.free(slice);
    allocator.free(slice2);
}

test "setting a memory cap" {
    var gpa = DebugAllocator(.{ .enable_memory_limit = true }){};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    gpa.requested_memory_limit = 1010;

    const small = try allocator.create(i32);
    try std.testing.expect(gpa.total_requested_bytes == 4);

    const big = try allocator.alloc(u8, 1000);
    try std.testing.expect(gpa.total_requested_bytes == 1004);

    try std.testing.expectError(error.OutOfMemory, allocator.create(u64));

    allocator.destroy(small);
    try std.testing.expect(gpa.total_requested_bytes == 1000);

    allocator.free(big);
    try std.testing.expect(gpa.total_requested_bytes == 0);

    const exact = try allocator.alloc(u8, 1010);
    try std.testing.expect(gpa.total_requested_bytes == 1010);
    allocator.free(exact);
}

test "large allocations count requested size not backing size" {
    var gpa: DebugAllocator(.{ .enable_memory_limit = true }) = .{};
    const allocator = gpa.allocator();

    var buf = try allocator.alignedAlloc(u8, 1, default_page_size + 1);
    try std.testing.expectEqual(default_page_size + 1, gpa.total_requested_bytes);
    buf = try allocator.realloc(buf, 1);
    try std.testing.expectEqual(1, gpa.total_requested_bytes);
    buf = try allocator.realloc(buf, 2);
    try std.testing.expectEqual(2, gpa.total_requested_bytes);
}

test "retain metadata and never unmap" {
    var gpa = std.heap.DebugAllocator(.{
        .safety = true,
        .never_unmap = true,
        .retain_metadata = true,
    }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const alloc = try allocator.alloc(u8, 8);
    allocator.free(alloc);

    const alloc2 = try allocator.alloc(u8, 8);
    allocator.free(alloc2);
}

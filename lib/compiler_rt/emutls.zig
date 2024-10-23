//! __emutls_get_address specific builtin
//!
//! derived work from LLVM Compiler Infrastructure - release 8.0 (MIT)
//! https://github.com/llvm-mirror/compiler-rt/blob/release_80/lib/builtins/emutls.c

const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");

const abort = std.posix.abort;
const assert = std.debug.assert;
const expect = std.testing.expect;

/// defined in C as:
/// typedef unsigned int gcc_word __attribute__((mode(word)));
const gcc_word = usize;

pub const panic = common.panic;

comptime {
    if (builtin.link_libc and (builtin.abi.isAndroid() or builtin.os.tag == .openbsd)) {
        @export(&__emutls_get_address, .{ .name = "__emutls_get_address", .linkage = common.linkage, .visibility = common.visibility });
    }
}

/// public entrypoint for generated code using EmulatedTLS
pub fn __emutls_get_address(control: *emutls_control) callconv(.C) *anyopaque {
    return control.getPointer();
}

/// Simple allocator interface, to avoid pulling in the while
/// std allocator implementation.
const simple_allocator = struct {
    /// Allocate a memory chunk for requested type. Return a pointer on the data.
    pub fn alloc(comptime T: type) *T {
        return @ptrCast(@alignCast(advancedAlloc(@alignOf(T), @sizeOf(T))));
    }

    /// Allocate a slice of T, with len elements.
    pub fn allocSlice(comptime T: type, len: usize) []T {
        return @as([*]T, @ptrCast(@alignCast(
            advancedAlloc(@alignOf(T), @sizeOf(T) * len),
        )))[0 .. len - 1];
    }

    /// Allocate a memory chunk.
    pub fn advancedAlloc(alignment: u29, size: usize) [*]u8 {
        const minimal_alignment = @max(@alignOf(usize), alignment);

        var aligned_ptr: ?*anyopaque = undefined;
        if (std.c.posix_memalign(&aligned_ptr, minimal_alignment, size) != 0) {
            abort();
        }

        return @ptrCast(aligned_ptr);
    }

    /// Resize a slice.
    pub fn reallocSlice(comptime T: type, slice: []T, len: usize) []T {
        const c_ptr: *anyopaque = @ptrCast(slice.ptr);
        const new_array: [*]T = @ptrCast(@alignCast(std.c.realloc(c_ptr, @sizeOf(T) * len) orelse abort()));
        return new_array[0..len];
    }

    /// Free a memory chunk allocated with simple_allocator.
    pub fn free(ptr: anytype) void {
        std.c.free(@ptrCast(ptr));
    }
};

/// Simple array of ?ObjectPointer with automatic resizing and
/// automatic storage allocation.
const ObjectArray = struct {
    const ObjectPointer = *anyopaque;

    // content of the array
    slots: []?ObjectPointer,

    /// create a new ObjectArray with n slots. must call deinit() to deallocate.
    pub fn init(n: usize) *ObjectArray {
        const array = simple_allocator.alloc(ObjectArray);

        array.* = ObjectArray{
            .slots = simple_allocator.allocSlice(?ObjectPointer, n),
        };

        for (array.slots) |*object| {
            object.* = null;
        }

        return array;
    }

    /// deallocate the ObjectArray.
    pub fn deinit(self: *ObjectArray) void {
        // deallocated used objects in the array
        for (self.slots) |*object| {
            simple_allocator.free(object.*);
        }
        simple_allocator.free(self.slots);
        simple_allocator.free(self);
    }

    /// resize the ObjectArray if needed.
    pub fn ensureLength(self: *ObjectArray, new_len: usize) *ObjectArray {
        const old_len = self.slots.len;

        if (old_len > new_len) {
            return self;
        }

        // reallocate
        self.slots = simple_allocator.reallocSlice(?ObjectPointer, self.slots, new_len);

        // init newly added slots
        for (self.slots[old_len..]) |*object| {
            object.* = null;
        }

        return self;
    }

    /// Retrieve the pointer at request index, using control to initialize it if needed.
    pub fn getPointer(self: *ObjectArray, index: usize, control: *emutls_control) ObjectPointer {
        if (self.slots[index] == null) {
            // initialize the slot
            const size = control.size;
            const alignment: u29 = @truncate(control.alignment);

            var data = simple_allocator.advancedAlloc(alignment, size);
            errdefer simple_allocator.free(data);

            if (control.default_value) |value| {
                // default value: copy the content to newly allocated object.
                @memcpy(data[0..size], @as([*]const u8, @ptrCast(value)));
            } else {
                // no default: return zeroed memory.
                @memset(data[0..size], 0);
            }

            self.slots[index] = data;
        }

        return self.slots[index].?;
    }
};

// Global structure for Thread Storage.
// It provides thread-safety for on-demand storage of Thread Objects.
const current_thread_storage = struct {
    var key: std.c.pthread_key_t = undefined;
    var init_once = std.once(current_thread_storage.init);

    /// Return a per thread ObjectArray with at least the expected index.
    pub fn getArray(index: usize) *ObjectArray {
        if (current_thread_storage.getspecific()) |array| {
            // we already have a specific. just ensure the array is
            // big enough for the wanted index.
            return array.ensureLength(index);
        }

        // no specific. we need to create a new array.

        // make it to contains at least 16 objects (to avoid too much
        // reallocation at startup).
        const size = @max(16, index);

        // create a new array and store it.
        const array: *ObjectArray = ObjectArray.init(size);
        current_thread_storage.setspecific(array);
        return array;
    }

    /// Return casted thread specific value.
    fn getspecific() ?*ObjectArray {
        return @ptrCast(@alignCast(std.c.pthread_getspecific(current_thread_storage.key)));
    }

    /// Set casted thread specific value.
    fn setspecific(new: ?*ObjectArray) void {
        if (std.c.pthread_setspecific(current_thread_storage.key, @ptrCast(new)) != 0) {
            abort();
        }
    }

    /// Initialize pthread_key_t.
    fn init() void {
        if (std.c.pthread_key_create(&current_thread_storage.key, current_thread_storage.deinit) != .SUCCESS) {
            abort();
        }
    }

    /// Invoked by pthread specific destructor. the passed argument is the ObjectArray pointer.
    fn deinit(arrayPtr: *anyopaque) callconv(.C) void {
        var array: *ObjectArray = @ptrCast(@alignCast(arrayPtr));
        array.deinit();
    }
};

const emutls_control = extern struct {
    // A emutls_control value is a global value across all
    // threads. The threads shares the index of TLS variable. The data
    // array (containing address of allocated variables) is thread
    // specific and stored using pthread_setspecific().

    // size of the object in bytes
    size: gcc_word,

    // alignment of the object in bytes
    alignment: gcc_word,

    object: extern union {
        // data[index-1] is the object address / 0 = uninit
        index: usize,

        // object address, when in single thread env (not used)
        address: *anyopaque,
    },

    // null or non-zero initial value for the object
    default_value: ?*const anyopaque,

    // global Mutex used to serialize control.index initialization.
    var mutex: std.c.pthread_mutex_t = std.c.PTHREAD_MUTEX_INITIALIZER;

    // global counter for keeping track of requested indexes.
    // access should be done with mutex held.
    var next_index: usize = 1;

    /// Simple wrapper for global lock.
    fn lock() void {
        if (std.c.pthread_mutex_lock(&emutls_control.mutex) != .SUCCESS) {
            abort();
        }
    }

    /// Simple wrapper for global unlock.
    fn unlock() void {
        if (std.c.pthread_mutex_unlock(&emutls_control.mutex) != .SUCCESS) {
            abort();
        }
    }

    /// Helper to retrieve nad initialize global unique index per emutls variable.
    pub fn getIndex(self: *emutls_control) usize {
        // Two threads could race against the same emutls_control.

        // Use atomic for reading coherent value lockless.
        const index_lockless = @atomicLoad(usize, &self.object.index, .acquire);

        if (index_lockless != 0) {
            // index is already initialized, return it.
            return index_lockless;
        }

        // index is uninitialized: take global lock to avoid possible race.
        emutls_control.lock();
        defer emutls_control.unlock();

        const index_locked = self.object.index;
        if (index_locked != 0) {
            // we lost a race, but index is already initialized: nothing particular to do.
            return index_locked;
        }

        // Store a new index atomically (for having coherent index_lockless reading).
        @atomicStore(usize, &self.object.index, emutls_control.next_index, .release);

        // Increment the next available index
        emutls_control.next_index += 1;

        return self.object.index;
    }

    /// Simple helper for testing purpose.
    pub fn init(comptime T: type, default_value: ?*const T) emutls_control {
        return emutls_control{
            .size = @sizeOf(T),
            .alignment = @alignOf(T),
            .object = .{ .index = 0 },
            .default_value = @ptrCast(default_value),
        };
    }

    /// Get the pointer on allocated storage for emutls variable.
    pub fn getPointer(self: *emutls_control) *anyopaque {
        // ensure current_thread_storage initialization is done
        current_thread_storage.init_once.call();

        const index = self.getIndex();
        var array = current_thread_storage.getArray(index);

        return array.getPointer(index - 1, self);
    }

    /// Testing helper for retrieving typed pointer.
    pub fn get_typed_pointer(self: *emutls_control, comptime T: type) *T {
        assert(self.size == @sizeOf(T));
        assert(self.alignment == @alignOf(T));
        return @ptrCast(@alignCast(self.getPointer()));
    }
};

test "simple_allocator" {
    if (!builtin.link_libc or builtin.os.tag != .openbsd) return error.SkipZigTest;

    const data1: *[64]u8 = simple_allocator.alloc([64]u8);
    defer simple_allocator.free(data1);
    for (data1) |*c| {
        c.* = 0xff;
    }

    const data2: [*]u8 = simple_allocator.advancedAlloc(@alignOf(u8), 64);
    defer simple_allocator.free(data2);
    for (data2[0..63]) |*c| {
        c.* = 0xff;
    }
}

test "__emutls_get_address zeroed" {
    if (!builtin.link_libc or builtin.os.tag != .openbsd) return error.SkipZigTest;

    var ctl = emutls_control.init(usize, null);
    try expect(ctl.object.index == 0);

    // retrieve a variable from ctl
    const x: *usize = @ptrCast(@alignCast(__emutls_get_address(&ctl)));
    try expect(ctl.object.index != 0); // index has been allocated for this ctl
    try expect(x.* == 0); // storage has been zeroed

    // modify the storage
    x.* = 1234;

    // retrieve a variable from ctl (same ctl)
    const y: *usize = @ptrCast(@alignCast(__emutls_get_address(&ctl)));

    try expect(y.* == 1234); // same content that x.*
    try expect(x == y); // same pointer
}

test "__emutls_get_address with default_value" {
    if (!builtin.link_libc or builtin.os.tag != .openbsd) return error.SkipZigTest;

    const value: usize = 5678; // default value
    var ctl = emutls_control.init(usize, &value);
    try expect(ctl.object.index == 0);

    const x: *usize = @ptrCast(@alignCast(__emutls_get_address(&ctl)));
    try expect(ctl.object.index != 0);
    try expect(x.* == 5678); // storage initialized with default value

    // modify the storage
    x.* = 9012;

    try expect(value == 5678); // the default value didn't change

    const y: *usize = @ptrCast(@alignCast(__emutls_get_address(&ctl)));
    try expect(y.* == 9012); // the modified storage persists
}

test "test default_value with different sizes" {
    if (!builtin.link_libc or builtin.os.tag != .openbsd) return error.SkipZigTest;

    const testType = struct {
        fn _testType(comptime T: type, value: T) !void {
            var ctl = emutls_control.init(T, &value);
            const x = ctl.get_typed_pointer(T);
            try expect(x.* == value);
        }
    }._testType;

    try testType(usize, 1234);
    try testType(u32, 1234);
    try testType(i16, -12);
    try testType(f64, -12.0);
    try testType(
        @TypeOf("012345678901234567890123456789"),
        "012345678901234567890123456789",
    );
}

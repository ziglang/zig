const std = @import("std.zig");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;

/// A contiguous, growable list of items in memory.
/// This is a wrapper around an array of T values. Initialize with `init`.
///
/// This struct internally stores a `std.mem.Allocator` for memory management.
/// To manually specify an allocator with each method call see `ArrayListUnmanaged`.
pub fn ArrayList(comptime T: type) type {
    return ArrayListAligned(T, null);
}

/// A contiguous, growable list of arbitrarily aligned items in memory.
/// This is a wrapper around an array of T values aligned to `alignment`-byte
/// addresses. If the specified alignment is `null`, then `@alignOf(T)` is used.
/// Initialize with `init`.
///
/// This struct internally stores a `std.mem.Allocator` for memory management.
/// To manually specify an allocator with each method call see `ArrayListAlignedUnmanaged`.
pub fn ArrayListAligned(comptime T: type, comptime alignment: ?u29) type {
    if (alignment) |a| {
        if (a == @alignOf(T)) {
            return ArrayListAligned(T, null);
        }
    }
    return struct {
        const Self = @This();
        /// Contents of the list. Pointers to elements in this slice are
        /// **invalid after resizing operations** on the ArrayList unless the
        /// operation explicitly either: (1) states otherwise or (2) lists the
        /// invalidated pointers.
        ///
        /// The allocator used determines how element pointers are
        /// invalidated, so the behavior may vary between lists. To avoid
        /// illegal behavior, take into account the above paragraph plus the
        /// explicit statements given in each method.
        items: Slice,
        /// How many T values this list can hold without allocating
        /// additional memory.
        capacity: usize,
        allocator: Allocator,

        pub const Slice = if (alignment) |a| ([]align(a) T) else []T;

        pub fn SentinelSlice(comptime s: T) type {
            return if (alignment) |a| ([:s]align(a) T) else [:s]T;
        }

        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn init(allocator: Allocator) Self {
            return Self{
                .items = &[_]T{},
                .capacity = 0,
                .allocator = allocator,
            };
        }

        /// Initialize with capacity to hold `num` elements.
        /// The resulting capacity will equal `num` exactly.
        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn initCapacity(allocator: Allocator, num: usize) Allocator.Error!Self {
            var self = Self.init(allocator);
            try self.ensureTotalCapacityPrecise(num);
            return self;
        }

        /// Release all allocated memory.
        pub fn deinit(self: Self) void {
            if (@sizeOf(T) > 0) {
                self.allocator.free(self.allocatedSlice());
            }
        }

        /// ArrayList takes ownership of the passed in slice. The slice must have been
        /// allocated with `allocator`.
        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn fromOwnedSlice(allocator: Allocator, slice: Slice) Self {
            return Self{
                .items = slice,
                .capacity = slice.len,
                .allocator = allocator,
            };
        }

        /// ArrayList takes ownership of the passed in slice. The slice must have been
        /// allocated with `allocator`.
        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn fromOwnedSliceSentinel(allocator: Allocator, comptime sentinel: T, slice: [:sentinel]T) Self {
            return Self{
                .items = slice,
                .capacity = slice.len + 1,
                .allocator = allocator,
            };
        }

        /// Initializes an ArrayListUnmanaged with the `items` and `capacity` fields
        /// of this ArrayList. Empties this ArrayList.
        pub fn moveToUnmanaged(self: *Self) ArrayListAlignedUnmanaged(T, alignment) {
            const allocator = self.allocator;
            const result = .{ .items = self.items, .capacity = self.capacity };
            self.* = init(allocator);
            return result;
        }

        /// The caller owns the returned memory. Empties this ArrayList,
        /// Its capacity is cleared, making deinit() safe but unnecessary to call.
        pub fn toOwnedSlice(self: *Self) Allocator.Error!Slice {
            const allocator = self.allocator;

            const old_memory = self.allocatedSlice();
            if (allocator.resize(old_memory, self.items.len)) {
                const result = self.items;
                self.* = init(allocator);
                return result;
            }

            const new_memory = try allocator.alignedAlloc(T, alignment, self.items.len);
            @memcpy(new_memory, self.items);
            @memset(self.items, undefined);
            self.clearAndFree();
            return new_memory;
        }

        /// The caller owns the returned memory. Empties this ArrayList.
        pub fn toOwnedSliceSentinel(self: *Self, comptime sentinel: T) Allocator.Error!SentinelSlice(sentinel) {
            try self.ensureTotalCapacityPrecise(self.items.len + 1);
            self.appendAssumeCapacity(sentinel);
            const result = try self.toOwnedSlice();
            return result[0 .. result.len - 1 :sentinel];
        }

        /// Creates a copy of this ArrayList, using the same allocator.
        pub fn clone(self: Self) Allocator.Error!Self {
            var cloned = try Self.initCapacity(self.allocator, self.capacity);
            cloned.appendSliceAssumeCapacity(self.items);
            return cloned;
        }

        /// Insert `item` at index `n`. Moves `list[n .. list.len]` to higher indices to make room.
        /// If `n` is equal to the length of the list this operation is equivalent to append.
        /// This operation is O(N).
        /// Invalidates pointers if additional memory is needed.
        pub fn insert(self: *Self, n: usize, item: T) Allocator.Error!void {
            try self.ensureUnusedCapacity(1);
            self.insertAssumeCapacity(n, item);
        }

        /// Insert `item` at index `n`. Moves `list[n .. list.len]` to higher indices to make room.
        /// If `n` is equal to the length of the list this operation is equivalent to append.
        /// This operation is O(N).
        /// Asserts that there is enough capacity for the new item.
        pub fn insertAssumeCapacity(self: *Self, n: usize, item: T) void {
            assert(self.items.len < self.capacity);
            self.items.len += 1;

            mem.copyBackwards(T, self.items[n + 1 .. self.items.len], self.items[n .. self.items.len - 1]);
            self.items[n] = item;
        }

        /// Insert slice `items` at index `i` by moving `list[i .. list.len]` to make room.
        /// This operation is O(N).
        /// Invalidates pointers if additional memory is needed.
        pub fn insertSlice(self: *Self, i: usize, items: []const T) Allocator.Error!void {
            try self.ensureUnusedCapacity(items.len);
            self.items.len += items.len;

            mem.copyBackwards(T, self.items[i + items.len .. self.items.len], self.items[i .. self.items.len - items.len]);
            @memcpy(self.items[i..][0..items.len], items);
        }

        /// Replace range of elements `list[start..][0..len]` with `new_items`.
        /// Grows list if `len < new_items.len`.
        /// Shrinks list if `len > new_items.len`.
        /// Invalidates pointers if this ArrayList is resized.
        pub fn replaceRange(self: *Self, start: usize, len: usize, new_items: []const T) Allocator.Error!void {
            const after_range = start + len;
            const range = self.items[start..after_range];

            if (range.len == new_items.len)
                @memcpy(range[0..new_items.len], new_items)
            else if (range.len < new_items.len) {
                const first = new_items[0..range.len];
                const rest = new_items[range.len..];

                @memcpy(range[0..first.len], first);
                try self.insertSlice(after_range, rest);
            } else {
                @memcpy(range[0..new_items.len], new_items);
                const after_subrange = start + new_items.len;

                for (self.items[after_range..], 0..) |item, i| {
                    self.items[after_subrange..][i] = item;
                }

                self.items.len -= len - new_items.len;
            }
        }

        /// Extend the list by 1 element. Allocates more memory as necessary.
        /// Invalidates pointers if additional memory is needed.
        pub fn append(self: *Self, item: T) Allocator.Error!void {
            const new_item_ptr = try self.addOne();
            new_item_ptr.* = item;
        }

        /// Extend the list by 1 element, but assert `self.capacity`
        /// is sufficient to hold an additional item. **Does not**
        /// invalidate pointers.
        pub fn appendAssumeCapacity(self: *Self, item: T) void {
            const new_item_ptr = self.addOneAssumeCapacity();
            new_item_ptr.* = item;
        }

        /// Remove the element at index `i`, shift elements after index
        /// `i` forward, and return the removed element.
        /// Asserts the array has at least one item.
        /// Invalidates pointers to end of list.
        /// This operation is O(N).
        /// This preserves item order. Use `swapRemove` if order preservation is not important.
        pub fn orderedRemove(self: *Self, i: usize) T {
            const newlen = self.items.len - 1;
            if (newlen == i) return self.pop();

            const old_item = self.items[i];
            for (self.items[i..newlen], 0..) |*b, j| b.* = self.items[i + 1 + j];
            self.items[newlen] = undefined;
            self.items.len = newlen;
            return old_item;
        }

        /// Removes the element at the specified index and returns it.
        /// The empty slot is filled from the end of the list.
        /// This operation is O(1).
        /// This may not preserve item order. Use `orderedRemove` if you need to preserve order.
        pub fn swapRemove(self: *Self, i: usize) T {
            if (self.items.len - 1 == i) return self.pop();

            const old_item = self.items[i];
            self.items[i] = self.pop();
            return old_item;
        }

        /// Append the slice of items to the list. Allocates more
        /// memory as necessary.
        /// Invalidates pointers if additional memory is needed.
        pub fn appendSlice(self: *Self, items: []const T) Allocator.Error!void {
            try self.ensureUnusedCapacity(items.len);
            self.appendSliceAssumeCapacity(items);
        }

        /// Append the slice of items to the list, asserting the capacity is already
        /// enough to store the new items. **Does not** invalidate pointers.
        pub fn appendSliceAssumeCapacity(self: *Self, items: []const T) void {
            const old_len = self.items.len;
            const new_len = old_len + items.len;
            assert(new_len <= self.capacity);
            self.items.len = new_len;
            @memcpy(self.items[old_len..][0..items.len], items);
        }

        /// Append an unaligned slice of items to the list. Allocates more
        /// memory as necessary. Only call this function if calling
        /// `appendSlice` instead would be a compile error.
        /// Invalidates pointers if additional memory is needed.
        pub fn appendUnalignedSlice(self: *Self, items: []align(1) const T) Allocator.Error!void {
            try self.ensureUnusedCapacity(items.len);
            self.appendUnalignedSliceAssumeCapacity(items);
        }

        /// Append the slice of items to the list, asserting the capacity is already
        /// enough to store the new items. **Does not** invalidate pointers.
        /// Only call this function if calling `appendSliceAssumeCapacity` instead
        /// would be a compile error.
        pub fn appendUnalignedSliceAssumeCapacity(self: *Self, items: []align(1) const T) void {
            const old_len = self.items.len;
            const new_len = old_len + items.len;
            assert(new_len <= self.capacity);
            self.items.len = new_len;
            @memcpy(self.items[old_len..][0..items.len], items);
        }

        pub const Writer = if (T != u8)
            @compileError("The Writer interface is only defined for ArrayList(u8) " ++
                "but the given type is ArrayList(" ++ @typeName(T) ++ ")")
        else
            std.io.Writer(*Self, error{OutOfMemory}, appendWrite);

        /// Initializes a Writer which will append to the list.
        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        /// Same as `append` except it returns the number of bytes written, which is always the same
        /// as `m.len`. The purpose of this function existing is to match `std.io.Writer` API.
        /// Invalidates pointers if additional memory is needed.
        fn appendWrite(self: *Self, m: []const u8) Allocator.Error!usize {
            try self.appendSlice(m);
            return m.len;
        }

        /// Append a value to the list `n` times.
        /// Allocates more memory as necessary.
        /// Invalidates pointers if additional memory is needed.
        /// The function is inline so that a comptime-known `value` parameter will
        /// have a more optimal memset codegen in case it has a repeated byte pattern.
        pub inline fn appendNTimes(self: *Self, value: T, n: usize) Allocator.Error!void {
            const old_len = self.items.len;
            try self.resize(self.items.len + n);
            @memset(self.items[old_len..self.items.len], value);
        }

        /// Append a value to the list `n` times.
        /// Asserts the capacity is enough. **Does not** invalidate pointers.
        /// The function is inline so that a comptime-known `value` parameter will
        /// have a more optimal memset codegen in case it has a repeated byte pattern.
        pub inline fn appendNTimesAssumeCapacity(self: *Self, value: T, n: usize) void {
            const new_len = self.items.len + n;
            assert(new_len <= self.capacity);
            @memset(self.items.ptr[self.items.len..new_len], value);
            self.items.len = new_len;
        }

        /// Adjust the list's length to `new_len`.
        /// Does not initialize added items if any.
        /// Invalidates pointers if additional memory is needed.
        pub fn resize(self: *Self, new_len: usize) Allocator.Error!void {
            try self.ensureTotalCapacity(new_len);
            self.items.len = new_len;
        }

        /// Reduce allocated capacity to `new_len`.
        /// May invalidate element pointers.
        pub fn shrinkAndFree(self: *Self, new_len: usize) void {
            var unmanaged = self.moveToUnmanaged();
            unmanaged.shrinkAndFree(self.allocator, new_len);
            self.* = unmanaged.toManaged(self.allocator);
        }

        /// Reduce length to `new_len`.
        /// Invalidates pointers for the elements `items[new_len..]`.
        pub fn shrinkRetainingCapacity(self: *Self, new_len: usize) void {
            assert(new_len <= self.items.len);
            self.items.len = new_len;
        }

        /// Invalidates all element pointers.
        pub fn clearRetainingCapacity(self: *Self) void {
            self.items.len = 0;
        }

        /// Invalidates all element pointers.
        pub fn clearAndFree(self: *Self) void {
            self.allocator.free(self.allocatedSlice());
            self.items.len = 0;
            self.capacity = 0;
        }

        /// Modify the array so that it can hold at least `new_capacity` items.
        /// Invalidates pointers if additional memory is needed.
        pub fn ensureTotalCapacity(self: *Self, new_capacity: usize) Allocator.Error!void {
            if (@sizeOf(T) == 0) {
                self.capacity = math.maxInt(usize);
                return;
            }

            if (self.capacity >= new_capacity) return;

            var better_capacity = self.capacity;
            while (true) {
                better_capacity +|= better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }

            return self.ensureTotalCapacityPrecise(better_capacity);
        }

        /// Modify the array so that it can hold `new_capacity` items.
        /// Like `ensureTotalCapacity`, but the resulting capacity is guaranteed
        /// to be equal to `new_capacity`.
        /// Invalidates pointers if additional memory is needed.
        pub fn ensureTotalCapacityPrecise(self: *Self, new_capacity: usize) Allocator.Error!void {
            if (@sizeOf(T) == 0) {
                self.capacity = math.maxInt(usize);
                return;
            }

            if (self.capacity >= new_capacity) return;

            // Here we avoid copying allocated but unused bytes by
            // attempting a resize in place, and falling back to allocating
            // a new buffer and doing our own copy. With a realloc() call,
            // the allocator implementation would pointlessly copy our
            // extra capacity.
            const old_memory = self.allocatedSlice();
            if (self.allocator.resize(old_memory, new_capacity)) {
                self.capacity = new_capacity;
            } else {
                const new_memory = try self.allocator.alignedAlloc(T, alignment, new_capacity);
                @memcpy(new_memory[0..self.items.len], self.items);
                self.allocator.free(old_memory);
                self.items.ptr = new_memory.ptr;
                self.capacity = new_memory.len;
            }
        }

        /// Modify the array so that it can hold at least `additional_count` **more** items.
        /// Invalidates pointers if additional memory is needed.
        pub fn ensureUnusedCapacity(self: *Self, additional_count: usize) Allocator.Error!void {
            return self.ensureTotalCapacity(self.items.len + additional_count);
        }

        /// Increases the array's length to match the full capacity that is already allocated.
        /// The new elements have `undefined` values. **Does not** invalidate pointers.
        pub fn expandToCapacity(self: *Self) void {
            self.items.len = self.capacity;
        }

        /// Increase length by 1, returning pointer to the new item.
        /// The returned pointer becomes invalid when the list resized.
        pub fn addOne(self: *Self) Allocator.Error!*T {
            try self.ensureTotalCapacity(self.items.len + 1);
            return self.addOneAssumeCapacity();
        }

        /// Increase length by 1, returning pointer to the new item.
        /// Asserts that there is already space for the new item without allocating more.
        /// The returned pointer becomes invalid when the list is resized.
        /// **Does not** invalidate element pointers.
        pub fn addOneAssumeCapacity(self: *Self) *T {
            assert(self.items.len < self.capacity);
            self.items.len += 1;
            return &self.items[self.items.len - 1];
        }

        /// Resize the array, adding `n` new elements, which have `undefined` values.
        /// The return value is an array pointing to the newly allocated elements.
        /// The returned pointer becomes invalid when the list is resized.
        /// Resizes list if `self.capacity` is not large enough.
        pub fn addManyAsArray(self: *Self, comptime n: usize) Allocator.Error!*[n]T {
            const prev_len = self.items.len;
            try self.resize(self.items.len + n);
            return self.items[prev_len..][0..n];
        }

        /// Resize the array, adding `n` new elements, which have `undefined` values.
        /// The return value is an array pointing to the newly allocated elements.
        /// Asserts that there is already space for the new item without allocating more.
        /// **Does not** invalidate element pointers.
        /// The returned pointer becomes invalid when the list is resized.
        pub fn addManyAsArrayAssumeCapacity(self: *Self, comptime n: usize) *[n]T {
            assert(self.items.len + n <= self.capacity);
            const prev_len = self.items.len;
            self.items.len += n;
            return self.items[prev_len..][0..n];
        }

        /// Resize the array, adding `n` new elements, which have `undefined` values.
        /// The return value is a slice pointing to the newly allocated elements.
        /// The returned pointer becomes invalid when the list is resized.
        /// Resizes list if `self.capacity` is not large enough.
        pub fn addManyAsSlice(self: *Self, n: usize) Allocator.Error![]T {
            const prev_len = self.items.len;
            try self.resize(self.items.len + n);
            return self.items[prev_len..][0..n];
        }

        /// Resize the array, adding `n` new elements, which have `undefined` values.
        /// The return value is a slice pointing to the newly allocated elements.
        /// Asserts that there is already space for the new item without allocating more.
        /// **Does not** invalidate element pointers.
        /// The returned pointer becomes invalid when the list is resized.
        pub fn addManyAsSliceAssumeCapacity(self: *Self, n: usize) []T {
            assert(self.items.len + n <= self.capacity);
            const prev_len = self.items.len;
            self.items.len += n;
            return self.items[prev_len..][0..n];
        }

        /// Remove and return the last element from the list.
        /// Asserts the list has at least one item.
        /// Invalidates pointers to the removed element.
        pub fn pop(self: *Self) T {
            const val = self.items[self.items.len - 1];
            self.items.len -= 1;
            return val;
        }

        /// Remove and return the last element from the list, or
        /// return `null` if list is empty.
        /// Invalidates pointers to the removed element, if any.
        pub fn popOrNull(self: *Self) ?T {
            if (self.items.len == 0) return null;
            return self.pop();
        }

        /// Returns a slice of all the items plus the extra capacity, whose memory
        /// contents are `undefined`.
        pub fn allocatedSlice(self: Self) Slice {
            // `items.len` is the length, not the capacity.
            return self.items.ptr[0..self.capacity];
        }

        /// Returns a slice of only the extra capacity after items.
        /// This can be useful for writing directly into an ArrayList.
        /// Note that such an operation must be followed up with a direct
        /// modification of `self.items.len`.
        pub fn unusedCapacitySlice(self: Self) Slice {
            return self.allocatedSlice()[self.items.len..];
        }

        /// Return the last element from the list.
        /// Asserts the list has at least one item.
        pub fn getLast(self: Self) T {
            const val = self.items[self.items.len - 1];
            return val;
        }

        /// Return the last element from the list, or
        /// return `null` if list is empty.
        pub fn getLastOrNull(self: Self) ?T {
            if (self.items.len == 0) return null;
            return self.getLast();
        }
    };
}

/// An ArrayList, but the allocator is passed as a parameter to the relevant functions
/// rather than stored in the struct itself. The same allocator **must** be used throughout
/// the entire lifetime of an ArrayListUnmanaged. Initialize directly or with
/// `initCapacity`, and deinitialize with `deinit` or use `toOwnedSlice`.
pub fn ArrayListUnmanaged(comptime T: type) type {
    return ArrayListAlignedUnmanaged(T, null);
}

/// An ArrayListAligned, but the allocator is passed as a parameter to the relevant
/// functions rather than stored  in the struct itself. The same allocator **must**
/// be used throughout the entire lifetime of an ArrayListAlignedUnmanaged.
/// Initialize directly or with `initCapacity`, and deinitialize with `deinit` or use `toOwnedSlice`.
pub fn ArrayListAlignedUnmanaged(comptime T: type, comptime alignment: ?u29) type {
    if (alignment) |a| {
        if (a == @alignOf(T)) {
            return ArrayListAlignedUnmanaged(T, null);
        }
    }
    return struct {
        const Self = @This();
        /// Contents of the list. Pointers to elements in this slice are
        /// **invalid after resizing operations** on the ArrayList unless the
        /// operation explicitly either: (1) states otherwise or (2) lists the
        /// invalidated pointers.
        ///
        /// The allocator used determines how element pointers are
        /// invalidated, so the behavior may vary between lists. To avoid
        /// illegal behavior, take into account the above paragraph plus the
        /// explicit statements given in each method.
        items: Slice = &[_]T{},
        /// How many T values this list can hold without allocating
        /// additional memory.
        capacity: usize = 0,

        pub const Slice = if (alignment) |a| ([]align(a) T) else []T;

        pub fn SentinelSlice(comptime s: T) type {
            return if (alignment) |a| ([:s]align(a) T) else [:s]T;
        }

        /// Initialize with capacity to hold `num` elements.
        /// The resulting capacity will equal `num` exactly.
        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn initCapacity(allocator: Allocator, num: usize) Allocator.Error!Self {
            var self = Self{};
            try self.ensureTotalCapacityPrecise(allocator, num);
            return self;
        }

        /// Release all allocated memory.
        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self.allocatedSlice());
            self.* = undefined;
        }

        /// Convert this list into an analogous memory-managed one.
        /// The returned list has ownership of the underlying memory.
        pub fn toManaged(self: *Self, allocator: Allocator) ArrayListAligned(T, alignment) {
            return .{ .items = self.items, .capacity = self.capacity, .allocator = allocator };
        }

        /// ArrayListUnmanaged takes ownership of the passed in slice. The slice must have been
        /// allocated with `allocator`.
        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn fromOwnedSlice(slice: Slice) Self {
            return Self{
                .items = slice,
                .capacity = slice.len,
            };
        }

        /// ArrayListUnmanaged takes ownership of the passed in slice. The slice must have been
        /// allocated with `allocator`.
        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn fromOwnedSliceSentinel(comptime sentinel: T, slice: [:sentinel]T) Self {
            return Self{
                .items = slice,
                .capacity = slice.len + 1,
            };
        }

        /// The caller owns the returned memory. Empties this ArrayList.
        /// Its capacity is cleared, making deinit() safe but unnecessary to call.
        pub fn toOwnedSlice(self: *Self, allocator: Allocator) Allocator.Error!Slice {
            const old_memory = self.allocatedSlice();
            if (allocator.resize(old_memory, self.items.len)) {
                const result = self.items;
                self.* = .{};
                return result;
            }

            const new_memory = try allocator.alignedAlloc(T, alignment, self.items.len);
            @memcpy(new_memory, self.items);
            @memset(self.items, undefined);
            self.clearAndFree(allocator);
            return new_memory;
        }

        /// The caller owns the returned memory. ArrayList becomes empty.
        pub fn toOwnedSliceSentinel(self: *Self, allocator: Allocator, comptime sentinel: T) Allocator.Error!SentinelSlice(sentinel) {
            try self.ensureTotalCapacityPrecise(allocator, self.items.len + 1);
            self.appendAssumeCapacity(sentinel);
            const result = try self.toOwnedSlice(allocator);
            return result[0 .. result.len - 1 :sentinel];
        }

        /// Creates a copy of this ArrayList.
        pub fn clone(self: Self, allocator: Allocator) Allocator.Error!Self {
            var cloned = try Self.initCapacity(allocator, self.capacity);
            cloned.appendSliceAssumeCapacity(self.items);
            return cloned;
        }

        /// Insert `item` at index `n`. Moves `list[n .. list.len]` to higher indices to make room.
        /// If `n` is equal to the length of the list this operation is equivalent to append.
        /// This operation is O(N).
        /// Invalidates pointers if additional memory is needed.
        pub fn insert(self: *Self, allocator: Allocator, n: usize, item: T) Allocator.Error!void {
            try self.ensureUnusedCapacity(allocator, 1);
            self.insertAssumeCapacity(n, item);
        }

        /// Insert `item` at index `n`. Moves `list[n .. list.len]` to higher indices to make room.
        /// If `n` is equal to the length of the list this operation is equivalent to append.
        /// This operation is O(N).
        /// Asserts that there is enough capacity for the new item.
        pub fn insertAssumeCapacity(self: *Self, n: usize, item: T) void {
            assert(self.items.len < self.capacity);
            self.items.len += 1;

            mem.copyBackwards(T, self.items[n + 1 .. self.items.len], self.items[n .. self.items.len - 1]);
            self.items[n] = item;
        }

        /// Insert slice `items` at index `i`. Moves `list[i .. list.len]` to
        /// higher indicices make room.
        /// This operation is O(N).
        /// Invalidates pointers if additional memory is needed.
        pub fn insertSlice(self: *Self, allocator: Allocator, i: usize, items: []const T) Allocator.Error!void {
            try self.ensureUnusedCapacity(allocator, items.len);
            self.items.len += items.len;

            mem.copyBackwards(T, self.items[i + items.len .. self.items.len], self.items[i .. self.items.len - items.len]);
            @memcpy(self.items[i..][0..items.len], items);
        }

        /// Replace range of elements `list[start..][0..len]` with `new_items`
        /// Grows list if `len < new_items.len`.
        /// Shrinks list if `len > new_items.len`
        /// Invalidates pointers if this ArrayList is resized.
        pub fn replaceRange(self: *Self, allocator: Allocator, start: usize, len: usize, new_items: []const T) Allocator.Error!void {
            var managed = self.toManaged(allocator);
            try managed.replaceRange(start, len, new_items);
            self.* = managed.moveToUnmanaged();
        }

        /// Extend the list by 1 element. Allocates more memory as necessary.
        /// Invalidates pointers if additional memory is needed.
        pub fn append(self: *Self, allocator: Allocator, item: T) Allocator.Error!void {
            const new_item_ptr = try self.addOne(allocator);
            new_item_ptr.* = item;
        }

        /// Extend the list by 1 element, but asserting `self.capacity`
        /// is sufficient to hold an additional item.
        pub fn appendAssumeCapacity(self: *Self, item: T) void {
            const new_item_ptr = self.addOneAssumeCapacity();
            new_item_ptr.* = item;
        }

        /// Remove the element at index `i` from the list and return its value.
        /// Asserts the array has at least one item. Invalidates pointers to
        /// last element.
        /// This operation is O(N).
        pub fn orderedRemove(self: *Self, i: usize) T {
            const newlen = self.items.len - 1;
            if (newlen == i) return self.pop();

            const old_item = self.items[i];
            for (self.items[i..newlen], 0..) |*b, j| b.* = self.items[i + 1 + j];
            self.items[newlen] = undefined;
            self.items.len = newlen;
            return old_item;
        }

        /// Removes the element at the specified index and returns it.
        /// The empty slot is filled from the end of the list.
        /// Invalidates pointers to last element.
        /// This operation is O(1).
        pub fn swapRemove(self: *Self, i: usize) T {
            if (self.items.len - 1 == i) return self.pop();

            const old_item = self.items[i];
            self.items[i] = self.pop();
            return old_item;
        }

        /// Append the slice of items to the list. Allocates more
        /// memory as necessary.
        /// Invalidates pointers if additional memory is needed.
        pub fn appendSlice(self: *Self, allocator: Allocator, items: []const T) Allocator.Error!void {
            try self.ensureUnusedCapacity(allocator, items.len);
            self.appendSliceAssumeCapacity(items);
        }

        /// Append the slice of items to the list, asserting the capacity is enough
        /// to store the new items.
        pub fn appendSliceAssumeCapacity(self: *Self, items: []const T) void {
            const old_len = self.items.len;
            const new_len = old_len + items.len;
            assert(new_len <= self.capacity);
            self.items.len = new_len;
            @memcpy(self.items[old_len..][0..items.len], items);
        }

        /// Append the slice of items to the list. Allocates more
        /// memory as necessary. Only call this function if a call to `appendSlice` instead would
        /// be a compile error.
        /// Invalidates pointers if additional memory is needed.
        pub fn appendUnalignedSlice(self: *Self, allocator: Allocator, items: []align(1) const T) Allocator.Error!void {
            try self.ensureUnusedCapacity(allocator, items.len);
            self.appendUnalignedSliceAssumeCapacity(items);
        }

        /// Append an unaligned slice of items to the list, asserting the capacity is enough
        /// to store the new items. Only call this function if a call to `appendSliceAssumeCapacity`
        /// instead would be a compile error.
        pub fn appendUnalignedSliceAssumeCapacity(self: *Self, items: []align(1) const T) void {
            const old_len = self.items.len;
            const new_len = old_len + items.len;
            assert(new_len <= self.capacity);
            self.items.len = new_len;
            @memcpy(self.items[old_len..][0..items.len], items);
        }

        pub const WriterContext = struct {
            self: *Self,
            allocator: Allocator,
        };

        pub const Writer = if (T != u8)
            @compileError("The Writer interface is only defined for ArrayList(u8) " ++
                "but the given type is ArrayList(" ++ @typeName(T) ++ ")")
        else
            std.io.Writer(WriterContext, error{OutOfMemory}, appendWrite);

        /// Initializes a Writer which will append to the list.
        pub fn writer(self: *Self, allocator: Allocator) Writer {
            return .{ .context = .{ .self = self, .allocator = allocator } };
        }

        /// Same as `append` except it returns the number of bytes written, which is always the same
        /// as `m.len`. The purpose of this function existing is to match `std.io.Writer` API.
        /// Invalidates pointers if additional memory is needed.
        fn appendWrite(context: WriterContext, m: []const u8) Allocator.Error!usize {
            try context.self.appendSlice(context.allocator, m);
            return m.len;
        }

        /// Append a value to the list `n` times.
        /// Allocates more memory as necessary.
        /// Invalidates pointers if additional memory is needed.
        /// The function is inline so that a comptime-known `value` parameter will
        /// have a more optimal memset codegen in case it has a repeated byte pattern.
        pub inline fn appendNTimes(self: *Self, allocator: Allocator, value: T, n: usize) Allocator.Error!void {
            const old_len = self.items.len;
            try self.resize(allocator, self.items.len + n);
            @memset(self.items[old_len..self.items.len], value);
        }

        /// Append a value to the list `n` times.
        /// **Does not** invalidate pointers.
        /// Asserts the capacity is enough.
        /// The function is inline so that a comptime-known `value` parameter will
        /// have a more optimal memset codegen in case it has a repeated byte pattern.
        pub inline fn appendNTimesAssumeCapacity(self: *Self, value: T, n: usize) void {
            const new_len = self.items.len + n;
            assert(new_len <= self.capacity);
            @memset(self.items.ptr[self.items.len..new_len], value);
            self.items.len = new_len;
        }

        /// Adjust the list's length to `new_len`.
        /// Does not initialize added items, if any.
        /// Invalidates pointers if additional memory is needed.
        pub fn resize(self: *Self, allocator: Allocator, new_len: usize) Allocator.Error!void {
            try self.ensureTotalCapacity(allocator, new_len);
            self.items.len = new_len;
        }

        /// Reduce allocated capacity to `new_len`.
        /// May invalidate element pointers.
        pub fn shrinkAndFree(self: *Self, allocator: Allocator, new_len: usize) void {
            assert(new_len <= self.items.len);

            if (@sizeOf(T) == 0) {
                self.items.len = new_len;
                return;
            }

            const old_memory = self.allocatedSlice();
            if (allocator.resize(old_memory, new_len)) {
                self.capacity = new_len;
                self.items.len = new_len;
                return;
            }

            const new_memory = allocator.alignedAlloc(T, alignment, new_len) catch |e| switch (e) {
                error.OutOfMemory => {
                    // No problem, capacity is still correct then.
                    self.items.len = new_len;
                    return;
                },
            };

            @memcpy(new_memory, self.items[0..new_len]);
            allocator.free(old_memory);
            self.items = new_memory;
            self.capacity = new_memory.len;
        }

        /// Reduce length to `new_len`.
        /// Invalidates pointers to elements `items[new_len..]`.
        /// Keeps capacity the same.
        pub fn shrinkRetainingCapacity(self: *Self, new_len: usize) void {
            assert(new_len <= self.items.len);
            self.items.len = new_len;
        }

        /// Invalidates all element pointers.
        pub fn clearRetainingCapacity(self: *Self) void {
            self.items.len = 0;
        }

        /// Invalidates all element pointers.
        pub fn clearAndFree(self: *Self, allocator: Allocator) void {
            allocator.free(self.allocatedSlice());
            self.items.len = 0;
            self.capacity = 0;
        }

        /// Modify the array so that it can hold at least `new_capacity` items.
        /// Invalidates pointers if additional memory is needed.
        pub fn ensureTotalCapacity(self: *Self, allocator: Allocator, new_capacity: usize) Allocator.Error!void {
            if (self.capacity >= new_capacity) return;

            var better_capacity = self.capacity;
            while (true) {
                better_capacity +|= better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }

            return self.ensureTotalCapacityPrecise(allocator, better_capacity);
        }

        /// Modify the array so that it can hold `new_capacity` items.
        /// Like `ensureTotalCapacity`, but the resulting capacity is guaranteed
        /// to be equal to `new_capacity`.
        /// Invalidates pointers if additional memory is needed.
        pub fn ensureTotalCapacityPrecise(self: *Self, allocator: Allocator, new_capacity: usize) Allocator.Error!void {
            if (@sizeOf(T) == 0) {
                self.capacity = math.maxInt(usize);
                return;
            }

            if (self.capacity >= new_capacity) return;

            // Here we avoid copying allocated but unused bytes by
            // attempting a resize in place, and falling back to allocating
            // a new buffer and doing our own copy. With a realloc() call,
            // the allocator implementation would pointlessly copy our
            // extra capacity.
            const old_memory = self.allocatedSlice();
            if (allocator.resize(old_memory, new_capacity)) {
                self.capacity = new_capacity;
            } else {
                const new_memory = try allocator.alignedAlloc(T, alignment, new_capacity);
                @memcpy(new_memory[0..self.items.len], self.items);
                allocator.free(old_memory);
                self.items.ptr = new_memory.ptr;
                self.capacity = new_memory.len;
            }
        }

        /// Modify the array so that it can hold at least `additional_count` **more** items.
        /// Invalidates pointers if additional memory is needed.
        pub fn ensureUnusedCapacity(
            self: *Self,
            allocator: Allocator,
            additional_count: usize,
        ) Allocator.Error!void {
            return self.ensureTotalCapacity(allocator, self.items.len + additional_count);
        }

        /// Increases the array's length to match the full capacity that is already allocated.
        /// The new elements have `undefined` values.
        /// **Does not** invalidate pointers.
        pub fn expandToCapacity(self: *Self) void {
            self.items.len = self.capacity;
        }

        /// Increase length by 1, returning pointer to the new item.
        /// The returned pointer becomes invalid when the list resized.
        pub fn addOne(self: *Self, allocator: Allocator) Allocator.Error!*T {
            const newlen = self.items.len + 1;
            try self.ensureTotalCapacity(allocator, newlen);
            return self.addOneAssumeCapacity();
        }

        /// Increase length by 1, returning pointer to the new item.
        /// Asserts that there is already space for the new item without allocating more.
        /// **Does not** invalidate pointers.
        /// The returned pointer becomes invalid when the list resized.
        pub fn addOneAssumeCapacity(self: *Self) *T {
            assert(self.items.len < self.capacity);

            self.items.len += 1;
            return &self.items[self.items.len - 1];
        }

        /// Resize the array, adding `n` new elements, which have `undefined` values.
        /// The return value is an array pointing to the newly allocated elements.
        /// The returned pointer becomes invalid when the list is resized.
        pub fn addManyAsArray(self: *Self, allocator: Allocator, comptime n: usize) Allocator.Error!*[n]T {
            const prev_len = self.items.len;
            try self.resize(allocator, self.items.len + n);
            return self.items[prev_len..][0..n];
        }

        /// Resize the array, adding `n` new elements, which have `undefined` values.
        /// The return value is an array pointing to the newly allocated elements.
        /// Asserts that there is already space for the new item without allocating more.
        /// **Does not** invalidate pointers.
        /// The returned pointer becomes invalid when the list is resized.
        pub fn addManyAsArrayAssumeCapacity(self: *Self, comptime n: usize) *[n]T {
            assert(self.items.len + n <= self.capacity);
            const prev_len = self.items.len;
            self.items.len += n;
            return self.items[prev_len..][0..n];
        }

        /// Resize the array, adding `n` new elements, which have `undefined` values.
        /// The return value is a slice pointing to the newly allocated elements.
        /// The returned pointer becomes invalid when the list is resized.
        /// Resizes list if `self.capacity` is not large enough.
        pub fn addManyAsSlice(self: *Self, allocator: Allocator, n: usize) Allocator.Error![]T {
            const prev_len = self.items.len;
            try self.resize(allocator, self.items.len + n);
            return self.items[prev_len..][0..n];
        }

        /// Resize the array, adding `n` new elements, which have `undefined` values.
        /// The return value is a slice pointing to the newly allocated elements.
        /// Asserts that there is already space for the new item without allocating more.
        /// **Does not** invalidate element pointers.
        /// The returned pointer becomes invalid when the list is resized.
        pub fn addManyAsSliceAssumeCapacity(self: *Self, n: usize) []T {
            assert(self.items.len + n <= self.capacity);
            const prev_len = self.items.len;
            self.items.len += n;
            return self.items[prev_len..][0..n];
        }

        /// Remove and return the last element from the list.
        /// Asserts the list has at least one item.
        /// Invalidates pointers to last element.
        pub fn pop(self: *Self) T {
            const val = self.items[self.items.len - 1];
            self.items.len -= 1;
            return val;
        }

        /// Remove and return the last element from the list.
        /// If the list is empty, returns `null`.
        /// Invalidates pointers to last element.
        pub fn popOrNull(self: *Self) ?T {
            if (self.items.len == 0) return null;
            return self.pop();
        }

        /// Returns a slice of all the items plus the extra capacity, whose memory
        /// contents are `undefined`.
        pub fn allocatedSlice(self: Self) Slice {
            return self.items.ptr[0..self.capacity];
        }

        /// Returns a slice of only the extra capacity after items.
        /// This can be useful for writing directly into an ArrayList.
        /// Note that such an operation must be followed up with a direct
        /// modification of `self.items.len`.
        pub fn unusedCapacitySlice(self: Self) Slice {
            return self.allocatedSlice()[self.items.len..];
        }

        /// Return the last element from the list.
        /// Asserts the list has at least one item.
        pub fn getLast(self: Self) T {
            const val = self.items[self.items.len - 1];
            return val;
        }

        /// Return the last element from the list, or
        /// return `null` if list is empty.
        pub fn getLastOrNull(self: Self) ?T {
            if (self.items.len == 0) return null;
            return self.getLast();
        }
    };
}

test "std.ArrayList/ArrayListUnmanaged.init" {
    {
        var list = ArrayList(i32).init(testing.allocator);
        defer list.deinit();

        try testing.expect(list.items.len == 0);
        try testing.expect(list.capacity == 0);
    }

    {
        var list = ArrayListUnmanaged(i32){};

        try testing.expect(list.items.len == 0);
        try testing.expect(list.capacity == 0);
    }
}

test "std.ArrayList/ArrayListUnmanaged.initCapacity" {
    const a = testing.allocator;
    {
        var list = try ArrayList(i8).initCapacity(a, 200);
        defer list.deinit();
        try testing.expect(list.items.len == 0);
        try testing.expect(list.capacity >= 200);
    }
    {
        var list = try ArrayListUnmanaged(i8).initCapacity(a, 200);
        defer list.deinit(a);
        try testing.expect(list.items.len == 0);
        try testing.expect(list.capacity >= 200);
    }
}

test "std.ArrayList/ArrayListUnmanaged.clone" {
    const a = testing.allocator;
    {
        var array = ArrayList(i32).init(a);
        try array.append(-1);
        try array.append(3);
        try array.append(5);

        const cloned = try array.clone();
        defer cloned.deinit();

        try testing.expectEqualSlices(i32, array.items, cloned.items);
        try testing.expectEqual(array.allocator, cloned.allocator);
        try testing.expect(cloned.capacity >= array.capacity);

        array.deinit();

        try testing.expectEqual(@as(i32, -1), cloned.items[0]);
        try testing.expectEqual(@as(i32, 3), cloned.items[1]);
        try testing.expectEqual(@as(i32, 5), cloned.items[2]);
    }
    {
        var array = ArrayListUnmanaged(i32){};
        try array.append(a, -1);
        try array.append(a, 3);
        try array.append(a, 5);

        var cloned = try array.clone(a);
        defer cloned.deinit(a);

        try testing.expectEqualSlices(i32, array.items, cloned.items);
        try testing.expect(cloned.capacity >= array.capacity);

        array.deinit(a);

        try testing.expectEqual(@as(i32, -1), cloned.items[0]);
        try testing.expectEqual(@as(i32, 3), cloned.items[1]);
        try testing.expectEqual(@as(i32, 5), cloned.items[2]);
    }
}

test "std.ArrayList/ArrayListUnmanaged.basic" {
    const a = testing.allocator;
    {
        var list = ArrayList(i32).init(a);
        defer list.deinit();

        {
            var i: usize = 0;
            while (i < 10) : (i += 1) {
                list.append(@as(i32, @intCast(i + 1))) catch unreachable;
            }
        }

        {
            var i: usize = 0;
            while (i < 10) : (i += 1) {
                try testing.expect(list.items[i] == @as(i32, @intCast(i + 1)));
            }
        }

        for (list.items, 0..) |v, i| {
            try testing.expect(v == @as(i32, @intCast(i + 1)));
        }

        try testing.expect(list.pop() == 10);
        try testing.expect(list.items.len == 9);

        list.appendSlice(&[_]i32{ 1, 2, 3 }) catch unreachable;
        try testing.expect(list.items.len == 12);
        try testing.expect(list.pop() == 3);
        try testing.expect(list.pop() == 2);
        try testing.expect(list.pop() == 1);
        try testing.expect(list.items.len == 9);

        var unaligned: [3]i32 align(1) = [_]i32{ 4, 5, 6 };
        list.appendUnalignedSlice(&unaligned) catch unreachable;
        try testing.expect(list.items.len == 12);
        try testing.expect(list.pop() == 6);
        try testing.expect(list.pop() == 5);
        try testing.expect(list.pop() == 4);
        try testing.expect(list.items.len == 9);

        list.appendSlice(&[_]i32{}) catch unreachable;
        try testing.expect(list.items.len == 9);

        // can only set on indices < self.items.len
        list.items[7] = 33;
        list.items[8] = 42;

        try testing.expect(list.pop() == 42);
        try testing.expect(list.pop() == 33);
    }
    {
        var list = ArrayListUnmanaged(i32){};
        defer list.deinit(a);

        {
            var i: usize = 0;
            while (i < 10) : (i += 1) {
                list.append(a, @as(i32, @intCast(i + 1))) catch unreachable;
            }
        }

        {
            var i: usize = 0;
            while (i < 10) : (i += 1) {
                try testing.expect(list.items[i] == @as(i32, @intCast(i + 1)));
            }
        }

        for (list.items, 0..) |v, i| {
            try testing.expect(v == @as(i32, @intCast(i + 1)));
        }

        try testing.expect(list.pop() == 10);
        try testing.expect(list.items.len == 9);

        list.appendSlice(a, &[_]i32{ 1, 2, 3 }) catch unreachable;
        try testing.expect(list.items.len == 12);
        try testing.expect(list.pop() == 3);
        try testing.expect(list.pop() == 2);
        try testing.expect(list.pop() == 1);
        try testing.expect(list.items.len == 9);

        var unaligned: [3]i32 align(1) = [_]i32{ 4, 5, 6 };
        list.appendUnalignedSlice(a, &unaligned) catch unreachable;
        try testing.expect(list.items.len == 12);
        try testing.expect(list.pop() == 6);
        try testing.expect(list.pop() == 5);
        try testing.expect(list.pop() == 4);
        try testing.expect(list.items.len == 9);

        list.appendSlice(a, &[_]i32{}) catch unreachable;
        try testing.expect(list.items.len == 9);

        // can only set on indices < self.items.len
        list.items[7] = 33;
        list.items[8] = 42;

        try testing.expect(list.pop() == 42);
        try testing.expect(list.pop() == 33);
    }
}

test "std.ArrayList/ArrayListUnmanaged.appendNTimes" {
    const a = testing.allocator;
    {
        var list = ArrayList(i32).init(a);
        defer list.deinit();

        try list.appendNTimes(2, 10);
        try testing.expectEqual(@as(usize, 10), list.items.len);
        for (list.items) |element| {
            try testing.expectEqual(@as(i32, 2), element);
        }
    }
    {
        var list = ArrayListUnmanaged(i32){};
        defer list.deinit(a);

        try list.appendNTimes(a, 2, 10);
        try testing.expectEqual(@as(usize, 10), list.items.len);
        for (list.items) |element| {
            try testing.expectEqual(@as(i32, 2), element);
        }
    }
}

test "std.ArrayList/ArrayListUnmanaged.appendNTimes with failing allocator" {
    const a = testing.failing_allocator;
    {
        var list = ArrayList(i32).init(a);
        defer list.deinit();
        try testing.expectError(error.OutOfMemory, list.appendNTimes(2, 10));
    }
    {
        var list = ArrayListUnmanaged(i32){};
        defer list.deinit(a);
        try testing.expectError(error.OutOfMemory, list.appendNTimes(a, 2, 10));
    }
}

test "std.ArrayList/ArrayListUnmanaged.orderedRemove" {
    const a = testing.allocator;
    {
        var list = ArrayList(i32).init(a);
        defer list.deinit();

        try list.append(1);
        try list.append(2);
        try list.append(3);
        try list.append(4);
        try list.append(5);
        try list.append(6);
        try list.append(7);

        //remove from middle
        try testing.expectEqual(@as(i32, 4), list.orderedRemove(3));
        try testing.expectEqual(@as(i32, 5), list.items[3]);
        try testing.expectEqual(@as(usize, 6), list.items.len);

        //remove from end
        try testing.expectEqual(@as(i32, 7), list.orderedRemove(5));
        try testing.expectEqual(@as(usize, 5), list.items.len);

        //remove from front
        try testing.expectEqual(@as(i32, 1), list.orderedRemove(0));
        try testing.expectEqual(@as(i32, 2), list.items[0]);
        try testing.expectEqual(@as(usize, 4), list.items.len);
    }
    {
        var list = ArrayListUnmanaged(i32){};
        defer list.deinit(a);

        try list.append(a, 1);
        try list.append(a, 2);
        try list.append(a, 3);
        try list.append(a, 4);
        try list.append(a, 5);
        try list.append(a, 6);
        try list.append(a, 7);

        //remove from middle
        try testing.expectEqual(@as(i32, 4), list.orderedRemove(3));
        try testing.expectEqual(@as(i32, 5), list.items[3]);
        try testing.expectEqual(@as(usize, 6), list.items.len);

        //remove from end
        try testing.expectEqual(@as(i32, 7), list.orderedRemove(5));
        try testing.expectEqual(@as(usize, 5), list.items.len);

        //remove from front
        try testing.expectEqual(@as(i32, 1), list.orderedRemove(0));
        try testing.expectEqual(@as(i32, 2), list.items[0]);
        try testing.expectEqual(@as(usize, 4), list.items.len);
    }
}

test "std.ArrayList/ArrayListUnmanaged.swapRemove" {
    const a = testing.allocator;
    {
        var list = ArrayList(i32).init(a);
        defer list.deinit();

        try list.append(1);
        try list.append(2);
        try list.append(3);
        try list.append(4);
        try list.append(5);
        try list.append(6);
        try list.append(7);

        //remove from middle
        try testing.expect(list.swapRemove(3) == 4);
        try testing.expect(list.items[3] == 7);
        try testing.expect(list.items.len == 6);

        //remove from end
        try testing.expect(list.swapRemove(5) == 6);
        try testing.expect(list.items.len == 5);

        //remove from front
        try testing.expect(list.swapRemove(0) == 1);
        try testing.expect(list.items[0] == 5);
        try testing.expect(list.items.len == 4);
    }
    {
        var list = ArrayListUnmanaged(i32){};
        defer list.deinit(a);

        try list.append(a, 1);
        try list.append(a, 2);
        try list.append(a, 3);
        try list.append(a, 4);
        try list.append(a, 5);
        try list.append(a, 6);
        try list.append(a, 7);

        //remove from middle
        try testing.expect(list.swapRemove(3) == 4);
        try testing.expect(list.items[3] == 7);
        try testing.expect(list.items.len == 6);

        //remove from end
        try testing.expect(list.swapRemove(5) == 6);
        try testing.expect(list.items.len == 5);

        //remove from front
        try testing.expect(list.swapRemove(0) == 1);
        try testing.expect(list.items[0] == 5);
        try testing.expect(list.items.len == 4);
    }
}

test "std.ArrayList/ArrayListUnmanaged.insert" {
    const a = testing.allocator;
    {
        var list = ArrayList(i32).init(a);
        defer list.deinit();

        try list.insert(0, 1);
        try list.append(2);
        try list.insert(2, 3);
        try list.insert(0, 5);
        try testing.expect(list.items[0] == 5);
        try testing.expect(list.items[1] == 1);
        try testing.expect(list.items[2] == 2);
        try testing.expect(list.items[3] == 3);
    }
    {
        var list = ArrayListUnmanaged(i32){};
        defer list.deinit(a);

        try list.insert(a, 0, 1);
        try list.append(a, 2);
        try list.insert(a, 2, 3);
        try list.insert(a, 0, 5);
        try testing.expect(list.items[0] == 5);
        try testing.expect(list.items[1] == 1);
        try testing.expect(list.items[2] == 2);
        try testing.expect(list.items[3] == 3);
    }
}

test "std.ArrayList/ArrayListUnmanaged.insertSlice" {
    const a = testing.allocator;
    {
        var list = ArrayList(i32).init(a);
        defer list.deinit();

        try list.append(1);
        try list.append(2);
        try list.append(3);
        try list.append(4);
        try list.insertSlice(1, &[_]i32{ 9, 8 });
        try testing.expect(list.items[0] == 1);
        try testing.expect(list.items[1] == 9);
        try testing.expect(list.items[2] == 8);
        try testing.expect(list.items[3] == 2);
        try testing.expect(list.items[4] == 3);
        try testing.expect(list.items[5] == 4);

        const items = [_]i32{1};
        try list.insertSlice(0, items[0..0]);
        try testing.expect(list.items.len == 6);
        try testing.expect(list.items[0] == 1);
    }
    {
        var list = ArrayListUnmanaged(i32){};
        defer list.deinit(a);

        try list.append(a, 1);
        try list.append(a, 2);
        try list.append(a, 3);
        try list.append(a, 4);
        try list.insertSlice(a, 1, &[_]i32{ 9, 8 });
        try testing.expect(list.items[0] == 1);
        try testing.expect(list.items[1] == 9);
        try testing.expect(list.items[2] == 8);
        try testing.expect(list.items[3] == 2);
        try testing.expect(list.items[4] == 3);
        try testing.expect(list.items[5] == 4);

        const items = [_]i32{1};
        try list.insertSlice(a, 0, items[0..0]);
        try testing.expect(list.items.len == 6);
        try testing.expect(list.items[0] == 1);
    }
}

test "std.ArrayList/ArrayListUnmanaged.replaceRange" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const init = [_]i32{ 1, 2, 3, 4, 5 };
    const new = [_]i32{ 0, 0, 0 };

    const result_zero = [_]i32{ 1, 0, 0, 0, 2, 3, 4, 5 };
    const result_eq = [_]i32{ 1, 0, 0, 0, 5 };
    const result_le = [_]i32{ 1, 0, 0, 0, 4, 5 };
    const result_gt = [_]i32{ 1, 0, 0, 0 };

    {
        var list_zero = ArrayList(i32).init(a);
        var list_eq = ArrayList(i32).init(a);
        var list_lt = ArrayList(i32).init(a);
        var list_gt = ArrayList(i32).init(a);

        try list_zero.appendSlice(&init);
        try list_eq.appendSlice(&init);
        try list_lt.appendSlice(&init);
        try list_gt.appendSlice(&init);

        try list_zero.replaceRange(1, 0, &new);
        try list_eq.replaceRange(1, 3, &new);
        try list_lt.replaceRange(1, 2, &new);

        // after_range > new_items.len in function body
        try testing.expect(1 + 4 > new.len);
        try list_gt.replaceRange(1, 4, &new);

        try testing.expectEqualSlices(i32, list_zero.items, &result_zero);
        try testing.expectEqualSlices(i32, list_eq.items, &result_eq);
        try testing.expectEqualSlices(i32, list_lt.items, &result_le);
        try testing.expectEqualSlices(i32, list_gt.items, &result_gt);
    }
    {
        var list_zero = ArrayListUnmanaged(i32){};
        var list_eq = ArrayListUnmanaged(i32){};
        var list_lt = ArrayListUnmanaged(i32){};
        var list_gt = ArrayListUnmanaged(i32){};

        try list_zero.appendSlice(a, &init);
        try list_eq.appendSlice(a, &init);
        try list_lt.appendSlice(a, &init);
        try list_gt.appendSlice(a, &init);

        try list_zero.replaceRange(a, 1, 0, &new);
        try list_eq.replaceRange(a, 1, 3, &new);
        try list_lt.replaceRange(a, 1, 2, &new);

        // after_range > new_items.len in function body
        try testing.expect(1 + 4 > new.len);
        try list_gt.replaceRange(a, 1, 4, &new);

        try testing.expectEqualSlices(i32, list_zero.items, &result_zero);
        try testing.expectEqualSlices(i32, list_eq.items, &result_eq);
        try testing.expectEqualSlices(i32, list_lt.items, &result_le);
        try testing.expectEqualSlices(i32, list_gt.items, &result_gt);
    }
}

const Item = struct {
    integer: i32,
    sub_items: ArrayList(Item),
};

const ItemUnmanaged = struct {
    integer: i32,
    sub_items: ArrayListUnmanaged(ItemUnmanaged),
};

test "std.ArrayList/ArrayListUnmanaged: ArrayList(T) of struct T" {
    const a = std.testing.allocator;
    {
        var root = Item{ .integer = 1, .sub_items = ArrayList(Item).init(a) };
        defer root.sub_items.deinit();
        try root.sub_items.append(Item{ .integer = 42, .sub_items = ArrayList(Item).init(a) });
        try testing.expect(root.sub_items.items[0].integer == 42);
    }
    {
        var root = ItemUnmanaged{ .integer = 1, .sub_items = ArrayListUnmanaged(ItemUnmanaged){} };
        defer root.sub_items.deinit(a);
        try root.sub_items.append(a, ItemUnmanaged{ .integer = 42, .sub_items = ArrayListUnmanaged(ItemUnmanaged){} });
        try testing.expect(root.sub_items.items[0].integer == 42);
    }
}

test "std.ArrayList(u8)/ArrayListAligned implements writer" {
    const a = testing.allocator;

    {
        var buffer = ArrayList(u8).init(a);
        defer buffer.deinit();

        const x: i32 = 42;
        const y: i32 = 1234;
        try buffer.writer().print("x: {}\ny: {}\n", .{ x, y });

        try testing.expectEqualSlices(u8, "x: 42\ny: 1234\n", buffer.items);
    }
    {
        var list = ArrayListAligned(u8, 2).init(a);
        defer list.deinit();

        const writer = list.writer();
        try writer.writeAll("a");
        try writer.writeAll("bc");
        try writer.writeAll("d");
        try writer.writeAll("efg");

        try testing.expectEqualSlices(u8, list.items, "abcdefg");
    }
}

test "std.ArrayListUnmanaged(u8) implements writer" {
    const a = testing.allocator;

    {
        var buffer: ArrayListUnmanaged(u8) = .{};
        defer buffer.deinit(a);

        const x: i32 = 42;
        const y: i32 = 1234;
        try buffer.writer(a).print("x: {}\ny: {}\n", .{ x, y });

        try testing.expectEqualSlices(u8, "x: 42\ny: 1234\n", buffer.items);
    }
    {
        var list: ArrayListAlignedUnmanaged(u8, 2) = .{};
        defer list.deinit(a);

        const writer = list.writer(a);
        try writer.writeAll("a");
        try writer.writeAll("bc");
        try writer.writeAll("d");
        try writer.writeAll("efg");

        try testing.expectEqualSlices(u8, list.items, "abcdefg");
    }
}

test "shrink still sets length when resizing is disabled" {
    // Use the testing allocator but with resize disabled.
    var a = testing.allocator;
    a.vtable = &.{
        .alloc = a.vtable.alloc,
        .resize = Allocator.noResize,
        .free = a.vtable.free,
    };

    {
        var list = ArrayList(i32).init(a);
        defer list.deinit();

        try list.append(1);
        try list.append(2);
        try list.append(3);

        list.shrinkAndFree(1);
        try testing.expect(list.items.len == 1);
    }
    {
        var list = ArrayListUnmanaged(i32){};
        defer list.deinit(a);

        try list.append(a, 1);
        try list.append(a, 2);
        try list.append(a, 3);

        list.shrinkAndFree(a, 1);
        try testing.expect(list.items.len == 1);
    }
}

test "shrinkAndFree with a copy" {
    // Use the testing allocator but with resize disabled.
    var a = testing.allocator;
    a.vtable = &.{
        .alloc = a.vtable.alloc,
        .resize = Allocator.noResize,
        .free = a.vtable.free,
    };
    var list = ArrayList(i32).init(a);
    defer list.deinit();

    try list.appendNTimes(3, 16);
    list.shrinkAndFree(4);
    try testing.expect(mem.eql(i32, list.items, &.{ 3, 3, 3, 3 }));
}

test "std.ArrayList/ArrayListUnmanaged.addManyAsArray" {
    const a = std.testing.allocator;
    {
        var list = ArrayList(u8).init(a);
        defer list.deinit();

        (try list.addManyAsArray(4)).* = "aoeu".*;
        try list.ensureTotalCapacity(8);
        list.addManyAsArrayAssumeCapacity(4).* = "asdf".*;

        try testing.expectEqualSlices(u8, list.items, "aoeuasdf");
    }
    {
        var list = ArrayListUnmanaged(u8){};
        defer list.deinit(a);

        (try list.addManyAsArray(a, 4)).* = "aoeu".*;
        try list.ensureTotalCapacity(a, 8);
        list.addManyAsArrayAssumeCapacity(4).* = "asdf".*;

        try testing.expectEqualSlices(u8, list.items, "aoeuasdf");
    }
}

test "std.ArrayList/ArrayList.fromOwnedSliceSentinel" {
    const a = testing.allocator;

    var orig_list = ArrayList(u8).init(a);
    defer orig_list.deinit();
    try orig_list.appendSlice("foobar");
    const sentinel_slice = try orig_list.toOwnedSliceSentinel(0);

    var list = ArrayList(u8).fromOwnedSliceSentinel(a, 0, sentinel_slice);
    defer list.deinit();
    try testing.expectEqualStrings(list.items, "foobar");
}

test "std.ArrayList/ArrayListUnmanaged.fromOwnedSlice" {
    const a = testing.allocator;

    var list = ArrayList(u8).init(a);
    defer list.deinit();
    try list.appendSlice("foobar");

    const slice = try list.toOwnedSlice();
    var unmanaged = ArrayListUnmanaged(u8).fromOwnedSlice(slice);
    defer unmanaged.deinit(a);
    try testing.expectEqualStrings(unmanaged.items, "foobar");
}

test "std.ArrayList/ArrayListUnmanaged.fromOwnedSliceSentinel" {
    const a = testing.allocator;

    var list = ArrayList(u8).init(a);
    defer list.deinit();
    try list.appendSlice("foobar");

    const sentinel_slice = try list.toOwnedSliceSentinel(0);
    var unmanaged = ArrayListUnmanaged(u8).fromOwnedSliceSentinel(0, sentinel_slice);
    defer unmanaged.deinit(a);
    try testing.expectEqualStrings(unmanaged.items, "foobar");
}

test "std.ArrayList/ArrayListUnmanaged.toOwnedSliceSentinel" {
    const a = testing.allocator;
    {
        var list = ArrayList(u8).init(a);
        defer list.deinit();

        try list.appendSlice("foobar");

        const result = try list.toOwnedSliceSentinel(0);
        defer a.free(result);
        try testing.expectEqualStrings(result, mem.sliceTo(result.ptr, 0));
    }
    {
        var list = ArrayListUnmanaged(u8){};
        defer list.deinit(a);

        try list.appendSlice(a, "foobar");

        const result = try list.toOwnedSliceSentinel(a, 0);
        defer a.free(result);
        try testing.expectEqualStrings(result, mem.sliceTo(result.ptr, 0));
    }
}

test "ArrayListAligned/ArrayListAlignedUnmanaged accepts unaligned slices" {
    const a = testing.allocator;
    {
        var list = std.ArrayListAligned(u8, 8).init(a);
        defer list.deinit();

        try list.appendSlice(&.{ 0, 1, 2, 3 });
        try list.insertSlice(2, &.{ 4, 5, 6, 7 });
        try list.replaceRange(1, 3, &.{ 8, 9 });

        try testing.expectEqualSlices(u8, list.items, &.{ 0, 8, 9, 6, 7, 2, 3 });
    }
    {
        var list = std.ArrayListAlignedUnmanaged(u8, 8){};
        defer list.deinit(a);

        try list.appendSlice(a, &.{ 0, 1, 2, 3 });
        try list.insertSlice(a, 2, &.{ 4, 5, 6, 7 });
        try list.replaceRange(a, 1, 3, &.{ 8, 9 });

        try testing.expectEqualSlices(u8, list.items, &.{ 0, 8, 9, 6, 7, 2, 3 });
    }
}

test "std.ArrayList(u0)" {
    // An ArrayList on zero-sized types should not need to allocate
    var failing_allocator = testing.FailingAllocator.init(testing.allocator, 0);
    const a = failing_allocator.allocator();

    var list = ArrayList(u0).init(a);
    defer list.deinit();

    try list.append(0);
    try list.append(0);
    try list.append(0);
    try testing.expectEqual(list.items.len, 3);

    var count: usize = 0;
    for (list.items) |x| {
        try testing.expectEqual(x, 0);
        count += 1;
    }
    try testing.expectEqual(count, 3);
}

test "std.ArrayList(?u32).popOrNull()" {
    const a = testing.allocator;

    var list = ArrayList(?u32).init(a);
    defer list.deinit();

    try list.append(null);
    try list.append(1);
    try list.append(2);
    try testing.expectEqual(list.items.len, 3);

    try testing.expect(list.popOrNull().? == @as(u32, 2));
    try testing.expect(list.popOrNull().? == @as(u32, 1));
    try testing.expect(list.popOrNull().? == null);
    try testing.expect(list.popOrNull() == null);
}

test "std.ArrayList(u32).getLast()" {
    const a = testing.allocator;

    var list = ArrayList(u32).init(a);
    defer list.deinit();

    try list.append(2);
    const const_list = list;
    try testing.expectEqual(const_list.getLast(), 2);
}

test "std.ArrayList(u32).getLastOrNull()" {
    const a = testing.allocator;

    var list = ArrayList(u32).init(a);
    defer list.deinit();

    try testing.expectEqual(list.getLastOrNull(), null);

    try list.append(2);
    const const_list = list;
    try testing.expectEqual(const_list.getLastOrNull().?, 2);
}

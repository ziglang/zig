//! This ring buffer stores read and write indices while being able to utilise
//! the full backing slice by incrementing the indices modulo twice the slice's
//! length and reducing indices modulo the slice's length on slice access. This
//! means that whether the ring buffer is full or empty can be distinguished by
//! looking at the difference between the read and write indices without adding
//! an extra boolean flag or having to reserve a slot in the buffer.
//!
//! This ring buffer has not been implemented with thread safety in mind, and
//! therefore should not be assumed to be suitable for use cases involving
//! separate reader and writer threads.

const Allocator = @import("std").mem.Allocator;
const assert = @import("std").debug.assert;

const RingBuffer = @This();

data: []u8,
read_index: usize,
write_index: usize,

pub const Error = error{Full};

/// Allocate a new `RingBuffer`; `deinit()` should be called to free the buffer.
pub fn init(allocator: Allocator, capacity: usize) Allocator.Error!RingBuffer {
    const bytes = try allocator.alloc(u8, capacity);
    return RingBuffer{
        .data = bytes,
        .write_index = 0,
        .read_index = 0,
    };
}

/// Free the data backing a `RingBuffer`; must be passed the same `Allocator` as
/// `init()`.
pub fn deinit(self: *RingBuffer, allocator: Allocator) void {
    allocator.free(self.data);
    self.* = undefined;
}

/// Returns `index` modulo the length of the backing slice.
pub fn mask(self: RingBuffer, index: usize) usize {
    return index % self.data.len;
}

/// Returns `index` modulo twice the length of the backing slice.
pub fn mask2(self: RingBuffer, index: usize) usize {
    return index % (2 * self.data.len);
}

/// Write `byte` into the ring buffer. Returns `error.Full` if the ring
/// buffer is full.
pub fn write(self: *RingBuffer, byte: u8) Error!void {
    if (self.isFull()) return error.Full;
    self.writeAssumeCapacity(byte);
}

/// Write `byte` into the ring buffer. If the ring buffer is full, the
/// oldest byte is overwritten.
pub fn writeAssumeCapacity(self: *RingBuffer, byte: u8) void {
    self.data[self.mask(self.write_index)] = byte;
    self.write_index = self.mask2(self.write_index + 1);
}

/// Write `bytes` into the ring buffer. Returns `error.Full` if the ring
/// buffer does not have enough space, without writing any data.
pub fn writeSlice(self: *RingBuffer, bytes: []const u8) Error!void {
    if (self.len() + bytes.len > self.data.len) return error.Full;
    self.writeSliceAssumeCapacity(bytes);
}

/// Write `bytes` into the ring buffer. If there is not enough space, older
/// bytes will be overwritten.
pub fn writeSliceAssumeCapacity(self: *RingBuffer, bytes: []const u8) void {
    for (bytes) |b| self.writeAssumeCapacity(b);
}

/// Consume a byte from the ring buffer and return it. Returns `null` if the
/// ring buffer is empty.
pub fn read(self: *RingBuffer) ?u8 {
    if (self.isEmpty()) return null;
    return self.readAssumeLength();
}

/// Consume a byte from the ring buffer and return it; asserts that the buffer
/// is not empty.
pub fn readAssumeLength(self: *RingBuffer) u8 {
    assert(!self.isEmpty());
    const byte = self.data[self.mask(self.read_index)];
    self.read_index = self.mask2(self.read_index + 1);
    return byte;
}

/// Returns `true` if the ring buffer is empty and `false` otherwise.
pub fn isEmpty(self: RingBuffer) bool {
    return self.write_index == self.read_index;
}

/// Returns `true` if the ring buffer is full and `false` otherwise.
pub fn isFull(self: RingBuffer) bool {
    return self.mask2(self.write_index + self.data.len) == self.read_index;
}

/// Returns the length
pub fn len(self: RingBuffer) usize {
    const wrap_offset = 2 * self.data.len * @intFromBool(self.write_index < self.read_index);
    const adjusted_write_index = self.write_index + wrap_offset;
    return adjusted_write_index - self.read_index;
}

/// A `Slice` represents a region of a ring buffer. The region is split into two
/// sections as the ring buffer data will not be contiguous if the desired
/// region wraps to the start of the backing slice.
pub const Slice = struct {
    first: []u8,
    second: []u8,
};

/// Returns a `Slice` for the region of the ring buffer starting at
/// `self.mask(start_unmasked)` with the specified length.
pub fn sliceAt(self: RingBuffer, start_unmasked: usize, length: usize) Slice {
    assert(length <= self.data.len);
    const slice1_start = self.mask(start_unmasked);
    const slice1_end = @min(self.data.len, slice1_start + length);
    const slice1 = self.data[slice1_start..slice1_end];
    const slice2 = self.data[0 .. length - slice1.len];
    return Slice{
        .first = slice1,
        .second = slice2,
    };
}

/// Returns a `Slice` for the last `length` bytes written to the ring buffer.
/// Does not check that any bytes have been written into the region.
pub fn sliceLast(self: RingBuffer, length: usize) Slice {
    return self.sliceAt(self.write_index + self.data.len - length, length);
}

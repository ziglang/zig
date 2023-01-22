//! This ring buffer stores read and write indices while being able to utilise the full
//! backing slice by incrementing the indices modulo twice the slice's length and reducing
//! indices modulo the slice's length on slice access. This means that the bit of information
//! distinguishing whether the buffer is full or empty in an implementation utilising
//! and extra flag is stored in difference of the indices.

const assert = @import("std").debug.assert;

const RingBuffer = @This();

data: []u8,
read_index: usize,
write_index: usize,

pub fn mask(self: RingBuffer, index: usize) usize {
    return index % self.data.len;
}

pub fn mask2(self: RingBuffer, index: usize) usize {
    return index % (2 * self.data.len);
}

pub fn write(self: *RingBuffer, byte: u8) !void {
    if (self.isFull()) return error.Full;
    self.writeAssumeCapacity(byte);
}

pub fn writeAssumeCapacity(self: *RingBuffer, byte: u8) void {
    self.data[self.mask(self.write_index)] = byte;
    self.write_index = self.mask2(self.write_index + 1);
}

pub fn writeSlice(self: *RingBuffer, bytes: []const u8) !void {
    if (self.len() + bytes.len > self.data.len) return error.Full;
    self.writeSliceAssumeCapacity(bytes);
}

pub fn writeSliceAssumeCapacity(self: *RingBuffer, bytes: []const u8) void {
    for (bytes) |b| self.writeAssumeCapacity(b);
}

pub fn read(self: *RingBuffer) ?u8 {
    if (self.isEmpty()) return null;
    const byte = self.data[self.mask(self.read_index)];
    self.read_index = self.mask2(self.read_index + 1);
    return byte;
}

pub fn isEmpty(self: RingBuffer) bool {
    return self.write_index == self.read_index;
}

pub fn isFull(self: RingBuffer) bool {
    return self.mask2(self.write_index + self.data.len) == self.read_index;
}

pub fn len(self: RingBuffer) usize {
    const adjusted_write_index = self.write_index + @boolToInt(self.write_index < self.read_index) * 2 * self.data.len;
    return adjusted_write_index - self.read_index;
}

const Slice = struct {
    first: []u8,
    second: []u8,
};

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

pub fn sliceLast(self: RingBuffer, length: usize) Slice {
    return self.sliceAt(self.write_index + self.data.len - length, length);
}

//! An set of array and slice types that bit-pack elements. A normal [12]u3 takes up
//! 12 bytes of memory since u3's alignment is 1. PackedArray(u3, 12) only takes up
//! 4 bytes of memory. Packed structs can also save space using PackedArray, but 
//! unpacked structs will recieve no benefit.

const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;
const testing = std.testing;
const native_endian = builtin.target.cpu.arch.endian();
const Endian = std.builtin.Endian;

/// Provides a set of functions for reading and writing to packed data from a given
/// slice of bytes.
pub fn PackedIo(comptime T: type, comptime endian: Endian) type {
    //The general technique employed here is to cast bytes in the array to a container
    // integer (having bits % 8 == 0) large enough to contain the number of bits we want,
    // then we can retrieve or store the new value with a relative minimum of masking
    // and shifting. In this worst case, this means that we'll need an integer that's
    // actually 1 byte larger than the minimum required to store the bits, because it
    // is possible that the bits start at the end of the first byte, continue through
    // zero or more, then end in the beginning of the last. But, if we try to access
    // a value in the very last byte of memory with that integer size, that extra byte
    // will be out of bounds. Depending on the circumstances of the memory, that might
    // mean the OS fatally kills the program. Thus, we use a larger container (MaxIo)
    // most of the time, but a smaller container (MinIo) when touching the last byte
    // of the memory.
    const int_bits = @bitSizeOf(T);

    //create a backing int type of the packed data
    const Int = std.meta.Int(.unsigned, int_bits);

    //in the best case, this is the number of bytes we need to touch
    // to read or write a value, as bits
    const min_io_bits = ((int_bits + 7) / 8) * 8;

    //in the worst case, this is the number of bytes we need to touch
    // to read or write a value, as bits. To calculate for int_bits > 1,
    // set aside 2 bits to touch the first and last bytes, then divide
    // by 8 to see how many bytes can be filled up inbetween.
    const max_io_bits = switch (int_bits) {
        0 => 0,
        1 => 8,
        else => ((int_bits - 2) / 8 + 2) * 8,
    };

    //we bitcast the desired Int type to an unsigned version of itself
    // to avoid issues with shifting signed ints.
    const UnInt = std.meta.Int(.unsigned, int_bits);

    //The maximum container int type
    const MinIo = std.meta.Int(.unsigned, min_io_bits);

    //The minimum container int type
    const MaxIo = std.meta.Int(.unsigned, max_io_bits);

    return struct {
        /// Retrieves the element at `index` from the packed data beginning at `bit_offset`
        /// within `bytes`.
        pub fn get(bytes: []const u8, index: usize, bit_offset: u7) T {
            if (int_bits == 0) return 0;

            const bit_index = (index * int_bits) + bit_offset;
            const max_end_byte = (bit_index + max_io_bits) / 8;

            //Using the larger container size will potentially read out of bounds
            if (max_end_byte > bytes.len) {
                const bits = getBits(bytes, MinIo, bit_index);
                return @bitCast(T, bits);
            }
            const bits = getBits(bytes, MaxIo, bit_index);
            return @bitCast(T, bits);
        }

        fn getBits(bytes: []const u8, comptime Container: type, bit_index: usize) Int {
            const container_bits = comptime std.meta.bitCount(Container);
            const Shift = std.math.Log2Int(Container);

            const start_byte = bit_index / 8;
            const head_keep_bits = bit_index - (start_byte * 8);
            const tail_keep_bits = container_bits - (int_bits + head_keep_bits);

            //read bytes as container
            const value_ptr = @ptrCast(*align(1) const Container, &bytes[start_byte]);
            var value = value_ptr.*;

            if (endian != native_endian) value = @byteSwap(Container, value);

            switch (endian) {
                .Big => {
                    value <<= @intCast(Shift, head_keep_bits);
                    value >>= @intCast(Shift, head_keep_bits);
                    value >>= @intCast(Shift, tail_keep_bits);
                },
                .Little => {
                    value <<= @intCast(Shift, tail_keep_bits);
                    value >>= @intCast(Shift, tail_keep_bits);
                    value >>= @intCast(Shift, head_keep_bits);
                },
            }

            return @bitCast(Int, @truncate(UnInt, value));
        }

        /// Sets the element at `index` to `val` within the packed data beginning
        /// at `bit_offset` into `bytes`.
        pub fn set(bytes: []u8, index: usize, bit_offset: u3, val: T) void {
            if (int_bits == 0) return;

            const int = @bitCast(Int, val);

            const bit_index = (index * int_bits) + bit_offset;
            const max_end_byte = (bit_index + max_io_bits) / 8;

            //Using the larger container size will potentially write out of bounds
            if (max_end_byte > bytes.len) return setBits(bytes, MinIo, bit_index, int);
            setBits(bytes, MaxIo, bit_index, int);
        }

        fn setBits(bytes: []u8, comptime Container: type, bit_index: usize, int: Int) void {
            const container_bits = comptime std.meta.bitCount(Container);
            const Shift = std.math.Log2Int(Container);

            const start_byte = bit_index / 8;
            const head_keep_bits = bit_index - (start_byte * 8);
            const tail_keep_bits = container_bits - (int_bits + head_keep_bits);
            const keep_shift = switch (endian) {
                .Big => @intCast(Shift, tail_keep_bits),
                .Little => @intCast(Shift, head_keep_bits),
            };

            //position the bits where they need to be in the container
            const value = @intCast(Container, @bitCast(UnInt, int)) << keep_shift;

            //read existing bytes
            const target_ptr = @ptrCast(*align(1) Container, &bytes[start_byte]);
            var target = target_ptr.*;

            if (endian != native_endian) target = @byteSwap(Container, target);

            //zero the bits we want to replace in the existing bytes
            const inv_mask = @intCast(Container, std.math.maxInt(UnInt)) << keep_shift;
            const mask = ~inv_mask;
            target &= mask;

            //merge the new value
            target |= value;

            if (endian != native_endian) target = @byteSwap(Container, target);

            //save it back
            target_ptr.* = target;
        }

        /// Provides a PackedSlice of the packed data in `bytes` (which begins at `bit_offset`)
        /// from the element specified by `start` to the element specified by `end`.
        pub fn slice(bytes: []u8, bit_offset: u3, start: usize, end: usize) PackedSliceEndian(T, endian) {
            debug.assert(end >= start);

            const length = end - start;
            const bit_index = (start * int_bits) + bit_offset;
            const start_byte = bit_index / 8;
            const end_byte = (bit_index + (length * int_bits) + 7) / 8;
            const new_bytes = bytes[start_byte..end_byte];

            if (length == 0) return PackedSliceEndian(T, endian).init(new_bytes[0..0], 0);

            var new_slice = PackedSliceEndian(T, endian).init(new_bytes, length);
            new_slice.bit_offset = @intCast(u3, (bit_index - (start_byte * 8)));
            return new_slice;
        }

        /// Recasts a packed slice to a version with elements of type `NewT` and endianness `new_endian`.
        /// Slice will begin at `bit_offset` within `bytes` and the new length will be automatically
        /// calculated from `old_len` using the sizes of `T` and `NewT`.
        pub fn sliceCast(bytes: []u8, comptime NewT: type, comptime new_endian: Endian, bit_offset: u3, old_len: usize) PackedSliceEndian(NewT, new_endian) {
            const new_int_bits = comptime @bitSizeOf(NewT);
            const New = PackedSliceEndian(NewT, new_endian);

            const total_bits = (old_len * int_bits);
            const new_int_count = total_bits / new_int_bits;

            debug.assert(total_bits == new_int_count * new_int_bits);

            var new = New.init(bytes, new_int_count);
            new.bit_offset = bit_offset;

            return new;
        }
    };
}

/// Creates a bit-packed array of `T`. Non-byte-multiple integers and
/// packed structs will take up less memory in PackedArray than in a
/// normal array. Elements are packed using native endianess and without
/// storing any meta data. PackedArray(i3, 8) will occupy exactly 3 bytes 
/// of memory.
pub fn PackedArray(comptime T: type, comptime count: usize) type {
    return PackedArrayEndian(T, native_endian, count);
}

/// Creates a bit-packed array of `T` with bit order specified by `endian`.
/// Non-byte-multiple integers and packed structs will take up less memory in
/// PackedArrayEndian than in a normal array. Elements are packed without
/// storing any meta data. PackedArrayEndian(i3, 8) will occupy exactly 3 bytes 
/// of memory.
pub fn PackedArrayEndian(comptime T: type, comptime endian: Endian, comptime count: usize) type {
    const int_bits = @bitSizeOf(T);
    const total_bits = int_bits * count;
    const total_bytes = (total_bits + 7) / 8;

    const Io = PackedIo(T, endian);

    return struct {
        const Self = @This();

        /// The byte buffer containing the packed data.
        bytes: [total_bytes]u8,
        /// The number of elements in the packed array.
        comptime len: usize = count,

        /// Initialize a packed array using the unpacked array
        /// `array` or, more likely, an array literal.
        pub fn init(array: [count]T) Self {
            var self = @as(Self, undefined);
            for (array) |item, i| self.set(i, item);
            return self;
        }

        /// Initialize all entries of a packed array to `val`.
        pub fn initAllTo(val: T) Self {
            // TODO: use `var self = @as(Self, undefined);` https://github.com/ziglang/zig/issues/7635
            var self = Self{ .bytes = [_]u8{0} ** total_bytes, .len = count };
            self.setAll(val);
            return self;
        }

        /// Return the element stored at `index`.
        pub fn get(self: Self, index: usize) T {
            debug.assert(index < count);
            return Io.get(&self.bytes, index, 0);
        }

        /// Copy `val` into the array at element `index`.
        pub fn set(self: *Self, index: usize, val: T) void {
            debug.assert(index < count);
            return Io.set(&self.bytes, index, 0, val);
        }

        /// Set all entries of a packed array to `val`.
        pub fn setAll(self: *Self, val: T) void {
            var i: usize = 0;
            while (i < count) : (i += 1) {
                self.set(i, val);
            }
        }

        /// Create a PackedSlice of the array from given `start` to given `end`
        pub fn slice(self: *Self, start: usize, end: usize) PackedSliceEndian(T, endian) {
            debug.assert(start < count);
            debug.assert(end <= count);
            return Io.slice(&self.bytes, 0, start, end);
        }

        /// Create a PackedSlice of the array using `NewT` as the element type.
        /// NewT's bit width must fit evenly within the array's total bits.
        pub fn sliceCast(self: *Self, comptime NewT: type) PackedSlice(NewT) {
            return self.sliceCastEndian(NewT, endian);
        }

        /// Create a PackedSlice of the array using `NewT` as the element type
        /// with the endianess specified by `new_endian`. `NewT`'s bit width
        /// must fit evenly within the array's total bits.
        pub fn sliceCastEndian(self: *Self, comptime NewT: type, comptime new_endian: Endian) PackedSliceEndian(NewT, new_endian) {
            return Io.sliceCast(&self.bytes, NewT, new_endian, 0, count);
        }
    };
}

/// A bit-packed slice.
pub fn PackedSlice(comptime T: type) type {
    return PackedSliceEndian(T, native_endian);
}

///Uses a slice as a bit-packed block of int_count integers of type Int.
/// Bits are packed using specified endianess and without storing any meta
/// data.
pub fn PackedSliceEndian(comptime T: type, comptime endian: Endian) type {
    const bits = @bitSizeOf(T);
    const Io = PackedIo(T, endian);

    return struct {
        const Self = @This();

        /// A slice of the buffer containing the packed data.
        bytes: []u8,

        /// The number of elements in the packed data.
        len: usize,

        /// The offset of the bit within `bytes` where the first
        /// element of packed data begins.
        bit_offset: u3,

        /// Calculates the number of bytes required to store a desired count
        /// of elements.
        pub fn bytesRequired(count: usize) usize {
            const total_bits = bits * count;
            const total_bytes = (total_bits + 7) / 8;
            return total_bytes;
        }

        /// Initialize a packed slice using the memory at `bytes`, with `count`
        /// elements. `bytes` must be large enough to accomodate the requested
        /// count.
        pub fn init(bytes: []u8, count: usize) Self {
            debug.assert(bytes.len >= bytesRequired(count));

            return Self{
                .bytes = bytes,
                .len = count,
                .bit_offset = 0,
            };
        }

        /// Return the element stored at `index`.
        pub fn get(self: Self, index: usize) T {
            debug.assert(index < self.len);
            return Io.get(self.bytes, index, self.bit_offset);
        }

        /// Copy `val` into the array at `index`.
        pub fn set(self: *Self, index: usize, val: T) void {
            debug.assert(index < self.len);
            return Io.set(self.bytes, index, self.bit_offset, val);
        }

        /// Create a PackedSlice of this slice from given `start` to given `end`.
        pub fn slice(self: Self, start: usize, end: usize) PackedSliceEndian(T, endian) {
            debug.assert(start < self.len);
            debug.assert(end <= self.len);
            return Io.slice(self.bytes, self.bit_offset, start, end);
        }

        /// Create a PackedSlice of this slice using `NewT` as the element type.
        /// `NewT`'s bit width must fit evenly within this slice's total bits.
        pub fn sliceCast(self: Self, comptime NewT: type) PackedSliceEndian(NewT, endian) {
            return self.sliceCastEndian(NewT, endian);
        }

        /// Create a PackedSlice of this slice using `NewT` as the element type and
        /// `new_endian` as the new endianess. `NewT`'s bit width must fit evenly within
        /// this slice's total bits.
        pub fn sliceCastEndian(self: Self, comptime NewT: type, comptime new_endian: Endian) PackedSliceEndian(NewT, new_endian) {
            return Io.sliceCast(self.bytes, NewT, new_endian, self.bit_offset, self.len);
        }
    };
}

const we_are_testing_this_with_stage1_which_leaks_comptime_memory = true;

test "PackedArray with ints" {
    // TODO @setEvalBranchQuota generates panics in wasm32. Investigate.
    if (builtin.target.cpu.arch == .wasm32) return error.SkipZigTest;
    if (we_are_testing_this_with_stage1_which_leaks_comptime_memory) return error.SkipZigTest;

    @setEvalBranchQuota(10000);
    const max_bits = 256;
    const int_count = 19;

    comptime var bits = 0;
    inline while (bits <= max_bits) : (bits += 1) {
        //alternate unsigned and signed
        const sign: std.builtin.Signedness = if (bits % 2 == 0) .signed else .unsigned;
        const I = std.meta.Int(sign, bits);

        const Array = PackedArray(I, int_count);
        const expected_bytes = ((bits * int_count) + 7) / 8;
        try testing.expect(@sizeOf(Array) == expected_bytes);

        var data = @as(Array, undefined);

        //write values, counting up
        var i = @as(usize, 0);
        var count = @as(I, 0);
        while (i < data.len) : (i += 1) {
            data.set(i, count);
            if (bits > 0) count +%= 1;
        }

        //read and verify values
        i = 0;
        count = 0;
        while (i < data.len) : (i += 1) {
            const val = data.get(i);
            try testing.expect(val == count);
            if (bits > 0) count +%= 1;
        }
    }
}

test "PackedIo with ints" {
    const bytes = [_]u8{ 0b01101_000, 0b01011_110, 0b00011_101 };
    try testing.expectEqual(@as(u15, 0x2bcd), PackedIo(u15, .Little).get(&bytes, 0, 3));
    try testing.expectEqual(@as(u16, 0xabcd), PackedIo(u16, .Little).get(&bytes, 0, 3));
    try testing.expectEqual(@as(u17, 0x1abcd), PackedIo(u17, .Little).get(&bytes, 0, 3));
    try testing.expectEqual(@as(u18, 0x3abcd), PackedIo(u18, .Little).get(&bytes, 0, 3));
}

test "PackedArray init" {
    if (we_are_testing_this_with_stage1_which_leaks_comptime_memory) return error.SkipZigTest;
    const Array = PackedArray(u3, 8);
    var packed_array = Array.init([_]u3{ 0, 1, 2, 3, 4, 5, 6, 7 });
    var i = @as(usize, 0);
    while (i < packed_array.len) : (i += 1) try testing.expectEqual(@intCast(u3, i), packed_array.get(i));
}

test "PackedArray initAllTo" {
    if (we_are_testing_this_with_stage1_which_leaks_comptime_memory) return error.SkipZigTest;
    const Array = PackedArray(u3, 8);
    var packed_array = Array.initAllTo(5);
    var i = @as(usize, 0);
    while (i < packed_array.len) : (i += 1) try testing.expectEqual(@as(u3, 5), packed_array.get(i));
}

test "PackedSlice with ints" {
    // TODO @setEvalBranchQuota generates panics in wasm32. Investigate.
    if (builtin.target.cpu.arch == .wasm32) return error.SkipZigTest;
    if (we_are_testing_this_with_stage1_which_leaks_comptime_memory) return error.SkipZigTest;

    @setEvalBranchQuota(10000);
    const max_bits = 256;
    const int_count = 19;
    const total_bits = max_bits * int_count;
    const total_bytes = (total_bits + 7) / 8;

    var buffer: [total_bytes]u8 = undefined;

    comptime var bits = 0;
    inline while (bits <= max_bits) : (bits += 1) {
        //alternate unsigned and signed
        const sign: std.builtin.Signedness = if (bits % 2 == 0) .signed else .unsigned;
        const I = std.meta.Int(sign, bits);
        const P = PackedSlice(I);

        var data = P.init(&buffer, int_count);

        //write values, counting up
        var i = @as(usize, 0);
        var count = @as(I, 0);
        while (i < data.len) : (i += 1) {
            data.set(i, count);
            if (bits > 0) count +%= 1;
        }

        //read and verify values
        i = 0;
        count = 0;
        while (i < data.len) : (i += 1) {
            const val = data.get(i);
            try testing.expect(val == count);
            if (bits > 0) count +%= 1;
        }
    }
}

test "PackedSlice of Packed(Array/Slice)" {
    if (we_are_testing_this_with_stage1_which_leaks_comptime_memory) return error.SkipZigTest;
    const max_bits = 16;
    const int_count = 19;

    comptime var bits = 0;
    inline while (bits <= max_bits) : (bits += 1) {
        const Int = std.meta.Int(.unsigned, bits);

        const Array = PackedArray(Int, int_count);
        var packed_array = @as(Array, undefined);

        const limit = (1 << bits);

        var i = @as(usize, 0);
        while (i < packed_array.len) : (i += 1) {
            packed_array.set(i, @intCast(Int, i % limit));
        }

        //slice of array
        var packed_slice = packed_array.slice(2, 5);
        try testing.expect(packed_slice.len == 3);
        const ps_bit_count = (bits * packed_slice.len) + packed_slice.bit_offset;
        const ps_expected_bytes = (ps_bit_count + 7) / 8;
        try testing.expect(packed_slice.bytes.len == ps_expected_bytes);
        try testing.expect(packed_slice.get(0) == 2 % limit);
        try testing.expect(packed_slice.get(1) == 3 % limit);
        try testing.expect(packed_slice.get(2) == 4 % limit);
        packed_slice.set(1, 7 % limit);
        try testing.expect(packed_slice.get(1) == 7 % limit);

        //write through slice
        try testing.expect(packed_array.get(3) == 7 % limit);

        //slice of a slice
        const packed_slice_two = packed_slice.slice(0, 3);
        try testing.expect(packed_slice_two.len == 3);
        const ps2_bit_count = (bits * packed_slice_two.len) + packed_slice_two.bit_offset;
        const ps2_expected_bytes = (ps2_bit_count + 7) / 8;
        try testing.expect(packed_slice_two.bytes.len == ps2_expected_bytes);
        try testing.expect(packed_slice_two.get(1) == 7 % limit);
        try testing.expect(packed_slice_two.get(2) == 4 % limit);

        //size one case
        const packed_slice_three = packed_slice_two.slice(1, 2);
        try testing.expect(packed_slice_three.len == 1);
        const ps3_bit_count = (bits * packed_slice_three.len) + packed_slice_three.bit_offset;
        const ps3_expected_bytes = (ps3_bit_count + 7) / 8;
        try testing.expect(packed_slice_three.bytes.len == ps3_expected_bytes);
        try testing.expect(packed_slice_three.get(0) == 7 % limit);

        //empty slice case
        const packed_slice_empty = packed_slice.slice(0, 0);
        try testing.expect(packed_slice_empty.len == 0);
        try testing.expect(packed_slice_empty.bytes.len == 0);

        //slicing at byte boundaries
        const packed_slice_edge = packed_array.slice(8, 16);
        try testing.expect(packed_slice_edge.len == 8);
        const pse_bit_count = (bits * packed_slice_edge.len) + packed_slice_edge.bit_offset;
        const pse_expected_bytes = (pse_bit_count + 7) / 8;
        try testing.expect(packed_slice_edge.bytes.len == pse_expected_bytes);
        try testing.expect(packed_slice_edge.bit_offset == 0);
    }
}

test "PackedIntSlice accumulating bit offsets" {
    if (we_are_testing_this_with_stage1_which_leaks_comptime_memory) return error.SkipZigTest;
    //bit_offset is u3, so standard debugging asserts should catch
    // anything
    {
        const Array = PackedArray(u3, 16);
        var packed_array = @as(Array, undefined);

        var packed_slice = packed_array.slice(0, packed_array.len);
        var i = @as(usize, 0);
        while (i < packed_array.len - 1) : (i += 1) {
            packed_slice = packed_slice.slice(1, packed_slice.len);
        }
    }
    {
        const Array = PackedArray(u11, 88);
        var packed_array = @as(Array, undefined);

        var packed_slice = packed_array.slice(0, packed_array.len);
        var i = @as(usize, 0);
        while (i < packed_array.len - 1) : (i += 1) {
            packed_slice = packed_slice.slice(1, packed_slice.len);
        }
    }
}

//@NOTE: As I do not have a big endian system to test this on,
// big endian values were not tested
test "Packed(Array/Slice) sliceCast" {
    if (we_are_testing_this_with_stage1_which_leaks_comptime_memory) return error.SkipZigTest;

    const Array = PackedArray(u1, 16);
    var packed_array = Array.init([_]u1{ 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1 });
    const packed_slice_cast_2 = packed_array.sliceCast(u2);
    const packed_slice_cast_4 = packed_slice_cast_2.sliceCast(u4);
    var packed_slice_cast_9 = packed_array.slice(0, (packed_array.len / 9) * 9).sliceCast(u9);
    const packed_slice_cast_3 = packed_slice_cast_9.sliceCast(u3);

    var i = @as(usize, 0);
    while (i < packed_slice_cast_2.len) : (i += 1) {
        const val = switch (native_endian) {
            .Big => 0b01,
            .Little => 0b10,
        };
        try testing.expect(packed_slice_cast_2.get(i) == val);
    }
    i = 0;
    while (i < packed_slice_cast_4.len) : (i += 1) {
        const val = switch (native_endian) {
            .Big => 0b0101,
            .Little => 0b1010,
        };
        try testing.expect(packed_slice_cast_4.get(i) == val);
    }
    i = 0;
    while (i < packed_slice_cast_9.len) : (i += 1) {
        const val = 0b010101010;
        try testing.expect(packed_slice_cast_9.get(i) == val);
        packed_slice_cast_9.set(i, 0b111000111);
    }
    i = 0;
    while (i < packed_slice_cast_3.len) : (i += 1) {
        const val = switch (native_endian) {
            .Big => if (i % 2 == 0) @as(u3, 0b111) else @as(u3, 0b000),
            .Little => if (i % 2 == 0) @as(u3, 0b111) else @as(u3, 0b000),
        };
        try testing.expect(packed_slice_cast_3.get(i) == val);
    }
}

test "Packed(Array/Slice)Endian" {
    if (we_are_testing_this_with_stage1_which_leaks_comptime_memory) return error.SkipZigTest;

    {
        const PackedArrayBe = PackedArrayEndian(u4, .Big, 8);
        var packed_array_be = PackedArrayBe.init([_]u4{ 0, 1, 2, 3, 4, 5, 6, 7 });
        try testing.expect(packed_array_be.bytes[0] == 0b00000001);
        try testing.expect(packed_array_be.bytes[1] == 0b00100011);

        var i = @as(usize, 0);
        while (i < packed_array_be.len) : (i += 1) {
            try testing.expect(packed_array_be.get(i) == i);
        }

        var packed_slice_le = packed_array_be.sliceCastEndian(u4, .Little);
        i = 0;
        while (i < packed_slice_le.len) : (i += 1) {
            const val = if (i % 2 == 0) i + 1 else i - 1;
            try testing.expect(packed_slice_le.get(i) == val);
        }

        var packed_slice_le_shift = packed_array_be.slice(1, 5).sliceCastEndian(u4, .Little);
        i = 0;
        while (i < packed_slice_le_shift.len) : (i += 1) {
            const val = if (i % 2 == 0) i else i + 2;
            try testing.expect(packed_slice_le_shift.get(i) == val);
        }
    }

    {
        const PackedArrayBe = PackedArrayEndian(u11, .Big, 8);
        var packed_array_be = PackedArrayBe.init([_]u11{ 0, 1, 2, 3, 4, 5, 6, 7 });
        try testing.expect(packed_array_be.bytes[0] == 0b00000000);
        try testing.expect(packed_array_be.bytes[1] == 0b00000000);
        try testing.expect(packed_array_be.bytes[2] == 0b00000100);
        try testing.expect(packed_array_be.bytes[3] == 0b00000001);
        try testing.expect(packed_array_be.bytes[4] == 0b00000000);

        var i = @as(usize, 0);
        while (i < packed_array_be.len) : (i += 1) {
            try testing.expect(packed_array_be.get(i) == i);
        }

        var packed_slice_le = packed_array_be.sliceCastEndian(u11, .Little);
        try testing.expect(packed_slice_le.get(0) == 0b00000000000);
        try testing.expect(packed_slice_le.get(1) == 0b00010000000);
        try testing.expect(packed_slice_le.get(2) == 0b00000000100);
        try testing.expect(packed_slice_le.get(3) == 0b00000000000);
        try testing.expect(packed_slice_le.get(4) == 0b00010000011);
        try testing.expect(packed_slice_le.get(5) == 0b00000000010);
        try testing.expect(packed_slice_le.get(6) == 0b10000010000);
        try testing.expect(packed_slice_le.get(7) == 0b00000111001);

        var packed_slice_le_shift = packed_array_be.slice(1, 5).sliceCastEndian(u11, .Little);
        try testing.expect(packed_slice_le_shift.get(0) == 0b00010000000);
        try testing.expect(packed_slice_le_shift.get(1) == 0b00000000100);
        try testing.expect(packed_slice_le_shift.get(2) == 0b00000000000);
        try testing.expect(packed_slice_le_shift.get(3) == 0b00010000011);
    }
}

//@NOTE: Need to manually update this list as more posix os's get
// added to DirectAllocator.

//These tests prove we aren't accidentally accessing memory past
// the end of the array/slice by placing it at the end of a page
// and reading the last element. The assumption is that the page
// after this one is not mapped and will cause a segfault if we
// don't account for the bounds.
test "PackedArray at end of available memory" {
    if (we_are_testing_this_with_stage1_which_leaks_comptime_memory) return error.SkipZigTest;

    switch (builtin.target.os.tag) {
        .linux, .macos, .ios, .freebsd, .netbsd, .openbsd, .windows => {},
        else => return,
    }
    const Array = PackedArray(u3, 8);

    const Padded = struct {
        _: [std.mem.page_size - @sizeOf(Array)]u8,
        p: Array,
    };

    const allocator = std.testing.allocator;

    var pad = try allocator.create(Padded);
    defer allocator.destroy(pad);
    pad.p.set(7, std.math.maxInt(u3));
}

test "PackedSlice at end of available memory" {
    if (we_are_testing_this_with_stage1_which_leaks_comptime_memory) return error.SkipZigTest;

    switch (builtin.target.os.tag) {
        .linux, .macos, .ios, .freebsd, .netbsd, .openbsd, .windows => {},
        else => return,
    }
    const Slice = PackedSlice(u11);

    const allocator = std.testing.allocator;

    var page = try allocator.alloc(u8, std.mem.page_size);
    defer allocator.free(page);

    var p = Slice.init(page[std.mem.page_size - 2 ..], 1);
    p.set(0, std.math.maxInt(u11));
}

test "PackedArray of packed struct" {
    if (we_are_testing_this_with_stage1_which_leaks_comptime_memory) return error.SkipZigTest;

    const S = packed struct {
        three: u3,
        two: u2,
    };

    const Array = PackedArray(S, 3);
    try testing.expectEqual(@sizeOf(Array), 2); //array only requires 15 bits

    var array = Array.init(.{ .{ .three = 6, .two = 1 }, .{ .three = 1, .two = 3 }, .{ .three = 2, .two = 2 } });

    {
        const s0 = array.get(0);
        try testing.expectEqual(s0.three, 6);
        try testing.expectEqual(s0.two, 1);

        const s1 = array.get(1);
        try testing.expectEqual(s1.three, 1);
        try testing.expectEqual(s1.two, 3);

        const s2 = array.get(2);
        try testing.expectEqual(s2.three, 2);
        try testing.expectEqual(s2.two, 2);
    }

    array.set(0, .{ .three = 7, .two = 0 });
    array.set(1, .{ .three = 0, .two = 3 });
    array.set(2, .{ .three = 5, .two = 1 });

    {
        const s0 = array.get(0);
        try testing.expectEqual(s0.three, 7);
        try testing.expectEqual(s0.two, 0);

        const s1 = array.get(1);
        try testing.expectEqual(s1.three, 0);
        try testing.expectEqual(s1.two, 3);

        const s2 = array.get(2);
        try testing.expectEqual(s2.three, 5);
        try testing.expectEqual(s2.two, 1);
    }
}
const assert = @import("debug.zig").assert;
const rand_test = @import("rand_test.zig");
const mem = @import("mem.zig");

pub const MT19937_32 = MersenneTwister(
    u32, 624, 397, 31,
    0x9908B0DF,
    11, 0xFFFFFFFF,
    7, 0x9D2C5680,
    15, 0xEFC60000,
    18, 1812433253);

pub const MT19937_64 = MersenneTwister(
    u64, 312, 156, 31,
    0xB5026F5AA96619E9,
    29, 0x5555555555555555,
    17, 0x71D67FFFEDA60000,
    37, 0xFFF7EEE000000000,
    43, 6364136223846793005);

/// Use `init` to initialize this state.
pub const Rand = struct {
    const Rng = if (@sizeOf(usize) >= 8) MT19937_64 else MT19937_32;

    rng: Rng,

    /// Initialize random state with the given seed.
    pub fn init(r: &Rand, seed: usize) {
        r.rng.init(seed);
    }

    /// Get an integer or boolean with random bits.
    pub fn scalar(r: &Rand, comptime T: type) -> T {
        if (T == usize) {
            return r.rng.get();
        } else if (T == bool) {
            return (r.rng.get() & 0b1) == 0;
        } else {
            var result: [@sizeOf(T)]u8 = undefined;
            r.fillBytes(result[0...]);
            return mem.readInt(result, T, false);
        }
    }

    /// Fill `buf` with randomness.
    pub fn fillBytes(r: &Rand, buf: []u8) {
        var bytes_left = buf.len;
        while (bytes_left >= @sizeOf(usize)) {
            mem.writeInt(buf[buf.len - bytes_left...], r.rng.get(), false);
            bytes_left -= @sizeOf(usize);
        }
        if (bytes_left > 0) {
            var rand_val_array: [@sizeOf(usize)]u8 = undefined;
            mem.writeInt(rand_val_array[0...], r.rng.get(), false);
            while (bytes_left > 0) {
                buf[buf.len - bytes_left] = rand_val_array[@sizeOf(usize) - bytes_left];
                bytes_left -= 1;
            }
        }
    }

    /// Get a random unsigned integer with even distribution between `start`
    /// inclusive and `end` exclusive.
    // TODO support signed integers and then rename to "range"
    pub fn rangeUnsigned(r: &Rand, comptime T: type, start: T, end: T) -> T {
        const range = end - start;
        const leftover = @maxValue(T) % range;
        const upper_bound = @maxValue(T) - leftover;
        var rand_val_array: [@sizeOf(T)]u8 = undefined;

        while (true) {
            r.fillBytes(rand_val_array[0...]);
            const rand_val = mem.readInt(rand_val_array, T, false);
            if (rand_val < upper_bound) {
                return start + (rand_val % range);
            }
        }
    }

    /// Get a floating point value in the range 0.0..1.0.
    pub fn float(r: &Rand, comptime T: type) -> T {
        // TODO Implement this way instead:
        // const int = @int_type(false, @sizeOf(T) * 8);
        // const mask = ((1 << @float_mantissa_bit_count(T)) - 1);
        // const rand_bits = r.rng.scalar(int) & mask;
        // return @float_compose(T, false, 0, rand_bits) - 1.0
        const int_type = @IntType(false, @sizeOf(T) * 8);
        const precision = if (T == f32) {
            16777216
        } else if (T == f64) {
            9007199254740992
        } else {
            @compileError("unknown floating point type")
        };
        return T(r.rangeUnsigned(int_type, 0, precision)) / T(precision);
    }
};

fn MersenneTwister(
    comptime int: type, comptime n: usize, comptime m: usize, comptime r: int,
    comptime a: int,
    comptime u: int, comptime d: int,
    comptime s: int, comptime b: int,
    comptime t: int, comptime c: int,
    comptime l: int, comptime f: int) -> type
{
    struct {
        const Self = this;

        array: [n]int,
        index: usize,

        pub fn init(mt: &Self, seed: int) {
            mt.index = n;

            var prev_value = seed;
            mt.array[0] = prev_value;
            {var i: usize = 1; while (i < n; i += 1) {
                prev_value = int(i) +% f *% (prev_value ^ (prev_value >> (int.bit_count - 2)));
                mt.array[i] = prev_value;
            }};
        }

        pub fn get(mt: &Self) -> int {
            const mag01 = []int{0, a};
            const LM: int = (1 << r) - 1;
            const UM = ~LM;

            if (mt.index >= n) {
                var i: usize = 0;

                while (i < n - m; i += 1) {
                    const x = (mt.array[i] & UM) | (mt.array[i + 1] & LM);
                    mt.array[i] = mt.array[i + m] ^ (x >> 1) ^ mag01[x & 0x1];
                }

                while (i < n - 1; i += 1) {
                    const x = (mt.array[i] & UM) | (mt.array[i + 1] & LM);
                    mt.array[i] = mt.array[i + m - n] ^ (x >> 1) ^ mag01[x & 0x1];

                }
                const x = (mt.array[i] & UM) | (mt.array[0] & LM);
                mt.array[i] = mt.array[m - 1] ^ (x >> 1) ^ mag01[x & 0x1];

                mt.index = 0;
            }

            var x = mt.array[mt.index];
            mt.index += 1;

            x ^= ((x >> u) & d);
            x ^= ((x <<% s) & b);
            x ^= ((x <<% t) & c);
            x ^= (x >> l);

            return x;
        }
    }
}

test "testFloat32" {
    var r: Rand = undefined;
    r.init(42);

    {var i: usize = 0; while (i < 1000; i += 1) {
        const val = r.float(f32);
        assert(val >= 0.0);
        assert(val < 1.0);
    }}
}

test "testMT19937_64" {
    var rng: MT19937_64 = undefined;
    rng.init(rand_test.mt64_seed);
    for (rand_test.mt64_data) |value| {
        assert(value == rng.get());
    }
}

test "testMT19937_32" {
    var rng: MT19937_32 = undefined;
    rng.init(rand_test.mt32_seed);
    for (rand_test.mt32_data) |value| {
        assert(value == rng.get());
    }
}

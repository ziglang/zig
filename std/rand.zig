// Mersenne Twister
const ARRAY_SIZE = 624;

/// Use `rand_init` to initialize this state.
pub struct Rand {
    array: [ARRAY_SIZE]u32,
    index: isize,

    /// Get 32 bits of randomness.
    pub fn get_u32(r: &Rand) -> u32 {
        if (r.index == 0) {
            r.generate_numbers();
        }

        // temper the number
        var y : u32 = r.array[r.index];
        y ^= y >> 11;
        y ^= (y >> 7) & 0x9d2c5680;
        y ^= (y >> 15) & 0xefc60000;
        y ^= y >> 18;

        r.index = (r.index + 1) % ARRAY_SIZE;
        return y;
    }

    /// Fill `buf` with randomness.
    pub fn get_bytes(r: &Rand, buf: []u8) {
        var bytes_left = r.get_bytes_aligned(buf);
        if (bytes_left > 0) {
            var rand_val_array : [@sizeof(u32)]u8 = undefined;
            *((&u32)(&rand_val_array[0])) = r.get_u32();
            while (bytes_left > 0) {
                buf[buf.len - bytes_left] = rand_val_array[@sizeof(u32) - bytes_left];
                bytes_left -= 1;
            }
        }
    }

    /// Get a random unsigned integer with even distribution between `start`
    /// inclusive and `end` exclusive.
    pub fn range_u64(r: &Rand, start: u64, end: u64) -> u64 {
        const range = end - start;
        const leftover = @max_value(u64) % range;
        const upper_bound = @max_value(u64) - leftover;
        var rand_val_array : [@sizeof(u64)]u8 = undefined;

        while (true) {
            r.get_bytes_aligned(rand_val_array);
            const rand_val = *(&u64)(&rand_val_array[0]);
            if (rand_val < upper_bound) {
                return start + (rand_val % range);
            }
        }
    }

    pub fn float32(r: &Rand) -> f32 {
        const precision = 16777216;
        return f32(r.range_u64(0, precision)) / precision;
    }

    pub fn boolean(r: &Rand) -> bool {
        return (r.get_u32() & 0x1) == 1;
    }

    fn generate_numbers(r: &Rand) {
        for (r.array) |item, i| {
            const y : u32 = (item & 0x80000000) + (r.array[(i + 1) % ARRAY_SIZE] & 0x7fffffff);
            const untempered : u32 = r.array[(i + 397) % ARRAY_SIZE] ^ (y >> 1);
            r.array[i] = if ((y % 2) == 0) {
                untempered
            } else {
                // y is odd
                untempered ^ 0x9908b0df
            };
        }
    }

    // does not populate the remaining (buf.len % 4) bytes
    fn get_bytes_aligned(r: &Rand, buf: []u8) -> isize {
        var bytes_left = buf.len;
        while (bytes_left >= 4) {
            *((&u32)(&buf[buf.len - bytes_left])) = r.get_u32();
            bytes_left -= @sizeof(u32);
        }
        return bytes_left;
    }

    /// Initialize random state with the given seed.
    pub fn init(seed: u32) -> Rand {
        var r: Rand = undefined;
        r.index = 0;
        r.array[0] = seed;
        var i : isize = 1;
        var prev_value: u64 = seed;
        while (i < ARRAY_SIZE) {
            r.array[i] = u32((prev_value ^ (prev_value << 30)) * 0x6c078965 + u32(i));
            prev_value = r.array[i];
            i += 1;
        }
        return r;
    }
}

#attribute("test")
fn test_float32() {
    var r = Rand.init(42);

    // TODO for loop with range
    var i: i32 = 0;
    while (i < 1000) {
        const val = r.float32();
        if (!(val >= 0.0)) unreachable{};
        if (!(val < 1.0)) unreachable{};
        i += 1;
    }
}

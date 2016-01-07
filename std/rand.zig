// Mersenne Twister
const ARRAY_SIZE : u16 = 624;

/// Use `rand_init` to initialize this state.
pub struct Rand {
    // TODO use ARRAY_SIZE here
    array: [624]u32,
    // TODO use #typeof(ARRAY_SIZE) here
    index: u16,

    /// Initialize random state with the given seed.
    pub fn init(r: &Rand, seed: u32) {
        r.index = 0;
        r.array[0] = seed;
        var i : #typeof(ARRAY_SIZE) = 1;
        while (i < ARRAY_SIZE) {
            const prev_value : u64 = r.array[i - 1];
            r.array[i] = ((prev_value ^ (prev_value << 30)) * 0x6c078965 + i) as u32;
            i += 1;
        }
    }


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
            var rand_val_array : [#sizeof(u32)]u8;
            *(rand_val_array.ptr as &u32) = r.get_u32();
            while (bytes_left > 0) {
                // TODO array index operator so we can remove the .ptr
                buf.ptr[buf.len - bytes_left] = rand_val_array[#sizeof(u32) - bytes_left];
                bytes_left -= 1;
            }
        }
    }

    /// Get a random unsigned integer with even distribution between `start`
    /// inclusive and `end` exclusive.
    pub fn range_u64(r: &Rand, start: u64, end: u64) -> u64 {
        const range = end - start;
        const leftover = #max_value(u64) % range;
        const upper_bound = #max_value(u64) - leftover;
        var rand_val_array : [#sizeof(u64)]u8;

        while (true) {
            r.get_bytes_aligned(rand_val_array);
            const rand_val = *(rand_val_array.ptr as &u64);
            if (rand_val < upper_bound) {
                return start + (rand_val % range);
            }
        }
    }

    fn generate_numbers(r: &Rand) {
        var i : #typeof(ARRAY_SIZE) = 0;
        while (i < ARRAY_SIZE) {
            const y : u32 = (r.array[i] & 0x80000000) + (r.array[(i + 1) % ARRAY_SIZE] & 0x7fffffff);
            const untempered : u32 = r.array[(i + 397) % ARRAY_SIZE] ^ (y >> 1);
            r.array[i] = if ((y % 2) == 0) {
                untempered
            } else {
                // y is odd
                untempered ^ 0x9908b0df
            };
            i += 1;
        }
    }

    // does not populate the remaining (buf.len % 4) bytes
    fn get_bytes_aligned(r: &Rand, buf: []u8) -> usize {
        var bytes_left = buf.len;
        while (bytes_left >= 4) {
            // TODO: array access so we can remove .ptr
            *(&buf.ptr[buf.len - bytes_left] as &u32) = r.get_u32();
            bytes_left -= #sizeof(u32);
        }
        return bytes_left;
    }
}


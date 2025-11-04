const std = @import("std");
const builtin = @import("builtin");
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Thread = std.Thread;

const TurboSHAKE128State = crypto.hash.sha3.TurboShake128(0x06);
const TurboSHAKE256State = crypto.hash.sha3.TurboShake256(0x06);

const chunk_size: usize = 8192; // Chunk size for tree hashing (8 KiB)
const cache_line_size = std.atomic.cache_line;

// Optimal SIMD vector length for u64 on this target platform
const optimal_vector_len = std.simd.suggestVectorLength(u64) orelse 1;

// Multi-threading threshold: inputs larger than this will use parallel processing.
// Benchmarked optimal value for ReleaseFast mode.
const large_file_threshold: usize = 2 * 1024 * 1024; // 2 MB

// Round constants for Keccak-p[1600,12]
const RC = [12]u64{
    0x000000008000808B,
    0x800000000000008B,
    0x8000000000008089,
    0x8000000000008003,
    0x8000000000008002,
    0x8000000000000080,
    0x000000000000800A,
    0x800000008000000A,
    0x8000000080008081,
    0x8000000000008080,
    0x0000000080000001,
    0x8000000080008008,
};

/// Generic KangarooTwelve variant builder.
/// Creates a variant type with specific cryptographic parameters.
fn KangarooVariant(
    comptime security_level_bits: comptime_int,
    comptime rate_bytes: usize,
    comptime cv_size_bytes: usize,
    comptime StateTypeParam: type,
    comptime sep_x: usize,
    comptime sep_y: usize,
    comptime pad_x: usize,
    comptime pad_y: usize,
    comptime toBufferFn: fn (*const MultiSliceView, u8, []u8) void,
    comptime allocFn: fn (Allocator, *const MultiSliceView, u8, usize) anyerror![]u8,
) type {
    return struct {
        const security_level = security_level_bits;
        const rate = rate_bytes;
        const rate_in_lanes = rate_bytes / 8;
        const cv_size = cv_size_bytes;
        const StateType = StateTypeParam;
        const separation_byte_pos = .{ .x = sep_x, .y = sep_y };
        const padding_pos = .{ .x = pad_x, .y = pad_y };

        inline fn turboSHAKEToBuffer(view: *const MultiSliceView, separation_byte: u8, output: []u8) void {
            toBufferFn(view, separation_byte, output);
        }

        inline fn turboSHAKEMultiSliceAlloc(
            allocator: Allocator,
            view: *const MultiSliceView,
            separation_byte: u8,
            output_len: usize,
        ) ![]u8 {
            return allocFn(allocator, view, separation_byte, output_len);
        }
    };
}

/// KangarooTwelve with 128-bit security parameters
const KT128Variant = KangarooVariant(
    128, // Security level in bits
    168, // TurboSHAKE128 rate in bytes
    32, // Chaining value size in bytes
    TurboSHAKE128State,
    1, // separation_byte_pos.x (lane 11: 88 bytes into 168-byte rate)
    3, // separation_byte_pos.y
    0, // padding_pos.x (lane 20: last lane of 168-byte rate)
    4, // padding_pos.y
    turboSHAKE128MultiSliceToBuffer,
    turboSHAKE128MultiSlice,
);

/// KangarooTwelve with 256-bit security parameters
const KT256Variant = KangarooVariant(
    256, // Security level in bits
    136, // TurboSHAKE256 rate in bytes
    64, // Chaining value size in bytes
    TurboSHAKE256State,
    4, // separation_byte_pos.x (lane 4: 32 bytes into 136-byte rate)
    0, // separation_byte_pos.y
    1, // padding_pos.x (lane 16: last lane of 136-byte rate)
    3, // padding_pos.y
    turboSHAKE256MultiSliceToBuffer,
    turboSHAKE256MultiSlice,
);

/// Rotate left for u64 vector
inline fn rol64Vec(comptime N: usize, v: @Vector(N, u64), comptime n: u6) @Vector(N, u64) {
    if (n == 0) return v;
    const left: @Vector(N, u64) = @splat(n);
    const right_shift: u64 = 64 - @as(u64, n);
    const right: @Vector(N, u64) = @splat(right_shift);
    return (v << left) | (v >> right);
}

/// Load a 64-bit little-endian value
inline fn load64(bytes: []const u8) u64 {
    return std.mem.readInt(u64, bytes[0..8], .little);
}

/// Store a 64-bit little-endian value
inline fn store64(value: u64, bytes: []u8) void {
    std.mem.writeInt(u64, bytes[0..8], value, .little);
}

/// Right-encode result type (max 9 bytes for 64-bit usize)
const RightEncoded = struct {
    bytes: [9]u8,
    len: u8,

    fn slice(self: *const RightEncoded) []const u8 {
        return self.bytes[0..self.len];
    }
};

/// Right-encode: encodes a number as bytes with length suffix (no allocation)
fn rightEncode(x: usize) RightEncoded {
    var result: RightEncoded = undefined;

    if (x == 0) {
        result.bytes[0] = 0;
        result.len = 1;
        return result;
    }

    var temp: [9]u8 = undefined;
    var len: usize = 0;
    var val = x;

    while (val > 0) : (val /= 256) {
        temp[len] = @intCast(val % 256);
        len += 1;
    }

    // Reverse bytes (MSB first)
    for (0..len) |i| {
        result.bytes[i] = temp[len - 1 - i];
    }
    result.bytes[len] = @intCast(len);
    result.len = @intCast(len + 1);

    return result;
}

/// Virtual contiguous view over multiple slices (zero-copy)
const MultiSliceView = struct {
    slices: [3][]const u8,
    offsets: [4]usize,

    fn init(s1: []const u8, s2: []const u8, s3: []const u8) MultiSliceView {
        return .{
            .slices = .{ s1, s2, s3 },
            .offsets = .{
                0,
                s1.len,
                s1.len + s2.len,
                s1.len + s2.len + s3.len,
            },
        };
    }

    fn totalLen(self: *const MultiSliceView) usize {
        return self.offsets[3];
    }

    /// Get byte at position (zero-copy)
    fn getByte(self: *const MultiSliceView, pos: usize) u8 {
        for (0..3) |i| {
            if (pos >= self.offsets[i] and pos < self.offsets[i + 1]) {
                return self.slices[i][pos - self.offsets[i]];
            }
        }
        unreachable;
    }

    /// Try to get a contiguous slice [start..end) - returns null if spans boundaries
    fn tryGetSlice(self: *const MultiSliceView, start: usize, end: usize) ?[]const u8 {
        for (0..3) |i| {
            if (start >= self.offsets[i] and end <= self.offsets[i + 1]) {
                const local_start = start - self.offsets[i];
                const local_end = end - self.offsets[i];
                return self.slices[i][local_start..local_end];
            }
        }
        return null;
    }

    /// Copy range [start..end) to buffer (used when slice spans boundaries)
    fn copyRange(self: *const MultiSliceView, start: usize, end: usize, buffer: []u8) void {
        var pos: usize = 0;
        for (start..end) |i| {
            buffer[pos] = self.getByte(i);
            pos += 1;
        }
    }
};

/// Apply Keccak-p[1600,12] to N states in parallel
fn keccakP1600timesN(comptime N: usize, states: *[5][5]@Vector(N, u64)) void {
    @setEvalBranchQuota(10000);

    // Pre-computed rotation offsets for rho-pi step
    const rho_offsets = comptime blk: {
        var offsets: [24]u6 = undefined;
        var px: usize = 1;
        var py: usize = 0;
        for (0..24) |t| {
            const rot_amount = ((t + 1) * (t + 2) / 2) % 64;
            offsets[t] = @intCast(rot_amount);
            const temp_x = py;
            py = (2 * px + 3 * py) % 5;
            px = temp_x;
        }
        break :blk offsets;
    };

    var round: usize = 0;
    while (round < 12) : (round += 2) {
        inline for (0..2) |i| {
            // θ (theta)
            var C: [5]@Vector(N, u64) = undefined;
            inline for (0..5) |x| {
                C[x] = states[x][0] ^ states[x][1] ^ states[x][2] ^ states[x][3] ^ states[x][4];
            }

            var D: [5]@Vector(N, u64) = undefined;
            inline for (0..5) |x| {
                D[x] = C[(x + 4) % 5] ^ rol64Vec(N, C[(x + 1) % 5], 1);
            }

            // Apply D to all lanes
            inline for (0..5) |x| {
                states[x][0] ^= D[x];
                states[x][1] ^= D[x];
                states[x][2] ^= D[x];
                states[x][3] ^= D[x];
                states[x][4] ^= D[x];
            }

            // ρ (rho) and π (pi) - optimized with pre-computed offsets
            var current = states[1][0];
            var px: usize = 1;
            var py: usize = 0;
            inline for (rho_offsets) |rot| {
                const next_y = (2 * px + 3 * py) % 5;
                const next = states[py][next_y];
                states[py][next_y] = rol64Vec(N, current, rot);
                current = next;
                px = py;
                py = next_y;
            }

            // χ (chi) - optimized with better register usage
            inline for (0..5) |y| {
                const t0 = states[0][y];
                const t1 = states[1][y];
                const t2 = states[2][y];
                const t3 = states[3][y];
                const t4 = states[4][y];

                states[0][y] = t0 ^ (~t1 & t2);
                states[1][y] = t1 ^ (~t2 & t3);
                states[2][y] = t2 ^ (~t3 & t4);
                states[3][y] = t3 ^ (~t4 & t0);
                states[4][y] = t4 ^ (~t0 & t1);
            }

            // ι (iota)
            const rc_splat: @Vector(N, u64) = @splat(RC[round + i]);
            states[0][0] ^= rc_splat;
        }
    }
}

/// Add lanes from data to N states in parallel with stride - optimized version
fn addLanesAll(
    comptime N: usize,
    states: *[5][5]@Vector(N, u64),
    data: []const u8,
    lane_count: usize,
    lane_offset: usize,
) void {

    // Process lanes (at most 25 lanes in Keccak state)
    inline for (0..25) |xy| {
        if (xy < lane_count) {
            const x = xy % 5;
            const y = xy / 5;

            // Load N lanes with stride - optimized memory access pattern
            var loaded_data: @Vector(N, u64) = undefined;
            inline for (0..N) |i| {
                loaded_data[i] = load64(data[8 * (i * lane_offset + xy) ..]);
            }
            states[x][y] ^= loaded_data;
        }
    }
}

/// Apply Keccak-p[1600,12] to a single state (byte representation)
fn keccakP(state: *[200]u8) void {
    @setEvalBranchQuota(10000);
    var lanes: [5][5]u64 = undefined;

    // Load state into lanes
    inline for (0..5) |x| {
        inline for (0..5) |y| {
            lanes[x][y] = load64(state[8 * (x + 5 * y) ..]);
        }
    }

    // Apply 12 rounds
    var round: usize = 0;
    while (round < 12) : (round += 2) {
        inline for (0..2) |i| {
            // θ
            var C: [5]u64 = undefined;
            inline for (0..5) |x| {
                C[x] = lanes[x][0] ^ lanes[x][1] ^ lanes[x][2] ^ lanes[x][3] ^ lanes[x][4];
            }
            var D: [5]u64 = undefined;
            inline for (0..5) |x| {
                D[x] = C[(x + 4) % 5] ^ std.math.rotl(u64, C[(x + 1) % 5], 1);
            }
            inline for (0..5) |x| {
                inline for (0..5) |y| {
                    lanes[x][y] ^= D[x];
                }
            }

            // ρ and π
            var current = lanes[1][0];
            var px: usize = 1;
            var py: usize = 0;
            inline for (0..24) |t| {
                const temp = lanes[py][(2 * px + 3 * py) % 5];
                const rot_amount = ((t + 1) * (t + 2) / 2) % 64;
                lanes[py][(2 * px + 3 * py) % 5] = std.math.rotl(u64, current, @as(u6, @intCast(rot_amount)));
                current = temp;
                const temp_x = py;
                py = (2 * px + 3 * py) % 5;
                px = temp_x;
            }

            // χ
            inline for (0..5) |y| {
                const T = [5]u64{ lanes[0][y], lanes[1][y], lanes[2][y], lanes[3][y], lanes[4][y] };
                inline for (0..5) |x| {
                    lanes[x][y] = T[x] ^ (~T[(x + 1) % 5] & T[(x + 2) % 5]);
                }
            }

            // ι
            lanes[0][0] ^= RC[round + i];
        }
    }

    // Store lanes back to state
    inline for (0..5) |x| {
        inline for (0..5) |y| {
            store64(lanes[x][y], state[8 * (x + 5 * y) ..]);
        }
    }
}

/// Apply Keccak-p[1600,12] to a single state (u64 lane representation)
fn keccakPLanes(lanes: *[25]u64) void {
    @setEvalBranchQuota(10000);

    // Apply 12 rounds
    inline for (RC) |rc| {
        // θ
        var C: [5]u64 = undefined;
        inline for (0..5) |x| {
            C[x] = lanes[x] ^ lanes[x + 5] ^ lanes[x + 10] ^ lanes[x + 15] ^ lanes[x + 20];
        }
        var D: [5]u64 = undefined;
        inline for (0..5) |x| {
            D[x] = C[(x + 4) % 5] ^ std.math.rotl(u64, C[(x + 1) % 5], 1);
        }
        inline for (0..5) |x| {
            inline for (0..5) |y| {
                lanes[x + 5 * y] ^= D[x];
            }
        }

        // ρ and π
        var current = lanes[1];
        var px: usize = 1;
        var py: usize = 0;
        inline for (0..24) |t| {
            const next_y = (2 * px + 3 * py) % 5;
            const next_idx = py + 5 * next_y;
            const temp = lanes[next_idx];
            const rot_amount = ((t + 1) * (t + 2) / 2) % 64;
            lanes[next_idx] = std.math.rotl(u64, current, @as(u6, @intCast(rot_amount)));
            current = temp;
            px = py;
            py = next_y;
        }

        // χ
        inline for (0..5) |y| {
            const idx = 5 * y;
            const T = [5]u64{ lanes[idx], lanes[idx + 1], lanes[idx + 2], lanes[idx + 3], lanes[idx + 4] };
            inline for (0..5) |x| {
                lanes[idx + x] = T[x] ^ (~T[(x + 1) % 5] & T[(x + 2) % 5]);
            }
        }

        // ι
        lanes[0] ^= rc;
    }
}

/// Generic non-allocating TurboSHAKE: write output to provided buffer
fn turboSHAKEMultiSliceToBuffer(
    comptime rate: usize,
    view: *const MultiSliceView,
    separation_byte: u8,
    output: []u8,
) void {
    var state: [200]u8 = @splat(0);
    var state_pos: usize = 0;

    // Absorb all bytes from the multi-slice view
    const total = view.totalLen();
    var pos: usize = 0;
    while (pos < total) {
        state[state_pos] ^= view.getByte(pos);
        state_pos += 1;
        pos += 1;

        if (state_pos == rate) {
            keccakP(&state);
            state_pos = 0;
        }
    }

    // Add separation byte and padding
    state[state_pos] ^= separation_byte;
    state[rate - 1] ^= 0x80;
    keccakP(&state);

    // Squeeze
    var out_offset: usize = 0;
    while (out_offset < output.len) {
        const chunk = @min(rate, output.len - out_offset);
        @memcpy(output[out_offset..][0..chunk], state[0..chunk]);
        out_offset += chunk;
        if (out_offset < output.len) {
            keccakP(&state);
        }
    }
}

/// Generic allocating TurboSHAKE
fn turboSHAKEMultiSlice(
    comptime rate: usize,
    allocator: Allocator,
    view: *const MultiSliceView,
    separation_byte: u8,
    output_len: usize,
) ![]u8 {
    const output = try allocator.alloc(u8, output_len);
    turboSHAKEMultiSliceToBuffer(rate, view, separation_byte, output);
    return output;
}

/// Non-allocating TurboSHAKE128: write output to provided buffer
fn turboSHAKE128MultiSliceToBuffer(
    view: *const MultiSliceView,
    separation_byte: u8,
    output: []u8,
) void {
    turboSHAKEMultiSliceToBuffer(168, view, separation_byte, output);
}

/// Allocating TurboSHAKE128
fn turboSHAKE128MultiSlice(
    allocator: Allocator,
    view: *const MultiSliceView,
    separation_byte: u8,
    output_len: usize,
) ![]u8 {
    return turboSHAKEMultiSlice(168, allocator, view, separation_byte, output_len);
}

/// Non-allocating TurboSHAKE256: write output to provided buffer
fn turboSHAKE256MultiSliceToBuffer(
    view: *const MultiSliceView,
    separation_byte: u8,
    output: []u8,
) void {
    turboSHAKEMultiSliceToBuffer(136, view, separation_byte, output);
}

/// Allocating TurboSHAKE256
fn turboSHAKE256MultiSlice(
    allocator: Allocator,
    view: *const MultiSliceView,
    separation_byte: u8,
    output_len: usize,
) ![]u8 {
    return turboSHAKEMultiSlice(136, allocator, view, separation_byte, output_len);
}

/// Process N leaves (8KiB chunks) in parallel - generic version
fn processLeaves(
    comptime Variant: type,
    comptime N: usize,
    data: []const u8,
    result: *[N * Variant.cv_size]u8,
) void {
    const rate_in_lanes: usize = Variant.rate_in_lanes;
    const rate_in_bytes: usize = rate_in_lanes * 8;
    const cv_size: usize = Variant.cv_size;

    // Initialize N all-zero states with cache alignment
    var states: [5][5]@Vector(N, u64) align(cache_line_size) = undefined;
    inline for (0..5) |x| {
        inline for (0..5) |y| {
            states[x][y] = @splat(0);
        }
    }

    // Process complete blocks
    var j: usize = 0;
    while (j + rate_in_bytes <= chunk_size) : (j += rate_in_bytes) {
        addLanesAll(N, &states, data[j..], rate_in_lanes, chunk_size / 8);
        keccakP1600timesN(N, &states);
    }

    // Process last incomplete block
    const remaining_lanes = (chunk_size - j) / 8;
    if (remaining_lanes > 0) {
        addLanesAll(N, &states, data[j..], remaining_lanes, chunk_size / 8);
    }

    // Add suffix 0x0B and padding
    const suffix_pos = Variant.separation_byte_pos;
    const padding_pos = Variant.padding_pos;

    const suffix_splat: @Vector(N, u64) = @splat(0x0B);
    states[suffix_pos.x][suffix_pos.y] ^= suffix_splat;
    const padding_splat: @Vector(N, u64) = @splat(0x8000000000000000);
    states[padding_pos.x][padding_pos.y] ^= padding_splat;

    keccakP1600timesN(N, &states);

    // Extract chaining values from each state
    const lanes_to_extract = cv_size / 8;
    comptime var lane_idx: usize = 0;
    inline while (lane_idx < lanes_to_extract) : (lane_idx += 1) {
        const x = lane_idx % 5;
        const y = lane_idx / 5;
        inline for (0..N) |i| {
            store64(states[x][y][i], result[i * cv_size + lane_idx * 8 ..]);
        }
    }
}

/// Context for processing a batch of leaves in a thread
const LeafBatchContext = struct {
    output_cvs: []u8,
    batch_start: usize,
    batch_count: usize,
    view: *const MultiSliceView,
    scratch_buffer: []u8, // Pre-allocated scratch space (no allocations in worker)
    total_len: usize, // Total length of input data (for boundary checking)
};

/// Helper function to process N leaves in parallel, reducing code duplication
inline fn processNLeaves(
    comptime Variant: type,
    comptime N: usize,
    view: *const MultiSliceView,
    j: usize,
    leaf_buffer: []u8,
    output: []u8,
) void {
    const cv_size = Variant.cv_size;
    if (view.tryGetSlice(j, j + N * chunk_size)) |leaf_data| {
        var leaf_cvs: [N * cv_size]u8 = undefined;
        processLeaves(Variant, N, leaf_data, &leaf_cvs);
        @memcpy(output[0..leaf_cvs.len], &leaf_cvs);
    } else {
        view.copyRange(j, j + N * chunk_size, leaf_buffer[0 .. N * chunk_size]);
        var leaf_cvs: [N * cv_size]u8 = undefined;
        processLeaves(Variant, N, leaf_buffer[0 .. N * chunk_size], &leaf_cvs);
        @memcpy(output[0..leaf_cvs.len], &leaf_cvs);
    }
}

/// Process a batch of leaves in a single thread using SIMD
fn processLeafBatch(comptime Variant: type, ctx: LeafBatchContext) void {
    const cv_size = Variant.cv_size;
    const leaf_buffer = ctx.scratch_buffer[0 .. 8 * chunk_size];
    const cv_scratch = ctx.scratch_buffer[8 * chunk_size .. 8 * chunk_size + cv_size];

    var cvs_offset: usize = 0;
    var j: usize = ctx.batch_start;
    const batch_end = @min(ctx.batch_start + ctx.batch_count * chunk_size, ctx.total_len);

    // Process leaves using SIMD (8x, 4x, 2x) based on optimal vector length
    inline for ([_]usize{ 8, 4, 2 }) |batch_size| {
        while (optimal_vector_len >= batch_size and j + batch_size * chunk_size <= batch_end) {
            processNLeaves(Variant, batch_size, ctx.view, j, leaf_buffer, ctx.output_cvs[cvs_offset..]);
            cvs_offset += batch_size * cv_size;
            j += batch_size * chunk_size;
        }
    }

    // Process remaining single leaves
    while (j < batch_end) {
        const chunk_len = @min(chunk_size, batch_end - j);
        if (ctx.view.tryGetSlice(j, j + chunk_len)) |leaf_data| {
            const cv_slice = MultiSliceView.init(leaf_data, &[_]u8{}, &[_]u8{});
            Variant.turboSHAKEToBuffer(&cv_slice, 0x0B, cv_scratch[0..cv_size]);
            @memcpy(ctx.output_cvs[cvs_offset..][0..cv_size], cv_scratch[0..cv_size]);
        } else {
            ctx.view.copyRange(j, j + chunk_len, leaf_buffer[0..chunk_len]);
            const cv_slice = MultiSliceView.init(leaf_buffer[0..chunk_len], &[_]u8{}, &[_]u8{});
            Variant.turboSHAKEToBuffer(&cv_slice, 0x0B, cv_scratch[0..cv_size]);
            @memcpy(ctx.output_cvs[cvs_offset..][0..cv_size], cv_scratch[0..cv_size]);
        }
        cvs_offset += cv_size;
        j += chunk_size;
    }
}

/// Helper to process N leaves in SIMD and absorb CVs into state
inline fn processAndAbsorbNLeaves(
    comptime Variant: type,
    comptime N: usize,
    view: *const MultiSliceView,
    j: usize,
    leaf_buffer: []u8,
    final_state: anytype,
) void {
    const cv_size = Variant.cv_size;
    if (view.tryGetSlice(j, j + N * chunk_size)) |leaf_data| {
        var leaf_cvs: [N * cv_size]u8 align(cache_line_size) = undefined;
        processLeaves(Variant, N, leaf_data, &leaf_cvs);
        final_state.update(&leaf_cvs);
    } else {
        view.copyRange(j, j + N * chunk_size, leaf_buffer[0 .. N * chunk_size]);
        var leaf_cvs: [N * cv_size]u8 align(cache_line_size) = undefined;
        processLeaves(Variant, N, leaf_buffer[0 .. N * chunk_size], &leaf_cvs);
        final_state.update(&leaf_cvs);
    }
}

/// Generic single-threaded implementation
fn ktSingleThreaded(comptime Variant: type, view: *const MultiSliceView, total_len: usize, output: []u8) void {
    const cv_size = Variant.cv_size;
    const StateType = Variant.StateType;

    // Initialize streaming TurboSHAKE state for final node (delimiter 0x06 is set in the type)
    var final_state = StateType.init(.{});

    // Absorb first B bytes from input
    var first_b_buffer: [chunk_size]u8 = undefined;
    if (view.tryGetSlice(0, chunk_size)) |first_chunk| {
        final_state.update(first_chunk);
    } else {
        view.copyRange(0, chunk_size, &first_b_buffer);
        final_state.update(&first_b_buffer);
    }

    // Absorb padding bytes (8 bytes: 0x03 followed by 7 zeros)
    const padding = [_]u8{ 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    final_state.update(&padding);

    var j: usize = chunk_size;
    var n: usize = 0;

    // Temporary buffers for boundary-spanning leaves and CV computation
    var leaf_buffer: [chunk_size * 8]u8 align(cache_line_size) = undefined;
    var cv_buffer: [64]u8 = undefined; // Max CV size is 64 bytes

    // Process leaves in SIMD batches (8x, 4x, 2x)
    inline for ([_]usize{ 8, 4, 2 }) |batch_size| {
        while (optimal_vector_len >= batch_size and j + batch_size * chunk_size <= total_len) {
            processAndAbsorbNLeaves(Variant, batch_size, view, j, &leaf_buffer, &final_state);
            j += batch_size * chunk_size;
            n += batch_size;
        }
    }

    // Process remaining leaves one at a time
    while (j < total_len) {
        const chunk_len = @min(chunk_size, total_len - j);
        if (view.tryGetSlice(j, j + chunk_len)) |leaf_data| {
            const cv_slice = MultiSliceView.init(leaf_data, &[_]u8{}, &[_]u8{});
            Variant.turboSHAKEToBuffer(&cv_slice, 0x0B, cv_buffer[0..cv_size]);
            final_state.update(cv_buffer[0..cv_size]); // Absorb CV immediately
        } else {
            view.copyRange(j, j + chunk_len, leaf_buffer[0..chunk_len]);
            const cv_slice = MultiSliceView.init(leaf_buffer[0..chunk_len], &[_]u8{}, &[_]u8{});
            Variant.turboSHAKEToBuffer(&cv_slice, 0x0B, cv_buffer[0..cv_size]);
            final_state.update(cv_buffer[0..cv_size]);
        }
        j += chunk_size;
        n += 1;
    }

    // Absorb right_encode(n) and terminator
    const n_enc = rightEncode(n);
    final_state.update(n_enc.slice());
    const terminator = [_]u8{ 0xFF, 0xFF };
    final_state.update(&terminator);

    // Finalize and squeeze output
    final_state.final(output);
}

/// Generic multi-threaded implementation
fn ktMultiThreaded(
    comptime Variant: type,
    allocator: Allocator,
    io: Io,
    view: *const MultiSliceView,
    total_len: usize,
    output: []u8,
) !void {
    const cv_size = Variant.cv_size;

    // Calculate total number of leaves
    const total_leaves: usize = (total_len - 1) / chunk_size;

    // Check if we have enough threads to benefit from parallelization
    const thread_count = Thread.getCpuCount() catch 1;
    if (thread_count <= 1) {
        // Single-threaded fallback - more efficient than using group.async
        ktSingleThreaded(Variant, view, total_len, output);
        return;
    }

    // Allocate buffer for all chaining values
    const cvs = try allocator.alloc(u8, total_leaves * cv_size);
    defer allocator.free(cvs);

    // Divide work among threads
    const leaves_per_thread = (total_leaves + thread_count - 1) / thread_count;

    // Pre-allocate scratch buffers for all threads (8 leaves + CV size)
    const scratch_size = 8 * chunk_size + cv_size;
    const all_scratch = try allocator.alloc(u8, thread_count * scratch_size);
    defer allocator.free(all_scratch);

    const contexts = try allocator.alloc(LeafBatchContext, thread_count);
    defer allocator.free(contexts);

    var leaves_assigned: usize = 0;
    var context_count: usize = 0;

    while (leaves_assigned < total_leaves) {
        const batch_count = @min(leaves_per_thread, total_leaves - leaves_assigned);
        const batch_start = chunk_size + leaves_assigned * chunk_size;
        const cvs_offset = leaves_assigned * cv_size;

        contexts[context_count] = LeafBatchContext{
            .output_cvs = cvs[cvs_offset .. cvs_offset + batch_count * cv_size],
            .batch_start = batch_start,
            .batch_count = batch_count,
            .view = view,
            .scratch_buffer = all_scratch[context_count * scratch_size .. (context_count + 1) * scratch_size],
            .total_len = total_len,
        };

        leaves_assigned += batch_count;
        context_count += 1;
    }

    var group: Io.Group = .init;
    for (contexts[0..context_count]) |ctx| {
        group.async(io, struct {
            fn process(c: LeafBatchContext) void {
                processLeafBatch(Variant, c);
            }
        }.process, .{ctx});
    }

    // Wait for all threads to complete
    group.wait(io);

    // Build final node
    const n_enc = rightEncode(total_leaves);
    const final_node_len = chunk_size + 8 + total_leaves * cv_size + n_enc.len + 2;
    const final_node = try allocator.alloc(u8, final_node_len);
    defer allocator.free(final_node);

    // Copy first B bytes
    if (view.tryGetSlice(0, chunk_size)) |first_chunk| {
        @memcpy(final_node[0..chunk_size], first_chunk);
    } else {
        view.copyRange(0, chunk_size, final_node[0..chunk_size]);
    }

    @memset(final_node[chunk_size..][0..8], 0);
    final_node[chunk_size] = 0x03;
    @memcpy(final_node[chunk_size + 8 ..][0 .. total_leaves * cv_size], cvs);
    @memcpy(final_node[chunk_size + 8 + total_leaves * cv_size ..][0..n_enc.len], n_enc.slice());
    final_node[final_node_len - 2] = 0xFF;
    final_node[final_node_len - 1] = 0xFF;

    const final_view = MultiSliceView.init(final_node, &[_]u8{}, &[_]u8{});
    Variant.turboSHAKEToBuffer(&final_view, 0x06, output);
}

/// Generic KangarooTwelve hash function builder.
/// Creates a public API type with hash and hashParallel methods for a specific variant.
fn KTHash(
    comptime Variant: type,
    comptime singleChunkFn: fn (*const MultiSliceView, u8, []u8) void,
) type {
    return struct {
        const Self = @This();
        const StateType = Variant.StateType;

        /// The recommended output length, in bytes.
        pub const digest_length = Variant.security_level / 8 * 2;
        /// The block length, or rate, in bytes.
        pub const block_length = Variant.rate;

        /// Configuration options for KangarooTwelve hashing.
        ///
        /// Options include an optional customization string that provides domain separation,
        /// ensuring that identical inputs with different customization strings
        /// produce completely distinct hash outputs.
        ///
        /// This prevents hash collisions when the same data is hashed in different contexts.
        ///
        /// Customization strings can be of any length.
        ///
        /// Common options for customization::
        ///
        /// - Key derivation or MAC: 16-byte secret for KT128, 32-byte secret for KT256
        /// - Context Separation: domain-specific strings (e.g., "email", "password", "session")
        /// - Composite Keys: concatenation of secret key + context string
        pub const Options = struct {
            customization: ?[]const u8 = null,
        };

        // Message buffer (accumulates message data only, not customization)
        buffer: [chunk_size]u8,
        buffer_len: usize,
        message_len: usize,

        // Customization string (fixed at init)
        customization: []const u8,
        custom_len_enc: RightEncoded,

        // Tree mode state (lazy initialization when buffer overflows first time)
        first_chunk: ?[chunk_size]u8, // Saved first chunk for tree mode
        final_state: ?StateType, // Running TurboSHAKE state for final node
        num_leaves: usize, // Count of leaves processed (after first chunk)

        // SIMD chunk batching
        pending_chunks: [8 * chunk_size]u8 align(cache_line_size), // Buffer for up to 8 chunks
        pending_count: usize, // Number of complete chunks in pending_chunks

        /// Initialize a KangarooTwelve hashing context.
        ///
        /// Options include an optional customization string that provides domain separation,
        /// ensuring that identical inputs with different customization strings
        /// produce completely distinct hash outputs.
        ///
        /// This prevents hash collisions when the same data is hashed in different contexts.
        ///
        /// Customization strings can be of any length.
        ///
        /// Common options for customization::
        ///
        /// - Key derivation or MAC: 16-byte secret for KT128, 32-byte secret for KT256
        /// - Context Separation: domain-specific strings (e.g., "email", "password", "session")
        /// - Composite Keys: concatenation of secret key + context string
        pub fn init(options: Options) Self {
            const custom = options.customization orelse &[_]u8{};
            return .{
                .buffer = undefined,
                .buffer_len = 0,
                .message_len = 0,
                .customization = custom,
                .custom_len_enc = rightEncode(custom.len),
                .first_chunk = null,
                .final_state = null,
                .num_leaves = 0,
                .pending_chunks = undefined,
                .pending_count = 0,
            };
        }

        /// Flush all pending chunks using SIMD when possible
        fn flushPendingChunks(self: *Self) void {
            const cv_size = Variant.cv_size;

            // Process all pending chunks using the largest SIMD batch sizes possible
            while (self.pending_count > 0) {
                // Try SIMD batches in decreasing size order
                inline for ([_]usize{ 8, 4, 2 }) |batch_size| {
                    if (optimal_vector_len >= batch_size and self.pending_count >= batch_size) {
                        var leaf_cvs: [batch_size * cv_size]u8 align(cache_line_size) = undefined;
                        processLeaves(Variant, batch_size, self.pending_chunks[0 .. batch_size * chunk_size], &leaf_cvs);
                        self.final_state.?.update(&leaf_cvs);
                        self.num_leaves += batch_size;
                        self.pending_count -= batch_size;

                        // Shift remaining chunks to the front
                        if (self.pending_count > 0) {
                            const remaining_bytes = self.pending_count * chunk_size;
                            @memcpy(self.pending_chunks[0..remaining_bytes], self.pending_chunks[batch_size * chunk_size ..][0..remaining_bytes]);
                        }
                        break; // Continue outer loop to try next batch
                    }
                }

                // If no SIMD batch was possible, process one chunk with scalar code
                if (self.pending_count > 0 and self.pending_count < 2) {
                    var cv_buffer: [64]u8 = undefined;
                    const cv_slice = MultiSliceView.init(self.pending_chunks[0..chunk_size], &[_]u8{}, &[_]u8{});
                    Variant.turboSHAKEToBuffer(&cv_slice, 0x0B, cv_buffer[0..cv_size]);
                    self.final_state.?.update(cv_buffer[0..cv_size]);
                    self.num_leaves += 1;
                    self.pending_count -= 1;
                    break; // No more chunks to process
                }
            }
        }

        /// Absorb data into the hash state.
        /// Can be called multiple times to incrementally add data.
        pub fn update(self: *Self, data: []const u8) void {
            if (data.len == 0) return;

            var remaining = data;

            while (remaining.len > 0) {
                const space_in_buffer = chunk_size - self.buffer_len;
                const to_copy = @min(space_in_buffer, remaining.len);

                // Copy data into buffer
                @memcpy(self.buffer[self.buffer_len..][0..to_copy], remaining[0..to_copy]);
                self.buffer_len += to_copy;
                self.message_len += to_copy;
                remaining = remaining[to_copy..];

                // If buffer is full, process it
                if (self.buffer_len == chunk_size) {
                    if (self.first_chunk == null) {
                        // First time buffer fills - initialize tree mode
                        self.first_chunk = self.buffer;
                        self.final_state = StateType.init(.{});

                        // Absorb first chunk into final state
                        self.final_state.?.update(&self.buffer);

                        // Absorb padding (8 bytes: 0x03 followed by 7 zeros)
                        const padding = [_]u8{ 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
                        self.final_state.?.update(&padding);
                    } else {
                        // Add chunk to pending buffer for SIMD batch processing
                        @memcpy(self.pending_chunks[self.pending_count * chunk_size ..][0..chunk_size], &self.buffer);
                        self.pending_count += 1;

                        // Flush when we have enough chunks for optimal SIMD batch
                        // Determine best batch size for this architecture
                        const optimal_batch_size = comptime blk: {
                            if (optimal_vector_len >= 8) break :blk 8;
                            if (optimal_vector_len >= 4) break :blk 4;
                            if (optimal_vector_len >= 2) break :blk 2;
                            break :blk 1;
                        };
                        if (self.pending_count >= optimal_batch_size) {
                            self.flushPendingChunks();
                        }
                    }
                    self.buffer_len = 0;
                }
            }
        }

        /// Finalize the hash and produce output.
        ///
        /// Unlike traditional hash functions, the output can be of any length.
        ///
        /// When using as a regular hash function, use the recommended `digest_length` value (32 bytes for KT128, 64 bytes for KT256).
        ///
        /// After calling this method, the context should not be reused. However, the structure can be cloned before finalizing
        /// to compute multiple hashes with the same prefix.
        pub fn final(self: *Self, out: []u8) void {
            const cv_size = Variant.cv_size;

            // Calculate total length: message + customization + right_encode(customization.len)
            const total_len = self.message_len + self.customization.len + self.custom_len_enc.len;

            // Single chunk mode: total data fits in one chunk
            if (total_len <= chunk_size) {
                // Build the complete input: buffer + customization + encoded length
                var single_chunk: [chunk_size]u8 = undefined;
                @memcpy(single_chunk[0..self.buffer_len], self.buffer[0..self.buffer_len]);
                @memcpy(single_chunk[self.buffer_len..][0..self.customization.len], self.customization);
                @memcpy(single_chunk[self.buffer_len + self.customization.len ..][0..self.custom_len_enc.len], self.custom_len_enc.slice());

                const view = MultiSliceView.init(single_chunk[0..total_len], &[_]u8{}, &[_]u8{});
                singleChunkFn(&view, 0x07, out);
                return;
            }

            // Flush any pending chunks with SIMD
            self.flushPendingChunks();

            // Build view over remaining data (buffer + customization + encoding)
            const remaining_view = MultiSliceView.init(
                self.buffer[0..self.buffer_len],
                self.customization,
                self.custom_len_enc.slice(),
            );
            const remaining_len = remaining_view.totalLen();

            var final_leaves = self.num_leaves;
            var leaf_start: usize = 0;

            // Tree mode: initialize if not already done (lazy initialization)
            if (self.final_state == null and remaining_len > 0) {
                self.final_state = StateType.init(.{});

                // Absorb first chunk (up to chunk_size bytes from remaining data)
                const first_chunk_len = @min(chunk_size, remaining_len);
                if (remaining_view.tryGetSlice(0, first_chunk_len)) |first_chunk| {
                    // Data is contiguous, use it directly
                    self.final_state.?.update(first_chunk);
                } else {
                    // Data spans boundaries, copy to buffer
                    var first_chunk_buf: [chunk_size]u8 = undefined;
                    remaining_view.copyRange(0, first_chunk_len, first_chunk_buf[0..first_chunk_len]);
                    self.final_state.?.update(first_chunk_buf[0..first_chunk_len]);
                }

                // Absorb padding (8 bytes: 0x03 followed by 7 zeros)
                const padding = [_]u8{ 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
                self.final_state.?.update(&padding);

                // Process remaining data as leaves
                leaf_start = first_chunk_len;
            }

            // Process all remaining data as leaves (starting from leaf_start)
            var offset = leaf_start;
            while (offset < remaining_len) {
                const leaf_end = @min(offset + chunk_size, remaining_len);
                const leaf_size = leaf_end - offset;

                var cv_buffer: [64]u8 = undefined;
                if (remaining_view.tryGetSlice(offset, leaf_end)) |leaf_data| {
                    // Data is contiguous, use it directly
                    const cv_slice = MultiSliceView.init(leaf_data, &[_]u8{}, &[_]u8{});
                    Variant.turboSHAKEToBuffer(&cv_slice, 0x0B, cv_buffer[0..cv_size]);
                } else {
                    // Data spans boundaries, copy to buffer
                    var leaf_buf: [chunk_size]u8 = undefined;
                    remaining_view.copyRange(offset, leaf_end, leaf_buf[0..leaf_size]);
                    const cv_slice = MultiSliceView.init(leaf_buf[0..leaf_size], &[_]u8{}, &[_]u8{});
                    Variant.turboSHAKEToBuffer(&cv_slice, 0x0B, cv_buffer[0..cv_size]);
                }
                self.final_state.?.update(cv_buffer[0..cv_size]);
                final_leaves += 1;
                offset = leaf_end;
            }

            // Absorb right_encode(num_leaves) and terminator
            const n_enc = rightEncode(final_leaves);
            self.final_state.?.update(n_enc.slice());
            const terminator = [_]u8{ 0xFF, 0xFF };
            self.final_state.?.update(&terminator);

            // Squeeze output
            self.final_state.?.final(out);
        }

        /// Hash a message using sequential processing with SIMD acceleration.
        ///
        /// Parameters:
        ///   - message: Input data to hash (any length)
        ///   - out: Output buffer (any length, arbitrary output sizes supported, `digest_length` recommended for standard use)
        ///   - options: Optional settings to include a secret key or a context separation string
        pub fn hash(message: []const u8, out: []u8, options: Options) !void {
            const custom = options.customization orelse &[_]u8{};

            // Right-encode customization length
            const custom_len_enc = rightEncode(custom.len);

            // Create zero-copy multi-slice view (no concatenation)
            const view = MultiSliceView.init(message, custom, custom_len_enc.slice());
            const total_len = view.totalLen();

            // Single chunk case - zero-copy absorption!
            if (total_len <= chunk_size) {
                singleChunkFn(&view, 0x07, out);
                return;
            }

            // Tree mode - single-threaded SIMD processing
            ktSingleThreaded(Variant, &view, total_len, out);
        }

        /// Hash with automatic parallelization for large inputs (>2MB).
        /// Automatically uses sequential processing for smaller inputs to avoid thread overhead.
        /// Allocator required for temporary buffers. IO object required for thread management.
        pub fn hashParallel(message: []const u8, out: []u8, options: Options, allocator: Allocator, io: Io) !void {
            const custom = options.customization orelse &[_]u8{};

            const custom_len_enc = rightEncode(custom.len);
            const view = MultiSliceView.init(message, custom, custom_len_enc.slice());
            const total_len = view.totalLen();

            // Single chunk case
            if (total_len <= chunk_size) {
                singleChunkFn(&view, 0x07, out);
                return;
            }

            // Use single-threaded processing if below threshold
            if (total_len < large_file_threshold) {
                ktSingleThreaded(Variant, &view, total_len, out);
                return;
            }

            // Tree mode - multi-threaded processing
            try ktMultiThreaded(Variant, allocator, io, &view, total_len, out);
        }
    };
}

/// KangarooTwelve is a fast, secure cryptographic hash function that uses tree-hashing
/// on top of TurboSHAKE. It is built on the Keccak permutation, the same primitive
/// underlying SHA-3, which has undergone over 15 years of intensive cryptanalysis
/// since the SHA-3 competition (2008-2012) and remains secure.
///
/// K12 uses Keccak-p[1600,12] with 12 rounds (half of SHA-3's 24 rounds), providing
/// 128-bit security strength equivalent to AES-128 and SHAKE128. While this offers
/// less conservative margin than SHA-3, current cryptanalysis reaches only 6 rounds,
/// leaving a substantial security margin. This deliberate trade-off delivers
/// significantly better performance while maintaining strong practical security.
///
/// Standardized as RFC 9861 after 8 years of public scrutiny. Supports arbitrary-length
/// output and optional customization strings for domain separation.
pub const KT128 = KTHash(KT128Variant, turboSHAKE128MultiSliceToBuffer);

/// KangarooTwelve is a fast, secure cryptographic hash function that uses tree-hashing
/// on top of TurboSHAKE. It is built on the Keccak permutation, the same primitive
/// underlying SHA-3, which has undergone over 15 years of intensive cryptanalysis
/// since the SHA-3 competition (2008-2012) and remains secure.
///
/// KT256 provides 256-bit security strength and achieves NIST post-quantum security
/// level 2 when using at least 256-bit outputs. Like KT128, it uses Keccak-p[1600,12]
/// with 12 rounds, offering a deliberate trade-off between conservative margin and
/// significantly better performance while maintaining strong practical security.
///
/// Use KT256 when you need extra conservative margins.
/// For most applications, KT128 offers better performance with adequate security.
pub const KT256 = KTHash(KT256Variant, turboSHAKE256MultiSliceToBuffer);

test "KT128 sequential and parallel produce same output for small inputs" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    // Test with different small input sizes
    const test_sizes = [_]usize{ 100, 1024, 4096, 8192 }; // 100B, 1KB, 4KB, 8KB

    for (test_sizes) |size| {
        const input = try allocator.alloc(u8, size);
        defer allocator.free(input);

        // Fill with random data
        crypto.random.bytes(input);

        var output_seq: [32]u8 = undefined;
        var output_par: [32]u8 = undefined;

        // Hash with sequential method
        try KT128.hash(input, &output_seq, .{});

        // Hash with parallel method
        try KT128.hashParallel(input, &output_par, .{}, allocator, io);

        // Verify outputs match
        try std.testing.expectEqualSlices(u8, &output_seq, &output_par);
    }
}

test "KT128 sequential and parallel produce same output for large inputs" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    // Test with large input sizes that trigger parallel processing
    // The threshold is 3-10MB depending on CPU count, so we test above that
    const test_sizes = [_]usize{ 11 * 1024 * 1024, 20 * 1024 * 1024 }; // 11MB, 20MB

    for (test_sizes) |size| {
        const input = try allocator.alloc(u8, size);
        defer allocator.free(input);

        // Fill with random data
        crypto.random.bytes(input);

        var output_seq: [64]u8 = undefined;
        var output_par: [64]u8 = undefined;

        // Hash with sequential method
        try KT128.hash(input, &output_seq, .{});

        // Hash with parallel method
        try KT128.hashParallel(input, &output_par, .{}, allocator, io);

        // Verify outputs match
        try std.testing.expectEqualSlices(u8, &output_seq, &output_par);
    }
}

test "KT128 sequential and parallel produce same output with customization" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const input_size = 15 * 1024 * 1024; // 15MB
    const input = try allocator.alloc(u8, input_size);
    defer allocator.free(input);

    // Fill with random data
    crypto.random.bytes(input);

    const customization = "test domain";
    var output_seq: [48]u8 = undefined;
    var output_par: [48]u8 = undefined;

    // Hash with sequential method
    try KT128.hash(input, &output_seq, .{ .customization = customization });

    // Hash with parallel method
    try KT128.hashParallel(input, &output_par, .{ .customization = customization }, allocator, io);

    // Verify outputs match
    try std.testing.expectEqualSlices(u8, &output_seq, &output_par);
}

test "KT256 sequential and parallel produce same output for small inputs" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    // Test with different small input sizes
    const test_sizes = [_]usize{ 100, 1024, 4096, 8192 }; // 100B, 1KB, 4KB, 8KB

    for (test_sizes) |size| {
        const input = try allocator.alloc(u8, size);
        defer allocator.free(input);

        // Fill with random data
        crypto.random.bytes(input);

        var output_seq: [64]u8 = undefined;
        var output_par: [64]u8 = undefined;

        // Hash with sequential method
        try KT256.hash(input, &output_seq, .{});

        // Hash with parallel method
        try KT256.hashParallel(input, &output_par, .{}, allocator, io);

        // Verify outputs match
        try std.testing.expectEqualSlices(u8, &output_seq, &output_par);
    }
}

test "KT256 sequential and parallel produce same output for large inputs" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    // Test with large input sizes that trigger parallel processing
    const test_sizes = [_]usize{ 11 * 1024 * 1024, 20 * 1024 * 1024 }; // 11MB, 20MB

    for (test_sizes) |size| {
        const input = try allocator.alloc(u8, size);
        defer allocator.free(input);

        // Fill with random data
        crypto.random.bytes(input);

        var output_seq: [64]u8 = undefined;
        var output_par: [64]u8 = undefined;

        // Hash with sequential method
        try KT256.hash(input, &output_seq, .{});

        // Hash with parallel method
        try KT256.hashParallel(input, &output_par, .{}, allocator, io);

        // Verify outputs match
        try std.testing.expectEqualSlices(u8, &output_seq, &output_par);
    }
}

test "KT256 sequential and parallel produce same output with customization" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const input_size = 15 * 1024 * 1024; // 15MB
    const input = try allocator.alloc(u8, input_size);
    defer allocator.free(input);

    // Fill with random data
    crypto.random.bytes(input);

    const customization = "test domain";
    var output_seq: [80]u8 = undefined;
    var output_par: [80]u8 = undefined;

    // Hash with sequential method
    try KT256.hash(input, &output_seq, .{ .customization = customization });

    // Hash with parallel method
    try KT256.hashParallel(input, &output_par, .{ .customization = customization }, allocator, io);

    // Verify outputs match
    try std.testing.expectEqualSlices(u8, &output_seq, &output_par);
}

/// Helper: Generate pattern data where data[i] = (i % 251)
fn generatePattern(allocator: Allocator, len: usize) ![]u8 {
    const data = try allocator.alloc(u8, len);
    for (data, 0..) |*byte, i| {
        byte.* = @intCast(i % 251);
    }
    return data;
}

test "KT128: empty message, empty customization, 32 bytes" {
    var output: [32]u8 = undefined;
    try KT128.hash(&[_]u8{}, &output, .{});

    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "1AC2D450FC3B4205D19DA7BFCA1B37513C0803577AC7167F06FE2CE1F0EF39E5");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT128: empty message, empty customization, 64 bytes" {
    var output: [64]u8 = undefined;
    try KT128.hash(&[_]u8{}, &output, .{});

    var expected: [64]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "1AC2D450FC3B4205D19DA7BFCA1B37513C0803577AC7167F06FE2CE1F0EF39E54269C056B8C82E48276038B6D292966CC07A3D4645272E31FF38508139EB0A71");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT128: empty message, empty customization, 10032 bytes (last 32)" {
    const allocator = std.testing.allocator;
    const output = try allocator.alloc(u8, 10032);
    defer allocator.free(output);

    try KT128.hash(&[_]u8{}, output, .{});

    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "E8DC563642F7228C84684C898405D3A834799158C079B12880277A1D28E2FF6D");
    try std.testing.expectEqualSlices(u8, &expected, output[10000..]);
}

test "KT128: pattern message (1 byte), empty customization, 32 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 1);
    defer allocator.free(message);

    var output: [32]u8 = undefined;
    try KT128.hash(message, &output, .{});

    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "2BDA92450E8B147F8A7CB629E784A058EFCA7CF7D8218E02D345DFAA65244A1F");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT128: pattern message (17 bytes), empty customization, 32 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 17);
    defer allocator.free(message);

    var output: [32]u8 = undefined;
    try KT128.hash(message, &output, .{});

    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "6BF75FA2239198DB4772E36478F8E19B0F371205F6A9A93A273F51DF37122888");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT128: pattern message (289 bytes), empty customization, 32 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 289);
    defer allocator.free(message);

    var output: [32]u8 = undefined;
    try KT128.hash(message, &output, .{});

    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "0C315EBCDEDBF61426DE7DCF8FB725D1E74675D7F5327A5067F367B108ECB67C");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT128: 0xFF message (1 byte), pattern customization (1 byte), 32 bytes" {
    const allocator = std.testing.allocator;
    const customization = try generatePattern(allocator, 1);
    defer allocator.free(customization);

    const message = [_]u8{0xFF};
    var output: [32]u8 = undefined;
    try KT128.hash(&message, &output, .{ .customization = customization });

    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "A20B92B251E3D62443EC286E4B9B470A4E8315C156EEB24878B038ABE20650BE");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT128: pattern message (8191 bytes), empty customization, 32 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 8191);
    defer allocator.free(message);

    var output: [32]u8 = undefined;
    try KT128.hash(message, &output, .{});

    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "1B577636F723643E990CC7D6A659837436FD6A103626600EB8301CD1DBE553D6");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT128: pattern message (8192 bytes), empty customization, 32 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 8192);
    defer allocator.free(message);

    var output: [32]u8 = undefined;
    try KT128.hash(message, &output, .{});

    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "48F256F6772F9EDFB6A8B661EC92DC93B95EBD05A08A17B39AE3490870C926C3");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT256: empty message, empty customization, 64 bytes" {
    var output: [64]u8 = undefined;
    try KT256.hash(&[_]u8{}, &output, .{});

    var expected: [64]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "B23D2E9CEA9F4904E02BEC06817FC10CE38CE8E93EF4C89E6537076AF8646404E3E8B68107B8833A5D30490AA33482353FD4ADC7148ECB782855003AAEBDE4A9");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT256: empty message, empty customization, 128 bytes" {
    var output: [128]u8 = undefined;
    try KT256.hash(&[_]u8{}, &output, .{});

    var expected: [128]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "B23D2E9CEA9F4904E02BEC06817FC10CE38CE8E93EF4C89E6537076AF8646404E3E8B68107B8833A5D30490AA33482353FD4ADC7148ECB782855003AAEBDE4A9B0925319D8EA1E121A609821EC19EFEA89E6D08DAEE1662B69C840289F188BA860F55760B61F82114C030C97E5178449608CCD2CD2D919FC7829FF69931AC4D0");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT256: pattern message (1 byte), empty customization, 64 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 1);
    defer allocator.free(message);

    var output: [64]u8 = undefined;
    try KT256.hash(message, &output, .{});

    var expected: [64]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "0D005A194085360217128CF17F91E1F71314EFA5564539D444912E3437EFA17F82DB6F6FFE76E781EAA068BCE01F2BBF81EACB983D7230F2FB02834A21B1DDD0");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT256: pattern message (17 bytes), empty customization, 64 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 17);
    defer allocator.free(message);

    var output: [64]u8 = undefined;
    try KT256.hash(message, &output, .{});

    var expected: [64]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "1BA3C02B1FC514474F06C8979978A9056C8483F4A1B63D0DCCEFE3A28A2F323E1CDCCA40EBF006AC76EF0397152346837B1277D3E7FAA9C9653B19075098527B");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT256: pattern message (8191 bytes), empty customization, 64 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 8191);
    defer allocator.free(message);

    var output: [64]u8 = undefined;
    try KT256.hash(message, &output, .{});

    var expected: [64]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "3081434D93A4108D8D8A3305B89682CEBEDC7CA4EA8A3CE869FBB73CBE4A58EEF6F24DE38FFC170514C70E7AB2D01F03812616E863D769AFB3753193BA045B20");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT256: pattern message (8192 bytes), empty customization, 64 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 8192);
    defer allocator.free(message);

    var output: [64]u8 = undefined;
    try KT256.hash(message, &output, .{});

    var expected: [64]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "C6EE8E2AD3200C018AC87AAA031CDAC22121B412D07DC6E0DCCBB53423747E9A1C18834D99DF596CF0CF4B8DFAFB7BF02D139D0C9035725ADC1A01B7230A41FA");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT128: pattern message (8193 bytes), empty customization, 32 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 8193);
    defer allocator.free(message);

    var output: [32]u8 = undefined;
    try KT128.hash(message, &output, .{});

    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "BB66FE72EAEA5179418D5295EE1344854D8AD7F3FA17EFCB467EC152341284CF");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT128: pattern message (16384 bytes), empty customization, 32 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 16384);
    defer allocator.free(message);

    var output: [32]u8 = undefined;
    try KT128.hash(message, &output, .{});

    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "82778F7F7234C83352E76837B721FBDBB5270B88010D84FA5AB0B61EC8CE0956");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT128: pattern message (16385 bytes), empty customization, 32 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 16385);
    defer allocator.free(message);

    var output: [32]u8 = undefined;
    try KT128.hash(message, &output, .{});

    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "5F8D2B943922B451842B4E82740D02369E2D5F9F33C5123509A53B955FE177B2");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT256: pattern message (8193 bytes), empty customization, 64 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 8193);
    defer allocator.free(message);

    var output: [64]u8 = undefined;
    try KT256.hash(message, &output, .{});

    var expected: [64]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "65FF03335900E5197ACBD5F41B797F0E7E36AD4FF7D89C09FA6F28AE58D1E8BC2DF1779B86F988C3B13690172914EA172423B23EF4057255BB0836AB3A99836E");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT256: pattern message (16384 bytes), empty customization, 64 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 16384);
    defer allocator.free(message);

    var output: [64]u8 = undefined;
    try KT256.hash(message, &output, .{});

    var expected: [64]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "74604239A14847CB79069B4FF0E51070A93034C9AC4DFF4D45E0F2C5DA81D930DE6055C2134B4DF4E49F27D1B2C66E95491858B182A924BD0504DA5976BC516D");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT256: pattern message (16385 bytes), empty customization, 64 bytes" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 16385);
    defer allocator.free(message);

    var output: [64]u8 = undefined;
    try KT256.hash(message, &output, .{});

    var expected: [64]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "C814F23132DADBFD55379F18CB988CB39B751F119322823FD982644A897485397B9F40EB11C6E416359B8AE695A5CE0FA79D1ADA1EEC745D82E0A5AB08A9F014");
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "KT128 incremental: empty message matches one-shot" {
    var output_oneshot: [32]u8 = undefined;
    var output_incremental: [32]u8 = undefined;

    try KT128.hash(&[_]u8{}, &output_oneshot, .{});

    var hasher = KT128.init(.{});
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT128 incremental: small message matches one-shot" {
    const message = "Hello, KangarooTwelve!";

    var output_oneshot: [32]u8 = undefined;
    var output_incremental: [32]u8 = undefined;

    try KT128.hash(message, &output_oneshot, .{});

    var hasher = KT128.init(.{});
    hasher.update(message);
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT128 incremental: multiple updates match single update" {
    const part1 = "Hello, ";
    const part2 = "Kangaroo";
    const part3 = "Twelve!";

    var output_single: [32]u8 = undefined;
    var output_multi: [32]u8 = undefined;

    // Single update
    var hasher1 = KT128.init(.{});
    hasher1.update(part1 ++ part2 ++ part3);
    hasher1.final(&output_single);

    // Multiple updates
    var hasher2 = KT128.init(.{});
    hasher2.update(part1);
    hasher2.update(part2);
    hasher2.update(part3);
    hasher2.final(&output_multi);

    try std.testing.expectEqualSlices(u8, &output_single, &output_multi);
}

test "KT128 incremental: exactly chunk_size matches one-shot" {
    const allocator = std.testing.allocator;
    const message = try allocator.alloc(u8, 8192);
    defer allocator.free(message);
    @memset(message, 0xAB);

    var output_oneshot: [32]u8 = undefined;
    var output_incremental: [32]u8 = undefined;

    try KT128.hash(message, &output_oneshot, .{});

    var hasher = KT128.init(.{});
    hasher.update(message);
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT128 incremental: larger than chunk_size matches one-shot" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 16384);
    defer allocator.free(message);

    var output_oneshot: [32]u8 = undefined;
    var output_incremental: [32]u8 = undefined;

    try KT128.hash(message, &output_oneshot, .{});

    var hasher = KT128.init(.{});
    hasher.update(message);
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT128 incremental: with customization matches one-shot" {
    const message = "Test message";
    const customization = "my custom domain";

    var output_oneshot: [32]u8 = undefined;
    var output_incremental: [32]u8 = undefined;

    try KT128.hash(message, &output_oneshot, .{ .customization = customization });

    var hasher = KT128.init(.{ .customization = customization });
    hasher.update(message);
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT128 incremental: large message with customization" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 20000);
    defer allocator.free(message);
    const customization = "test domain";

    var output_oneshot: [48]u8 = undefined;
    var output_incremental: [48]u8 = undefined;

    try KT128.hash(message, &output_oneshot, .{ .customization = customization });

    var hasher = KT128.init(.{ .customization = customization });
    hasher.update(message);
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT128 incremental: streaming chunks matches one-shot" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 25000);
    defer allocator.free(message);

    var output_oneshot: [32]u8 = undefined;
    var output_incremental: [32]u8 = undefined;

    try KT128.hash(message, &output_oneshot, .{});

    var hasher = KT128.init(.{});

    // Feed in 1KB chunks
    var offset: usize = 0;
    while (offset < message.len) {
        const chunk_size_local = @min(1024, message.len - offset);
        hasher.update(message[offset..][0..chunk_size_local]);
        offset += chunk_size_local;
    }
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT256 incremental: empty message matches one-shot" {
    var output_oneshot: [64]u8 = undefined;
    var output_incremental: [64]u8 = undefined;

    try KT256.hash(&[_]u8{}, &output_oneshot, .{});

    var hasher = KT256.init(.{});
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT256 incremental: small message matches one-shot" {
    const message = "Hello, KangarooTwelve with 256-bit security!";

    var output_oneshot: [64]u8 = undefined;
    var output_incremental: [64]u8 = undefined;

    try KT256.hash(message, &output_oneshot, .{});

    var hasher = KT256.init(.{});
    hasher.update(message);
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT256 incremental: large message matches one-shot" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 30000);
    defer allocator.free(message);

    var output_oneshot: [64]u8 = undefined;
    var output_incremental: [64]u8 = undefined;

    try KT256.hash(message, &output_oneshot, .{});

    var hasher = KT256.init(.{});
    hasher.update(message);
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT256 incremental: with customization matches one-shot" {
    const allocator = std.testing.allocator;
    const message = try generatePattern(allocator, 15000);
    defer allocator.free(message);
    const customization = "KT256 custom domain";

    var output_oneshot: [80]u8 = undefined;
    var output_incremental: [80]u8 = undefined;

    try KT256.hash(message, &output_oneshot, .{ .customization = customization });

    var hasher = KT256.init(.{ .customization = customization });
    hasher.update(message);
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT128 incremental: random small message with random chunk sizes" {
    const allocator = std.testing.allocator;

    const test_sizes = [_]usize{ 100, 500, 2000, 5000, 10000 };

    for (test_sizes) |total_size| {
        const message = try allocator.alloc(u8, total_size);
        defer allocator.free(message);
        crypto.random.bytes(message);

        var output_oneshot: [32]u8 = undefined;
        var output_incremental: [32]u8 = undefined;

        try KT128.hash(message, &output_oneshot, .{});

        var hasher = KT128.init(.{});
        var offset: usize = 0;

        while (offset < message.len) {
            const remaining = message.len - offset;
            const max_chunk = @min(1000, remaining);
            const chunk_size_local = if (max_chunk == 1) 1 else crypto.random.intRangeAtMost(usize, 1, max_chunk);

            hasher.update(message[offset..][0..chunk_size_local]);
            offset += chunk_size_local;
        }
        hasher.final(&output_incremental);

        try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
    }
}

test "KT128 incremental: random large message (1MB) with random chunk sizes" {
    const allocator = std.testing.allocator;

    const total_size: usize = 1024 * 1024; // 1 MB
    const message = try allocator.alloc(u8, total_size);
    defer allocator.free(message);
    crypto.random.bytes(message);

    var output_oneshot: [32]u8 = undefined;
    var output_incremental: [32]u8 = undefined;

    try KT128.hash(message, &output_oneshot, .{});

    var hasher = KT128.init(.{});
    var offset: usize = 0;

    while (offset < message.len) {
        const remaining = message.len - offset;
        const max_chunk = @min(10000, remaining);
        const chunk_size_local = if (max_chunk == 1) 1 else crypto.random.intRangeAtMost(usize, 1, max_chunk);

        hasher.update(message[offset..][0..chunk_size_local]);
        offset += chunk_size_local;
    }
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT256 incremental: random small message with random chunk sizes" {
    const allocator = std.testing.allocator;

    const test_sizes = [_]usize{ 100, 500, 2000, 5000, 10000 };

    for (test_sizes) |total_size| {
        // Generate random message
        const message = try allocator.alloc(u8, total_size);
        defer allocator.free(message);
        crypto.random.bytes(message);

        var output_oneshot: [64]u8 = undefined;
        var output_incremental: [64]u8 = undefined;

        try KT256.hash(message, &output_oneshot, .{});

        var hasher = KT256.init(.{});
        var offset: usize = 0;

        while (offset < message.len) {
            const remaining = message.len - offset;
            const max_chunk = @min(1000, remaining);
            const chunk_size_local = if (max_chunk == 1) 1 else crypto.random.intRangeAtMost(usize, 1, max_chunk);

            hasher.update(message[offset..][0..chunk_size_local]);
            offset += chunk_size_local;
        }
        hasher.final(&output_incremental);

        try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
    }
}

test "KT256 incremental: random large message (1MB) with random chunk sizes" {
    const allocator = std.testing.allocator;

    const total_size: usize = 1024 * 1024; // 1 MB
    const message = try allocator.alloc(u8, total_size);
    defer allocator.free(message);
    crypto.random.bytes(message);

    var output_oneshot: [64]u8 = undefined;
    var output_incremental: [64]u8 = undefined;

    try KT256.hash(message, &output_oneshot, .{});

    var hasher = KT256.init(.{});
    var offset: usize = 0;

    while (offset < message.len) {
        const remaining = message.len - offset;
        const max_chunk = @min(10000, remaining);
        const chunk_size_local = if (max_chunk == 1) 1 else crypto.random.intRangeAtMost(usize, 1, max_chunk);

        hasher.update(message[offset..][0..chunk_size_local]);
        offset += chunk_size_local;
    }
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

test "KT128 incremental: random message with customization and random chunks" {
    const allocator = std.testing.allocator;

    const total_size: usize = 50000;
    const message = try allocator.alloc(u8, total_size);
    defer allocator.free(message);
    crypto.random.bytes(message);

    const customization = "random test domain";

    var output_oneshot: [48]u8 = undefined;
    var output_incremental: [48]u8 = undefined;

    try KT128.hash(message, &output_oneshot, .{ .customization = customization });

    var hasher = KT128.init(.{ .customization = customization });
    var offset: usize = 0;

    while (offset < message.len) {
        const remaining = message.len - offset;
        const max_chunk = @min(5000, remaining);
        const chunk_size_local = if (max_chunk == 1) 1 else crypto.random.intRangeAtMost(usize, 1, max_chunk);

        hasher.update(message[offset..][0..chunk_size_local]);
        offset += chunk_size_local;
    }
    hasher.final(&output_incremental);

    try std.testing.expectEqualSlices(u8, &output_oneshot, &output_incremental);
}

const std = @import("std");
const assert = std.debug.assert;

const types = @import("../types.zig");
const Table = types.compressed_block.Table;

pub fn decodeFseTable(
    bit_reader: anytype,
    expected_symbol_count: usize,
    max_accuracy_log: u4,
    entries: []Table.Fse,
) !usize {
    const accuracy_log_biased = try bit_reader.readBitsNoEof(u4, 4);
    if (accuracy_log_biased > max_accuracy_log -| 5) return error.MalformedAccuracyLog;
    const accuracy_log = accuracy_log_biased + 5;

    var values: [256]u16 = undefined;
    var value_count: usize = 0;

    const total_probability = @as(u16, 1) << accuracy_log;
    var accumulated_probability: u16 = 0;

    while (accumulated_probability < total_probability) {
        // WARNING: The RFC is poorly worded, and would suggest std.math.log2_int_ceil is correct here,
        //          but power of two (remaining probabilities + 1) need max bits set to 1 more.
        const max_bits = std.math.log2_int(u16, total_probability - accumulated_probability + 1) + 1;
        const small = try bit_reader.readBitsNoEof(u16, max_bits - 1);

        const cutoff = (@as(u16, 1) << max_bits) - 1 - (total_probability - accumulated_probability + 1);

        const value = if (small < cutoff)
            small
        else value: {
            const value_read = small + (try bit_reader.readBitsNoEof(u16, 1) << (max_bits - 1));
            break :value if (value_read < @as(u16, 1) << (max_bits - 1))
                value_read
            else
                value_read - cutoff;
        };

        accumulated_probability += if (value != 0) value - 1 else 1;

        values[value_count] = value;
        value_count += 1;

        if (value == 1) {
            while (true) {
                const repeat_flag = try bit_reader.readBitsNoEof(u2, 2);
                if (repeat_flag + value_count > 256) return error.MalformedFseTable;
                for (0..repeat_flag) |_| {
                    values[value_count] = 1;
                    value_count += 1;
                }
                if (repeat_flag < 3) break;
            }
        }
        if (value_count == 256) break;
    }
    bit_reader.alignToByte();

    if (value_count < 2) return error.MalformedFseTable;
    if (accumulated_probability != total_probability) return error.MalformedFseTable;
    if (value_count > expected_symbol_count) return error.MalformedFseTable;

    const table_size = total_probability;

    try buildFseTable(values[0..value_count], entries[0..table_size]);
    return table_size;
}

fn buildFseTable(values: []const u16, entries: []Table.Fse) !void {
    const total_probability = @as(u16, @intCast(entries.len));
    const accuracy_log = std.math.log2_int(u16, total_probability);
    assert(total_probability <= 1 << 9);

    var less_than_one_count: usize = 0;
    for (values, 0..) |value, i| {
        if (value == 0) {
            entries[entries.len - 1 - less_than_one_count] = Table.Fse{
                .symbol = @as(u8, @intCast(i)),
                .baseline = 0,
                .bits = accuracy_log,
            };
            less_than_one_count += 1;
        }
    }

    var position: usize = 0;
    var temp_states: [1 << 9]u16 = undefined;
    for (values, 0..) |value, symbol| {
        if (value == 0 or value == 1) continue;
        const probability = value - 1;

        const state_share_dividend = std.math.ceilPowerOfTwo(u16, probability) catch
            return error.MalformedFseTable;
        const share_size = @divExact(total_probability, state_share_dividend);
        const double_state_count = state_share_dividend - probability;
        const single_state_count = probability - double_state_count;
        const share_size_log = std.math.log2_int(u16, share_size);

        for (0..probability) |i| {
            temp_states[i] = @as(u16, @intCast(position));
            position += (entries.len >> 1) + (entries.len >> 3) + 3;
            position &= entries.len - 1;
            while (position >= entries.len - less_than_one_count) {
                position += (entries.len >> 1) + (entries.len >> 3) + 3;
                position &= entries.len - 1;
            }
        }
        std.mem.sort(u16, temp_states[0..probability], {}, std.sort.asc(u16));
        for (0..probability) |i| {
            entries[temp_states[i]] = if (i < double_state_count) Table.Fse{
                .symbol = @as(u8, @intCast(symbol)),
                .bits = share_size_log + 1,
                .baseline = single_state_count * share_size + @as(u16, @intCast(i)) * 2 * share_size,
            } else Table.Fse{
                .symbol = @as(u8, @intCast(symbol)),
                .bits = share_size_log,
                .baseline = (@as(u16, @intCast(i)) - double_state_count) * share_size,
            };
        }
    }
}

test buildFseTable {
    const literals_length_default_values = [36]u16{
        5, 4, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 2,
        3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 3, 2, 2, 2, 2, 2,
        0, 0, 0, 0,
    };

    const match_lengths_default_values = [53]u16{
        2, 5, 4, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0,
        0, 0, 0, 0, 0,
    };

    const offset_codes_default_values = [29]u16{
        2, 2, 2, 2, 2, 2, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0,
    };

    var entries: [64]Table.Fse = undefined;
    try buildFseTable(&literals_length_default_values, &entries);
    try std.testing.expectEqualSlices(Table.Fse, types.compressed_block.predefined_literal_fse_table.fse, &entries);

    try buildFseTable(&match_lengths_default_values, &entries);
    try std.testing.expectEqualSlices(Table.Fse, types.compressed_block.predefined_match_fse_table.fse, &entries);

    try buildFseTable(&offset_codes_default_values, entries[0..32]);
    try std.testing.expectEqualSlices(Table.Fse, types.compressed_block.predefined_offset_fse_table.fse, entries[0..32]);
}

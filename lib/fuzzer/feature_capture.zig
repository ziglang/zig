const std = @import("std");

var buffer: [*]u32 = undefined;
var top: usize = 0;
var last_valid_index: usize = 0;

/// Primitive prevention of wasting space in the buffer on duplicite features.
/// TODO: is the size right?
const TableSize = 16 * 4096;
var epoch: u8 = 0;
var table: [TableSize]u8 = [1]u8{0} ** TableSize;

/// Instrumentation inserts call to this with almost-unique values based on the
/// calling context. We don't require any specifics. Fuzzer is trying to
/// maximize number of unique arguments given to this function
pub fn newFeature(f: u32) void {
    const hash = std.hash.uint32(f);
    const entry: *u8 = &table[hash % table.len];
    const new_top = @min(b: {
        @setRuntimeSafety(false); // we will never overflow this
        break :b top + 1;
    }, last_valid_index);

    if (entry.* != epoch) {
        entry.* = epoch;
        buffer[top] = f;
        top = new_top;
    }
}

/// Run before calling the instrumented function
pub fn prepare(b: []u32) void {
    buffer = b.ptr;
    last_valid_index = b.len - 1;
    top = 0;
    if (epoch == 255) {
        // TODO mark unlikely
        @memset(&table, 0);
        epoch = 1;
    } else {
        epoch += 1;
    }
}

/// Get the features after the instrumented function completed
pub fn values() []u32 {
    return buffer[0..top];
}

pub fn is_full() bool {
    return top == last_valid_index;
}

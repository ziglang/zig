//! This file captures features from the running instrumented program. LLVM
//! inserts callbacks (in ../fuzzer.zig) that call into newFeature here.
//!
//! "Feature" is any interesting thing that happened while the program was
//! running. Usually an edge in the CFG was taken or a specific cmp instruction
//! was executed. They are represented as u32s and are usually created by
//! xoring the program counter and other random unique looking values that are
//! available when the feature was hit. We score inputs based on how many
//! unique features they hit.

const std = @import("std");

var buffer: []u32 = undefined;
var top: usize = 0;

// TODO: is the size right? libfuzzer uses 1 << 21. Maybe a bloom filter?
/// Primitive prevention of wasting space in the buffer on duplicate features.
const TableSize = 16 * 4096;
var epoch: u8 = 0;
var table: [TableSize]u8 = @splat(0);

/// Instrumentation inserts call to this with almost-unique values based on the
/// calling context. We don't require any specifics. Fuzzer is trying to
/// maximize number of unique arguments given to this function
pub fn newFeature(f: u32) void {
    const hash = std.hash.uint32(f);
    const entry: *u8 = &table[hash % table.len];

    if (entry.* != epoch and top < buffer.len) {
        entry.* = epoch;
        buffer[top] = f;
        top += 1;
    }
}

/// Run before calling the instrumented function
pub fn prepare(b: []u32) void {
    buffer = b;
    top = 0;
    if (epoch == 255) {
        @branchHint(.cold);
        @memset(&table, 0);
        epoch = 1;
    } else {
        epoch += 1;
    }
}

/// Get the captured features
pub fn values() []u32 {
    return buffer[0..top];
}

pub fn is_full() bool {
    return top == buffer.len;
}

const builtin = @import("builtin");
const std = @import("../std.zig");
const sort = std.sort;
const math = std.math;
const mem = std.mem;

const Range = struct {
    start: usize,
    end: usize,

    fn init(start: usize, end: usize) Range {
        return Range{
            .start = start,
            .end = end,
        };
    }

    fn length(self: Range) usize {
        return self.end - self.start;
    }
};

const Iterator = struct {
    size: usize,
    power_of_two: usize,
    numerator: usize,
    decimal: usize,
    denominator: usize,
    decimal_step: usize,
    numerator_step: usize,

    fn init(size2: usize, min_level: usize) Iterator {
        const power_of_two = math.floorPowerOfTwo(usize, size2);
        const denominator = power_of_two / min_level;
        return Iterator{
            .numerator = 0,
            .decimal = 0,
            .size = size2,
            .power_of_two = power_of_two,
            .denominator = denominator,
            .decimal_step = size2 / denominator,
            .numerator_step = size2 % denominator,
        };
    }

    fn begin(self: *Iterator) void {
        self.numerator = 0;
        self.decimal = 0;
    }

    fn nextRange(self: *Iterator) Range {
        const start = self.decimal;

        self.decimal += self.decimal_step;
        self.numerator += self.numerator_step;
        if (self.numerator >= self.denominator) {
            self.numerator -= self.denominator;
            self.decimal += 1;
        }

        return Range{
            .start = start,
            .end = self.decimal,
        };
    }

    fn finished(self: *Iterator) bool {
        return self.decimal >= self.size;
    }

    fn nextLevel(self: *Iterator) bool {
        self.decimal_step += self.decimal_step;
        self.numerator_step += self.numerator_step;
        if (self.numerator_step >= self.denominator) {
            self.numerator_step -= self.denominator;
            self.decimal_step += 1;
        }

        return (self.decimal_step < self.size);
    }

    fn length(self: *Iterator) usize {
        return self.decimal_step;
    }
};

const Pull = struct {
    from: usize,
    to: usize,
    count: usize,
    range: Range,
};

/// Stable in-place sort. O(n) best case, O(n*log(n)) worst case and average case.
/// O(1) memory (no allocator required).
/// Sorts in ascending order with respect to the given `lessThan` function.
///
/// NOTE: The algorithm only works when the comparison is less-than or greater-than.
///       (See https://github.com/ziglang/zig/issues/8289)
pub fn block(
    comptime T: type,
    items: []T,
    context: anytype,
    comptime lessThanFn: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) void {
    const Context = struct {
        items: []T,
        sub_ctx: @TypeOf(context),

        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return lessThanFn(ctx.sub_ctx, ctx.items[a], ctx.items[b]);
        }

        pub fn swap(ctx: @This(), a: usize, b: usize) void {
            return mem.swap(T, &ctx.items[a], &ctx.items[b]);
        }
    };
    return blockContext(T, items, context, lessThanFn, 0, items.len, Context{ .items = items, .sub_ctx = context });
}

/// Stable in-place sort. O(n) best case, O(n*log(n)) worst case and average case.
/// O(1) memory (no allocator required).
/// Sorts in ascending order with respect to the given `lessThan` function.
/// `context` must have methods `swap` and `lessThan`,
/// which each take 2 `usize` parameters indicating the index of an item.
///
/// NOTE: The algorithm only works when the comparison is less-than or greater-than.
///       (See https://github.com/ziglang/zig/issues/8289)
pub fn blockContext(
    comptime T: type,
    items: []T,
    inner_context: anytype,
    comptime lessThanFn: fn (@TypeOf(inner_context), lhs: T, rhs: T) bool,
    a: usize,
    b: usize,
    context: anytype,
) void {
    // Implementation ported from https://github.com/BonzaiThePenguin/WikiSort/blob/master/WikiSort.c
    const Context = struct {
        sub_ctx: @TypeOf(context),

        pub const lessThan = if (builtin.mode == .Debug) lessThanChecked else lessThanUnchecked;

        fn lessThanChecked(ctx: @This(), i: usize, j: usize) bool {
            const lt = ctx.sub_ctx.lessThan(i, j);
            const gt = ctx.sub_ctx.lessThan(j, i);
            std.debug.assert(!(lt and gt));
            return lt;
        }

        fn lessThanUnchecked(ctx: @This(), i: usize, j: usize) bool {
            return ctx.sub_ctx.lessThan(i, j);
        }

        pub fn swap(ctx: @This(), i: usize, j: usize) void {
            return ctx.sub_ctx.swap(i, j);
        }
    };
    const wrapped_context = Context{ .sub_ctx = context };
    const lessThan = if (builtin.mode == .Debug) struct {
        fn lessThan(ctx: @TypeOf(inner_context), lhs: T, rhs: T) bool {
            const lt = lessThanFn(ctx, lhs, rhs);
            const gt = lessThanFn(ctx, rhs, lhs);
            std.debug.assert(!(lt and gt));
            return lt;
        }
    }.lessThan else lessThanFn;

    const range_length = b - a;

    if (range_length < 4) {
        if (range_length == 3) {
            // hard coded insertion sort
            if (wrapped_context.lessThan(a + 1, a + 0)) wrapped_context.swap(a + 0, a + 1);
            if (wrapped_context.lessThan(a + 2, a + 1)) {
                wrapped_context.swap(a + 1, a + 2);
                if (wrapped_context.lessThan(a + 1, a + 0)) wrapped_context.swap(a + 0, a + 1);
            }
        } else if (range_length == 2) {
            if (wrapped_context.lessThan(a + 1, a + 0)) wrapped_context.swap(a + 0, a + 1);
        }
        return;
    }

    // sort groups of 4-8 items at a time using an unstable sorting network,
    // but keep track of the original item orders to force it to be stable
    // http://pages.ripco.net/~jgamble/nw.html
    var iterator = Iterator.init(range_length, 4);
    while (!iterator.finished()) {
        var order = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7 };
        const range = iterator.nextRange();

        switch (range.length()) {
            8 => {
                swap(&order, a + range.start, 0, 1, wrapped_context);
                swap(&order, a + range.start, 2, 3, wrapped_context);
                swap(&order, a + range.start, 4, 5, wrapped_context);
                swap(&order, a + range.start, 6, 7, wrapped_context);
                swap(&order, a + range.start, 0, 2, wrapped_context);
                swap(&order, a + range.start, 1, 3, wrapped_context);
                swap(&order, a + range.start, 4, 6, wrapped_context);
                swap(&order, a + range.start, 5, 7, wrapped_context);
                swap(&order, a + range.start, 1, 2, wrapped_context);
                swap(&order, a + range.start, 5, 6, wrapped_context);
                swap(&order, a + range.start, 0, 4, wrapped_context);
                swap(&order, a + range.start, 3, 7, wrapped_context);
                swap(&order, a + range.start, 1, 5, wrapped_context);
                swap(&order, a + range.start, 2, 6, wrapped_context);
                swap(&order, a + range.start, 1, 4, wrapped_context);
                swap(&order, a + range.start, 3, 6, wrapped_context);
                swap(&order, a + range.start, 2, 4, wrapped_context);
                swap(&order, a + range.start, 3, 5, wrapped_context);
                swap(&order, a + range.start, 3, 4, wrapped_context);
            },
            7 => {
                swap(&order, a + range.start, 1, 2, wrapped_context);
                swap(&order, a + range.start, 3, 4, wrapped_context);
                swap(&order, a + range.start, 5, 6, wrapped_context);
                swap(&order, a + range.start, 0, 2, wrapped_context);
                swap(&order, a + range.start, 3, 5, wrapped_context);
                swap(&order, a + range.start, 4, 6, wrapped_context);
                swap(&order, a + range.start, 0, 1, wrapped_context);
                swap(&order, a + range.start, 4, 5, wrapped_context);
                swap(&order, a + range.start, 2, 6, wrapped_context);
                swap(&order, a + range.start, 0, 4, wrapped_context);
                swap(&order, a + range.start, 1, 5, wrapped_context);
                swap(&order, a + range.start, 0, 3, wrapped_context);
                swap(&order, a + range.start, 2, 5, wrapped_context);
                swap(&order, a + range.start, 1, 3, wrapped_context);
                swap(&order, a + range.start, 2, 4, wrapped_context);
                swap(&order, a + range.start, 2, 3, wrapped_context);
            },
            6 => {
                swap(&order, a + range.start, 1, 2, wrapped_context);
                swap(&order, a + range.start, 4, 5, wrapped_context);
                swap(&order, a + range.start, 0, 2, wrapped_context);
                swap(&order, a + range.start, 3, 5, wrapped_context);
                swap(&order, a + range.start, 0, 1, wrapped_context);
                swap(&order, a + range.start, 3, 4, wrapped_context);
                swap(&order, a + range.start, 2, 5, wrapped_context);
                swap(&order, a + range.start, 0, 3, wrapped_context);
                swap(&order, a + range.start, 1, 4, wrapped_context);
                swap(&order, a + range.start, 2, 4, wrapped_context);
                swap(&order, a + range.start, 1, 3, wrapped_context);
                swap(&order, a + range.start, 2, 3, wrapped_context);
            },
            5 => {
                swap(&order, a + range.start, 0, 1, wrapped_context);
                swap(&order, a + range.start, 3, 4, wrapped_context);
                swap(&order, a + range.start, 2, 4, wrapped_context);
                swap(&order, a + range.start, 2, 3, wrapped_context);
                swap(&order, a + range.start, 1, 4, wrapped_context);
                swap(&order, a + range.start, 0, 3, wrapped_context);
                swap(&order, a + range.start, 0, 2, wrapped_context);
                swap(&order, a + range.start, 1, 3, wrapped_context);
                swap(&order, a + range.start, 1, 2, wrapped_context);
            },
            4 => {
                swap(&order, a + range.start, 0, 1, wrapped_context);
                swap(&order, a + range.start, 2, 3, wrapped_context);
                swap(&order, a + range.start, 0, 2, wrapped_context);
                swap(&order, a + range.start, 1, 3, wrapped_context);
                swap(&order, a + range.start, 1, 2, wrapped_context);
            },
            else => {},
        }
    }
    if (range_length < 8) return;

    // then merge sort the higher levels, which can be 8-15, 16-31, 32-63, 64-127, etc.
    while (true) {
        // this is where the in-place merge logic starts!
        // 1. pull out two internal buffers each containing √A unique values
        //    1a. adjust block_size and buffer_size if we couldn't find enough unique values
        // 2. loop over the A and B subarrays within this level of the merge sort
        // 3. break A and B into blocks of size 'block_size'
        // 4. "tag" each of the A blocks with values from the first internal buffer
        // 5. roll the A blocks through the B blocks and drop/rotate them where they belong
        // 6. merge each A block with any B values that follow, using the second internal buffer
        // 7. sort the second internal buffer if it exists
        // 8. redistribute the two internal buffers back into the items
        var block_size: usize = math.sqrt(iterator.length());
        var buffer_size = iterator.length() / block_size + 1;

        // as an optimization, we really only need to pull out the internal buffers once for each level of merges
        // after that we can reuse the same buffers over and over, then redistribute it when we're finished with this level
        var A: Range = undefined;
        var B: Range = undefined;
        var index: usize = 0;
        var last: usize = 0;
        var count: usize = 0;
        var find: usize = 0;
        var start: usize = 0;
        var pull_index: usize = 0;
        var pull = [_]Pull{
            Pull{
                .from = 0,
                .to = 0,
                .count = 0,
                .range = Range.init(0, 0),
            },
            Pull{
                .from = 0,
                .to = 0,
                .count = 0,
                .range = Range.init(0, 0),
            },
        };

        var buffer1 = Range.init(0, 0);
        var buffer2 = Range.init(0, 0);

        // find two internal buffers of size 'buffer_size' each
        find = buffer_size + buffer_size;
        var find_separately = false;

        if (find > iterator.length()) {
            // we can't fit both buffers into the same A or B subarray, so find two buffers separately
            find = buffer_size;
            find_separately = true;
        }

        // we need to find either a single contiguous space containing 2√A unique values (which will be split up into two buffers of size √A each),
        // or we need to find one buffer of < 2√A unique values, and a second buffer of √A unique values,
        // OR if we couldn't find that many unique values, we need the largest possible buffer we can get

        // in the case where it couldn't find a single buffer of at least √A unique values,
        // all of the Merge steps must be replaced by a different merge algorithm (MergeInPlace)
        iterator.begin();
        while (!iterator.finished()) {
            A = iterator.nextRange();
            B = iterator.nextRange();

            // just store information about where the values will be pulled from and to,
            // as well as how many values there are, to create the two internal buffers

            // check A for the number of unique values we need to fill an internal buffer
            // these values will be pulled out to the start of A
            last = A.start;
            count = 1;
            while (count < find) : ({
                last = index;
                count += 1;
            }) {
                index = findLastForward(T, items, last, items[last], Range.init(last + 1, A.end), find - count, inner_context, lessThan, a, wrapped_context);
                if (index == A.end) break;
            }
            index = last;

            if (count >= buffer_size) {
                // keep track of the range within the items where we'll need to "pull out" these values to create the internal buffer
                pull[pull_index] = Pull{
                    .range = Range.init(A.start, B.end),
                    .count = count,
                    .from = index,
                    .to = A.start,
                };
                pull_index = 1;

                if (count == buffer_size + buffer_size) {
                    // we were able to find a single contiguous section containing 2√A unique values,
                    // so this section can be used to contain both of the internal buffers we'll need
                    buffer1 = Range.init(A.start, A.start + buffer_size);
                    buffer2 = Range.init(A.start + buffer_size, A.start + count);
                    break;
                } else if (find == buffer_size + buffer_size) {
                    // we found a buffer that contains at least √A unique values, but did not contain the full 2√A unique values,
                    // so we still need to find a second separate buffer of at least √A unique values
                    buffer1 = Range.init(A.start, A.start + count);
                    find = buffer_size;
                } else if (find_separately) {
                    // found one buffer, but now find the other one
                    buffer1 = Range.init(A.start, A.start + count);
                    find_separately = false;
                } else {
                    // we found a second buffer in an 'A' subarray containing √A unique values, so we're done!
                    buffer2 = Range.init(A.start, A.start + count);
                    break;
                }
            } else if (pull_index == 0 and count > buffer1.length()) {
                // keep track of the largest buffer we were able to find
                buffer1 = Range.init(A.start, A.start + count);
                pull[pull_index] = Pull{
                    .range = Range.init(A.start, B.end),
                    .count = count,
                    .from = index,
                    .to = A.start,
                };
            }

            // check B for the number of unique values we need to fill an internal buffer
            // these values will be pulled out to the end of B
            last = B.end - 1;
            count = 1;
            while (count < find) : ({
                last = index - 1;
                count += 1;
            }) {
                index = findFirstBackward(T, items, last, items[last], Range.init(B.start, last), find - count, inner_context, lessThan, a, wrapped_context);
                if (index == B.start) break;
            }
            index = last;

            if (count >= buffer_size) {
                // keep track of the range within the items where we'll need to "pull out" these values to create the internal buffe
                pull[pull_index] = Pull{
                    .range = Range.init(A.start, B.end),
                    .count = count,
                    .from = index,
                    .to = B.end,
                };
                pull_index = 1;

                if (count == buffer_size + buffer_size) {
                    // we were able to find a single contiguous section containing 2√A unique values,
                    // so this section can be used to contain both of the internal buffers we'll need
                    buffer1 = Range.init(B.end - count, B.end - buffer_size);
                    buffer2 = Range.init(B.end - buffer_size, B.end);
                    break;
                } else if (find == buffer_size + buffer_size) {
                    // we found a buffer that contains at least √A unique values, but did not contain the full 2√A unique values,
                    // so we still need to find a second separate buffer of at least √A unique values
                    buffer1 = Range.init(B.end - count, B.end);
                    find = buffer_size;
                } else if (find_separately) {
                    // found one buffer, but now find the other one
                    buffer1 = Range.init(B.end - count, B.end);
                    find_separately = false;
                } else {
                    // buffer2 will be pulled out from a 'B' subarray, so if the first buffer was pulled out from the corresponding 'A' subarray,
                    // we need to adjust the end point for that A subarray so it knows to stop redistributing its values before reaching buffer2
                    if (pull[0].range.start == A.start) pull[0].range.end -= pull[1].count;

                    // we found a second buffer in an 'B' subarray containing √A unique values, so we're done!
                    buffer2 = Range.init(B.end - count, B.end);
                    break;
                }
            } else if (pull_index == 0 and count > buffer1.length()) {
                // keep track of the largest buffer we were able to find
                buffer1 = Range.init(B.end - count, B.end);
                pull[pull_index] = Pull{
                    .range = Range.init(A.start, B.end),
                    .count = count,
                    .from = index,
                    .to = B.end,
                };
            }
        }

        // pull out the two ranges so we can use them as internal buffers
        pull_index = 0;
        while (pull_index < 2) : (pull_index += 1) {
            const length = pull[pull_index].count;

            if (pull[pull_index].to < pull[pull_index].from) {
                // we're pulling the values out to the left, which means the start of an A subarray
                index = pull[pull_index].from;
                count = 1;
                while (count < length) : (count += 1) {
                    index = findFirstBackward(T, items, index - 1, items[index - 1], Range.init(pull[pull_index].to, pull[pull_index].from - (count - 1)), length - count, inner_context, lessThan, a, wrapped_context);
                    const range = Range.init(index + 1, pull[pull_index].from + 1);
                    mem.rotate(T, items[range.start..range.end], range.length() - count);
                    pull[pull_index].from = index + count;
                }
            } else if (pull[pull_index].to > pull[pull_index].from) {
                // we're pulling values out to the right, which means the end of a B subarray
                index = pull[pull_index].from + 1;
                count = 1;
                while (count < length) : (count += 1) {
                    index = findLastForward(T, items, index, items[index], Range.init(index, pull[pull_index].to), length - count, inner_context, lessThan, a, wrapped_context);
                    const range = Range.init(pull[pull_index].from, index - 1);
                    mem.rotate(T, items[range.start..range.end], count);
                    pull[pull_index].from = index - 1 - count;
                }
            }
        }

        // adjust block_size and buffer_size based on the values we were able to pull out
        buffer_size = buffer1.length();
        block_size = iterator.length() / buffer_size + 1;

        // the first buffer NEEDS to be large enough to tag each of the evenly sized A blocks,
        // so this was originally here to test the math for adjusting block_size above
        // assert((iterator.length() + 1)/block_size <= buffer_size);

        // now that the two internal buffers have been created, it's time to merge each A+B combination at this level of the merge sort!
        iterator.begin();
        while (!iterator.finished()) {
            A = iterator.nextRange();
            B = iterator.nextRange();

            // remove any parts of A or B that are being used by the internal buffers
            start = A.start;
            if (start == pull[0].range.start) {
                if (pull[0].from > pull[0].to) {
                    A.start += pull[0].count;

                    // if the internal buffer takes up the entire A or B subarray, then there's nothing to merge
                    // this only happens for very small subarrays, like √4 = 2, 2 * (2 internal buffers) = 4
                    if (A.length() == 0) continue;
                } else if (pull[0].from < pull[0].to) {
                    B.end -= pull[0].count;
                    if (B.length() == 0) continue;
                }
            }
            if (start == pull[1].range.start) {
                if (pull[1].from > pull[1].to) {
                    A.start += pull[1].count;
                    if (A.length() == 0) continue;
                } else if (pull[1].from < pull[1].to) {
                    B.end -= pull[1].count;
                    if (B.length() == 0) continue;
                }
            }

            if (lessThan(inner_context, items[B.end - 1], items[A.start])) {
                // the two ranges are in reverse order, so a simple rotation should fix it
                mem.rotate(T, items[A.start..B.end], A.length());
            } else if (lessThan(inner_context, items[A.end], items[A.end - 1])) {
                // these two ranges weren't already in order, so we'll need to merge them!
                var findA: usize = undefined;

                // break the remainder of A into blocks. firstA is the uneven-sized first A block
                var blockA = Range.init(A.start, A.end);
                var firstA = Range.init(A.start, A.start + blockA.length() % block_size);

                // swap the first value of each A block with the value in buffer1
                var indexA = buffer1.start;
                index = firstA.end;
                while (index < blockA.end) : ({
                    indexA += 1;
                    index += block_size;
                }) {
                    mem.swap(T, &items[indexA], &items[index]);
                }

                // start rolling the A blocks through the B blocks!
                // whenever we leave an A block behind, we'll need to merge the previous A block with any B blocks that follow it, so track that information as well
                var lastA = firstA;
                var lastB = Range.init(0, 0);
                var blockB = Range.init(B.start, B.start + @min(block_size, B.length()));
                blockA.start += firstA.length();
                indexA = buffer1.start;

                // if the second buffer is available, block swap the contents into that
                if (buffer2.length() > 0) {
                    blockSwap(lastA.start, buffer2.start, lastA.length(), wrapped_context);
                }

                if (blockA.length() > 0) {
                    while (true) {
                        // if there's a previous B block and the first value of the minimum A block is <= the last value of the previous B block,
                        // then drop that minimum A block behind. or if there are no B blocks left then keep dropping the remaining A blocks.
                        if ((lastB.length() > 0 and !lessThan(inner_context, items[lastB.end - 1], items[indexA])) or blockB.length() == 0) {
                            // figure out where to split the previous B block, and rotate it at the split
                            const B_split = binaryFirst(T, items, items[indexA], lastB, inner_context, lessThan);
                            const B_remaining = lastB.end - B_split;

                            // swap the minimum A block to the beginning of the rolling A blocks
                            var minA = blockA.start;
                            findA = minA + block_size;
                            while (findA < blockA.end) : (findA += block_size) {
                                if (lessThan(inner_context, items[findA], items[minA])) {
                                    minA = findA;
                                }
                            }
                            blockSwap(blockA.start, minA, block_size, wrapped_context);

                            // swap the first item of the previous A block back with its original value, which is stored in buffer1
                            mem.swap(T, &items[blockA.start], &items[indexA]);
                            indexA += 1;

                            // locally merge the previous A block with the B values that follow it
                            // if lastA fits into the second internal buffer exists we'll use that (with MergeInternal),
                            // or failing that we'll use a strictly in-place merge algorithm (MergeInPlace)

                            if (buffer2.length() > 0) {
                                mergeInternal(T, items, lastA, Range.init(lastA.end, B_split), buffer2, inner_context, lessThan, wrapped_context);
                            } else {
                                mergeInPlace(T, items, lastA, Range.init(lastA.end, B_split), inner_context, lessThan);
                            }

                            if (buffer2.length() > 0) {
                                // copy the previous A block into the buffer2, since that's where we need it to be when we go to merge it anyway
                                blockSwap(blockA.start, buffer2.start, block_size, wrapped_context);

                                // this is equivalent to rotating, but faster
                                // the area normally taken up by the A block is either the contents of buffer2, or data we don't need anymore since we memcopied it
                                // either way, we don't need to retain the order of those items, so instead of rotating we can just block swap B to where it belongs
                                blockSwap(B_split, blockA.start + block_size - B_remaining, B_remaining, wrapped_context);
                            } else {
                                // we are unable to use the 'buffer2' trick to speed up the rotation operation since buffer2 doesn't exist, so perform a normal rotation
                                mem.rotate(T, items[B_split .. blockA.start + block_size], blockA.start - B_split);
                            }

                            // update the range for the remaining A blocks, and the range remaining from the B block after it was split
                            lastA = Range.init(blockA.start - B_remaining, blockA.start - B_remaining + block_size);
                            lastB = Range.init(lastA.end, lastA.end + B_remaining);

                            // if there are no more A blocks remaining, this step is finished!
                            blockA.start += block_size;
                            if (blockA.length() == 0) break;
                        } else if (blockB.length() < block_size) {
                            // move the last B block, which is unevenly sized, to before the remaining A blocks, by using a rotation
                            mem.rotate(T, items[blockA.start..blockB.end], blockB.start - blockA.start);

                            lastB = Range.init(blockA.start, blockA.start + blockB.length());
                            blockA.start += blockB.length();
                            blockA.end += blockB.length();
                            blockB.end = blockB.start;
                        } else {
                            // roll the leftmost A block to the end by swapping it with the next B block
                            blockSwap(blockA.start, blockB.start, block_size, wrapped_context);
                            lastB = Range.init(blockA.start, blockA.start + block_size);

                            blockA.start += block_size;
                            blockA.end += block_size;
                            blockB.start += block_size;

                            if (blockB.end > B.end - block_size) {
                                blockB.end = B.end;
                            } else {
                                blockB.end += block_size;
                            }
                        }
                    }
                }

                // merge the last A block with the remaining B values
                if (buffer2.length() > 0) {
                    mergeInternal(T, items, lastA, Range.init(lastA.end, B.end), buffer2, inner_context, lessThan, wrapped_context);
                } else {
                    mergeInPlace(T, items, lastA, Range.init(lastA.end, B.end), inner_context, lessThan);
                }
            }
        }

        // when we're finished with this merge step we should have the one
        // or two internal buffers left over, where the second buffer is all jumbled up
        // insertion sort the second buffer, then redistribute the buffers
        // back into the items using the opposite process used for creating the buffer

        // while an unstable sort like quicksort could be applied here, in benchmarks
        // it was consistently slightly slower than a simple insertion sort,
        // even for tens of millions of items. this may be because insertion
        // sort is quite fast when the data is already somewhat sorted, like it is here
        sort.insertion(T, items[buffer2.start..buffer2.end], inner_context, lessThan);

        pull_index = 0;
        while (pull_index < 2) : (pull_index += 1) {
            var unique = pull[pull_index].count * 2;
            if (pull[pull_index].from > pull[pull_index].to) {
                // the values were pulled out to the left, so redistribute them back to the right
                var buffer = Range.init(pull[pull_index].range.start, pull[pull_index].range.start + pull[pull_index].count);
                while (buffer.length() > 0) {
                    index = findFirstForward(T, items, buffer.start, items[buffer.start], Range.init(buffer.end, pull[pull_index].range.end), unique, inner_context, lessThan, a, wrapped_context);
                    const amount = index - buffer.end;
                    mem.rotate(T, items[buffer.start..index], buffer.length());
                    buffer.start += (amount + 1);
                    buffer.end += amount;
                    unique -= 2;
                }
            } else if (pull[pull_index].from < pull[pull_index].to) {
                // the values were pulled out to the right, so redistribute them back to the left
                var buffer = Range.init(pull[pull_index].range.end - pull[pull_index].count, pull[pull_index].range.end);
                while (buffer.length() > 0) {
                    index = findLastBackward(T, items, items[buffer.end - 1], Range.init(pull[pull_index].range.start, buffer.start), unique, inner_context, lessThan);
                    const amount = buffer.start - index;
                    mem.rotate(T, items[index..buffer.end], amount);
                    buffer.start -= amount;
                    buffer.end -= (amount + 1);
                    unique -= 2;
                }
            }
        }

        // double the size of each A and B subarray that will be merged in the next level
        if (!iterator.nextLevel()) break;
    }
}
// merge operation without a buffer
fn mergeInPlace(
    comptime T: type,
    items: []T,
    A_arg: Range,
    B_arg: Range,
    context: anytype,
    comptime lessThan: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) void {
    if (A_arg.length() == 0 or B_arg.length() == 0) return;

    // this just repeatedly binary searches into B and rotates A into position.
    // the paper suggests using the 'rotation-based Hwang and Lin algorithm' here,
    // but I decided to stick with this because it had better situational performance
    //
    // (Hwang and Lin is designed for merging subarrays of very different sizes,
    // but WikiSort almost always uses subarrays that are roughly the same size)
    //
    // normally this is incredibly suboptimal, but this function is only called
    // when none of the A or B blocks in any subarray contained 2√A unique values,
    // which places a hard limit on the number of times this will ACTUALLY need
    // to binary search and rotate.
    //
    // according to my analysis the worst case is √A rotations performed on √A items
    // once the constant factors are removed, which ends up being O(n)
    //
    // again, this is NOT a general-purpose solution – it only works well in this case!
    // kind of like how the O(n^2) insertion sort is used in some places

    var A = A_arg;
    var B = B_arg;

    while (true) {
        // find the first place in B where the first item in A needs to be inserted
        const mid = binaryFirst(T, items, items[A.start], B, context, lessThan);

        // rotate A into place
        const amount = mid - A.end;
        mem.rotate(T, items[A.start..mid], A.length());
        if (B.end == mid) break;

        // calculate the new A and B ranges
        B.start = mid;
        A = Range.init(A.start + amount, B.start);
        A.start = binaryLast(T, items, items[A.start], A, context, lessThan);
        if (A.length() == 0) break;
    }
}

// merge operation using an internal buffer
fn mergeInternal(
    comptime T: type,
    items: []T,
    A: Range,
    B: Range,
    buffer: Range,
    context: anytype,
    comptime lessThan: fn (@TypeOf(context), lhs: T, rhs: T) bool,
    wrapped_context: anytype,
) void {
    // whenever we find a value to add to the final array, swap it with the value that's already in that spot
    // when this algorithm is finished, 'buffer' will contain its original contents, but in a different order
    var A_count: usize = 0;
    var B_count: usize = 0;
    var insert: usize = 0;

    if (B.length() > 0 and A.length() > 0) {
        while (true) {
            if (!lessThan(context, items[B.start + B_count], items[buffer.start + A_count])) {
                mem.swap(T, &items[A.start + insert], &items[buffer.start + A_count]);
                A_count += 1;
                insert += 1;
                if (A_count >= A.length()) break;
            } else {
                mem.swap(T, &items[A.start + insert], &items[B.start + B_count]);
                B_count += 1;
                insert += 1;
                if (B_count >= B.length()) break;
            }
        }
    }

    // swap the remainder of A into the final array
    blockSwap(buffer.start + A_count, A.start + insert, A.length() - A_count, wrapped_context);
}

fn blockSwap(start1: usize, start2: usize, block_size: usize, context: anytype) void {
    var index: usize = 0;
    while (index < block_size) : (index += 1) {
        context.swap(start1 + index, start2 + index);
    }
}

// combine a linear search with a binary search to reduce the number of comparisons in situations
// where have some idea as to how many unique values there are and where the next value might be
fn findFirstForward(
    comptime T: type,
    items: []T,
    value_index: usize,
    value: T,
    range: Range,
    unique: usize,
    context: anytype,
    comptime lessThan: fn (@TypeOf(context), lhs: T, rhs: T) bool,
    start_index: usize,
    wrapped_context: anytype,
) usize {
    const skip = @max(range.length() / unique, @as(usize, 1));

    var index = range.start + skip;
    while (wrapped_context.lessThan(start_index + index - 1, start_index + value_index)) : (index += skip) {
        if (index >= range.end - skip) {
            return binaryFirst(T, items, value, Range.init(index, range.end), context, lessThan);
        }
    }

    return binaryFirst(T, items, value, Range.init(index - skip, index), context, lessThan);
}

fn findFirstBackward(
    comptime T: type,
    items: []T,
    value_index: usize,
    value: T,
    range: Range,
    unique: usize,
    context: anytype,
    comptime lessThan: fn (@TypeOf(context), lhs: T, rhs: T) bool,
    start_index: usize,
    wrapped_context: anytype,
) usize {
    if (range.length() == 0) return range.start;
    const skip = @max(range.length() / unique, @as(usize, 1));

    var index = range.end - skip;
    while (index > range.start and !wrapped_context.lessThan(start_index + index - 1, start_index + value_index)) : (index -= skip) {
        if (index < range.start + skip) {
            return binaryFirst(T, items, value, Range.init(range.start, index), context, lessThan);
        }
    }

    return binaryFirst(T, items, value, Range.init(index, index + skip), context, lessThan);
}

fn findLastForward(
    comptime T: type,
    items: []T,
    value_index: usize,
    value: T,
    range: Range,
    unique: usize,
    context: anytype,
    comptime lessThan: fn (@TypeOf(context), lhs: T, rhs: T) bool,
    start_index: usize,
    wrapped_context: anytype,
) usize {
    if (range.length() == 0) return range.start;
    const skip = @max(range.length() / unique, @as(usize, 1));

    var index = range.start + skip;
    while (!wrapped_context.lessThan(start_index + value_index, start_index + index - 1)) : (index += skip) {
        if (index >= range.end - skip) {
            return binaryLast(T, items, value, Range.init(index, range.end), context, lessThan);
        }
    }

    return binaryLast(T, items, value, Range.init(index - skip, index), context, lessThan);
}

fn findLastBackward(
    comptime T: type,
    items: []T,
    value: T,
    range: Range,
    unique: usize,
    context: anytype,
    comptime lessThan: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) usize {
    if (range.length() == 0) return range.start;
    const skip = @max(range.length() / unique, @as(usize, 1));

    var index = range.end - skip;
    while (index > range.start and lessThan(context, value, items[index - 1])) : (index -= skip) {
        if (index < range.start + skip) {
            return binaryLast(T, items, value, Range.init(range.start, index), context, lessThan);
        }
    }

    return binaryLast(T, items, value, Range.init(index, index + skip), context, lessThan);
}

fn binaryFirst(
    comptime T: type,
    items: []T,
    value: T,
    range: Range,
    context: anytype,
    comptime lessThan: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) usize {
    var curr = range.start;
    var size = range.length();
    if (range.start >= range.end) return range.end;
    while (size > 0) {
        const offset = size % 2;

        size /= 2;
        const mid_item = items[curr + size];
        if (lessThan(context, mid_item, value)) {
            curr += size + offset;
        }
    }
    return curr;
}

fn binaryLast(
    comptime T: type,
    items: []T,
    value: T,
    range: Range,
    context: anytype,
    comptime lessThan: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) usize {
    var curr = range.start;
    var size = range.length();
    if (range.start >= range.end) return range.end;
    while (size > 0) {
        const offset = size % 2;

        size /= 2;
        const mid_item = items[curr + size];
        if (!lessThan(context, value, mid_item)) {
            curr += size + offset;
        }
    }
    return curr;
}

fn swap(
    order: *[8]u8,
    start_index: usize,
    x: usize,
    y: usize,
    context: anytype,
) void {
    if (context.lessThan(start_index + y, start_index + x) or ((order.*)[x] > (order.*)[y] and !context.lessThan(start_index + x, start_index + y))) {
        context.swap(start_index + x, start_index + y);
        mem.swap(u8, &(order.*)[x], &(order.*)[y]);
    }
}

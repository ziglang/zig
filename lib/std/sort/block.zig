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
/// NOTE: the algorithm only work when the comparison is less-than or greater-than
///       (See https://github.com/ziglang/zig/issues/8289)
pub fn block(
    comptime T: type,
    items: []T,
    context: anytype,
    comptime lessThanFn: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) void {
    const lessThan = if (builtin.mode == .Debug) struct {
        fn lessThan(ctx: @TypeOf(context), lhs: T, rhs: T) bool {
            const lt = lessThanFn(ctx, lhs, rhs);
            const gt = lessThanFn(ctx, rhs, lhs);
            std.debug.assert(!(lt and gt));
            return lt;
        }
    }.lessThan else lessThanFn;

    // Implementation ported from https://github.com/BonzaiThePenguin/WikiSort/blob/master/WikiSort.c
    var cache: [512]T = undefined;

    if (items.len < 4) {
        if (items.len == 3) {
            // hard coded insertion sort
            if (lessThan(context, items[1], items[0])) mem.swap(T, &items[0], &items[1]);
            if (lessThan(context, items[2], items[1])) {
                mem.swap(T, &items[1], &items[2]);
                if (lessThan(context, items[1], items[0])) mem.swap(T, &items[0], &items[1]);
            }
        } else if (items.len == 2) {
            if (lessThan(context, items[1], items[0])) mem.swap(T, &items[0], &items[1]);
        }
        return;
    }

    // sort groups of 4-8 items at a time using an unstable sorting network,
    // but keep track of the original item orders to force it to be stable
    // http://pages.ripco.net/~jgamble/nw.html
    var iterator = Iterator.init(items.len, 4);
    while (!iterator.finished()) {
        var order = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7 };
        const range = iterator.nextRange();

        const sliced_items = items[range.start..];
        switch (range.length()) {
            8 => {
                swap(T, sliced_items, &order, 0, 1, context, lessThan);
                swap(T, sliced_items, &order, 2, 3, context, lessThan);
                swap(T, sliced_items, &order, 4, 5, context, lessThan);
                swap(T, sliced_items, &order, 6, 7, context, lessThan);
                swap(T, sliced_items, &order, 0, 2, context, lessThan);
                swap(T, sliced_items, &order, 1, 3, context, lessThan);
                swap(T, sliced_items, &order, 4, 6, context, lessThan);
                swap(T, sliced_items, &order, 5, 7, context, lessThan);
                swap(T, sliced_items, &order, 1, 2, context, lessThan);
                swap(T, sliced_items, &order, 5, 6, context, lessThan);
                swap(T, sliced_items, &order, 0, 4, context, lessThan);
                swap(T, sliced_items, &order, 3, 7, context, lessThan);
                swap(T, sliced_items, &order, 1, 5, context, lessThan);
                swap(T, sliced_items, &order, 2, 6, context, lessThan);
                swap(T, sliced_items, &order, 1, 4, context, lessThan);
                swap(T, sliced_items, &order, 3, 6, context, lessThan);
                swap(T, sliced_items, &order, 2, 4, context, lessThan);
                swap(T, sliced_items, &order, 3, 5, context, lessThan);
                swap(T, sliced_items, &order, 3, 4, context, lessThan);
            },
            7 => {
                swap(T, sliced_items, &order, 1, 2, context, lessThan);
                swap(T, sliced_items, &order, 3, 4, context, lessThan);
                swap(T, sliced_items, &order, 5, 6, context, lessThan);
                swap(T, sliced_items, &order, 0, 2, context, lessThan);
                swap(T, sliced_items, &order, 3, 5, context, lessThan);
                swap(T, sliced_items, &order, 4, 6, context, lessThan);
                swap(T, sliced_items, &order, 0, 1, context, lessThan);
                swap(T, sliced_items, &order, 4, 5, context, lessThan);
                swap(T, sliced_items, &order, 2, 6, context, lessThan);
                swap(T, sliced_items, &order, 0, 4, context, lessThan);
                swap(T, sliced_items, &order, 1, 5, context, lessThan);
                swap(T, sliced_items, &order, 0, 3, context, lessThan);
                swap(T, sliced_items, &order, 2, 5, context, lessThan);
                swap(T, sliced_items, &order, 1, 3, context, lessThan);
                swap(T, sliced_items, &order, 2, 4, context, lessThan);
                swap(T, sliced_items, &order, 2, 3, context, lessThan);
            },
            6 => {
                swap(T, sliced_items, &order, 1, 2, context, lessThan);
                swap(T, sliced_items, &order, 4, 5, context, lessThan);
                swap(T, sliced_items, &order, 0, 2, context, lessThan);
                swap(T, sliced_items, &order, 3, 5, context, lessThan);
                swap(T, sliced_items, &order, 0, 1, context, lessThan);
                swap(T, sliced_items, &order, 3, 4, context, lessThan);
                swap(T, sliced_items, &order, 2, 5, context, lessThan);
                swap(T, sliced_items, &order, 0, 3, context, lessThan);
                swap(T, sliced_items, &order, 1, 4, context, lessThan);
                swap(T, sliced_items, &order, 2, 4, context, lessThan);
                swap(T, sliced_items, &order, 1, 3, context, lessThan);
                swap(T, sliced_items, &order, 2, 3, context, lessThan);
            },
            5 => {
                swap(T, sliced_items, &order, 0, 1, context, lessThan);
                swap(T, sliced_items, &order, 3, 4, context, lessThan);
                swap(T, sliced_items, &order, 2, 4, context, lessThan);
                swap(T, sliced_items, &order, 2, 3, context, lessThan);
                swap(T, sliced_items, &order, 1, 4, context, lessThan);
                swap(T, sliced_items, &order, 0, 3, context, lessThan);
                swap(T, sliced_items, &order, 0, 2, context, lessThan);
                swap(T, sliced_items, &order, 1, 3, context, lessThan);
                swap(T, sliced_items, &order, 1, 2, context, lessThan);
            },
            4 => {
                swap(T, sliced_items, &order, 0, 1, context, lessThan);
                swap(T, sliced_items, &order, 2, 3, context, lessThan);
                swap(T, sliced_items, &order, 0, 2, context, lessThan);
                swap(T, sliced_items, &order, 1, 3, context, lessThan);
                swap(T, sliced_items, &order, 1, 2, context, lessThan);
            },
            else => {},
        }
    }
    if (items.len < 8) return;

    // then merge sort the higher levels, which can be 8-15, 16-31, 32-63, 64-127, etc.
    while (true) {
        // if every A and B block will fit into the cache, use a special branch
        // specifically for merging with the cache
        // (we use < rather than <= since the block size might be one more than
        // iterator.length())
        if (iterator.length() < cache.len) {
            // if four subarrays fit into the cache, it's faster to merge both
            // pairs of subarrays into the cache,
            // then merge the two merged subarrays from the cache back into the original array
            if ((iterator.length() + 1) * 4 <= cache.len and iterator.length() * 4 <= items.len) {
                iterator.begin();
                while (!iterator.finished()) {
                    // merge A1 and B1 into the cache
                    var A1 = iterator.nextRange();
                    var B1 = iterator.nextRange();
                    var A2 = iterator.nextRange();
                    var B2 = iterator.nextRange();

                    if (lessThan(context, items[B1.end - 1], items[A1.start])) {
                        // the two ranges are in reverse order, so copy them in reverse order into the cache
                        const a1_items = items[A1.start..A1.end];
                        @memcpy(cache[B1.length()..][0..a1_items.len], a1_items);
                        const b1_items = items[B1.start..B1.end];
                        @memcpy(cache[0..b1_items.len], b1_items);
                    } else if (lessThan(context, items[B1.start], items[A1.end - 1])) {
                        // these two ranges weren't already in order, so merge them into the cache
                        mergeInto(T, items, A1, B1, cache[0..], context, lessThan);
                    } else {
                        // if A1, B1, A2, and B2 are all in order, skip doing anything else
                        if (!lessThan(context, items[B2.start], items[A2.end - 1]) and !lessThan(context, items[A2.start], items[B1.end - 1])) continue;

                        // copy A1 and B1 into the cache in the same order
                        const a1_items = items[A1.start..A1.end];
                        @memcpy(cache[0..a1_items.len], a1_items);
                        const b1_items = items[B1.start..B1.end];
                        @memcpy(cache[A1.length()..][0..b1_items.len], b1_items);
                    }
                    A1 = Range.init(A1.start, B1.end);

                    // merge A2 and B2 into the cache
                    if (lessThan(context, items[B2.end - 1], items[A2.start])) {
                        // the two ranges are in reverse order, so copy them in reverse order into the cache
                        const a2_items = items[A2.start..A2.end];
                        @memcpy(cache[A1.length() + B2.length() ..][0..a2_items.len], a2_items);
                        const b2_items = items[B2.start..B2.end];
                        @memcpy(cache[A1.length()..][0..b2_items.len], b2_items);
                    } else if (lessThan(context, items[B2.start], items[A2.end - 1])) {
                        // these two ranges weren't already in order, so merge them into the cache
                        mergeInto(T, items, A2, B2, cache[A1.length()..], context, lessThan);
                    } else {
                        // copy A2 and B2 into the cache in the same order
                        const a2_items = items[A2.start..A2.end];
                        @memcpy(cache[A1.length()..][0..a2_items.len], a2_items);
                        const b2_items = items[B2.start..B2.end];
                        @memcpy(cache[A1.length() + A2.length() ..][0..b2_items.len], b2_items);
                    }
                    A2 = Range.init(A2.start, B2.end);

                    // merge A1 and A2 from the cache into the items
                    const A3 = Range.init(0, A1.length());
                    const B3 = Range.init(A1.length(), A1.length() + A2.length());

                    if (lessThan(context, cache[B3.end - 1], cache[A3.start])) {
                        // the two ranges are in reverse order, so copy them in reverse order into the items
                        const a3_items = cache[A3.start..A3.end];
                        @memcpy(items[A1.start + A2.length() ..][0..a3_items.len], a3_items);
                        const b3_items = cache[B3.start..B3.end];
                        @memcpy(items[A1.start..][0..b3_items.len], b3_items);
                    } else if (lessThan(context, cache[B3.start], cache[A3.end - 1])) {
                        // these two ranges weren't already in order, so merge them back into the items
                        mergeInto(T, cache[0..], A3, B3, items[A1.start..], context, lessThan);
                    } else {
                        // copy A3 and B3 into the items in the same order
                        const a3_items = cache[A3.start..A3.end];
                        @memcpy(items[A1.start..][0..a3_items.len], a3_items);
                        const b3_items = cache[B3.start..B3.end];
                        @memcpy(items[A1.start + A1.length() ..][0..b3_items.len], b3_items);
                    }
                }

                // we merged two levels at the same time, so we're done with this level already
                // (iterator.nextLevel() is called again at the bottom of this outer merge loop)
                _ = iterator.nextLevel();
            } else {
                iterator.begin();
                while (!iterator.finished()) {
                    var A = iterator.nextRange();
                    var B = iterator.nextRange();

                    if (lessThan(context, items[B.end - 1], items[A.start])) {
                        // the two ranges are in reverse order, so a simple rotation should fix it
                        mem.rotate(T, items[A.start..B.end], A.length());
                    } else if (lessThan(context, items[B.start], items[A.end - 1])) {
                        // these two ranges weren't already in order, so we'll need to merge them!
                        const a_items = items[A.start..A.end];
                        @memcpy(cache[0..a_items.len], a_items);
                        mergeExternal(T, items, A, B, cache[0..], context, lessThan);
                    }
                }
            }
        } else {
            // this is where the in-place merge logic starts!
            // 1. pull out two internal buffers each containing √A unique values
            //    1a. adjust block_size and buffer_size if we couldn't find enough unique values
            // 2. loop over the A and B subarrays within this level of the merge sort
            // 3. break A and B into blocks of size 'block_size'
            // 4. "tag" each of the A blocks with values from the first internal buffer
            // 5. roll the A blocks through the B blocks and drop/rotate them where they belong
            // 6. merge each A block with any B values that follow, using the cache or the second internal buffer
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

            if (block_size <= cache.len) {
                // if every A block fits into the cache then we won't need the second internal buffer,
                // so we really only need to find 'buffer_size' unique values
                find = buffer_size;
            } else if (find > iterator.length()) {
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
                    index = findLastForward(T, items, items[last], Range.init(last + 1, A.end), find - count, context, lessThan);
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
                    } else if (block_size <= cache.len) {
                        // we found the first and only internal buffer that we need, so we're done!
                        buffer1 = Range.init(A.start, A.start + count);
                        break;
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
                    index = findFirstBackward(T, items, items[last], Range.init(B.start, last), find - count, context, lessThan);
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
                    } else if (block_size <= cache.len) {
                        // we found the first and only internal buffer that we need, so we're done!
                        buffer1 = Range.init(B.end - count, B.end);
                        break;
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
                        index = findFirstBackward(T, items, items[index - 1], Range.init(pull[pull_index].to, pull[pull_index].from - (count - 1)), length - count, context, lessThan);
                        const range = Range.init(index + 1, pull[pull_index].from + 1);
                        mem.rotate(T, items[range.start..range.end], range.length() - count);
                        pull[pull_index].from = index + count;
                    }
                } else if (pull[pull_index].to > pull[pull_index].from) {
                    // we're pulling values out to the right, which means the end of a B subarray
                    index = pull[pull_index].from + 1;
                    count = 1;
                    while (count < length) : (count += 1) {
                        index = findLastForward(T, items, items[index], Range.init(index, pull[pull_index].to), length - count, context, lessThan);
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
                        // this only happens for very small subarrays, like √4 = 2, 2 * (2 internal buffers) = 4,
                        // which also only happens when cache.len is small or 0 since it'd otherwise use MergeExternal
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

                if (lessThan(context, items[B.end - 1], items[A.start])) {
                    // the two ranges are in reverse order, so a simple rotation should fix it
                    mem.rotate(T, items[A.start..B.end], A.length());
                } else if (lessThan(context, items[A.end], items[A.end - 1])) {
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

                    // if the first unevenly sized A block fits into the cache, copy it there for when we go to Merge it
                    // otherwise, if the second buffer is available, block swap the contents into that
                    if (lastA.length() <= cache.len) {
                        const last_a_items = items[lastA.start..lastA.end];
                        @memcpy(cache[0..last_a_items.len], last_a_items);
                    } else if (buffer2.length() > 0) {
                        blockSwap(T, items, lastA.start, buffer2.start, lastA.length());
                    }

                    if (blockA.length() > 0) {
                        while (true) {
                            // if there's a previous B block and the first value of the minimum A block is <= the last value of the previous B block,
                            // then drop that minimum A block behind. or if there are no B blocks left then keep dropping the remaining A blocks.
                            if ((lastB.length() > 0 and !lessThan(context, items[lastB.end - 1], items[indexA])) or blockB.length() == 0) {
                                // figure out where to split the previous B block, and rotate it at the split
                                const B_split = binaryFirst(T, items, items[indexA], lastB, context, lessThan);
                                const B_remaining = lastB.end - B_split;

                                // swap the minimum A block to the beginning of the rolling A blocks
                                var minA = blockA.start;
                                findA = minA + block_size;
                                while (findA < blockA.end) : (findA += block_size) {
                                    if (lessThan(context, items[findA], items[minA])) {
                                        minA = findA;
                                    }
                                }
                                blockSwap(T, items, blockA.start, minA, block_size);

                                // swap the first item of the previous A block back with its original value, which is stored in buffer1
                                mem.swap(T, &items[blockA.start], &items[indexA]);
                                indexA += 1;

                                // locally merge the previous A block with the B values that follow it
                                // if lastA fits into the external cache we'll use that (with MergeExternal),
                                // or if the second internal buffer exists we'll use that (with MergeInternal),
                                // or failing that we'll use a strictly in-place merge algorithm (MergeInPlace)

                                if (lastA.length() <= cache.len) {
                                    mergeExternal(T, items, lastA, Range.init(lastA.end, B_split), cache[0..], context, lessThan);
                                } else if (buffer2.length() > 0) {
                                    mergeInternal(T, items, lastA, Range.init(lastA.end, B_split), buffer2, context, lessThan);
                                } else {
                                    mergeInPlace(T, items, lastA, Range.init(lastA.end, B_split), context, lessThan);
                                }

                                if (buffer2.length() > 0 or block_size <= cache.len) {
                                    // copy the previous A block into the cache or buffer2, since that's where we need it to be when we go to merge it anyway
                                    if (block_size <= cache.len) {
                                        @memcpy(cache[0..block_size], items[blockA.start..][0..block_size]);
                                    } else {
                                        blockSwap(T, items, blockA.start, buffer2.start, block_size);
                                    }

                                    // this is equivalent to rotating, but faster
                                    // the area normally taken up by the A block is either the contents of buffer2, or data we don't need anymore since we memcopied it
                                    // either way, we don't need to retain the order of those items, so instead of rotating we can just block swap B to where it belongs
                                    blockSwap(T, items, B_split, blockA.start + block_size - B_remaining, B_remaining);
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
                                // the cache is disabled here since it might contain the contents of the previous A block
                                mem.rotate(T, items[blockA.start..blockB.end], blockB.start - blockA.start);

                                lastB = Range.init(blockA.start, blockA.start + blockB.length());
                                blockA.start += blockB.length();
                                blockA.end += blockB.length();
                                blockB.end = blockB.start;
                            } else {
                                // roll the leftmost A block to the end by swapping it with the next B block
                                blockSwap(T, items, blockA.start, blockB.start, block_size);
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
                    if (lastA.length() <= cache.len) {
                        mergeExternal(T, items, lastA, Range.init(lastA.end, B.end), cache[0..], context, lessThan);
                    } else if (buffer2.length() > 0) {
                        mergeInternal(T, items, lastA, Range.init(lastA.end, B.end), buffer2, context, lessThan);
                    } else {
                        mergeInPlace(T, items, lastA, Range.init(lastA.end, B.end), context, lessThan);
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
            sort.insertion(T, items[buffer2.start..buffer2.end], context, lessThan);

            pull_index = 0;
            while (pull_index < 2) : (pull_index += 1) {
                var unique = pull[pull_index].count * 2;
                if (pull[pull_index].from > pull[pull_index].to) {
                    // the values were pulled out to the left, so redistribute them back to the right
                    var buffer = Range.init(pull[pull_index].range.start, pull[pull_index].range.start + pull[pull_index].count);
                    while (buffer.length() > 0) {
                        index = findFirstForward(T, items, items[buffer.start], Range.init(buffer.end, pull[pull_index].range.end), unique, context, lessThan);
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
                        index = findLastBackward(T, items, items[buffer.end - 1], Range.init(pull[pull_index].range.start, buffer.start), unique, context, lessThan);
                        const amount = buffer.start - index;
                        mem.rotate(T, items[index..buffer.end], amount);
                        buffer.start -= amount;
                        buffer.end -= (amount + 1);
                        unique -= 2;
                    }
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
    blockSwap(T, items, buffer.start + A_count, A.start + insert, A.length() - A_count);
}

fn blockSwap(comptime T: type, items: []T, start1: usize, start2: usize, block_size: usize) void {
    var index: usize = 0;
    while (index < block_size) : (index += 1) {
        mem.swap(T, &items[start1 + index], &items[start2 + index]);
    }
}

// combine a linear search with a binary search to reduce the number of comparisons in situations
// where have some idea as to how many unique values there are and where the next value might be
fn findFirstForward(
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

    var index = range.start + skip;
    while (lessThan(context, items[index - 1], value)) : (index += skip) {
        if (index >= range.end - skip) {
            return binaryFirst(T, items, value, Range.init(index, range.end), context, lessThan);
        }
    }

    return binaryFirst(T, items, value, Range.init(index - skip, index), context, lessThan);
}

fn findFirstBackward(
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
    while (index > range.start and !lessThan(context, items[index - 1], value)) : (index -= skip) {
        if (index < range.start + skip) {
            return binaryFirst(T, items, value, Range.init(range.start, index), context, lessThan);
        }
    }

    return binaryFirst(T, items, value, Range.init(index, index + skip), context, lessThan);
}

fn findLastForward(
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

    var index = range.start + skip;
    while (!lessThan(context, value, items[index - 1])) : (index += skip) {
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

fn mergeInto(
    comptime T: type,
    from: []T,
    A: Range,
    B: Range,
    into: []T,
    context: anytype,
    comptime lessThan: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) void {
    var A_index: usize = A.start;
    var B_index: usize = B.start;
    const A_last = A.end;
    const B_last = B.end;
    var insert_index: usize = 0;

    while (true) {
        if (!lessThan(context, from[B_index], from[A_index])) {
            into[insert_index] = from[A_index];
            A_index += 1;
            insert_index += 1;
            if (A_index == A_last) {
                // copy the remainder of B into the final array
                const from_b = from[B_index..B_last];
                @memcpy(into[insert_index..][0..from_b.len], from_b);
                break;
            }
        } else {
            into[insert_index] = from[B_index];
            B_index += 1;
            insert_index += 1;
            if (B_index == B_last) {
                // copy the remainder of A into the final array
                const from_a = from[A_index..A_last];
                @memcpy(into[insert_index..][0..from_a.len], from_a);
                break;
            }
        }
    }
}

fn mergeExternal(
    comptime T: type,
    items: []T,
    A: Range,
    B: Range,
    cache: []T,
    context: anytype,
    comptime lessThan: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) void {
    // A fits into the cache, so use that instead of the internal buffer
    var A_index: usize = 0;
    var B_index: usize = B.start;
    var insert_index: usize = A.start;
    const A_last = A.length();
    const B_last = B.end;

    if (B.length() > 0 and A.length() > 0) {
        while (true) {
            if (!lessThan(context, items[B_index], cache[A_index])) {
                items[insert_index] = cache[A_index];
                A_index += 1;
                insert_index += 1;
                if (A_index == A_last) break;
            } else {
                items[insert_index] = items[B_index];
                B_index += 1;
                insert_index += 1;
                if (B_index == B_last) break;
            }
        }
    }

    // copy the remainder of A into the final array
    const cache_a = cache[A_index..A_last];
    @memcpy(items[insert_index..][0..cache_a.len], cache_a);
}

fn swap(
    comptime T: type,
    items: []T,
    order: *[8]u8,
    x: usize,
    y: usize,
    context: anytype,
    comptime lessThan: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) void {
    if (lessThan(context, items[y], items[x]) or ((order.*)[x] > (order.*)[y] and !lessThan(context, items[x], items[y]))) {
        mem.swap(T, &items[x], &items[y]);
        mem.swap(u8, &(order.*)[x], &(order.*)[y]);
    }
}

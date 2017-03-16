const assert = @import("debug.zig").assert;
const mem = @import("mem.zig");
const math = @import("math.zig");

pub const Cmp = math.Cmp;

pub fn sort(comptime T: type, array: []T, comptime cmp: fn(a: &const T, b: &const T)->Cmp) {
    if (array.len > 0) {
        quicksort(T, array, 0, array.len - 1, cmp);
    }
}

fn quicksort(comptime T: type, array: []T, left: usize, right: usize, comptime cmp: fn(a: &const T, b: &const T)->Cmp) {
    var i = left;
    var j = right;
    const p = (i + j) / 2;

    while (i <= j) {
        while (cmp(array[i], array[p]) == Cmp.Less) {
            i += 1;
        }
        while (cmp(array[j], array[p]) == Cmp.Greater) {
            j -= 1;
        }
        if (i <= j) {
            const tmp = array[i];
            array[i] = array[j];
            array[j] = tmp;
            i += 1;
            if (j > 0) j -= 1;
        }
    }

    if (left < j) quicksort(T, array, left, j, cmp);
    if (i < right) quicksort(T, array, i, right, cmp);
}

pub fn i32asc(a: &const i32, b: &const i32) -> Cmp {
   return if (*a > *b) Cmp.Greater else if (*a < *b) Cmp.Less else Cmp.Equal
}

pub fn i32desc(a: &const i32, b: &const i32) -> Cmp {
    reverse(i32asc(a, b))
}

pub fn u8asc(a: &const u8, b: &const u8) -> Cmp {
    if (*a > *b) Cmp.Greater else if (*a < *b) Cmp.Less else Cmp.Equal
}

pub fn u8desc(a: &const u8, b: &const u8) -> Cmp {
    reverse(u8asc(a, b))
}

fn reverse(was: Cmp) -> Cmp {
    if (was == Cmp.Greater) Cmp.Less else if (was == Cmp.Less) Cmp.Greater else Cmp.Equal
}

// ---------------------------------------
// tests

test "testSort" {
    const u8cases = [][]const []const u8 {
        [][]const u8{"", ""},
        [][]const u8{"a", "a"},
        [][]const u8{"az", "az"},
        [][]const u8{"za", "az"},
        [][]const u8{"asdf", "adfs"},
        [][]const u8{"one", "eno"},
    };

    for (u8cases) |case| {
        var buf: [8]u8 = undefined;
        const slice = buf[0...case[0].len];
        mem.copy(u8, slice, case[0]);
        sort(u8, slice, u8asc);
        assert(mem.eql(u8, slice, case[1]));
    }

    const i32cases = [][]const []const i32 {
        [][]const i32{[]i32{}, []i32{}},
        [][]const i32{[]i32{1}, []i32{1}},
        [][]const i32{[]i32{0, 1}, []i32{0, 1}},
        [][]const i32{[]i32{1, 0}, []i32{0, 1}},
        [][]const i32{[]i32{1, -1, 0}, []i32{-1, 0, 1}},
        [][]const i32{[]i32{2, 1, 3}, []i32{1, 2, 3}},
    };

    for (i32cases) |case| {
        var buf: [8]i32 = undefined;
        const slice = buf[0...case[0].len];
        mem.copy(i32, slice, case[0]);
        sort(i32, slice, i32asc);
        assert(mem.eql(i32, slice, case[1]));
    }
}

test "testSortDesc" {
    const rev_cases = [][]const []const i32 {
        [][]const i32{[]i32{}, []i32{}},
        [][]const i32{[]i32{1}, []i32{1}},
        [][]const i32{[]i32{0, 1}, []i32{1, 0}},
        [][]const i32{[]i32{1, 0}, []i32{1, 0}},
        [][]const i32{[]i32{1, -1, 0}, []i32{1, 0, -1}},
        [][]const i32{[]i32{2, 1, 3}, []i32{3, 2, 1}},
    };

    for (rev_cases) |case| {
        var buf: [8]i32 = undefined;
        const slice = buf[0...case[0].len];
        mem.copy(i32, slice, case[0]);
        sort(i32, slice, i32desc);
        assert(mem.eql(i32, slice, case[1]));
    }
}

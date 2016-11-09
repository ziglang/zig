const assert = @import("debug.zig").assert;
const str = @import("str.zig");
const math = @import("math.zig");

pub const Cmp = math.Cmp;

pub fn sort(inline T: type, array: []T, inline cmp: fn(a: T, b: T)->Cmp) {
    if (array.len > 0) {
        quicksort(T, array, 0, array.len - 1, cmp);
    }
}

fn quicksort(inline T: type, array: []T, left: usize, right: usize, inline cmp: fn(a: T, b: T)->Cmp) {
    var i = left;
    var j = right;
    var p = (i + j) / 2;

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

pub fn i32asc(a: i32, b: i32) -> Cmp {
    return if (a > b) Cmp.Greater else if (a < b) Cmp.Less else Cmp.Equal;
}

pub fn i32desc(a: i32, b: i32) -> Cmp {
    return reverse(i32asc(a, b));
}

pub fn u8asc(a: u8, b: u8) -> Cmp {
    return if (a > b) Cmp.Greater else if (a < b) Cmp.Less else Cmp.Equal;
}

pub fn u8desc(a: u8, b: u8) -> Cmp {
    return reverse(u8asc(a, b));
}

fn reverse(was: Cmp) -> Cmp {
    return if (was == Cmp.Greater) Cmp.Less else if (was == Cmp.Less) Cmp.Greater else Cmp.Equal;
}

// ---------------------------------------
// tests

fn testSort() {
    @setFnTest(this, true);

    const u8cases = [][][]u8 {
        [][]u8{"", ""},
        [][]u8{"a", "a"},
        [][]u8{"az", "az"},
        [][]u8{"za", "az"},
        [][]u8{"asdf", "adfs"},
        [][]u8{"one", "eno"},
    };

    for (u8cases) |case| {
        sort(u8, case[0], u8asc);
        assert(str.eql(case[0], case[1]));
    }

    const i32cases = [][][]i32 {
        [][]i32{[]i32{}, []i32{}},
        [][]i32{[]i32{1}, []i32{1}},
        [][]i32{[]i32{0, 1}, []i32{0, 1}},
        [][]i32{[]i32{1, 0}, []i32{0, 1}},
        [][]i32{[]i32{1, -1, 0}, []i32{-1, 0, 1}},
        [][]i32{[]i32{2, 1, 3}, []i32{1, 2, 3}},
    };

    for (i32cases) |case| {
        sort(i32, case[0], i32asc);
        assert(str.sliceEql(i32, case[0], case[1]));
    }
}

fn testSortDesc() {
    @setFnTest(this, true);

    const revCases = [][][]i32 {
        [][]i32{[]i32{}, []i32{}},
        [][]i32{[]i32{1}, []i32{1}},
        [][]i32{[]i32{0, 1}, []i32{1, 0}},
        [][]i32{[]i32{1, 0}, []i32{1, 0}},
        [][]i32{[]i32{1, -1, 0}, []i32{1, 0, -1}},
        [][]i32{[]i32{2, 1, 3}, []i32{3, 2, 1}},
    };

    for (revCases) |case| {
        sort(i32, case[0], i32desc);
        assert(str.sliceEql(i32, case[0], case[1]));
    }

}


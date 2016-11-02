const assert = @import("debug.zig").assert;
const str = @import("str.zig");

pub fn sort(inline T: type, array: []T) {
    if (array.len > 0) {
        quicksort(T, array, 0, array.len - 1);
    }
}

fn quicksort(inline T: type, array: []T, left: usize, right: usize) {
    var i = left;
    var j = right;
    var p = (i + j) / 2;

    while (i <= j) {
        while (array[i] < array[p]) {
            i += 1;
        }
        while (array[j] > array[p]) {
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

    if (left < j) quicksort(T, array, left, j);
    if (i < right) quicksort(T, array, i, right);
}

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
        sort(u8, case[0]);
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
        sort(i32, case[0]);
        assert(str.sliceEql(i32, case[0], case[1]));
    }
}

const MyEnum = enum { One, Two, Three };

pub fn main() u8 {
    var val: MyEnum = .Two;
    _ = &val;
    const a: u8 = switch (val) {
        .One => 1,
        .Two => 2,
        .Three => 3,
    };

    return a - 2;
}

// run
//

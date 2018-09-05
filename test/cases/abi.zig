const assert = @import("std").debug.assert;

// S1
const S1 = extern struct {
    x: i32,
};

extern fn take_s1(s: S1) i32 {
    return s.x;
}

extern fn ret_s1() S1 {
    return S1 { .x = 0x12345678 };
}

test "ABI S1" {
    const s = ret_s1();
    assert(s.x == 0x12345678);
    assert(take_s1(s) == 0x12345678);
}

// S2
const S2 = extern struct {
    x: i64,
};

extern fn take_s2(s: S2) i64 {
    return s.x;
}

extern fn ret_s2() S2 {
    return S2 { .x = 0x123456789ABFDEFE };
}

test "ABI S2" {
    const s = ret_s2();
    assert(s.x == 0x123456789ABFDEFE);
    assert(take_s2(s) == 0x123456789ABFDEFE);
}

// S3
const S3 = extern struct {
    x: [2]i32,
};

extern fn take_s3(s: S3) i32 {
    return s.x[0] + s.x[1];
}

extern fn ret_s3() S3 {
    return S3 { .x = [2]i32{0x10101010, 0x02020202} };
}

test "ABI S3" {
    const s = ret_s3();
    assert(s.x[0] == 0x10101010);
    assert(s.x[1] == 0x02020202);
    assert(take_s3(s) == 0x12121212);
}

// S4
const S4 = extern struct {
    x: [2]i64,
};

extern fn take_s4(s: S4) i64 {
    return s.x[0] + s.x[1];
}

extern fn ret_s4() S4 {
    return S4 { .x = [2]i64{0x1010101010101010, 0x0202020202020202} };
}

test "ABI S4" {
    const s = ret_s4();
    assert(s.x[0] == 0x1010101010101010);
    assert(s.x[1] == 0x0202020202020202);
    assert(take_s4(s) == 0x1212121212121212);
}

pub fn f64_from_bits(bits: u64) -> f64 {
    const bits2 = bits;
    *(&f64)(&bits2)
}

pub fn f64_to_bits(f: f64) -> u64 {
    const f2 = f;
    *(&u64)(&f2)
}

pub fn f64_get_pos_inf() -> f64 {
    f64_from_bits(0x7FF0000000000000)
}

pub fn f64_get_neg_inf() -> f64 {
    f64_from_bits(0xFFF0000000000000)
}

pub fn f64_is_nan(f: f64) -> bool {
    const bits = f64_to_bits(f);
    const exp: i64 = i64((bits >> 52) & ((1 << 11) - 1));
    const sig = (bits & ((1 << 52) - 1)) | (1 << 52);

    sig != 0 && exp == (1 << 11) - 1
}

pub fn f64_is_inf(f: f64) -> bool {
    f == f64_get_neg_inf() || f == f64_get_pos_inf()
}

pub fn min_isize(x: isize, y: isize) -> isize {
    if (x < y) x else y
}


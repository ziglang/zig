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
    0x7FFFFFFFFFFFFFFF == f64_to_bits(f) // TODO improve to catch all cases
}

pub fn f64_is_inf(f: f64) -> bool {
    f == f64_get_neg_inf() || f == f64_get_pos_inf()
}

pub const Cmp = enum {
    Equal,
    Greater,
    Less,
};

pub fn min(x: var, y: var) -> @typeOf(x + y) {
    if (x < y) x else y
}

pub fn max(x: var, y: var) -> @typeOf(x + y) {
    if (x > y) x else y
}

error Overflow;
pub fn mulOverflow(comptime T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@mulWithOverflow(T, a, b, &answer)) error.Overflow else answer
}
pub fn addOverflow(comptime T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@addWithOverflow(T, a, b, &answer)) error.Overflow else answer
}
pub fn subOverflow(comptime T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@subWithOverflow(T, a, b, &answer)) error.Overflow else answer
}
pub fn shlOverflow(comptime T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@shlWithOverflow(T, a, b, &answer)) error.Overflow else answer
}

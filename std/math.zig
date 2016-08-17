pub enum Cmp {
    Equal,
    Greater,
    Less,
}

pub fn min(inline T: type, x: T, y: T) -> T {
    if (x < y) x else y
}

pub fn max(inline T: type, x: T, y: T) -> T {
    if (x > y) x else y
}

pub error Overflow;
pub fn mulOverflow(inline T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@mulWithOverflow(T, a, b, &answer)) error.Overflow else answer
}
pub fn addOverflow(inline T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@addWithOverflow(T, a, b, &answer)) error.Overflow else answer
}
pub fn subOverflow(inline T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@subWithOverflow(T, a, b, &answer)) error.Overflow else answer
}

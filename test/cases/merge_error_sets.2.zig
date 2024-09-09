comptime {
    const small: error{A}!u16 = 10;
    const large: error{ A, B }!u16 = small;
    if ((large catch 0) != 10) unreachable;
}

// compile
//

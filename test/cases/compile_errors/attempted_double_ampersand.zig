export fn entry(a: bool, b: bool) i32 {
    if (a && b) {
        return 1234;
    }
    return 5678;
}

// error
// backend=stage2
// target=native
//
// :2:11: error: ambiguous use of '&&'; use 'and' for logical AND, or change whitespace to ' & &' for bitwise AND

fn f2(u64) u64 {
    return x;
}
fn f3(*x) u64 {
    return x;
}
fn f1(x) u64 {
    return x;
}

// error
// backend=stage2
// target=native
//
// :1:7: error: missing parameter name
// :4:7: error: missing parameter name
// :7:7: error: missing parameter name or type
// :7:7: note: if this is a name, annotate its type 'x: T'
// :7:7: note: if this is a type, give it a name '<name>: x'

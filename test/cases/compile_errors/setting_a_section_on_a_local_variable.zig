export fn entry() i32 {
    var foo: i32 linksection(".text2") = 1234;
    return foo;
}

// error
//
// :2:30: error: cannot set section of local variable 'foo'

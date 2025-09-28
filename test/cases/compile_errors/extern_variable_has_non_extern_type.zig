extern var foo: u3;
pub export fn entry() void {
    _ = foo;
}

// error
//
// :1:17: error: extern variable cannot have type 'u3'
// :1:17: note: only integers with 0 or power of two bits are extern compatible

//! This file contains pointer coercions which are invalid because the element types are only
//! in-memory coercible *in one direction*. When casting a mutable pointer, the element type
//! must coerce in both directions for the pointer to coerce. Otherwise, you could do something
//! like this, where `A` coerces to `B` but not vice-versa:
//!
//! ```
//! var x: A = undefined;
//! const p: *B = &x; // `*A` -> `*B`
//! p.* = some_b;
//! const some_b_as_a = x;
//! ```

export fn error_set_to_larger() void {
    var x: error{Foo} = undefined;
    _ = @as(*const error{ Foo, Bar }, &x); // this is ok
    _ = @as(*error{ Foo, Bar }, &x); // compile error
}

export fn error_set_to_anyerror() void {
    var x: error{Foo} = undefined;
    _ = @as(*const anyerror, &x); // this is ok
    _ = @as(*anyerror, &x); // compile error
}

export fn error_union_to_anyerror_union() void {
    var x: error{Foo}!u32 = undefined;
    _ = @as(*const anyerror!u32, &x); // this is ok
    _ = @as(*anyerror!u32, &x); // compile error
}

export fn ptr_to_const_ptr() void {
    var x: *u32 = undefined;
    _ = @as(*const *const u32, &x); // this is ok
    _ = @as(**const u32, &x); // compile error
}

export fn ptr_to_allowzero_ptr() void {
    var x: *u32 = undefined;
    _ = @as(*const *allowzero u32, &x); // this is ok
    _ = @as(**allowzero u32, &x); // compile error
}

export fn ptr_to_volatile_ptr() void {
    var x: *u32 = undefined;
    _ = @as(*const *volatile u32, &x); // this is ok
    _ = @as(**volatile u32, &x); // compile error
}

export fn ptr_to_underaligned_ptr() void {
    var x: *u32 = undefined;
    _ = @as(*const *align(1) u32, &x); // this is ok
    _ = @as(**align(1) u32, &x); // compile error
}

// error
//
// :16:33: error: expected type '*error{Foo,Bar}', found '*error{Foo}'
// :16:33: note: pointer type child 'error{Foo}' cannot cast into pointer type child 'error{Foo,Bar}'
// :16:33: note: 'error.Bar' not a member of destination error set
// :22:24: error: expected type '*anyerror', found '*error{Foo}'
// :22:24: note: pointer type child 'error{Foo}' cannot cast into pointer type child 'anyerror'
// :22:24: note: global error set cannot cast into a smaller set
// :28:28: error: expected type '*anyerror!u32', found '*error{Foo}!u32'
// :28:28: note: pointer type child 'error{Foo}!u32' cannot cast into pointer type child 'anyerror!u32'
// :28:28: note: global error set cannot cast into a smaller set
// :34:26: error: expected type '**const u32', found '**u32'
// :34:26: note: pointer type child '*u32' cannot cast into pointer type child '*const u32'
// :34:26: note: mutable '*const u32' would allow illegal const pointers stored to type '*u32'
// :40:30: error: expected type '**allowzero u32', found '**u32'
// :40:30: note: pointer type child '*u32' cannot cast into pointer type child '*allowzero u32'
// :40:30: note: mutable '*allowzero u32' would allow illegal null values stored to type '*u32'
// :46:29: error: expected type '**volatile u32', found '**u32'
// :46:29: note: pointer type child '*u32' cannot cast into pointer type child '*volatile u32'
// :46:29: note: mutable '*volatile u32' would allow illegal volatile pointers stored to type '*u32'
// :52:29: error: expected type '**align(1) u32', found '**u32'
// :52:29: note: pointer type child '*u32' cannot cast into pointer type child '*align(1) u32'
// :52:29: note: pointer alignment '4' cannot cast into pointer alignment '1'

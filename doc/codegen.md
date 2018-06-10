# Code Generation

## Data Representation

Every type has a "handle". If a type is a simple primitive type such as i32 or
f64, the handle is "by value", meaning that we pass around the value itself when
we refer to a value of that type.

If a type is a container, error union, optional type, slice, or array, then its
handle is a pointer, and everywhere we refer to a value of this type we refer to
a pointer.

Parameters and return values are always passed as handles.

Error union types are represented as:

    struct {
        error: u32,
        payload: T,
    }

Optional types are represented as:

    struct {
        payload: T,
        is_non_null: u1,
    }

## Data Optimizations

Optional pointer types are special: the 0x0 pointer value is used to represent a
null pointer. Thus, instead of the struct above, optional pointer types are
represented as a `usize` in codegen and the handle is by value.

#attribute("test")
fn empty_function() {}




/**
    * multi line doc comment
    */
/// this is a documentation comment
/// doc comment line 2
#attribute("test")
fn comments() {
    comments_f1(/* mid-line comment /* nested */ */ "OK\n");
}

fn comments_f1(s: []u8) {}




#attribute("test")
fn fn_call_of_struct_field() {
    if (call_struct_field(Foo {.ptr = a_func,}) != 13) {
        unreachable{};
    }
}

struct Foo {
    ptr: fn() -> i32,
}

fn a_func() -> i32 { 13 }

fn call_struct_field(foo: Foo) -> i32 {
    return foo.ptr();
}

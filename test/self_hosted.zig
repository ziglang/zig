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



#attribute("test")
fn redefinition_of_error_values_allowed() {
    if (error.AnError == error.SecondError) unreachable{}
}
error AnError;
error AnError;
error SecondError;




#attribute("test")
fn constant_enum_with_payload() {
    should_be_empty(AnEnumWithPayload.Empty);
    should_be_not_empty(AnEnumWithPayload.Full(13));
}

fn should_be_empty(x: AnEnumWithPayload) {
    if (x != AnEnumWithPayload.Empty) unreachable{}
}

fn should_be_not_empty(x: AnEnumWithPayload) {
    if (x == AnEnumWithPayload.Empty) unreachable{}
}

enum AnEnumWithPayload {
    Empty,
    Full: i32,
}


#attribute("test")
fn continue_in_for_loop() {
    const array = []i32 {1, 2, 3, 4, 5};
    var sum : i32 = 0;
    for (x, array) {
        sum += x;
        if (x < 3) {
            continue;
        }
        break;
    }
    if (sum != 6) unreachable{}
}

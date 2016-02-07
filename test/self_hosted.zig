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
    var empty = AnEnumWithPayload.Empty;
    var full = AnEnumWithPayload.Full(13);
    should_be_empty(empty);
    should_be_not_empty(full);
}

fn should_be_empty(x: AnEnumWithPayload) {
    switch (x) {
        Empty => {},
        else => unreachable{},
    }
}

fn should_be_not_empty(x: AnEnumWithPayload) {
    switch (x) {
        Empty => unreachable{},
        else => {},
    }
}

enum AnEnumWithPayload {
    Empty,
    Full: i32,
}


#attribute("test")
fn continue_in_for_loop() {
    const array = []i32 {1, 2, 3, 4, 5};
    var sum : i32 = 0;
    for (array) |x| {
        sum += x;
        if (x < 3) {
            continue;
        }
        break;
    }
    if (sum != 6) unreachable{}
}


#attribute("test")
fn cast_bool_to_int() {
    const t = true;
    const f = false;
    if (i32(t) != i32(1)) unreachable{}
    if (i32(f) != i32(0)) unreachable{}
    non_const_cast_bool_to_int(t, f);
}

fn non_const_cast_bool_to_int(t: bool, f: bool) {
    if (i32(t) != i32(1)) unreachable{}
    if (i32(f) != i32(0)) unreachable{}
}


#attribute("test")
fn switch_on_enum() {
    const fruit = Fruit.Orange;
    switch (fruit) {
        Apple => unreachable{},
        Orange => {},
        Banana => unreachable{},
    }
    non_const_switch_on_enum(fruit);
}
enum Fruit {
    Apple,
    Orange,
    Banana,
}
fn non_const_switch_on_enum(fruit: Fruit) {
    switch (fruit) {
        Apple => unreachable{},
        Orange => {},
        Banana => unreachable{},
    }
}

#attribute("test")
fn switch_statement() {
    const foo = SwitchStatmentFoo.C;
    const val: i32 = switch (foo) {
        A => 1,
        B => 2,
        C => 3,
        D => 4,
    };
    if (val != 3) unreachable{};
}
enum SwitchStatmentFoo {
    A,
    B,
    C,
    D,
}


#attribute("test")
fn switch_prong_with_var() {
    switch_prong_with_var_fn(SwitchProngWithVarEnum.One(13));
    switch_prong_with_var_fn(SwitchProngWithVarEnum.Two(13.0));
    switch_prong_with_var_fn(SwitchProngWithVarEnum.Meh);
}
enum SwitchProngWithVarEnum {
    One: i32,
    Two: f32,
    Meh,
}
fn switch_prong_with_var_fn(a: SwitchProngWithVarEnum) {
    switch(a) {
        One => |x| {
            if (x != 13) unreachable{};
        },
        Two => |x| {
            if (x != 13.0) unreachable{};
        },
        Meh => |x| {
            const v: void = x;
        },
    }
}


#attribute("test")
fn err_return_in_assignment() {
    %%do_err_return_in_assignment();
}

fn do_err_return_in_assignment() -> %void {
    var x : i32 = undefined;
    x = %return make_a_non_err();
}

fn make_a_non_err() -> %i32 {
    return 1;
}



#attribute("test")
fn rhs_maybe_unwrap_return() {
    const x = ?true;
    const y = x ?? return;
}

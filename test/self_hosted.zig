// test std library
const std = @import("std");

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
fn if_statements() {
    should_be_equal(1, 1);
    first_eql_third(2, 1, 2);
}
fn should_be_equal(a: i32, b: i32) {
    if (a != b) {
        unreachable{};
    } else {
        return;
    }
}
fn first_eql_third(a: i32, b: i32, c: i32) {
    if (a == b) {
        unreachable{};
    } else if (b == c) {
        unreachable{};
    } else if (a == c) {
        return;
    } else {
        unreachable{};
    }
}


#attribute("test")
fn local_variables() {
    test_loc_vars(2);
}
fn test_loc_vars(b: i32) {
    const a: i32 = 1;
    if (a + b != 3) unreachable{};
}

#attribute("test")
fn bool_literals() {
    should_be_true(true);
    should_be_false(false);
}
fn should_be_true(b: bool) {
    if (!b) unreachable{};
}
fn should_be_false(b: bool) {
    if (b) unreachable{};
}


#attribute("test")
fn separate_block_scopes() {
    {
        const no_conflict : i32 = 5;
        assert(no_conflict == 5);
    }

    const c = {
        const no_conflict = i32(10);
        no_conflict
    };
    assert(c == 10);
}


#attribute("test")
fn void_struct_fields() {
    const foo = VoidStructFieldsFoo {
        .a = void{},
        .b = 1,
        .c = void{},
    };
    assert(foo.b == 1);
    assert(@sizeof(VoidStructFieldsFoo) == 4);
}
struct VoidStructFieldsFoo {
    a : void,
    b : i32,
    c : void,
}


#attribute("test")
fn void_arrays() {
    var array: [4]void = undefined;
    array[0] = void{};
    array[1] = array[2];
    assert(@sizeof(@typeof(array)) == 0);
    assert(array.len == 4);
}


#attribute("test")
fn three_expr_in_a_row() {
    assert_false(false || false || false);
    assert_false(true && true && false);
    assert_false(1 | 2 | 4 != 7);
    assert_false(3 ^ 6 ^ 8 != 13);
    assert_false(7 & 14 & 28 != 4);
    assert_false(9  << 1 << 2 != 9  << 3);
    assert_false(90 >> 1 >> 2 != 90 >> 3);
    assert_false(100 - 1 + 1000 != 1099);
    assert_false(5 * 4 / 2 % 3 != 1);
    assert_false(i32(i32(5)) != 5);
    assert_false(!!false);
    assert_false(i32(7) != --(i32(7)));
}
fn assert_false(b: bool) {
    assert(!b);
}


#attribute("test")
fn maybe_type() {
    const x : ?bool = true;

    if (const y ?= x) {
        if (y) {
            // OK
        } else {
            unreachable{};
        }
    } else {
        unreachable{};
    }

    const next_x : ?i32 = null;

    const z = next_x ?? 1234;

    assert(z == 1234);

    const final_x : ?i32 = 13;

    const num = final_x ?? unreachable{};

    assert(num == 13);
}


#attribute("test")
fn enum_type() {
    const foo1 = EnumTypeFoo.One(13);
    const foo2 = EnumTypeFoo.Two(EnumType { .x = 1234, .y = 5678, });
    const bar = EnumTypeBar.B;

    assert(bar == EnumTypeBar.B);
    assert(@member_count(EnumTypeFoo) == 3);
    assert(@member_count(EnumTypeBar) == 4);
    const expected_foo_size = switch (@compile_var("arch")) {
        i386 => 20,
        x86_64 => 24,
        else => unreachable{},
    };
    assert(@sizeof(EnumTypeFoo) == expected_foo_size);
    assert(@sizeof(EnumTypeBar) == 1);
}
struct EnumType {
    x: u64,
    y: u64,
}
enum EnumTypeFoo {
    One: i32,
    Two: EnumType,
    Three: void,
}
enum EnumTypeBar {
    A,
    B,
    C,
    D,
}


#attribute("test")
fn array_literal() {
    const HEX_MULT = []u16{4096, 256, 16, 1};

    assert(HEX_MULT.len == 4);
    assert(HEX_MULT[1] == 256);
}


#attribute("test")
fn const_number_literal() {
    const one = 1;
    const eleven = ten + one;

    assert(eleven == 11);
}
const ten = 10;


#attribute("test")
fn error_values() {
    const a = i32(error.err1);
    const b = i32(error.err2);
    assert(a != b);
}
error err1;
error err2;



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
    should_be_not_equal(error.AnError, error.SecondError);
}
error AnError;
error AnError;
error SecondError;
fn should_be_not_equal(a: error, b: error) {
    if (a == b) unreachable{}
}




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
    assert(i32(t) == i32(1));
    assert(i32(f) == i32(0));
    non_const_cast_bool_to_int(t, f);
}

fn non_const_cast_bool_to_int(t: bool, f: bool) {
    assert(i32(t) == i32(1));
    assert(i32(f) == i32(0));
}


#attribute("test")
fn switch_on_enum() {
    const fruit = Fruit.Orange;
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
    non_const_switch(SwitchStatmentFoo.C);
}
fn non_const_switch(foo: SwitchStatmentFoo) {
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


#attribute("test")
fn implicit_cast_fn_unreachable_return() {
    wants_fn_with_void(fn_with_unreachable);
}

fn wants_fn_with_void(f: fn()) { }

fn fn_with_unreachable() -> unreachable {
    unreachable {}
}


#attribute("test")
fn explicit_cast_maybe_pointers() {
    const a: ?&i32 = undefined;
    const b: ?&f32 = (?&f32)(a);
}


#attribute("test")
fn const_expr_eval_on_single_expr_blocks() {
    if (const_expr_eval_on_single_expr_blocks_fn(1, true) != 3) unreachable{}
}

fn const_expr_eval_on_single_expr_blocks_fn(x: i32, b: bool) -> i32 {
    const literal = 3;

    const result = if (b) {
        literal
    } else {
        x
    };

    return result;
}


#attribute("test")
fn builtin_const_eval() {
    const x : i32 = @const_eval(1 + 2 + 3);
    assert(x == @const_eval(6));
}

#attribute("test")
fn slicing() {
    var array : [20]i32 = undefined;

    array[5] = 1234;

    var slice = array[5...10];

    if (slice.len != 5) unreachable{};

    const ptr = &slice[0];
    if (ptr[0] != 1234) unreachable{};

    var slice_rest = array[10...];
    if (slice_rest.len != 10) unreachable{};
}


#attribute("test")
fn memcpy_and_memset_intrinsics() {
    var foo : [20]u8 = undefined;
    var bar : [20]u8 = undefined;

    @memset(&foo[0], 'A', foo.len);
    @memcpy(&bar[0], &foo[0], bar.len);

    if (bar[11] != 'A') unreachable{};
}


#attribute("test")
fn array_dot_len_const_expr() { }
struct ArrayDotLenConstExpr {
    y: [@const_eval(some_array.len)]u8,
}
const some_array = []u8 {0, 1, 2, 3};


#attribute("test")
fn count_leading_zeroes() {
    assert(@clz(u8, 0b00001010) == 4);
    assert(@clz(u8, 0b10001010) == 0);
    assert(@clz(u8, 0b00000000) == 8);
}

#attribute("test")
fn count_trailing_zeroes() {
    assert(@ctz(u8, 0b10100000) == 5);
    assert(@ctz(u8, 0b10001010) == 1);
    assert(@ctz(u8, 0b00000000) == 8);
}



fn assert(b: bool) {
    if (!b) unreachable{}
}

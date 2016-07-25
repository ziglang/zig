const std = @import("std");
const assert = std.debug.assert;
const str = std.str;
const cstr = std.cstr;
const other = @import("other.zig");

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
fn params() {
    assert(test_params_add(22, 11) == 33);
}
fn test_params_add(a: i32, b: i32) -> i32 {
    a + b
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
    assert(true);
    assert(!false);
}

#attribute("test")
fn void_parameters() {
    void_fun(1, void{}, 2, {});
}
fn void_fun(a : i32, b : void, c : i32, d : void) {
    const v = b;
    const vv : void = if (a == 1) {v} else {};
    assert(a + c == 3);
    return vv;
}

#attribute("test")
fn mutable_local_variables() {
    var zero : i32 = 0;
    assert(zero == 0);

    var i = i32(0);
    while (i != 3) {
        i += 1;
    }
    assert(i == 3);
}

#attribute("test")
fn arrays() {
    var array : [5]i32 = undefined;

    var i : i32 = 0;
    while (i < 5) {
        array[i] = i + 1;
        i = array[i];
    }

    i = 0;
    var accumulator = i32(0);
    while (i < 5) {
        accumulator += array[i];

        i += 1;
    }

    assert(accumulator == 15);
    assert(get_array_len(array) == 5);
}
fn get_array_len(a: []i32) -> isize {
    a.len
}

#attribute("test")
fn short_circuit() {
    var hit_1 = false;
    var hit_2 = false;
    var hit_3 = false;
    var hit_4 = false;

    if (true || {assert_runtime(false); false}) {
        hit_1 = true;
    }
    if (false || { hit_2 = true; false }) {
        assert_runtime(false);
    }

    if (true && { hit_3 = true; false }) {
        assert_runtime(false);
    }
    if (false && {assert_runtime(false); false}) {
        assert_runtime(false);
    } else {
        hit_4 = true;
    }
    assert(hit_1);
    assert(hit_2);
    assert(hit_3);
    assert(hit_4);
}

#static_eval_enable(false)
fn assert_runtime(b: bool) {
    if (!b) unreachable{}
}

#attribute("test")
fn modify_operators() {
    var i : i32 = 0;
    i += 5;  assert(i == 5);
    i -= 2;  assert(i == 3);
    i *= 20; assert(i == 60);
    i /= 3;  assert(i == 20);
    i %= 11; assert(i == 9);
    i <<= 1; assert(i == 18);
    i >>= 2; assert(i == 4);
    i = 6;
    i &= 5;  assert(i == 4);
    i ^= 6;  assert(i == 2);
    i = 6;
    i |= 3;  assert(i == 7);
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
pub fn structs() {
    var foo : StructFoo = undefined;
    @memset(&foo, 0, @sizeof(StructFoo));
    foo.a += 1;
    foo.b = foo.a == 1;
    test_foo(foo);
    test_mutation(&foo);
    assert(foo.c == 100);
}
struct StructFoo {
    a : i32,
    b : bool,
    c : f32,
}
fn test_foo(foo : StructFoo) {
    assert(foo.b);
}
fn test_mutation(foo : &StructFoo) {
    foo.c = 100;
}
struct Node {
    val: Val,
    next: &Node,
}

struct Val {
    x: i32,
}

#attribute("test")
fn struct_point_to_self() {
    var root : Node = undefined;
    root.val.x = 1;

    var node : Node = undefined;
    node.next = &root;
    node.val.x = 2;

    root.next = &node;

    assert(node.next.next.next.val.x == 1);
}

#attribute("test")
fn struct_byval_assign() {
    var foo1 : StructFoo = undefined;
    var foo2 : StructFoo = undefined;

    foo1.a = 1234;
    foo2.a = 0;
    assert(foo2.a == 0);
    foo2 = foo1;
    assert(foo2.a == 1234);
}

fn struct_initializer() {
    const val = Val { .x = 42 };
    assert(val.x == 42);
}


const g1 : i32 = 1233 + 1;
var g2 : i32 = 0;

#attribute("test")
fn global_variables() {
    assert(g2 == 0);
    g2 = g1;
    assert(g2 == 1234);
}


#attribute("test")
fn while_loop() {
    var i : i32 = 0;
    while (i < 4) {
        i += 1;
    }
    assert(i == 4);
    assert(while_loop_1() == 1);
}
fn while_loop_1() -> i32 {
    return while_loop_2();
}
fn while_loop_2() -> i32 {
    while (true) {
        return 1;
    }
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
    const foo1 = EnumTypeFoo.One {13};
    const foo2 = EnumTypeFoo.Two {EnumType { .x = 1234, .y = 5678, }};
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
    assert(call_struct_field(Foo {.ptr = a_func,}) == 13);
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
    var full = AnEnumWithPayload.Full {13};
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
#static_eval_enable(false)
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
#static_eval_enable(false)
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
    switch_prong_with_var_fn(SwitchProngWithVarEnum.One {13});
    switch_prong_with_var_fn(SwitchProngWithVarEnum.Two {13.0});
    switch_prong_with_var_fn(SwitchProngWithVarEnum.Meh);
}
enum SwitchProngWithVarEnum {
    One: i32,
    Two: f32,
    Meh,
}
#static_eval_enable(false)
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

#static_eval_enable(false)
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
    assert(const_expr_eval_on_single_expr_blocks_fn(1, true) == 3);
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


#attribute("test")
fn multiline_string() {
    const s1 = r"AOEU(
one
two)
three)AOEU";
    const s2 = "\none\ntwo)\nthree";
    const s3 = r"(
one
two)
three)";
    assert(str.eql(s1, s2));
    assert(str.eql(s3, s2));
}



#attribute("test")
fn simple_generic_fn() {
    assert(max(i32, 3, -1) == 3);
    assert(max(f32, 0.123, 0.456) == 0.456);
    assert(add(2, 3) == 5);
}

fn max(inline T: type, a: T, b: T) -> T {
    return if (a > b) a else b;
}

fn add(inline a: i32, b: i32) -> i32 {
    return @const_eval(a) + b;
}


#attribute("test")
fn constant_equal_function_pointers() {
    const alias = empty_fn;
    assert(@const_eval(empty_fn == alias));
}

fn empty_fn() {}


#attribute("test")
fn generic_malloc_free() {
    const a = %%mem_alloc(u8, 10);
    mem_free(u8, a);
}
const some_mem : [100]u8 = undefined;
#static_eval_enable(false)
fn mem_alloc(inline T: type, n: isize) -> %[]T {
    return (&T)(&some_mem[0])[0...n];
}
fn mem_free(inline T: type, mem: []T) { }


#attribute("test")
fn call_fn_with_empty_string() {
    accepts_string("");
}

fn accepts_string(foo: []u8) { }


#attribute("test")
fn hex_escape() {
    assert(str.eql("\x68\x65\x6c\x6c\x6f", "hello"));
}


error AnError;
error ALongerErrorName;
#attribute("test")
fn error_name_string() {
    assert(str.eql(@err_name(error.AnError), "AnError"));
    assert(str.eql(@err_name(error.ALongerErrorName), "ALongerErrorName"));
}


#attribute("test")
fn goto_and_labels() {
    goto_loop();
    assert(goto_counter == 10);
}
fn goto_loop() {
    var i: i32 = 0;
    goto cond;
loop:
    i += 1;
cond:
    if (!(i < 10)) goto end;
    goto_counter += 1;
    goto loop;
end:
}
var goto_counter: i32 = 0;



#attribute("test")
fn goto_leave_defer_scope() {
    test_goto_leave_defer_scope(true);
}
#static_eval_enable(false)
fn test_goto_leave_defer_scope(b: bool) {
    var it_worked = false;

    goto entry;
exit:
    if (it_worked) {
        return;
    }
    unreachable{};
entry:
    defer it_worked = true;
    if (b) goto exit;
}


#attribute("test")
fn cast_undefined() {
    const array: [100]u8 = undefined;
    const slice = ([]u8)(array);
    test_cast_undefined(slice);
}
fn test_cast_undefined(x: []u8) {}


#attribute("test")
fn cast_small_unsigned_to_larger_signed() {
    assert(cast_small_unsigned_to_larger_signed_1(200) == i16(200));
    assert(cast_small_unsigned_to_larger_signed_2(9999) == isize(9999));
}
fn cast_small_unsigned_to_larger_signed_1(x: u8) -> i16 { x }
fn cast_small_unsigned_to_larger_signed_2(x: u16) -> isize { x }


#attribute("test")
fn implicit_cast_after_unreachable() {
    assert(outer() == 1234);
}
fn inner() -> i32 { 1234 }
fn outer() -> isize {
    return inner();
}


#attribute("test")
fn else_if_expression() {
    assert(else_if_expression_f(1) == 1);
}
fn else_if_expression_f(c: u8) -> u8 {
    if (c == 0) {
        0
    } else if (c == 1) {
        1
    } else {
        2
    }
}

#attribute("test")
fn err_binary_operator() {
    const a = err_binary_operator_g(true) %% 3;
    const b = err_binary_operator_g(false) %% 3;
    assert(a == 3);
    assert(b == 10);
}
error ItBroke;
fn err_binary_operator_g(x: bool) -> %isize {
    if (x) {
        error.ItBroke
    } else {
        10
    }
}

#attribute("test")
fn unwrap_simple_value_from_error() {
    const i = %%unwrap_simple_value_from_error_do();
    assert(i == 13);
}
fn unwrap_simple_value_from_error_do() -> %isize { 13 }


#attribute("test")
fn store_member_function_in_variable() {
    const instance = MemberFnTestFoo { .x = 1234, };
    const member_fn = MemberFnTestFoo.member;
    const result = member_fn(instance);
    assert(result == 1234);
}
struct MemberFnTestFoo {
    x: i32,
    fn member(foo: MemberFnTestFoo) -> i32 { foo.x }
}

#attribute("test")
fn call_member_function_directly() {
    const instance = MemberFnTestFoo { .x = 1234, };
    const result = MemberFnTestFoo.member(instance);
    assert(result == 1234);
}

#attribute("test")
fn member_functions() {
    const r = MemberFnRand {.seed = 1234};
    assert(r.get_seed() == 1234);
}
struct MemberFnRand {
    seed: u32,
    pub fn get_seed(r: MemberFnRand) -> u32 {
        r.seed
    }
}

#attribute("test")
fn static_function_evaluation() {
    assert(statically_added_number == 3);
}
const statically_added_number = static_add(1, 2);
fn static_add(a: i32, b: i32) -> i32 { a + b }


#attribute("test")
fn statically_initalized_list() {
    assert(static_point_list[0].x == 1);
    assert(static_point_list[0].y == 2);
    assert(static_point_list[1].x == 3);
    assert(static_point_list[1].y == 4);
}
struct Point {
    x: i32,
    y: i32,
}
const static_point_list = []Point { make_point(1, 2), make_point(3, 4) };
fn make_point(x: i32, y: i32) -> Point {
    return Point {
        .x = x,
        .y = y,
    };
}


#attribute("test")
fn static_eval_recursive() {
    assert(seventh_fib_number == 21);
}
const seventh_fib_number = fibbonaci(7);
fn fibbonaci(x: i32) -> i32 {
    if (x <= 1) return 1;
    return fibbonaci(x - 1) + fibbonaci(x - 2);
}

#attribute("test")
fn static_eval_while() {
    assert(static_eval_while_number == 1);
}
const static_eval_while_number = static_while_loop_1();
fn static_while_loop_1() -> i32 {
    return while_loop_2();
}
fn static_while_loop_2() -> i32 {
    while (true) {
        return 1;
    }
}

#attribute("test")
fn static_eval_list_init() {
    assert(static_vec3.data[2] == 1.0);
}
const static_vec3 = vec3(0.0, 0.0, 1.0);
pub struct Vec3 {
    data: [3]f32,
}
pub fn vec3(x: f32, y: f32, z: f32) -> Vec3 {
    Vec3 {
        .data = []f32 { x, y, z, },
    }
}


#attribute("test")
fn generic_fn_with_implicit_cast() {
    assert(get_first_byte(u8, []u8 {13}) == 13);
    assert(get_first_byte(u16, []u16 {0, 13}) == 0);
}
fn get_byte(ptr: ?&u8) -> u8 {*??ptr}
fn get_first_byte(inline T: type, mem: []T) -> u8 {
    get_byte((&u8)(&mem[0]))
}

#attribute("test")
fn continue_and_break() {
    run_continue_and_break_test();
    assert(continue_and_break_counter == 8);
}
var continue_and_break_counter: i32 = 0;
fn run_continue_and_break_test() {
    var i : i32 = 0;
    while (true) {
        continue_and_break_counter += 2;
        i += 1;
        if (i < 4) {
            continue;
        }
        break;
    }
    assert(i == 4);
}

#attribute("test")
fn sizeof_and_typeof() {
    const y: @typeof(sizeof_and_typeof_x) = 120;
    assert(@sizeof(@typeof(y)) == 2);
}
const sizeof_and_typeof_x: u16 = 13;
const sizeof_and_typeof_z: @typeof(sizeof_and_typeof_x) = 19;


#attribute("test")
fn pointer_dereferencing() {
    var x = i32(3);
    const y = &x;

    *y += 1;

    assert(x == 4);
    assert(*y == 4);
}

#attribute("test")
fn constant_expressions() {
    var array : [ARRAY_SIZE]u8 = undefined;
    assert(@sizeof(@typeof(array)) == 20);
}
const ARRAY_SIZE : i8 = 20;


#attribute("test")
fn min_value_and_max_value() {
    assert(@max_value(u8) == 255);
    assert(@max_value(u16) == 65535);
    assert(@max_value(u32) == 4294967295);
    assert(@max_value(u64) == 18446744073709551615);

    assert(@max_value(i8) == 127);
    assert(@max_value(i16) == 32767);
    assert(@max_value(i32) == 2147483647);
    assert(@max_value(i64) == 9223372036854775807);

    assert(@min_value(u8) == 0);
    assert(@min_value(u16) == 0);
    assert(@min_value(u32) == 0);
    assert(@min_value(u64) == 0);

    assert(@min_value(i8) == -128);
    assert(@min_value(i16) == -32768);
    assert(@min_value(i32) == -2147483648);
    assert(@min_value(i64) == -9223372036854775808);
}

#attribute("test")
fn overflow_intrinsics() {
    var result: u8 = undefined;
    assert(@add_with_overflow(u8, 250, 100, &result));
    assert(!@add_with_overflow(u8, 100, 150, &result));
    assert(result == 250);
}


#attribute("test")
fn nested_arrays() {
    const array_of_strings = [][]u8 {"hello", "this", "is", "my", "thing"};
    for (array_of_strings) |s, i| {
        if (i == 0) assert(str.eql(s, "hello"));
        if (i == 1) assert(str.eql(s, "this"));
        if (i == 2) assert(str.eql(s, "is"));
        if (i == 3) assert(str.eql(s, "my"));
        if (i == 4) assert(str.eql(s, "thing"));
    }
}

#attribute("test")
fn int_to_ptr_cast() {
    const x = isize(13);
    const y = (&u8)(x);
    const z = usize(y);
    assert(z == 13);
}

#attribute("test")
fn string_concatenation() {
    assert(str.eql("OK" ++ " IT " ++ "WORKED", "OK IT WORKED"));
}

#attribute("test")
fn constant_struct_with_negation() {
    assert(vertices[0].x == -0.6);
}
struct Vertex {
    x: f32,
    y: f32,
    r: f32,
    g: f32,
    b: f32,
}
const vertices = []Vertex {
    Vertex { .x = -0.6, .y = -0.4, .r = 1.0, .g = 0.0, .b = 0.0 },
    Vertex { .x =  0.6, .y = -0.4, .r = 0.0, .g = 1.0, .b = 0.0 },
    Vertex { .x =  0.0, .y =  0.6, .r = 0.0, .g = 0.0, .b = 1.0 },
};


#attribute("test")
fn return_with_implicit_cast_from_while_loop() {
    %%return_with_implicit_cast_from_while_loop_test();
}
fn return_with_implicit_cast_from_while_loop_test() -> %void {
    while (true) {
        return;
    }
}

#attribute("test")
fn return_struct_byval_from_function() {
    const bar = make_bar(1234, 5678);
    assert(bar.y == 5678);
}
struct Bar {
    x: i32,
    y: i32,
}
fn make_bar(x: i32, y: i32) -> Bar {
    Bar {
        .x = x,
        .y = y,
    }
}

#attribute("test")
fn function_pointers() {
    const fns = []@typeof(fn1) { fn1, fn2, fn3, fn4, };
    for (fns) |f, i| {
        assert(f() == u32(i) + 5);
    }
}
fn fn1() -> u32 {5}
fn fn2() -> u32 {6}
fn fn3() -> u32 {7}
fn fn4() -> u32 {8}



#attribute("test")
fn statically_initalized_struct() {
    st_init_str_foo.x += 1;
    assert(st_init_str_foo.x == 14);
}
struct StInitStrFoo {
    x: i32,
    y: bool,
}
var st_init_str_foo = StInitStrFoo { .x = 13, .y = true, };

#attribute("test")
fn statically_initialized_array_literal() {
    const y : [4]u8 = st_init_arr_lit_x;
    assert(y[3] == 4);
}
const st_init_arr_lit_x = []u8{1,2,3,4};



#attribute("test")
fn pointer_to_void_return_type() {
    %%test_pointer_to_void_return_type();
}
fn test_pointer_to_void_return_type() -> %void {
    const a = test_pointer_to_void_return_type_2();
    return *a;
}
const test_pointer_to_void_return_type_x = void{};
fn test_pointer_to_void_return_type_2() -> &void {
    return &test_pointer_to_void_return_type_x;
}


#attribute("test")
fn call_result_of_if_else_expression() {
    assert(str.eql(f2(true), "a"));
    assert(str.eql(f2(false), "b"));
}
fn f2(x: bool) -> []u8 {
    return (if (x) f_a else f_b)();
}
fn f_a() -> []u8 { "a" }
fn f_b() -> []u8 { "b" }


#attribute("test")
fn const_expression_eval_handling_of_variables() {
    var x = true;
    while (x) {
        x = false;
    }
}



#attribute("test")
fn constant_enum_initialization_with_differing_sizes() {
    test3_1(test3_foo);
    test3_2(test3_bar);
}
enum Test3Foo {
    One,
    Two: f32,
    Three: Test3Point,
}
struct Test3Point {
    x: i32,
    y: i32,
}
const test3_foo = Test3Foo.Three{Test3Point {.x = 3, .y = 4}};
const test3_bar = Test3Foo.Two{13};
#static_eval_enable(false)
fn test3_1(f: Test3Foo) {
    switch (f) {
        Three => |pt| {
            assert(pt.x == 3);
            assert(pt.y == 4);
        },
        else => unreachable{},
    }
}
#static_eval_enable(false)
fn test3_2(f: Test3Foo) {
    switch (f) {
        Two => |x| {
            assert(x == 13);
        },
        else => unreachable{},
    }
}



#attribute("test")
fn pub_enum() {
    pub_enum_test(other.APubEnum.Two);
}
fn pub_enum_test(foo: other.APubEnum) {
    assert(foo == other.APubEnum.Two);
}


#attribute("test")
fn cast_with_imported_symbol() {
    assert(other.size_t(42) == 42);
}


#attribute("test")
fn while_with_continue_expr() {
    var sum: i32 = 0;
    {var i: i32 = 0; while (i < 10; i += 1) {
        if (i == 5) continue;
        sum += i;
    }}
    assert(sum == 40);
}


#attribute("test")
fn for_loop_with_pointer_elem_var() {
    const source = "abcdefg";
    var target: [source.len]u8 = undefined;
    @memcpy(&target[0], &source[0], source.len);
    mangle_string(target);
    assert(str.eql(target, "bcdefgh"));
}
#static_eval_enable(false)
fn mangle_string(s: []u8) {
    for (s) |*c| {
        *c += 1;
    }
}

#attribute("test")
fn empty_struct_method_call() {
    const es = EmptyStruct{};
    assert(es.method() == 1234);
}
struct EmptyStruct {
    #static_eval_enable(false)
    fn method(es: EmptyStruct) -> i32 { 1234 }
}


#attribute("test")
fn @"weird function name"() { }


#attribute("test")
fn return_empty_struct_from_fn() {
    test_return_empty_struct_from_fn();
    test_return_empty_struct_from_fn_noeval();
}
struct EmptyStruct2 {}
fn test_return_empty_struct_from_fn() -> EmptyStruct2 {
    EmptyStruct2 {}
}
#static_eval_enable(false)
fn test_return_empty_struct_from_fn_noeval() -> EmptyStruct2 {
    EmptyStruct2 {}
}

#attribute("test")
fn pass_slice_of_empty_struct_to_fn() {
    assert(test_pass_slice_of_empty_struct_to_fn([]EmptyStruct2{ EmptyStruct2{} }) == 1);
}
fn test_pass_slice_of_empty_struct_to_fn(slice: []EmptyStruct2) -> isize {
    slice.len
}


#attribute("test")
fn pointer_comparison() {
    const a = ([]u8)("a");
    const b = &a;
    assert(ptr_eql(b, b));
}
fn ptr_eql(a: &[]u8, b: &[]u8) -> bool {
    a == b
}

#attribute("test")
fn character_literals() {
    assert('\'' == single_quote);
}
const single_quote = '\'';


#attribute("test")
fn switch_with_multiple_expressions() {
    const x: i32 = switch (returns_five()) {
        1, 2, 3 => 1,
        4, 5, 6 => 2,
        else => 3,
    };
    assert(x == 2);
}
#static_eval_enable(false)
fn returns_five() -> i32 { 5 }


#attribute("test")
fn switch_on_error_union() {
    const x = switch (returns_ten()) {
        Ok => |val| val + 1,
        ItBroke, NoMem => 1,
        CrappedOut => 2,
    };
    assert(x == 11);
}
error ItBroke;
error NoMem;
error CrappedOut;
#static_eval_enable(false)
fn returns_ten() -> %i32 { 10 }


#attribute("test")
fn bool_cmp() {
    assert(test_bool_cmp(true, false) == false);
}
#static_eval_enable(false)
fn test_bool_cmp(a: bool, b: bool) -> bool { a == b }


#attribute("test")
fn take_address_of_parameter() {
    test_take_address_of_parameter(12.34);
    test_take_address_of_parameter_noeval(12.34);
}
fn test_take_address_of_parameter(f: f32) {
    const f_ptr = &f;
    assert(*f_ptr == 12.34);
}
#static_eval_enable(false)
fn test_take_address_of_parameter_noeval(f: f32) {
    const f_ptr = &f;
    assert(*f_ptr == 12.34);
}


#attribute("test")
fn array_mult_operator() {
    assert(str.eql("ab" ** 5, "ababababab"));
}

#attribute("test")
fn string_escapes() {
    assert(str.eql("\"", "\x22"));
    assert(str.eql("\'", "\x27"));
    assert(str.eql("\n", "\x0a"));
    assert(str.eql("\r", "\x0d"));
    assert(str.eql("\t", "\x09"));
    assert(str.eql("\\", "\x5c"));
    assert(str.eql("\u1234\u0069", "\xe1\x88\xb4\x69"));
}

#attribute("test")
fn if_var_maybe_pointer() {
    assert(should_be_a_plus_1(Particle {.a = 14, .b = 1, .c = 1, .d = 1}) == 15);
}
#static_eval_enable(false)
fn should_be_a_plus_1(p: Particle) -> u64 {
    var maybe_particle: ?Particle = p;
    if (const *particle ?= maybe_particle) {
        particle.a += 1;
    }
    if (const particle ?= maybe_particle) {
        return particle.a;
    }
    return 0;
}
struct Particle {
    a: u64,
    b: u64,
    c: u64,
    d: u64,
}

#attribute("test")
fn assign_to_if_var_ptr() {
    var maybe_bool: ?bool = true;

    if (const *b ?= maybe_bool) {
        *b = false;
    }

    assert(??maybe_bool == false);
}

#attribute("test")
fn cmpxchg() {
    var x: i32 = 1234;
    while (!@cmpxchg(&x, 1234, 5678, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) {}
    assert(x == 5678);
}

#attribute("test")
fn fence() {
    var x: i32 = 1234;
    @fence(AtomicOrder.SeqCst);
    x = 5678;
}

#attribute("test")
fn unsigned_wrapping() {
    test_unsigned_wrapping_eval(@max_value(u32));
    test_unsigned_wrapping_noeval(@max_value(u32));
}
fn test_unsigned_wrapping_eval(x: u32w) {
    const zero = x + 1;
    assert(zero == 0);
    const orig = zero - 1;
    assert(orig == @max_value(u32));
}
#static_eval_enable(false)
fn test_unsigned_wrapping_noeval(x: u32w) {
    const zero = x + 1;
    assert(zero == 0);
    const orig = zero - 1;
    assert(orig == @max_value(u32));
}

#attribute("test")
fn signed_wrapping() {
    test_signed_wrapping_eval(@max_value(i32));
    test_signed_wrapping_noeval(@max_value(i32));
}
fn test_signed_wrapping_eval(x: i32w) {
    const min_val = x + 1;
    assert(min_val == @min_value(i32));
    const max_val = min_val - 1;
    assert(max_val == @max_value(i32));
}
#static_eval_enable(false)
fn test_signed_wrapping_noeval(x: i32w) {
    const min_val = x + 1;
    assert(min_val == @min_value(i32));
    const max_val = min_val - 1;
    assert(max_val == @max_value(i32));
}

#attribute("test")
fn negation_wrapping() {
    test_negation_wrapping_eval(@min_value(i16));
    test_negation_wrapping_noeval(@min_value(i16));
}
fn test_negation_wrapping_eval(x: i16w) {
    assert(x == -32768);
    const neg = -x;
    assert(neg == -32768);
}
#static_eval_enable(false)
fn test_negation_wrapping_noeval(x: i16w) {
    assert(x == -32768);
    const neg = -x;
    assert(neg == -32768);
}

#attribute("test")
fn shl_wrapping() {
    test_shl_wrapping_eval(@max_value(u16));
    test_shl_wrapping_noeval(@max_value(u16));
}
fn test_shl_wrapping_eval(x: u16w) {
    const shifted = x << 1;
    assert(shifted == 65534);
}
#static_eval_enable(false)
fn test_shl_wrapping_noeval(x: u16w) {
    const shifted = x << 1;
    assert(shifted == 65534);
}

#attribute("test")
fn shl_with_overflow() {
    var result: u16 = undefined;
    assert(@shl_with_overflow(u16, 0b0010111111111111, 3, &result));
    assert(!@shl_with_overflow(u16, 0b0010111111111111, 2, &result));
    assert(result == 0b1011111111111100);
}

#attribute("test")
fn combine_non_wrap_with_wrap() {
    const x: i32 = 123;
    const y: i32w = 456;
    const z = x + y;
    const z2 = y + x;
    assert(@typeof(z) == i32w);
    assert(@typeof(z2) == i32w);

    const a: i8 = 123;
    const b: i32w = 456;
    const c = b + a;
    const d = a + b;
    assert(@typeof(c) == i32w);
    assert(@typeof(d) == i32w);
}

#attribute("test")
fn c_string_concatenation() {
    const a = c"OK" ++ c" IT " ++ c"WORKED";
    const b = c"OK IT WORKED";

    const len = cstr.len(b);
    const len_with_null = len + 1;
    {var i: i32 = 0; while (i < len_with_null; i += 1) {
        assert(a[i] == b[i]);
    }}
    assert(a[len] == 0);
    assert(b[len] == 0);
}

#attribute("test")
fn generic_struct() {
    var a1 = GenNode(i32) {.value = 13, .next = null,};
    var b1 = GenNode(bool) {.value = true, .next = null,};
    assert(a1.value == 13);
    assert(a1.value == a1.get_val());
    assert(b1.get_val());
}
struct GenNode(T: type) {
    value: T,
    next: ?&GenNode(T),
    fn get_val(n: &const GenNode(T)) -> T { n.value }
}

#attribute("test")
fn cast_slice_to_u8_slice() {
    assert(@sizeof(i32) == 4);
    var big_thing_array = []i32{1, 2, 3, 4};
    const big_thing_slice: []i32 = big_thing_array;
    const bytes = ([]u8)(big_thing_slice);
    assert(bytes.len == 4 * 4);
    bytes[4] = 0;
    bytes[5] = 0;
    bytes[6] = 0;
    bytes[7] = 0;
    assert(big_thing_slice[1] == 0);
    const big_thing_again = ([]i32)(bytes);
    assert(big_thing_again[2] == 3);
    big_thing_again[2] = -1;
    assert(bytes[8] == @max_value(u8));
    assert(bytes[9] == @max_value(u8));
    assert(bytes[10] == @max_value(u8));
    assert(bytes[11] == @max_value(u8));
}

#attribute("test")
fn float_division() {
    assert(fdiv32(12.0, 3.0) == 4.0);
}
#static_eval_enable(false)
fn fdiv32(a: f32, b: f32) -> f32 {
    a / b
}

#attribute("test")
fn exact_division() {
    assert(div_exact(55, 11) == 5);
}
#static_eval_enable(false)
fn div_exact(a: u32, b: u32) -> u32 {
    @div_exact(a, b)
}

#attribute("test")
fn null_literal_outside_function() {
    const is_null = if (const _ ?= here_is_a_null_literal.context) false else true;
    assert(is_null);
}
struct SillyStruct {
    context: ?i32,
}
const here_is_a_null_literal = SillyStruct {
    .context = null,
};

#attribute("test")
fn truncate() {
    assert(test_truncate(0x10fd) == 0xfd);
}
#static_eval_enable(false)
fn test_truncate(x: u32) -> u8 {
    @truncate(u8, x)
}

#attribute("test")
fn const_decls_in_struct() {
    assert(GenericDataThing(3).count_plus_one == 4);
}
struct GenericDataThing(count: isize) {
    const count_plus_one = count + 1;
}

#attribute("test")
fn use_generic_param_in_generic_param() {
    assert(a_generic_fn(i32, 3, 4) == 7);
}
fn a_generic_fn(inline T: type, inline a: T, b: T) -> T {
    return a + b;
}


#attribute("test")
fn namespace_depends_on_compile_var() {
    if (some_namespace.a_bool) {
        assert(some_namespace.a_bool);
    } else {
        assert(!some_namespace.a_bool);
    }
}
const some_namespace = switch(@compile_var("os")) {
    linux => @import("a.zig"),
    else => @import("b.zig"),
};


#attribute("test")
fn unsigned_64_bit_division() {
    const result = div(1152921504606846976, 34359738365);
    assert(result.quotient == 33554432);
    assert(result.remainder == 100663296);
}
#static_eval_enable(false)
fn div(a: u64, b: u64) -> DivResult {
    DivResult {
        .quotient = a / b,
        .remainder = a % b,
    }
}
struct DivResult {
    quotient: u64,
    remainder: u64,
}

#attribute("test")
fn int_type_builtin() {
    assert(@int_type(true, 8, false) == i8);
    assert(@int_type(true, 16, false) == i16);
    assert(@int_type(true, 32, false) == i32);
    assert(@int_type(true, 64, false) == i64);

    assert(@int_type(false, 8, false) == u8);
    assert(@int_type(false, 16, false) == u16);
    assert(@int_type(false, 32, false) == u32);
    assert(@int_type(false, 64, false) == u64);

    assert(@int_type(true, 8, true) == i8w);
    assert(@int_type(true, 16, true) == i16w);
    assert(@int_type(true, 32, true) == i32w);
    assert(@int_type(true, 64, true) == i64w);

    assert(@int_type(false, 8, true) == u8w);
    assert(@int_type(false, 16, true) == u16w);
    assert(@int_type(false, 32, true) == u32w);
    assert(@int_type(false, 64, true) == u64w);

    assert(i8.bit_count == 8);
    assert(i16.bit_count == 16);
    assert(i32.bit_count == 32);
    assert(i64.bit_count == 64);

    assert(!i8.is_wrapping);
    assert(!i16.is_wrapping);
    assert(!i32.is_wrapping);
    assert(!i64.is_wrapping);

    assert(i8w.is_wrapping);
    assert(i16w.is_wrapping);
    assert(i32w.is_wrapping);
    assert(i64w.is_wrapping);

    assert(i8.is_signed);
    assert(i16.is_signed);
    assert(i32.is_signed);
    assert(i64.is_signed);
    assert(isize.is_signed);

    assert(!u8.is_signed);
    assert(!u16.is_signed);
    assert(!u32.is_signed);
    assert(!u64.is_signed);
    assert(!usize.is_signed);

}

#attribute("test")
fn int_to_enum() {
    test_int_to_enum_eval(3);
    test_int_to_enum_noeval(3);
}
fn test_int_to_enum_eval(x: i32) {
    assert(IntToEnumNumber(x) == IntToEnumNumber.Three);
}
#static_eval_enable(false)
fn test_int_to_enum_noeval(x: i32) {
    assert(IntToEnumNumber(x) == IntToEnumNumber.Three);
}
enum IntToEnumNumber {
    Zero,
    One,
    Two,
    Three,
    Four,
}

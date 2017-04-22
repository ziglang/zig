const tests = @import("tests.zig");

pub fn addCases(cases: &tests.CompileErrorContext) {
    cases.add("implicit semicolon - block statement",
        \\export fn entry() {
        \\    {}
        \\    var good = {};
        \\    ({})
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - block expr",
        \\export fn entry() {
        \\    _ = {};
        \\    var good = {};
        \\    _ = {}
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - comptime statement",
        \\export fn entry() {
        \\    comptime {}
        \\    var good = {};
        \\    comptime ({})
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - comptime expression",
        \\export fn entry() {
        \\    _ = comptime {};
        \\    var good = {};
        \\    _ = comptime {}
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - defer",
        \\export fn entry() {
        \\    defer {}
        \\    var good = {};
        \\    defer ({})
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: expected token ';', found 'var'");

    cases.add("implicit semicolon - if statement",
        \\export fn entry() {
        \\    if(true) {}
        \\    var good = {};
        \\    if(true) ({})
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if expression",
        \\export fn entry() {
        \\    _ = if(true) {};
        \\    var good = {};
        \\    _ = if(true) {}
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if-else statement",
        \\export fn entry() {
        \\    if(true) {} else {}
        \\    var good = {};
        \\    if(true) ({}) else ({})
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if-else expression",
        \\export fn entry() {
        \\    _ = if(true) {} else {};
        \\    var good = {};
        \\    _ = if(true) {} else {}
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if-else-if statement",
        \\export fn entry() {
        \\    if(true) {} else if(true) {}
        \\    var good = {};
        \\    if(true) ({}) else if(true) ({})
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if-else-if expression",
        \\export fn entry() {
        \\    _ = if(true) {} else if(true) {};
        \\    var good = {};
        \\    _ = if(true) {} else if(true) {}
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if-else-if-else statement",
        \\export fn entry() {
        \\    if(true) {} else if(true) {} else {}
        \\    var good = {};
        \\    if(true) ({}) else if(true) ({}) else ({})
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if-else-if-else expression",
        \\export fn entry() {
        \\    _ = if(true) {} else if(true) {} else {};
        \\    var good = {};
        \\    _ = if(true) {} else if(true) {} else {}
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - try statement",
        \\export fn entry() {
        \\    try (foo()) {}
        \\    var good = {};
        \\    try (foo()) ({})
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - try expression",
        \\export fn entry() {
        \\    _ = try (foo()) {};
        \\    var good = {};
        \\    _ = try (foo()) {}
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - test statement",
        \\export fn entry() {
        \\    test (foo()) {}
        \\    var good = {};
        \\    test (foo()) ({})
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - test expression",
        \\export fn entry() {
        \\    _ = test (foo()) {};
        \\    var good = {};
        \\    _ = test (foo()) {}
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - while statement",
        \\export fn entry() {
        \\    while(true) {}
        \\    var good = {};
        \\    while(true) ({})
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - while expression",
        \\export fn entry() {
        \\    _ = while(true) {};
        \\    var good = {};
        \\    _ = while(true) {}
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - while-continue statement",
        \\export fn entry() {
        \\    while(true;{}) {}
        \\    var good = {};
        \\    while(true;{}) ({})
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - while-continue expression",
        \\export fn entry() {
        \\    _ = while(true;{}) {};
        \\    var good = {};
        \\    _ = while(true;{}) {}
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - for statement",
        \\export fn entry() {
        \\    for(foo()) {}
        \\    var good = {};
        \\    for(foo()) ({})
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - for expression",
        \\export fn entry() {
        \\    _ = for(foo()) {};
        \\    var good = {};
        \\    _ = for(foo()) {}
        \\    var bad = {};
        \\}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("multiple function definitions",
        \\fn a() {}
        \\fn a() {}
        \\export fn entry() { a(); }
    , ".tmp_source.zig:2:1: error: redefinition of 'a'");

    cases.add("unreachable with return",
        \\fn a() -> noreturn {return;}
        \\export fn entry() { a(); }
    , ".tmp_source.zig:1:21: error: expected type 'noreturn', found 'void'");

    cases.add("control reaches end of non-void function",
        \\fn a() -> i32 {}
        \\export fn entry() { _ = a(); }
    , ".tmp_source.zig:1:15: error: expected type 'i32', found 'void'");

    cases.add("undefined function call",
        \\export fn a() {
        \\    b();
        \\}
    , ".tmp_source.zig:2:5: error: use of undeclared identifier 'b'");

    cases.add("wrong number of arguments",
        \\export fn a() {
        \\    b(1);
        \\}
        \\fn b(a: i32, b: i32, c: i32) { }
    , ".tmp_source.zig:2:6: error: expected 3 arguments, found 1");

    cases.add("invalid type",
        \\fn a() -> bogus {}
        \\export fn entry() { _ = a(); }
    , ".tmp_source.zig:1:11: error: use of undeclared identifier 'bogus'");

    cases.add("pointer to unreachable",
        \\fn a() -> &noreturn {}
        \\export fn entry() { _ = a(); }
    , ".tmp_source.zig:1:12: error: pointer to unreachable not allowed");

    cases.add("unreachable code",
        \\export fn a() {
        \\    return;
        \\    b();
        \\}
        \\
        \\fn b() {}
    , ".tmp_source.zig:3:6: error: unreachable code");

    cases.add("bad import",
        \\const bogus = @import("bogus-does-not-exist.zig");
        \\export fn entry() { bogus.bogo(); }
    , ".tmp_source.zig:1:15: error: unable to find 'bogus-does-not-exist.zig'");

    cases.add("undeclared identifier",
        \\export fn a() {
        \\    b +
        \\    c
        \\}
    ,
            ".tmp_source.zig:2:5: error: use of undeclared identifier 'b'",
            ".tmp_source.zig:3:5: error: use of undeclared identifier 'c'");

    cases.add("parameter redeclaration",
        \\fn f(a : i32, a : i32) {
        \\}
        \\export fn entry() { f(1, 2); }
    , ".tmp_source.zig:1:15: error: redeclaration of variable 'a'");

    cases.add("local variable redeclaration",
        \\export fn f() {
        \\    const a : i32 = 0;
        \\    const a = 0;
        \\}
    , ".tmp_source.zig:3:5: error: redeclaration of variable 'a'");

    cases.add("local variable redeclares parameter",
        \\fn f(a : i32) {
        \\    const a = 0;
        \\}
        \\export fn entry() { f(1); }
    , ".tmp_source.zig:2:5: error: redeclaration of variable 'a'");

    cases.add("variable has wrong type",
        \\export fn f() -> i32 {
        \\    const a = c"a";
        \\    a
        \\}
    , ".tmp_source.zig:3:5: error: expected type 'i32', found '&const u8'");

    cases.add("if condition is bool, not int",
        \\export fn f() {
        \\    if (0) {}
        \\}
    , ".tmp_source.zig:2:9: error: integer value 0 cannot be implicitly casted to type 'bool'");

    cases.add("assign unreachable",
        \\export fn f() {
        \\    const a = return;
        \\}
    , ".tmp_source.zig:2:5: error: unreachable code");

    cases.add("unreachable variable",
        \\export fn f() {
        \\    const a: noreturn = {};
        \\}
    , ".tmp_source.zig:2:14: error: variable of type 'noreturn' not allowed");

    cases.add("unreachable parameter",
        \\fn f(a: noreturn) {}
        \\export fn entry() { f(); }
    , ".tmp_source.zig:1:9: error: parameter of type 'noreturn' not allowed");

    cases.add("bad assignment target",
        \\export fn f() {
        \\    3 = 3;
        \\}
    , ".tmp_source.zig:2:7: error: cannot assign to constant");

    cases.add("assign to constant variable",
        \\export fn f() {
        \\    const a = 3;
        \\    a = 4;
        \\}
    , ".tmp_source.zig:3:7: error: cannot assign to constant");

    cases.add("use of undeclared identifier",
        \\export fn f() {
        \\    b = 3;
        \\}
    , ".tmp_source.zig:2:5: error: use of undeclared identifier 'b'");

    cases.add("const is a statement, not an expression",
        \\export fn f() {
        \\    (const a = 0);
        \\}
    , ".tmp_source.zig:2:6: error: invalid token: 'const'");

    cases.add("array access of undeclared identifier",
        \\export fn f() {
        \\    i[i] = i[i];
        \\}
    , ".tmp_source.zig:2:5: error: use of undeclared identifier 'i'",
                 ".tmp_source.zig:2:12: error: use of undeclared identifier 'i'");

    cases.add("array access of non array",
        \\export fn f() {
        \\    var bad : bool = undefined;
        \\    bad[bad] = bad[bad];
        \\}
    , ".tmp_source.zig:3:8: error: array access of non-array type 'bool'",
                 ".tmp_source.zig:3:19: error: array access of non-array type 'bool'");

    cases.add("array access with non integer index",
        \\export fn f() {
        \\    var array = "aoeu";
        \\    var bad = false;
        \\    array[bad] = array[bad];
        \\}
    , ".tmp_source.zig:4:11: error: expected type 'usize', found 'bool'",
                 ".tmp_source.zig:4:24: error: expected type 'usize', found 'bool'");

    cases.add("write to const global variable",
        \\const x : i32 = 99;
        \\fn f() {
        \\    x = 1;
        \\}
        \\export fn entry() { f(); }
    , ".tmp_source.zig:3:7: error: cannot assign to constant");


    cases.add("missing else clause",
        \\fn f(b: bool) {
        \\    const x : i32 = if (b) { 1 };
        \\    const y = if (b) { i32(1) };
        \\}
        \\export fn entry() { f(true); }
    , ".tmp_source.zig:2:30: error: integer value 1 cannot be implicitly casted to type 'void'",
                 ".tmp_source.zig:3:15: error: incompatible types: 'i32' and 'void'");

    cases.add("direct struct loop",
        \\const A = struct { a : A, };
        \\export fn entry() -> usize { @sizeOf(A) }
    , ".tmp_source.zig:1:11: error: struct 'A' contains itself");

    cases.add("indirect struct loop",
        \\const A = struct { b : B, };
        \\const B = struct { c : C, };
        \\const C = struct { a : A, };
        \\export fn entry() -> usize { @sizeOf(A) }
    , ".tmp_source.zig:1:11: error: struct 'A' contains itself");

    cases.add("invalid struct field",
        \\const A = struct { x : i32, };
        \\export fn f() {
        \\    var a : A = undefined;
        \\    a.foo = 1;
        \\    const y = a.bar;
        \\}
    ,
            ".tmp_source.zig:4:6: error: no member named 'foo' in 'A'",
            ".tmp_source.zig:5:16: error: no member named 'bar' in 'A'");

    cases.add("redefinition of struct",
        \\const A = struct { x : i32, };
        \\const A = struct { y : i32, };
    , ".tmp_source.zig:2:1: error: redefinition of 'A'");

    cases.add("redefinition of enums",
        \\const A = enum {};
        \\const A = enum {};
    , ".tmp_source.zig:2:1: error: redefinition of 'A'");

    cases.add("redefinition of global variables",
        \\var a : i32 = 1;
        \\var a : i32 = 2;
    ,
            ".tmp_source.zig:2:1: error: redefinition of 'a'",
            ".tmp_source.zig:1:1: note: previous definition is here");

    cases.add("byvalue struct parameter in exported function",
        \\const A = struct { x : i32, };
        \\export fn f(a : A) {}
    , ".tmp_source.zig:2:13: error: byvalue types not yet supported on extern function parameters");

    cases.add("byvalue struct return value in exported function",
        \\const A = struct { x: i32, };
        \\export fn f() -> A {
        \\    A {.x = 1234 }
        \\}
    , ".tmp_source.zig:2:18: error: byvalue types not yet supported on extern function return values");

    cases.add("duplicate field in struct value expression",
        \\const A = struct {
        \\    x : i32,
        \\    y : i32,
        \\    z : i32,
        \\};
        \\export fn f() {
        \\    const a = A {
        \\        .z = 1,
        \\        .y = 2,
        \\        .x = 3,
        \\        .z = 4,
        \\    };
        \\}
    , ".tmp_source.zig:11:9: error: duplicate field");

    cases.add("missing field in struct value expression",
        \\const A = struct {
        \\    x : i32,
        \\    y : i32,
        \\    z : i32,
        \\};
        \\export fn f() {
        \\    // we want the error on the '{' not the 'A' because
        \\    // the A could be a complicated expression
        \\    const a = A {
        \\        .z = 4,
        \\        .y = 2,
        \\    };
        \\}
    , ".tmp_source.zig:9:17: error: missing field: 'x'");

    cases.add("invalid field in struct value expression",
        \\const A = struct {
        \\    x : i32,
        \\    y : i32,
        \\    z : i32,
        \\};
        \\export fn f() {
        \\    const a = A {
        \\        .z = 4,
        \\        .y = 2,
        \\        .foo = 42,
        \\    };
        \\}
    , ".tmp_source.zig:10:9: error: no member named 'foo' in 'A'");

    cases.add("invalid break expression",
        \\export fn f() {
        \\    break;
        \\}
    , ".tmp_source.zig:2:5: error: 'break' expression outside loop");

    cases.add("invalid continue expression",
        \\export fn f() {
        \\    continue;
        \\}
    , ".tmp_source.zig:2:5: error: 'continue' expression outside loop");

    cases.add("invalid maybe type",
        \\export fn f() {
        \\    test (true) |x| { }
        \\}
    , ".tmp_source.zig:2:11: error: expected nullable type, found 'bool'");

    cases.add("cast unreachable",
        \\fn f() -> i32 {
        \\    i32(return 1)
        \\}
        \\export fn entry() { _ = f(); }
    , ".tmp_source.zig:2:8: error: unreachable code");

    cases.add("invalid builtin fn",
        \\fn f() -> @bogus(foo) {
        \\}
        \\export fn entry() { _ = f(); }
    , ".tmp_source.zig:1:11: error: invalid builtin function: 'bogus'");

    cases.add("top level decl dependency loop",
        \\const a : @typeOf(b) = 0;
        \\const b : @typeOf(a) = 0;
        \\export fn entry() {
        \\    const c = a + b;
        \\}
    , ".tmp_source.zig:1:1: error: 'a' depends on itself");

    cases.add("noalias on non pointer param",
        \\fn f(noalias x: i32) {}
        \\export fn entry() { f(1234); }
    , ".tmp_source.zig:1:6: error: noalias on non-pointer parameter");

    cases.add("struct init syntax for array",
        \\const foo = []u16{.x = 1024,};
        \\export fn entry() -> usize { @sizeOf(@typeOf(foo)) }
    , ".tmp_source.zig:1:18: error: type '[]u16' does not support struct initialization syntax");

    cases.add("type variables must be constant",
        \\var foo = u8;
        \\export fn entry() -> foo {
        \\    return 1;
        \\}
    , ".tmp_source.zig:1:1: error: variable of type 'type' must be constant");


    cases.add("variables shadowing types",
        \\const Foo = struct {};
        \\const Bar = struct {};
        \\
        \\fn f(Foo: i32) {
        \\    var Bar : i32 = undefined;
        \\}
        \\
        \\export fn entry() {
        \\    f(1234);
        \\}
    ,
            ".tmp_source.zig:4:6: error: redefinition of 'Foo'",
            ".tmp_source.zig:1:1: note: previous definition is here",
            ".tmp_source.zig:5:5: error: redefinition of 'Bar'",
            ".tmp_source.zig:2:1: note: previous definition is here");

    cases.add("multiple else prongs in a switch",
        \\fn f(x: u32) {
        \\    const value: bool = switch (x) {
        \\        1234 => false,
        \\        else => true,
        \\        else => true,
        \\    };
        \\}
        \\export fn entry() {
        \\    f(1234);
        \\}
    , ".tmp_source.zig:5:9: error: multiple else prongs in switch expression");

    cases.add("global variable initializer must be constant expression",
        \\extern fn foo() -> i32;
        \\const x = foo();
        \\export fn entry() -> i32 { x }
    , ".tmp_source.zig:2:11: error: unable to evaluate constant expression");

    cases.add("array concatenation with wrong type",
        \\const src = "aoeu";
        \\const derp = usize(1234);
        \\const a = derp ++ "foo";
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(a)) }
    , ".tmp_source.zig:3:11: error: expected array or C string literal, found 'usize'");

    cases.add("non compile time array concatenation",
        \\fn f() -> []u8 {
        \\    s ++ "foo"
        \\}
        \\var s: [10]u8 = undefined;
        \\export fn entry() -> usize { @sizeOf(@typeOf(f)) }
    , ".tmp_source.zig:2:5: error: unable to evaluate constant expression");

    cases.add("@cImport with bogus include",
        \\const c = @cImport(@cInclude("bogus.h"));
        \\export fn entry() -> usize { @sizeOf(@typeOf(c.bogo)) }
    , ".tmp_source.zig:1:11: error: C import failed",
                 ".h:1:10: note: 'bogus.h' file not found");

    cases.add("address of number literal",
        \\const x = 3;
        \\const y = &x;
        \\fn foo() -> &const i32 { y }
        \\export fn entry() -> usize { @sizeOf(@typeOf(foo)) }
    , ".tmp_source.zig:3:26: error: expected type '&const i32', found '&const (integer literal)'");

    cases.add("integer overflow error",
        \\const x : u8 = 300;
        \\export fn entry() -> usize { @sizeOf(@typeOf(x)) }
    , ".tmp_source.zig:1:16: error: integer value 300 cannot be implicitly casted to type 'u8'");

    cases.add("incompatible number literals",
        \\const x = 2 == 2.0;
        \\export fn entry() -> usize { @sizeOf(@typeOf(x)) }
    , ".tmp_source.zig:1:11: error: integer value 2 cannot be implicitly casted to type '(float literal)'");

    cases.add("missing function call param",
        \\const Foo = struct {
        \\    a: i32,
        \\    b: i32,
        \\
        \\    fn member_a(foo: &const Foo) -> i32 {
        \\        return foo.a;
        \\    }
        \\    fn member_b(foo: &const Foo) -> i32 {
        \\        return foo.b;
        \\    }
        \\};
        \\
        \\const member_fn_type = @typeOf(Foo.member_a);
        \\const members = []member_fn_type {
        \\    Foo.member_a,
        \\    Foo.member_b,
        \\};
        \\
        \\fn f(foo: &const Foo, index: usize) {
        \\    const result = members[index]();
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(f)) }
    , ".tmp_source.zig:20:34: error: expected 1 arguments, found 0");

    cases.add("missing function name and param name",
        \\fn () {}
        \\fn f(i32) {}
        \\export fn entry() -> usize { @sizeOf(@typeOf(f)) }
    ,
            ".tmp_source.zig:1:1: error: missing function name",
            ".tmp_source.zig:2:6: error: missing parameter name");

    cases.add("wrong function type",
        \\const fns = []fn(){ a, b, c };
        \\fn a() -> i32 {0}
        \\fn b() -> i32 {1}
        \\fn c() -> i32 {2}
        \\export fn entry() -> usize { @sizeOf(@typeOf(fns)) }
    , ".tmp_source.zig:1:21: error: expected type 'fn()', found 'fn() -> i32'");

    cases.add("extern function pointer mismatch",
        \\const fns = [](fn(i32)->i32){ a, b, c };
        \\pub fn a(x: i32) -> i32 {x + 0}
        \\pub fn b(x: i32) -> i32 {x + 1}
        \\export fn c(x: i32) -> i32 {x + 2}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(fns)) }
    , ".tmp_source.zig:1:37: error: expected type 'fn(i32) -> i32', found 'extern fn(i32) -> i32'");


    cases.add("implicit cast from f64 to f32",
        \\const x : f64 = 1.0;
        \\const y : f32 = x;
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(y)) }
    , ".tmp_source.zig:2:17: error: expected type 'f32', found 'f64'");


    cases.add("colliding invalid top level functions",
        \\fn func() -> bogus {}
        \\fn func() -> bogus {}
        \\export fn entry() -> usize { @sizeOf(@typeOf(func)) }
    ,
            ".tmp_source.zig:2:1: error: redefinition of 'func'",
            ".tmp_source.zig:1:14: error: use of undeclared identifier 'bogus'");


    cases.add("bogus compile var",
        \\const x = @compileVar("bogus");
        \\export fn entry() -> usize { @sizeOf(@typeOf(x)) }
    , ".tmp_source.zig:1:23: error: unrecognized compile variable: 'bogus'");


    cases.add("non constant expression in array size outside function",
        \\const Foo = struct {
        \\    y: [get()]u8,
        \\};
        \\var global_var: usize = 1;
        \\fn get() -> usize { global_var }
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(Foo)) }
    ,
            ".tmp_source.zig:5:21: error: unable to evaluate constant expression",
            ".tmp_source.zig:2:12: note: called from here",
            ".tmp_source.zig:2:8: note: called from here");


    cases.add("addition with non numbers",
        \\const Foo = struct {
        \\    field: i32,
        \\};
        \\const x = Foo {.field = 1} + Foo {.field = 2};
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(x)) }
    , ".tmp_source.zig:4:28: error: invalid operands to binary expression: 'Foo' and 'Foo'");


    cases.add("division by zero",
        \\const lit_int_x = 1 / 0;
        \\const lit_float_x = 1.0 / 0.0;
        \\const int_x = i32(1) / i32(0);
        \\const float_x = f32(1.0) / f32(0.0);
        \\
        \\export fn entry1() -> usize { @sizeOf(@typeOf(lit_int_x)) }
        \\export fn entry2() -> usize { @sizeOf(@typeOf(lit_float_x)) }
        \\export fn entry3() -> usize { @sizeOf(@typeOf(int_x)) }
        \\export fn entry4() -> usize { @sizeOf(@typeOf(float_x)) }
    ,
            ".tmp_source.zig:1:21: error: division by zero is undefined",
            ".tmp_source.zig:2:25: error: division by zero is undefined",
            ".tmp_source.zig:3:22: error: division by zero is undefined",
            ".tmp_source.zig:4:26: error: division by zero is undefined");


    cases.add("missing switch prong",
        \\const Number = enum {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\};
        \\fn f(n: Number) -> i32 {
        \\    switch (n) {
        \\        Number.One => 1,
        \\        Number.Two => 2,
        \\        Number.Three => i32(3),
        \\    }
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(f)) }
    , ".tmp_source.zig:8:5: error: enumeration value 'Number.Four' not handled in switch");

    cases.add("normal string with newline",
        \\const foo = "a
        \\b";
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(foo)) }
    , ".tmp_source.zig:1:13: error: newline not allowed in string literal");

    cases.add("invalid comparison for function pointers",
        \\fn foo() {}
        \\const invalid = foo > foo;
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(invalid)) }
    , ".tmp_source.zig:2:21: error: operator not allowed for type 'fn()'");

    cases.add("generic function instance with non-constant expression",
        \\fn foo(comptime x: i32, y: i32) -> i32 { return x + y; }
        \\fn test1(a: i32, b: i32) -> i32 {
        \\    return foo(a, b);
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(test1)) }
    , ".tmp_source.zig:3:16: error: unable to evaluate constant expression");

    cases.add("goto jumping into block",
        \\export fn f() {
        \\    {
        \\a_label:
        \\    }
        \\    goto a_label;
        \\}
    , ".tmp_source.zig:5:5: error: no label in scope named 'a_label'");

    cases.add("goto jumping past a defer",
        \\fn f(b: bool) {
        \\    if (b) goto label;
        \\    defer derp();
        \\label:
        \\}
        \\fn derp(){}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(f)) }
    , ".tmp_source.zig:2:12: error: no label in scope named 'label'");

    cases.add("assign null to non-nullable pointer",
        \\const a: &u8 = null;
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(a)) }
    , ".tmp_source.zig:1:16: error: expected type '&u8', found '(null)'");

    cases.add("indexing an array of size zero",
        \\const array = []u8{};
        \\export fn foo() {
        \\    const pointer = &array[0];
        \\}
    , ".tmp_source.zig:3:27: error: index 0 outside array of size 0");

    cases.add("compile time division by zero",
        \\const y = foo(0);
        \\fn foo(x: i32) -> i32 {
        \\    1 / x
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(y)) }
    ,
            ".tmp_source.zig:3:7: error: division by zero is undefined",
            ".tmp_source.zig:1:14: note: called from here");

    cases.add("branch on undefined value",
        \\const x = if (undefined) true else false;
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(x)) }
    , ".tmp_source.zig:1:15: error: use of undefined value");


    cases.add("endless loop in function evaluation",
        \\const seventh_fib_number = fibbonaci(7);
        \\fn fibbonaci(x: i32) -> i32 {
        \\    return fibbonaci(x - 1) + fibbonaci(x - 2);
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(seventh_fib_number)) }
    ,
            ".tmp_source.zig:3:21: error: evaluation exceeded 1000 backwards branches",
            ".tmp_source.zig:3:21: note: called from here");

    cases.add("@embedFile with bogus file",
        \\const resource = @embedFile("bogus.txt");
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(resource)) }
    , ".tmp_source.zig:1:29: error: unable to find '", "/bogus.txt'");

    cases.add("non-const expression in struct literal outside function",
        \\const Foo = struct {
        \\    x: i32,
        \\};
        \\const a = Foo {.x = get_it()};
        \\extern fn get_it() -> i32;
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(a)) }
    , ".tmp_source.zig:4:21: error: unable to evaluate constant expression");

    cases.add("non-const expression function call with struct return value outside function",
        \\const Foo = struct {
        \\    x: i32,
        \\};
        \\const a = get_it();
        \\fn get_it() -> Foo {
        \\    global_side_effect = true;
        \\    Foo {.x = 13}
        \\}
        \\var global_side_effect = false;
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(a)) }
    ,
            ".tmp_source.zig:6:24: error: unable to evaluate constant expression",
            ".tmp_source.zig:4:17: note: called from here");

    cases.add("undeclared identifier error should mark fn as impure",
        \\export fn foo() {
        \\    test_a_thing();
        \\}
        \\fn test_a_thing() {
        \\    bad_fn_call();
        \\}
    , ".tmp_source.zig:5:5: error: use of undeclared identifier 'bad_fn_call'");

    cases.add("illegal comparison of types",
        \\fn bad_eql_1(a: []u8, b: []u8) -> bool {
        \\    a == b
        \\}
        \\const EnumWithData = enum {
        \\    One,
        \\    Two: i32,
        \\};
        \\fn bad_eql_2(a: &const EnumWithData, b: &const EnumWithData) -> bool {
        \\    *a == *b
        \\}
        \\
        \\export fn entry1() -> usize { @sizeOf(@typeOf(bad_eql_1)) }
        \\export fn entry2() -> usize { @sizeOf(@typeOf(bad_eql_2)) }
    ,
            ".tmp_source.zig:2:7: error: operator not allowed for type '[]u8'",
            ".tmp_source.zig:9:8: error: operator not allowed for type 'EnumWithData'");

    cases.add("non-const switch number literal",
        \\export fn foo() {
        \\    const x = switch (bar()) {
        \\        1, 2 => 1,
        \\        3, 4 => 2,
        \\        else => 3,
        \\    };
        \\}
        \\fn bar() -> i32 {
        \\    2
        \\}
    , ".tmp_source.zig:2:15: error: unable to infer expression type");

    cases.add("atomic orderings of cmpxchg - failure stricter than success",
        \\export fn f() {
        \\    var x: i32 = 1234;
        \\    while (!@cmpxchg(&x, 1234, 5678, AtomicOrder.Monotonic, AtomicOrder.SeqCst)) {}
        \\}
    , ".tmp_source.zig:3:72: error: failure atomic ordering must be no stricter than success");

    cases.add("atomic orderings of cmpxchg - success Monotonic or stricter",
        \\export fn f() {
        \\    var x: i32 = 1234;
        \\    while (!@cmpxchg(&x, 1234, 5678, AtomicOrder.Unordered, AtomicOrder.Unordered)) {}
        \\}
    , ".tmp_source.zig:3:49: error: success atomic ordering must be Monotonic or stricter");

    cases.add("negation overflow in function evaluation",
        \\const y = neg(-128);
        \\fn neg(x: i8) -> i8 {
        \\    -x
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(y)) }
    ,
            ".tmp_source.zig:3:5: error: negation caused overflow",
            ".tmp_source.zig:1:14: note: called from here");

    cases.add("add overflow in function evaluation",
        \\const y = add(65530, 10);
        \\fn add(a: u16, b: u16) -> u16 {
        \\    a + b
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(y)) }
    ,
            ".tmp_source.zig:3:7: error: operation caused overflow",
            ".tmp_source.zig:1:14: note: called from here");


    cases.add("sub overflow in function evaluation",
        \\const y = sub(10, 20);
        \\fn sub(a: u16, b: u16) -> u16 {
        \\    a - b
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(y)) }
    ,
            ".tmp_source.zig:3:7: error: operation caused overflow",
            ".tmp_source.zig:1:14: note: called from here");

    cases.add("mul overflow in function evaluation",
        \\const y = mul(300, 6000);
        \\fn mul(a: u16, b: u16) -> u16 {
        \\    a * b
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(y)) }
    ,
            ".tmp_source.zig:3:7: error: operation caused overflow",
            ".tmp_source.zig:1:14: note: called from here");

    cases.add("truncate sign mismatch",
        \\fn f() -> i8 {
        \\    const x: u32 = 10;
        \\    @truncate(i8, x)
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(f)) }
    , ".tmp_source.zig:3:19: error: expected signed integer type, found 'u32'");

    cases.add("%return in function with non error return type",
        \\export fn f() {
        \\    %return something();
        \\}
        \\fn something() -> %void { }
    ,
            ".tmp_source.zig:2:5: error: expected type 'void', found 'error'");

    cases.add("wrong return type for main",
        \\pub fn main() { }
    , ".tmp_source.zig:1:15: error: expected return type of main to be '%void', instead is 'void'");

    cases.add("double ?? on main return value",
        \\pub fn main() -> ??void {
        \\}
    , ".tmp_source.zig:1:18: error: expected return type of main to be '%void', instead is '??void'");

    cases.add("invalid pointer for var type",
        \\extern fn ext() -> usize;
        \\var bytes: [ext()]u8 = undefined;
        \\export fn f() {
        \\    for (bytes) |*b, i| {
        \\        *b = u8(i);
        \\    }
        \\}
    , ".tmp_source.zig:2:13: error: unable to evaluate constant expression");

    cases.add("export function with comptime parameter",
        \\export fn foo(comptime x: i32, y: i32) -> i32{
        \\    x + y
        \\}
    , ".tmp_source.zig:1:15: error: comptime parameter not allowed in extern function");

    cases.add("extern function with comptime parameter",
        \\extern fn foo(comptime x: i32, y: i32) -> i32;
        \\fn f() -> i32 {
        \\    foo(1, 2)
        \\}
        \\export fn entry() -> usize { @sizeOf(@typeOf(f)) }
    , ".tmp_source.zig:1:15: error: comptime parameter not allowed in extern function");

    cases.add("convert fixed size array to slice with invalid size",
        \\export fn f() {
        \\    var array: [5]u8 = undefined;
        \\    var foo = ([]const u32)(array)[0];
        \\}
    , ".tmp_source.zig:3:28: error: unable to convert [5]u8 to []const u32: size mismatch");

    cases.add("non-pure function returns type",
        \\var a: u32 = 0;
        \\pub fn List(comptime T: type) -> type {
        \\    a += 1;
        \\    SmallList(T, 8)
        \\}
        \\
        \\pub fn SmallList(comptime T: type, comptime STATIC_SIZE: usize) -> type {
        \\    struct {
        \\        items: []T,
        \\        length: usize,
        \\        prealloc_items: [STATIC_SIZE]T,
        \\    }
        \\}
        \\
        \\export fn function_with_return_type_type() {
        \\    var list: List(i32) = undefined;
        \\    list.length = 10;
        \\}
    , ".tmp_source.zig:3:7: error: unable to evaluate constant expression",
        ".tmp_source.zig:16:19: note: called from here");

    cases.add("bogus method call on slice",
        \\var self = "aoeu";
        \\fn f(m: []const u8) {
        \\    m.copy(u8, self[0...], m);
        \\}
        \\export fn entry() -> usize { @sizeOf(@typeOf(f)) }
    , ".tmp_source.zig:3:6: error: no member named 'copy' in '[]const u8'");

    cases.add("wrong number of arguments for method fn call",
        \\const Foo = struct {
        \\    fn method(self: &const Foo, a: i32) {}
        \\};
        \\fn f(foo: &const Foo) {
        \\
        \\    foo.method(1, 2);
        \\}
        \\export fn entry() -> usize { @sizeOf(@typeOf(f)) }
    , ".tmp_source.zig:6:15: error: expected 2 arguments, found 3");

    cases.add("assign through constant pointer",
        \\export fn f() {
        \\  var cstr = c"Hat";
        \\  cstr[0] = 'W';
        \\}
    , ".tmp_source.zig:3:11: error: cannot assign to constant");

    cases.add("assign through constant slice",
        \\export fn f() {
        \\  var cstr: []const u8 = "Hat";
        \\  cstr[0] = 'W';
        \\}
    , ".tmp_source.zig:3:11: error: cannot assign to constant");

    cases.add("main function with bogus args type",
        \\pub fn main(args: [][]bogus) -> %void {}
    , ".tmp_source.zig:1:23: error: use of undeclared identifier 'bogus'");

    cases.add("for loop missing element param",
        \\fn foo(blah: []u8) {
        \\    for (blah) { }
        \\}
        \\export fn entry() -> usize { @sizeOf(@typeOf(foo)) }
    , ".tmp_source.zig:2:5: error: for loop expression missing element parameter");

    cases.add("misspelled type with pointer only reference",
        \\const JasonHM = u8;
        \\const JasonList = &JsonNode;
        \\
        \\const JsonOA = enum {
        \\    JSONArray: JsonList,
        \\    JSONObject: JasonHM,
        \\};
        \\
        \\const JsonType = enum {
        \\    JSONNull: void,
        \\    JSONInteger: isize,
        \\    JSONDouble: f64,
        \\    JSONBool: bool,
        \\    JSONString: []u8,
        \\    JSONArray,
        \\    JSONObject,
        \\};
        \\
        \\pub const JsonNode = struct {
        \\    kind: JsonType,
        \\    jobject: ?JsonOA,
        \\};
        \\
        \\fn foo() {
        \\    var jll: JasonList = undefined;
        \\    jll.init(1234);
        \\    var jd = JsonNode {.kind = JsonType.JSONArray , .jobject = JsonOA.JSONArray {jll} };
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(foo)) }
    , ".tmp_source.zig:5:16: error: use of undeclared identifier 'JsonList'");

    cases.add("method call with first arg type primitive",
        \\const Foo = struct {
        \\    x: i32,
        \\
        \\    fn init(x: i32) -> Foo {
        \\        Foo {
        \\            .x = x,
        \\        }
        \\    }
        \\};
        \\
        \\export fn f() {
        \\    const derp = Foo.init(3);
        \\
        \\    derp.init();
        \\}
    , ".tmp_source.zig:14:5: error: expected type 'i32', found '&const Foo'");

    cases.add("method call with first arg type wrong container",
        \\pub const List = struct {
        \\    len: usize,
        \\    allocator: &Allocator,
        \\
        \\    pub fn init(allocator: &Allocator) -> List {
        \\        List {
        \\            .len = 0,
        \\            .allocator = allocator,
        \\        }
        \\    }
        \\};
        \\
        \\pub var global_allocator = Allocator {
        \\    .field = 1234,
        \\};
        \\
        \\pub const Allocator = struct {
        \\    field: i32,
        \\};
        \\
        \\export fn foo() {
        \\    var x = List.init(&global_allocator);
        \\    x.init();
        \\}
    , ".tmp_source.zig:23:5: error: expected type '&Allocator', found '&List'");

    cases.add("binary not on number literal",
        \\const TINY_QUANTUM_SHIFT = 4;
        \\const TINY_QUANTUM_SIZE = 1 << TINY_QUANTUM_SHIFT;
        \\var block_aligned_stuff: usize = (4 + TINY_QUANTUM_SIZE) & ~(TINY_QUANTUM_SIZE - 1);
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(block_aligned_stuff)) }
    , ".tmp_source.zig:3:60: error: unable to perform binary not operation on type '(integer literal)'");

    cases.addCase({
        const tc = cases.create("multiple files with private function error",
            \\const foo = @import("foo.zig");
            \\
            \\export fn callPrivFunction() {
            \\    foo.privateFunction();
            \\}
        ,
            ".tmp_source.zig:4:8: error: 'privateFunction' is private",
            "foo.zig:1:1: note: declared here");

        tc.addSourceFile("foo.zig",
            \\fn privateFunction() { }
        );

        tc
    });

    cases.add("container init with non-type",
        \\const zero: i32 = 0;
        \\const a = zero{1};
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(a)) }
    , ".tmp_source.zig:2:11: error: expected type, found 'i32'");

    cases.add("assign to constant field",
        \\const Foo = struct {
        \\    field: i32,
        \\};
        \\export fn derp() {
        \\    const f = Foo {.field = 1234,};
        \\    f.field = 0;
        \\}
    , ".tmp_source.zig:6:13: error: cannot assign to constant");

    cases.add("return from defer expression",
        \\pub fn testTrickyDefer() -> %void {
        \\    defer canFail() %% {};
        \\
        \\    defer %return canFail();
        \\
        \\    const a = maybeInt() ?? return;
        \\}
        \\
        \\fn canFail() -> %void { }
        \\
        \\pub fn maybeInt() -> ?i32 {
        \\    return 0;
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(testTrickyDefer)) }
    , ".tmp_source.zig:4:11: error: cannot return from defer expression");

    cases.add("attempt to access var args out of bounds",
        \\fn add(args: ...) -> i32 {
        \\    args[0] + args[1]
        \\}
        \\
        \\fn foo() -> i32 {
        \\    add(i32(1234))
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(foo)) }
    ,
            ".tmp_source.zig:2:19: error: index 1 outside argument list of size 1",
            ".tmp_source.zig:6:8: note: called from here");

    cases.add("pass integer literal to var args",
        \\fn add(args: ...) -> i32 {
        \\    var sum = i32(0);
        \\    {comptime var i: usize = 0; inline while (i < args.len; i += 1) {
        \\        sum += args[i];
        \\    }}
        \\    return sum;
        \\}
        \\
        \\fn bar() -> i32 {
        \\    add(1, 2, 3, 4)
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(bar)) }
    , ".tmp_source.zig:10:9: error: parameter of type '(integer literal)' requires comptime");

    cases.add("assign too big number to u16",
        \\export fn foo() {
        \\    var vga_mem: u16 = 0xB8000;
        \\}
    , ".tmp_source.zig:2:24: error: integer value 753664 cannot be implicitly casted to type 'u16'");

    cases.add("set global variable alignment to non power of 2",
        \\const some_data: [100]u8 = undefined;
        \\comptime {
        \\    @setGlobalAlign(some_data, 3);
        \\}
        \\export fn entry() -> usize { @sizeOf(@typeOf(some_data)) }
    , ".tmp_source.zig:3:32: error: alignment value must be power of 2");

    cases.add("compile log",
        \\export fn foo() {
        \\    comptime bar(12, "hi");
        \\}
        \\fn bar(a: i32, b: []const u8) {
        \\    @compileLog("begin");
        \\    @compileLog("a", a, "b", b);
        \\    @compileLog("end");
        \\}
    ,
        ".tmp_source.zig:5:5: error: found compile log statement",
        ".tmp_source.zig:2:17: note: called from here",
        ".tmp_source.zig:6:5: error: found compile log statement",
        ".tmp_source.zig:2:17: note: called from here",
        ".tmp_source.zig:7:5: error: found compile log statement",
        ".tmp_source.zig:2:17: note: called from here");

    cases.add("casting bit offset pointer to regular pointer",
        \\const u2 = @IntType(false, 2);
        \\const u3 = @IntType(false, 3);
        \\
        \\const BitField = packed struct {
        \\    a: u3,
        \\    b: u3,
        \\    c: u2,
        \\};
        \\
        \\fn foo(bit_field: &const BitField) -> u3 {
        \\    return bar(&bit_field.b);
        \\}
        \\
        \\fn bar(x: &const u3) -> u3 {
        \\    return *x;
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(foo)) }
    , ".tmp_source.zig:11:26: error: expected type '&const u3', found '&:3:6 const u3'");

    cases.add("referring to a struct that is invalid",
        \\const UsbDeviceRequest = struct {
        \\    Type: u8,
        \\};
        \\
        \\export fn foo() {
        \\    comptime assert(@sizeOf(UsbDeviceRequest) == 0x8);
        \\}
        \\
        \\fn assert(ok: bool) {
        \\    if (!ok) unreachable;
        \\}
    ,
            ".tmp_source.zig:10:14: error: unable to evaluate constant expression",
            ".tmp_source.zig:6:20: note: called from here");

    cases.add("control flow uses comptime var at runtime",
        \\export fn foo() {
        \\    comptime var i = 0;
        \\    while (i < 5; i += 1) {
        \\        bar();
        \\    }
        \\}
        \\
        \\fn bar() { }
    ,
            ".tmp_source.zig:3:5: error: control flow attempts to use compile-time variable at runtime",
            ".tmp_source.zig:3:21: note: compile-time variable assigned here");

    cases.add("ignored return value",
        \\export fn foo() {
        \\    bar();
        \\}
        \\fn bar() -> i32 { 0 }
    , ".tmp_source.zig:2:8: error: return value ignored");

    cases.add("integer literal on a non-comptime var",
        \\export fn foo() {
        \\    var i = 0;
        \\    while (i < 10; i += 1) { }
        \\}
    , ".tmp_source.zig:2:5: error: unable to infer variable type");

    cases.add("undefined literal on a non-comptime var",
        \\export fn foo() {
        \\    var i = undefined;
        \\    i = i32(1);
        \\}
    , ".tmp_source.zig:2:5: error: unable to infer variable type");

    cases.add("dereference an array",
        \\var s_buffer: [10]u8 = undefined;
        \\pub fn pass(in: []u8) -> []u8 {
        \\    var out = &s_buffer;
        \\    *out[0] = in[0];
        \\    return (*out)[0...1];
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(pass)) }
    , ".tmp_source.zig:4:5: error: attempt to dereference non pointer type '[10]u8'");

    cases.add("pass const ptr to mutable ptr fn",
        \\fn foo() -> bool {
        \\    const a = ([]const u8)("a");
        \\    const b = &a;
        \\    return ptrEql(b, b);
        \\}
        \\fn ptrEql(a: &[]const u8, b: &[]const u8) -> bool {
        \\    return true;
        \\}
        \\
        \\export fn entry() -> usize { @sizeOf(@typeOf(foo)) }
    , ".tmp_source.zig:4:19: error: expected type '&[]const u8', found '&const []const u8'");

    cases.addCase({
        const tc = cases.create("export collision",
            \\const foo = @import("foo.zig");
            \\
            \\export fn bar() -> usize {
            \\    return foo.baz;
            \\}
        ,
            "foo.zig:1:8: error: exported symbol collision: 'bar'",
            ".tmp_source.zig:3:8: note: other symbol is here");

        tc.addSourceFile("foo.zig",
            \\export fn bar() {}
            \\pub const baz = 1234;
        );

        tc
    });

    cases.add("pass non-copyable type by value to function",
        \\const Point = struct { x: i32, y: i32, };
        \\fn foo(p: Point) { }
        \\export fn entry() -> usize { @sizeOf(@typeOf(foo)) }
    , ".tmp_source.zig:2:11: error: type 'Point' is not copyable; cannot pass by value");

    cases.add("implicit cast from array to mutable slice",
        \\var global_array: [10]i32 = undefined;
        \\fn foo(param: []i32) {}
        \\export fn entry() {
        \\    foo(global_array);
        \\}
    , ".tmp_source.zig:4:9: error: expected type '[]i32', found '[10]i32'");

    cases.add("ptrcast to non-pointer",
        \\export fn entry(a: &i32) -> usize {
        \\    return @ptrCast(usize, a);
        \\}
    , ".tmp_source.zig:2:21: error: expected pointer, found 'usize'");

    cases.add("too many error values to cast to small integer",
        \\error A; error B; error C; error D; error E; error F; error G; error H;
        \\const u2 = @IntType(false, 2);
        \\fn foo(e: error) -> u2 {
        \\    return u2(e);
        \\}
        \\export fn entry() -> usize { @sizeOf(@typeOf(foo)) }
    , ".tmp_source.zig:4:14: error: too many error values to fit in 'u2'");

    cases.add("asm at compile time",
        \\comptime {
        \\    doSomeAsm();
        \\}
        \\
        \\fn doSomeAsm() {
        \\    asm volatile (
        \\        \\.globl aoeu;
        \\        \\.type aoeu, @function;
        \\        \\.set aoeu, derp;
        \\    );
        \\}
    , ".tmp_source.zig:6:5: error: unable to evaluate constant expression");

    cases.add("invalid member of builtin enum",
        \\export fn entry() {
        \\    const foo = Arch.x86;
        \\}
    , ".tmp_source.zig:2:21: error: container 'Arch' has no member called 'x86'");

    cases.add("int to ptr of 0 bits",
        \\export fn foo() {
        \\    var x: usize = 0x1000;
        \\    var y: &void = @intToPtr(&void, x);
        \\}
    , ".tmp_source.zig:3:31: error: type '&void' has 0 bits and cannot store information");

    cases.add("@fieldParentPtr - non struct",
        \\const Foo = i32;
        \\export fn foo(a: &i32) -> &Foo {
        \\    return @fieldParentPtr(Foo, "a", a);
        \\}
    , ".tmp_source.zig:3:28: error: expected struct type, found 'i32'");

    cases.add("@fieldParentPtr - bad field name",
        \\const Foo = struct {
        \\    derp: i32,
        \\};
        \\export fn foo(a: &i32) -> &Foo {
        \\    return @fieldParentPtr(Foo, "a", a);
        \\}
    , ".tmp_source.zig:5:33: error: struct 'Foo' has no field 'a'");

    cases.add("@fieldParentPtr - field pointer is not pointer",
        \\const Foo = struct {
        \\    a: i32,
        \\};
        \\export fn foo(a: i32) -> &Foo {
        \\    return @fieldParentPtr(Foo, "a", a);
        \\}
    , ".tmp_source.zig:5:38: error: expected pointer, found 'i32'");

    cases.add("@fieldParentPtr - comptime field ptr not based on struct",
        \\const Foo = struct {
        \\    a: i32,
        \\    b: i32,
        \\};
        \\const foo = Foo { .a = 1, .b = 2, };
        \\
        \\comptime {
        \\    const field_ptr = @intToPtr(&i32, 0x1234);
        \\    const another_foo_ptr = @fieldParentPtr(Foo, "b", field_ptr);
        \\}
    , ".tmp_source.zig:9:55: error: pointer value not based on parent struct");

    cases.add("@fieldParentPtr - comptime wrong field index",
        \\const Foo = struct {
        \\    a: i32,
        \\    b: i32,
        \\};
        \\const foo = Foo { .a = 1, .b = 2, };
        \\
        \\comptime {
        \\    const another_foo_ptr = @fieldParentPtr(Foo, "b", &foo.a);
        \\}
    , ".tmp_source.zig:8:29: error: field 'b' has index 1 but pointer value is index 0 of struct 'Foo'");

    cases.add("@offsetOf - non struct",
        \\const Foo = i32;
        \\export fn foo() -> usize {
        \\    return @offsetOf(Foo, "a");
        \\}
    , ".tmp_source.zig:3:22: error: expected struct type, found 'i32'");

    cases.add("@offsetOf - bad field name",
        \\const Foo = struct {
        \\    derp: i32,
        \\};
        \\export fn foo() -> usize {
        \\    return @offsetOf(Foo, "a");
        \\}
    , ".tmp_source.zig:5:27: error: struct 'Foo' has no field 'a'");

    cases.addExe("missing main fn in executable",
        \\
    , "error: no member named 'main' in '");

    cases.addExe("private main fn",
        \\fn main() {}
    ,
        "error: 'main' is private",
        ".tmp_source.zig:1:1: note: declared here");

    cases.add("@setGlobalAlign extern variable",
        \\extern var foo: i32;
        \\comptime {
        \\    @setGlobalAlign(foo, 4);
        \\}
    ,
        ".tmp_source.zig:3:5: error: cannot set alignment of external variable 'foo'",
        ".tmp_source.zig:1:8: note: declared here");

    cases.add("@setGlobalAlign extern fn",
        \\extern fn foo();
        \\comptime {
        \\    @setGlobalAlign(foo, 4);
        \\}
    ,
        ".tmp_source.zig:3:5: error: cannot set alignment of external function 'foo'",
        ".tmp_source.zig:1:8: note: declared here");

    cases.add("@setGlobalSection extern variable",
        \\extern var foo: i32;
        \\comptime {
        \\    @setGlobalSection(foo, ".text2");
        \\}
    ,
        ".tmp_source.zig:3:5: error: cannot set section of external variable 'foo'",
        ".tmp_source.zig:1:8: note: declared here");

    cases.add("@setGlobalSection extern fn",
        \\extern fn foo();
        \\comptime {
        \\    @setGlobalSection(foo, ".text2");
        \\}
    ,
        ".tmp_source.zig:3:5: error: cannot set section of external function 'foo'",
        ".tmp_source.zig:1:8: note: declared here");
}

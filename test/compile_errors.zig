const tests = @import("tests.zig");

pub fn addCases(cases: &tests.CompileErrorContext) {
    cases.add("wrong return type for main",
        \\pub fn main() { }
    , ".tmp_source.zig:1:15: error: expected return type of main to be '%void', instead is 'void'");

    cases.add("double ?? on main return value",
        \\pub fn main() -> ??void {
        \\}
    , ".tmp_source.zig:1:18: error: expected return type of main to be '%void', instead is '??void'");

    cases.add("setting a section on an extern variable",
        \\extern var foo: i32 section(".text2");
        \\extern fn entry() -> i32 {
        \\    return foo;
        \\}
        \\comptime { @export("entry", entry); }
    ,
        ".tmp_source.zig:1:29: error: cannot set section of external variable 'foo'");

    cases.add("setting a section on a local variable",
        \\extern fn entry() -> i32 {
        \\    var foo: i32 section(".text2") = 1234;
        \\    return foo;
        \\}
        \\comptime { @export("entry", entry); }
    ,
        ".tmp_source.zig:2:26: error: cannot set section of local variable 'foo'");

    cases.add("setting a section on an extern fn",
        \\extern fn foo() section(".text2");
        \\extern fn entry() {
        \\    foo();
        \\}
        \\comptime { @export("entry", entry); }
    ,
        ".tmp_source.zig:1:25: error: cannot set section of external function 'foo'");

    cases.add("wrong types given to exportWithLinkage",
        \\extern fn entry() { }
        \\comptime {
        \\    @exportWithLinkage("entry", entry, u32(1234));
        \\}
    ,
        ".tmp_source.zig:3:43: error: expected type 'GlobalLinkage', found 'u32'");

    cases.add("implicit semicolon - block statement",
        \\extern fn entry() {
        \\    {}
        \\    var good = {};
        \\    ({})
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - block expr",
        \\extern fn entry() {
        \\    _ = {};
        \\    var good = {};
        \\    _ = {}
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - comptime statement",
        \\extern fn entry() {
        \\    comptime {}
        \\    var good = {};
        \\    comptime ({})
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - comptime expression",
        \\extern fn entry() {
        \\    _ = comptime {};
        \\    var good = {};
        \\    _ = comptime {}
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - defer",
        \\extern fn entry() {
        \\    defer {}
        \\    var good = {};
        \\    defer ({})
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: expected token ';', found 'var'");

    cases.add("implicit semicolon - if statement",
        \\extern fn entry() {
        \\    if(true) {}
        \\    var good = {};
        \\    if(true) ({})
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if expression",
        \\extern fn entry() {
        \\    _ = if(true) {};
        \\    var good = {};
        \\    _ = if(true) {}
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if-else statement",
        \\extern fn entry() {
        \\    if(true) {} else {}
        \\    var good = {};
        \\    if(true) ({}) else ({})
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if-else expression",
        \\extern fn entry() {
        \\    _ = if(true) {} else {};
        \\    var good = {};
        \\    _ = if(true) {} else {}
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if-else-if statement",
        \\extern fn entry() {
        \\    if(true) {} else if(true) {}
        \\    var good = {};
        \\    if(true) ({}) else if(true) ({})
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if-else-if expression",
        \\extern fn entry() {
        \\    _ = if(true) {} else if(true) {};
        \\    var good = {};
        \\    _ = if(true) {} else if(true) {}
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if-else-if-else statement",
        \\extern fn entry() {
        \\    if(true) {} else if(true) {} else {}
        \\    var good = {};
        \\    if(true) ({}) else if(true) ({}) else ({})
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - if-else-if-else expression",
        \\extern fn entry() {
        \\    _ = if(true) {} else if(true) {} else {};
        \\    var good = {};
        \\    _ = if(true) {} else if(true) {} else {}
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - test statement",
        \\extern fn entry() {
        \\    if (foo()) |_| {}
        \\    var good = {};
        \\    if (foo()) |_| ({})
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - test expression",
        \\extern fn entry() {
        \\    _ = if (foo()) |_| {};
        \\    var good = {};
        \\    _ = if (foo()) |_| {}
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - while statement",
        \\extern fn entry() {
        \\    while(true) {}
        \\    var good = {};
        \\    while(true) ({})
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - while expression",
        \\extern fn entry() {
        \\    _ = while(true) {};
        \\    var good = {};
        \\    _ = while(true) {}
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - while-continue statement",
        \\extern fn entry() {
        \\    while(true):({}) {}
        \\    var good = {};
        \\    while(true):({}) ({})
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - while-continue expression",
        \\extern fn entry() {
        \\    _ = while(true):({}) {};
        \\    var good = {};
        \\    _ = while(true):({}) {}
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - for statement",
        \\extern fn entry() {
        \\    for(foo()) {}
        \\    var good = {};
        \\    for(foo()) ({})
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("implicit semicolon - for expression",
        \\extern fn entry() {
        \\    _ = for(foo()) {};
        \\    var good = {};
        \\    _ = for(foo()) {}
        \\    var bad = {};
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:5: error: invalid token: 'var'");

    cases.add("multiple function definitions",
        \\fn a() {}
        \\fn a() {}
        \\comptime {@export("entry", entry);}
        \\extern fn entry() { a(); }
    , ".tmp_source.zig:2:1: error: redefinition of 'a'");

    cases.add("unreachable with return",
        \\fn a() -> noreturn {return;}
        \\comptime {@export("entry", entry);}
        \\extern fn entry() { a(); }
    , ".tmp_source.zig:1:21: error: expected type 'noreturn', found 'void'");

    cases.add("control reaches end of non-void function",
        \\fn a() -> i32 {}
        \\comptime {@export("entry", entry);}
        \\extern fn entry() { _ = a(); }
    , ".tmp_source.zig:1:15: error: expected type 'i32', found 'void'");

    cases.add("undefined function call",
        \\extern fn a() {
        \\    b();
        \\}
        \\comptime {@export("a", a);}
    , ".tmp_source.zig:2:5: error: use of undeclared identifier 'b'");

    cases.add("wrong number of arguments",
        \\extern fn a() {
        \\    b(1);
        \\}
        \\fn b(a: i32, b: i32, c: i32) { }
        \\comptime {@export("a", a);}
    , ".tmp_source.zig:2:6: error: expected 3 arguments, found 1");

    cases.add("invalid type",
        \\fn a() -> bogus {}
        \\comptime {@export("entry", entry);}
        \\extern fn entry() { _ = a(); }
    , ".tmp_source.zig:1:11: error: use of undeclared identifier 'bogus'");

    cases.add("pointer to unreachable",
        \\fn a() -> &noreturn {}
        \\comptime {@export("entry", entry);}
        \\extern fn entry() { _ = a(); }
    , ".tmp_source.zig:1:12: error: pointer to unreachable not allowed");

    cases.add("unreachable code",
        \\extern fn a() {
        \\    return;
        \\    b();
        \\}
        \\
        \\fn b() {}
        \\comptime {@export("a", a);}
    , ".tmp_source.zig:3:5: error: unreachable code");

    cases.add("bad import",
        \\const bogus = @import("bogus-does-not-exist.zig");
        \\comptime {@export("entry", entry);}
        \\extern fn entry() { bogus.bogo(); }
    , ".tmp_source.zig:1:15: error: unable to find 'bogus-does-not-exist.zig'");

    cases.add("undeclared identifier",
        \\extern fn a() {
        \\    b +
        \\    c
        \\}
        \\comptime {@export("a", a);}
    ,
            ".tmp_source.zig:2:5: error: use of undeclared identifier 'b'",
            ".tmp_source.zig:3:5: error: use of undeclared identifier 'c'");

    cases.add("parameter redeclaration",
        \\fn f(a : i32, a : i32) {
        \\}
        \\comptime {@export("entry", entry);}
        \\extern fn entry() { f(1, 2); }
    , ".tmp_source.zig:1:15: error: redeclaration of variable 'a'");

    cases.add("local variable redeclaration",
        \\extern fn f() {
        \\    const a : i32 = 0;
        \\    const a = 0;
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:3:5: error: redeclaration of variable 'a'");

    cases.add("local variable redeclares parameter",
        \\fn f(a : i32) {
        \\    const a = 0;
        \\}
        \\comptime {@export("entry", entry);}
        \\extern fn entry() { f(1); }
    , ".tmp_source.zig:2:5: error: redeclaration of variable 'a'");

    cases.add("variable has wrong type",
        \\extern fn f() -> i32 {
        \\    const a = c"a";
        \\    a
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:3:5: error: expected type 'i32', found '&const u8'");

    cases.add("if condition is bool, not int",
        \\extern fn f() {
        \\    if (0) {}
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:2:9: error: integer value 0 cannot be implicitly casted to type 'bool'");

    cases.add("assign unreachable",
        \\extern fn f() {
        \\    const a = return;
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:2:5: error: unreachable code");

    cases.add("unreachable variable",
        \\extern fn f() {
        \\    const a: noreturn = {};
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:2:14: error: variable of type 'noreturn' not allowed");

    cases.add("unreachable parameter",
        \\fn f(a: noreturn) {}
        \\comptime {@export("entry", entry);}
        \\extern fn entry() { f(); }
    , ".tmp_source.zig:1:9: error: parameter of type 'noreturn' not allowed");

    cases.add("bad assignment target",
        \\extern fn f() {
        \\    3 = 3;
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:2:7: error: cannot assign to constant");

    cases.add("assign to constant variable",
        \\extern fn f() {
        \\    const a = 3;
        \\    a = 4;
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:3:7: error: cannot assign to constant");

    cases.add("use of undeclared identifier",
        \\extern fn f() {
        \\    b = 3;
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:2:5: error: use of undeclared identifier 'b'");

    cases.add("const is a statement, not an expression",
        \\extern fn f() {
        \\    (const a = 0);
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:2:6: error: invalid token: 'const'");

    cases.add("array access of undeclared identifier",
        \\extern fn f() {
        \\    i[i] = i[i];
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:2:5: error: use of undeclared identifier 'i'",
                 ".tmp_source.zig:2:12: error: use of undeclared identifier 'i'");

    cases.add("array access of non array",
        \\extern fn f() {
        \\    var bad : bool = undefined;
        \\    bad[bad] = bad[bad];
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:3:8: error: array access of non-array type 'bool'",
                 ".tmp_source.zig:3:19: error: array access of non-array type 'bool'");

    cases.add("array access with non integer index",
        \\extern fn f() {
        \\    var array = "aoeu";
        \\    var bad = false;
        \\    array[bad] = array[bad];
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:4:11: error: expected type 'usize', found 'bool'",
                 ".tmp_source.zig:4:24: error: expected type 'usize', found 'bool'");

    cases.add("write to const global variable",
        \\const x : i32 = 99;
        \\fn f() {
        \\    x = 1;
        \\}
        \\extern fn entry() { f(); }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:3:7: error: cannot assign to constant");


    cases.add("missing else clause",
        \\fn f(b: bool) {
        \\    const x : i32 = if (b) { 1 };
        \\    const y = if (b) { i32(1) };
        \\}
        \\extern fn entry() { f(true); }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:2:30: error: integer value 1 cannot be implicitly casted to type 'void'",
                 ".tmp_source.zig:3:15: error: incompatible types: 'i32' and 'void'");

    cases.add("direct struct loop",
        \\const A = struct { a : A, };
        \\extern fn entry() -> usize { @sizeOf(A) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:11: error: struct 'A' contains itself");

    cases.add("indirect struct loop",
        \\const A = struct { b : B, };
        \\const B = struct { c : C, };
        \\const C = struct { a : A, };
        \\extern fn entry() -> usize { @sizeOf(A) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:11: error: struct 'A' contains itself");

    cases.add("invalid struct field",
        \\const A = struct { x : i32, };
        \\extern fn f() {
        \\    var a : A = undefined;
        \\    a.foo = 1;
        \\    const y = a.bar;
        \\}
        \\comptime {@export("f", f);}
    ,
            ".tmp_source.zig:4:6: error: no member named 'foo' in struct 'A'",
            ".tmp_source.zig:5:16: error: no member named 'bar' in struct 'A'");

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

    cases.add("duplicate field in struct value expression",
        \\const A = struct {
        \\    x : i32,
        \\    y : i32,
        \\    z : i32,
        \\};
        \\extern fn f() {
        \\    const a = A {
        \\        .z = 1,
        \\        .y = 2,
        \\        .x = 3,
        \\        .z = 4,
        \\    };
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:11:9: error: duplicate field");

    cases.add("missing field in struct value expression",
        \\const A = struct {
        \\    x : i32,
        \\    y : i32,
        \\    z : i32,
        \\};
        \\extern fn f() {
        \\    // we want the error on the '{' not the 'A' because
        \\    // the A could be a complicated expression
        \\    const a = A {
        \\        .z = 4,
        \\        .y = 2,
        \\    };
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:9:17: error: missing field: 'x'");

    cases.add("invalid field in struct value expression",
        \\const A = struct {
        \\    x : i32,
        \\    y : i32,
        \\    z : i32,
        \\};
        \\extern fn f() {
        \\    const a = A {
        \\        .z = 4,
        \\        .y = 2,
        \\        .foo = 42,
        \\    };
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:10:9: error: no member named 'foo' in struct 'A'");

    cases.add("invalid break expression",
        \\extern fn f() {
        \\    break;
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:2:5: error: break expression outside loop");

    cases.add("invalid continue expression",
        \\extern fn f() {
        \\    continue;
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:2:5: error: continue expression outside loop");

    cases.add("invalid maybe type",
        \\extern fn f() {
        \\    if (true) |x| { }
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:2:9: error: expected nullable type, found 'bool'");

    cases.add("cast unreachable",
        \\fn f() -> i32 {
        \\    i32(return 1)
        \\}
        \\extern fn entry() { _ = f(); }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:2:8: error: unreachable code");

    cases.add("invalid builtin fn",
        \\fn f() -> @bogus(foo) {
        \\}
        \\extern fn entry() { _ = f(); }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:11: error: invalid builtin function: 'bogus'");

    cases.add("top level decl dependency loop",
        \\const a : @typeOf(b) = 0;
        \\const b : @typeOf(a) = 0;
        \\extern fn entry() {
        \\    const c = a + b;
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:1: error: 'a' depends on itself");

    cases.add("noalias on non pointer param",
        \\fn f(noalias x: i32) {}
        \\extern fn entry() { f(1234); }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:6: error: noalias on non-pointer parameter");

    cases.add("struct init syntax for array",
        \\const foo = []u16{.x = 1024,};
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:18: error: type '[]u16' does not support struct initialization syntax");

    cases.add("type variables must be constant",
        \\var foo = u8;
        \\extern fn entry() -> foo {
        \\    return 1;
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:1: error: variable of type 'type' must be constant");


    cases.add("variables shadowing types",
        \\const Foo = struct {};
        \\const Bar = struct {};
        \\
        \\fn f(Foo: i32) {
        \\    var Bar : i32 = undefined;
        \\}
        \\
        \\extern fn entry() {
        \\    f(1234);
        \\}
        \\comptime {@export("entry", entry);}
    ,
            ".tmp_source.zig:4:6: error: redefinition of 'Foo'",
            ".tmp_source.zig:1:1: note: previous definition is here",
            ".tmp_source.zig:5:5: error: redefinition of 'Bar'",
            ".tmp_source.zig:2:1: note: previous definition is here");

    cases.add("switch expression - missing enumeration prong",
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
        \\extern fn entry() -> usize { @sizeOf(@typeOf(f)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:8:5: error: enumeration value 'Number.Four' not handled in switch");

    cases.add("switch expression - duplicate enumeration prong",
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
        \\        Number.Four => 4,
        \\        Number.Two => 2,
        \\    }
        \\}
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(f)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:13:15: error: duplicate switch value",
      ".tmp_source.zig:10:15: note: other value is here");

    cases.add("switch expression - duplicate enumeration prong when else present",
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
        \\        Number.Four => 4,
        \\        Number.Two => 2,
        \\        else => 10,
        \\    }
        \\}
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(f)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:13:15: error: duplicate switch value",
      ".tmp_source.zig:10:15: note: other value is here");

    cases.add("switch expression - multiple else prongs",
        \\fn f(x: u32) {
        \\    const value: bool = switch (x) {
        \\        1234 => false,
        \\        else => true,
        \\        else => true,
        \\    };
        \\}
        \\extern fn entry() {
        \\    f(1234);
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:5:9: error: multiple else prongs in switch expression");

    cases.add("switch expression - non exhaustive integer prongs",
        \\fn foo(x: u8) {
        \\    switch (x) {
        \\        0 => {},
        \\    }
        \\}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:5: error: switch must handle all possibilities");

    cases.add("switch expression - duplicate or overlapping integer value",
        \\fn foo(x: u8) -> u8 {
        \\    switch (x) {
        \\        0 ... 100 => u8(0),
        \\        101 ... 200 => 1,
        \\        201, 203 ... 207 => 2,
        \\        206 ... 255 => 3,
        \\    }
        \\}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:6:9: error: duplicate switch value",
        ".tmp_source.zig:5:14: note: previous value is here");

    cases.add("switch expression - switch on pointer type with no else",
        \\fn foo(x: &u8) {
        \\    switch (x) {
        \\        &y => {},
        \\    }
        \\}
        \\const y: u8 = 100;
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:5: error: else prong required when switching on type '&u8'");

    cases.add("global variable initializer must be constant expression",
        \\extern fn foo() -> i32;
        \\const x = foo();
        \\extern fn entry() -> i32 { x }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:2:11: error: unable to evaluate constant expression");

    cases.add("array concatenation with wrong type",
        \\const src = "aoeu";
        \\const derp = usize(1234);
        \\const a = derp ++ "foo";
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(a)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:3:11: error: expected array or C string literal, found 'usize'");

    cases.add("non compile time array concatenation",
        \\fn f() -> []u8 {
        \\    s ++ "foo"
        \\}
        \\var s: [10]u8 = undefined;
        \\extern fn entry() -> usize { @sizeOf(@typeOf(f)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:2:5: error: unable to evaluate constant expression");

    cases.add("@cImport with bogus include",
        \\const c = @cImport(@cInclude("bogus.h"));
        \\extern fn entry() -> usize { @sizeOf(@typeOf(c.bogo)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:11: error: C import failed",
                 ".h:1:10: note: 'bogus.h' file not found");

    cases.add("address of number literal",
        \\const x = 3;
        \\const y = &x;
        \\fn foo() -> &const i32 { y }
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:3:26: error: expected type '&const i32', found '&const (integer literal)'");

    cases.add("integer overflow error",
        \\const x : u8 = 300;
        \\extern fn entry() -> usize { @sizeOf(@typeOf(x)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:16: error: integer value 300 cannot be implicitly casted to type 'u8'");

    cases.add("incompatible number literals",
        \\const x = 2 == 2.0;
        \\extern fn entry() -> usize { @sizeOf(@typeOf(x)) }
        \\comptime {@export("entry", entry);}
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
        \\extern fn entry() -> usize { @sizeOf(@typeOf(f)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:20:34: error: expected 1 arguments, found 0");

    cases.add("missing function name and param name",
        \\fn () {}
        \\fn f(i32) {}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(f)) }
        \\comptime {@export("entry", entry);}
    ,
            ".tmp_source.zig:1:1: error: missing function name",
            ".tmp_source.zig:2:6: error: missing parameter name");

    cases.add("wrong function type",
        \\const fns = []fn(){ a, b, c };
        \\fn a() -> i32 {0}
        \\fn b() -> i32 {1}
        \\fn c() -> i32 {2}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(fns)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:21: error: expected type 'fn()', found 'fn() -> i32'");

    cases.add("extern function pointer mismatch",
        \\const fns = [](fn(i32)->i32){ a, b, c };
        \\pub fn a(x: i32) -> i32 {x + 0}
        \\pub fn b(x: i32) -> i32 {x + 1}
        \\extern fn c(x: i32) -> i32 {x + 2}
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(fns)) }
        \\
        \\comptime {@export("entry", entry);}
        \\comptime {@export("c", c);}
    , ".tmp_source.zig:1:37: error: expected type 'fn(i32) -> i32', found 'extern fn(i32) -> i32'");


    cases.add("implicit cast from f64 to f32",
        \\const x : f64 = 1.0;
        \\const y : f32 = x;
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(y)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:2:17: error: expected type 'f32', found 'f64'");


    cases.add("colliding invalid top level functions",
        \\fn func() -> bogus {}
        \\fn func() -> bogus {}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(func)) }
        \\comptime {@export("entry", entry);}
    ,
            ".tmp_source.zig:2:1: error: redefinition of 'func'",
            ".tmp_source.zig:1:14: error: use of undeclared identifier 'bogus'");


    cases.add("bogus compile var",
        \\const x = @import("builtin").bogus;
        \\extern fn entry() -> usize { @sizeOf(@typeOf(x)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:29: error: no member named 'bogus' in '");


    cases.add("non constant expression in array size outside function",
        \\const Foo = struct {
        \\    y: [get()]u8,
        \\};
        \\var global_var: usize = 1;
        \\fn get() -> usize { global_var }
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(Foo)) }
        \\comptime {@export("entry", entry);}
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
        \\extern fn entry() -> usize { @sizeOf(@typeOf(x)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:4:28: error: invalid operands to binary expression: 'Foo' and 'Foo'");


    cases.add("division by zero",
        \\const lit_int_x = 1 / 0;
        \\const lit_float_x = 1.0 / 0.0;
        \\const int_x = u32(1) / u32(0);
        \\const float_x = f32(1.0) / f32(0.0);
        \\
        \\extern fn entry1() -> usize { @sizeOf(@typeOf(lit_int_x)) }
        \\extern fn entry2() -> usize { @sizeOf(@typeOf(lit_float_x)) }
        \\extern fn entry3() -> usize { @sizeOf(@typeOf(int_x)) }
        \\extern fn entry4() -> usize { @sizeOf(@typeOf(float_x)) }
        \\comptime {@export("entry1", entry1);}
        \\comptime {@export("entry2", entry2);}
        \\comptime {@export("entry3", entry3);}
        \\comptime {@export("entry4", entry4);}
    ,
            ".tmp_source.zig:1:21: error: division by zero is undefined",
            ".tmp_source.zig:2:25: error: division by zero is undefined",
            ".tmp_source.zig:3:22: error: division by zero is undefined",
            ".tmp_source.zig:4:26: error: division by zero is undefined");


    cases.add("normal string with newline",
        \\const foo = "a
        \\b";
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:13: error: newline not allowed in string literal");

    cases.add("invalid comparison for function pointers",
        \\fn foo() {}
        \\const invalid = foo > foo;
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(invalid)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:2:21: error: operator not allowed for type 'fn()'");

    cases.add("generic function instance with non-constant expression",
        \\fn foo(comptime x: i32, y: i32) -> i32 { return x + y; }
        \\fn test1(a: i32, b: i32) -> i32 {
        \\    return foo(a, b);
        \\}
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(test1)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:3:16: error: unable to evaluate constant expression");

    cases.add("goto jumping into block",
        \\extern fn f() {
        \\    {
        \\a_label:
        \\    }
        \\    goto a_label;
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:5:5: error: no label in scope named 'a_label'");

    cases.add("goto jumping past a defer",
        \\fn f(b: bool) {
        \\    if (b) goto label;
        \\    defer derp();
        \\label:
        \\}
        \\fn derp(){}
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(f)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:2:12: error: no label in scope named 'label'");

    cases.add("assign null to non-nullable pointer",
        \\const a: &u8 = null;
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(a)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:16: error: expected type '&u8', found '(null)'");

    cases.add("indexing an array of size zero",
        \\const array = []u8{};
        \\extern fn foo() {
        \\    const pointer = &array[0];
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:3:27: error: index 0 outside array of size 0");

    cases.add("compile time division by zero",
        \\const y = foo(0);
        \\fn foo(x: u32) -> u32 {
        \\    1 / x
        \\}
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(y)) }
        \\comptime {@export("entry", entry);}
    ,
            ".tmp_source.zig:3:7: error: division by zero is undefined",
            ".tmp_source.zig:1:14: note: called from here");

    cases.add("branch on undefined value",
        \\const x = if (undefined) true else false;
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(x)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:15: error: use of undefined value");


    cases.add("endless loop in function evaluation",
        \\const seventh_fib_number = fibbonaci(7);
        \\fn fibbonaci(x: i32) -> i32 {
        \\    return fibbonaci(x - 1) + fibbonaci(x - 2);
        \\}
        \\
        \\comptime {@export("entry", entry);}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(seventh_fib_number)) }
    ,
            ".tmp_source.zig:3:21: error: evaluation exceeded 1000 backwards branches",
            ".tmp_source.zig:3:21: note: called from here");

    cases.add("@embedFile with bogus file",
        \\const resource = @embedFile("bogus.txt");
        \\
        \\comptime {@export("entry", entry);}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(resource)) }
    , ".tmp_source.zig:1:29: error: unable to find '", "bogus.txt'");

    cases.add("non-const expression in struct literal outside function",
        \\const Foo = struct {
        \\    x: i32,
        \\};
        \\const a = Foo {.x = get_it()};
        \\extern fn get_it() -> i32;
        \\
        \\comptime {@export("entry", entry);}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(a)) }
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
        \\comptime {@export("entry", entry);}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(a)) }
    ,
            ".tmp_source.zig:6:24: error: unable to evaluate constant expression",
            ".tmp_source.zig:4:17: note: called from here");

    cases.add("undeclared identifier error should mark fn as impure",
        \\extern fn foo() {
        \\    test_a_thing();
        \\}
        \\fn test_a_thing() {
        \\    bad_fn_call();
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:5:5: error: use of undeclared identifier 'bad_fn_call'");

    cases.add("illegal comparison of types",
        \\fn bad_eql_1(a: []u8, b: []u8) -> bool {
        \\    a == b
        \\}
        \\const EnumWithData = union(enum) {
        \\    One: void,
        \\    Two: i32,
        \\};
        \\fn bad_eql_2(a: &const EnumWithData, b: &const EnumWithData) -> bool {
        \\    *a == *b
        \\}
        \\
        \\extern fn entry1() -> usize { @sizeOf(@typeOf(bad_eql_1)) }
        \\extern fn entry2() -> usize { @sizeOf(@typeOf(bad_eql_2)) }
        \\comptime {@export("entry1", entry1);}
        \\comptime {@export("entry2", entry2);}
    ,
            ".tmp_source.zig:2:7: error: operator not allowed for type '[]u8'",
            ".tmp_source.zig:9:8: error: operator not allowed for type 'EnumWithData'");

    cases.add("non-const switch number literal",
        \\extern fn foo() {
        \\    const x = switch (bar()) {
        \\        1, 2 => 1,
        \\        3, 4 => 2,
        \\        else => 3,
        \\    };
        \\}
        \\fn bar() -> i32 {
        \\    2
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:2:15: error: unable to infer expression type");

    cases.add("atomic orderings of cmpxchg - failure stricter than success",
        \\const AtomicOrder = @import("builtin").AtomicOrder;
        \\extern fn f() {
        \\    var x: i32 = 1234;
        \\    while (!@cmpxchg(&x, 1234, 5678, AtomicOrder.Monotonic, AtomicOrder.SeqCst)) {}
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:4:72: error: failure atomic ordering must be no stricter than success");

    cases.add("atomic orderings of cmpxchg - success Monotonic or stricter",
        \\const AtomicOrder = @import("builtin").AtomicOrder;
        \\extern fn f() {
        \\    var x: i32 = 1234;
        \\    while (!@cmpxchg(&x, 1234, 5678, AtomicOrder.Unordered, AtomicOrder.Unordered)) {}
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:4:49: error: success atomic ordering must be Monotonic or stricter");

    cases.add("negation overflow in function evaluation",
        \\const y = neg(-128);
        \\fn neg(x: i8) -> i8 {
        \\    -x
        \\}
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(y)) }
        \\comptime {@export("entry", entry);}
    ,
            ".tmp_source.zig:3:5: error: negation caused overflow",
            ".tmp_source.zig:1:14: note: called from here");

    cases.add("add overflow in function evaluation",
        \\const y = add(65530, 10);
        \\fn add(a: u16, b: u16) -> u16 {
        \\    a + b
        \\}
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(y)) }
        \\comptime {@export("entry", entry);}
    ,
            ".tmp_source.zig:3:7: error: operation caused overflow",
            ".tmp_source.zig:1:14: note: called from here");


    cases.add("sub overflow in function evaluation",
        \\const y = sub(10, 20);
        \\fn sub(a: u16, b: u16) -> u16 {
        \\    a - b
        \\}
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(y)) }
        \\comptime {@export("entry", entry);}
    ,
            ".tmp_source.zig:3:7: error: operation caused overflow",
            ".tmp_source.zig:1:14: note: called from here");

    cases.add("mul overflow in function evaluation",
        \\const y = mul(300, 6000);
        \\fn mul(a: u16, b: u16) -> u16 {
        \\    a * b
        \\}
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(y)) }
        \\comptime {@export("entry", entry);}
    ,
            ".tmp_source.zig:3:7: error: operation caused overflow",
            ".tmp_source.zig:1:14: note: called from here");

    cases.add("truncate sign mismatch",
        \\fn f() -> i8 {
        \\    const x: u32 = 10;
        \\    @truncate(i8, x)
        \\}
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(f)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:3:19: error: expected signed integer type, found 'u32'");

    cases.add("%return in function with non error return type",
        \\extern fn f() {
        \\    %return something();
        \\}
        \\fn something() -> %void { }
        \\comptime {@export("f", f);}
    ,
            ".tmp_source.zig:2:5: error: expected type 'void', found 'error'");

    cases.add("invalid pointer for var type",
        \\extern fn ext() -> usize;
        \\var bytes: [ext()]u8 = undefined;
        \\extern fn f() {
        \\    for (bytes) |*b, i| {
        \\        *b = u8(i);
        \\    }
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:2:13: error: unable to evaluate constant expression");

    cases.add("export function with comptime parameter",
        \\extern fn foo(comptime x: i32, y: i32) -> i32{
        \\    x + y
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:1:15: error: comptime parameter not allowed in function with calling convention 'ccc'");

    cases.add("extern function with comptime parameter",
        \\extern fn foo(comptime x: i32, y: i32) -> i32;
        \\fn f() -> i32 {
        \\    foo(1, 2)
        \\}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(f)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:15: error: comptime parameter not allowed in function with calling convention 'ccc'");

    cases.add("convert fixed size array to slice with invalid size",
        \\extern fn f() {
        \\    var array: [5]u8 = undefined;
        \\    var foo = ([]const u32)(array)[0];
        \\}
        \\comptime {@export("f", f);}
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
        \\extern fn function_with_return_type_type() {
        \\    var list: List(i32) = undefined;
        \\    list.length = 10;
        \\}
        \\comptime {@export("function_with_return_type_type", function_with_return_type_type);}
    , ".tmp_source.zig:3:7: error: unable to evaluate constant expression",
        ".tmp_source.zig:16:19: note: called from here");

    cases.add("bogus method call on slice",
        \\var self = "aoeu";
        \\fn f(m: []const u8) {
        \\    m.copy(u8, self[0..], m);
        \\}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(f)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:3:6: error: no member named 'copy' in '[]const u8'");

    cases.add("wrong number of arguments for method fn call",
        \\const Foo = struct {
        \\    fn method(self: &const Foo, a: i32) {}
        \\};
        \\fn f(foo: &const Foo) {
        \\
        \\    foo.method(1, 2);
        \\}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(f)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:6:15: error: expected 2 arguments, found 3");

    cases.add("assign through constant pointer",
        \\extern fn f() {
        \\  var cstr = c"Hat";
        \\  cstr[0] = 'W';
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:3:11: error: cannot assign to constant");

    cases.add("assign through constant slice",
        \\extern fn f() {
        \\  var cstr: []const u8 = "Hat";
        \\  cstr[0] = 'W';
        \\}
        \\comptime {@export("f", f);}
    , ".tmp_source.zig:3:11: error: cannot assign to constant");

    cases.add("main function with bogus args type",
        \\pub fn main(args: [][]bogus) -> %void {}
    , ".tmp_source.zig:1:23: error: use of undeclared identifier 'bogus'");

    cases.add("for loop missing element param",
        \\fn foo(blah: []u8) {
        \\    for (blah) { }
        \\}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:2:5: error: for loop expression missing element parameter");

    cases.add("misspelled type with pointer only reference",
        \\const JasonHM = u8;
        \\const JasonList = &JsonNode;
        \\
        \\const JsonOA = union(enum) {
        \\    JSONArray: JsonList,
        \\    JSONObject: JasonHM,
        \\};
        \\
        \\const JsonType = union(enum) {
        \\    JSONNull: void,
        \\    JSONInteger: isize,
        \\    JSONDouble: f64,
        \\    JSONBool: bool,
        \\    JSONString: []u8,
        \\    JSONArray: void,
        \\    JSONObject: void,
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
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
        \\comptime {@export("entry", entry);}
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
        \\extern fn f() {
        \\    const derp = Foo.init(3);
        \\
        \\    derp.init();
        \\}
        \\comptime {@export("f", f);}
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
        \\extern fn foo() {
        \\    var x = List.init(&global_allocator);
        \\    x.init();
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:23:5: error: expected type '&Allocator', found '&List'");

    cases.add("binary not on number literal",
        \\const TINY_QUANTUM_SHIFT = 4;
        \\const TINY_QUANTUM_SIZE = 1 << TINY_QUANTUM_SHIFT;
        \\var block_aligned_stuff: usize = (4 + TINY_QUANTUM_SIZE) & ~(TINY_QUANTUM_SIZE - 1);
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(block_aligned_stuff)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:3:60: error: unable to perform binary not operation on type '(integer literal)'");

    cases.addCase({
        const tc = cases.create("multiple files with private function error",
            \\const foo = @import("foo.zig");
            \\
            \\extern fn callPrivFunction() {
            \\    foo.privateFunction();
            \\}
            \\comptime {@export("callPrivFunction", callPrivFunction);}
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
        \\extern fn entry() -> usize { @sizeOf(@typeOf(a)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:2:11: error: expected type, found 'i32'");

    cases.add("assign to constant field",
        \\const Foo = struct {
        \\    field: i32,
        \\};
        \\extern fn derp() {
        \\    const f = Foo {.field = 1234,};
        \\    f.field = 0;
        \\}
        \\comptime {@export("derp", derp);}
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
        \\extern fn entry() -> usize { @sizeOf(@typeOf(testTrickyDefer)) }
        \\comptime {@export("entry", entry);}
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
        \\comptime {@export("entry", entry);}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
    ,
            ".tmp_source.zig:2:19: error: index 1 outside argument list of size 1",
            ".tmp_source.zig:6:8: note: called from here");

    cases.add("pass integer literal to var args",
        \\fn add(args: ...) -> i32 {
        \\    var sum = i32(0);
        \\    {comptime var i: usize = 0; inline while (i < args.len) : (i += 1) {
        \\        sum += args[i];
        \\    }}
        \\    return sum;
        \\}
        \\
        \\fn bar() -> i32 {
        \\    add(1, 2, 3, 4)
        \\}
        \\
        \\comptime {@export("entry", entry);}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(bar)) }
    , ".tmp_source.zig:10:9: error: parameter of type '(integer literal)' requires comptime");

    cases.add("assign too big number to u16",
        \\extern fn foo() {
        \\    var vga_mem: u16 = 0xB8000;
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:2:24: error: integer value 753664 cannot be implicitly casted to type 'u16'");

    cases.add("global variable alignment non power of 2",
        \\const some_data: [100]u8 align(3) = undefined;
        \\extern fn entry() -> usize { @sizeOf(@typeOf(some_data)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:32: error: alignment value 3 is not a power of 2");

    cases.add("function alignment non power of 2",
        \\extern fn foo() align(3);
        \\extern fn entry() { foo() }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:1:23: error: alignment value 3 is not a power of 2");

    cases.add("compile log",
        \\extern fn foo() {
        \\    comptime bar(12, "hi");
        \\}
        \\fn bar(a: i32, b: []const u8) {
        \\    @compileLog("begin");
        \\    @compileLog("a", a, "b", b);
        \\    @compileLog("end");
        \\}
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:5:5: error: found compile log statement",
        ".tmp_source.zig:2:17: note: called from here",
        ".tmp_source.zig:6:5: error: found compile log statement",
        ".tmp_source.zig:2:17: note: called from here",
        ".tmp_source.zig:7:5: error: found compile log statement",
        ".tmp_source.zig:2:17: note: called from here");

    cases.add("casting bit offset pointer to regular pointer",
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
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:8:26: error: expected type '&const u3', found '&align(1:3:6) const u3'");

    cases.add("referring to a struct that is invalid",
        \\const UsbDeviceRequest = struct {
        \\    Type: u8,
        \\};
        \\
        \\extern fn foo() {
        \\    comptime assert(@sizeOf(UsbDeviceRequest) == 0x8);
        \\}
        \\
        \\fn assert(ok: bool) {
        \\    if (!ok) unreachable;
        \\}
        \\comptime {@export("foo", foo);}
    ,
            ".tmp_source.zig:10:14: error: unable to evaluate constant expression",
            ".tmp_source.zig:6:20: note: called from here");

    cases.add("control flow uses comptime var at runtime",
        \\extern fn foo() {
        \\    comptime var i = 0;
        \\    while (i < 5) : (i += 1) {
        \\        bar();
        \\    }
        \\}
        \\
        \\fn bar() { }
        \\comptime {@export("foo", foo);}
    ,
            ".tmp_source.zig:3:5: error: control flow attempts to use compile-time variable at runtime",
            ".tmp_source.zig:3:24: note: compile-time variable assigned here");

    cases.add("ignored return value",
        \\extern fn foo() {
        \\    bar();
        \\}
        \\fn bar() -> i32 { 0 }
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:2:8: error: expression value is ignored");

    cases.add("ignored assert-err-ok return value",
        \\extern fn foo() {
        \\    %%bar();
        \\}
        \\fn bar() -> %i32 { 0 }
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:2:5: error: expression value is ignored");

    cases.add("ignored statement value",
        \\extern fn foo() {
        \\    1;
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:2:5: error: expression value is ignored");

    cases.add("ignored comptime statement value",
        \\extern fn foo() {
        \\    comptime {1;}
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:2:15: error: expression value is ignored");

    cases.add("ignored comptime value",
        \\extern fn foo() {
        \\    comptime 1;
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:2:5: error: expression value is ignored");

    cases.add("ignored defered statement value",
        \\extern fn foo() {
        \\    defer {1;}
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:2:12: error: expression value is ignored");

    cases.add("ignored defered statement value",
        \\extern fn foo() {
        \\    defer bar();
        \\}
        \\fn bar() -> %i32 { 0 }
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:2:14: error: expression value is ignored");

    cases.add("dereference an array",
        \\var s_buffer: [10]u8 = undefined;
        \\pub fn pass(in: []u8) -> []u8 {
        \\    var out = &s_buffer;
        \\    *out[0] = in[0];
        \\    return (*out)[0..1];
        \\}
        \\
        \\extern fn entry() -> usize { @sizeOf(@typeOf(pass)) }
        \\comptime {@export("entry", entry);}
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
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:4:19: error: expected type '&[]const u8', found '&const []const u8'");

    cases.add("pass non-copyable type by value to function",
        \\const Point = struct { x: i32, y: i32, };
        \\fn foo(p: Point) { }
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:2:11: error: type 'Point' is not copyable; cannot pass by value");

    cases.add("implicit cast from array to mutable slice",
        \\var global_array: [10]i32 = undefined;
        \\fn foo(param: []i32) {}
        \\extern fn entry() {
        \\    foo(global_array);
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:4:9: error: expected type '[]i32', found '[10]i32'");

    cases.add("ptrcast to non-pointer",
        \\extern fn entry(a: &i32) -> usize {
        \\    return @ptrCast(usize, a);
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:2:21: error: expected pointer, found 'usize'");

    cases.add("too many error values to cast to small integer",
        \\error A; error B; error C; error D; error E; error F; error G; error H;
        \\const u2 = @IntType(false, 2);
        \\fn foo(e: error) -> u2 {
        \\    return u2(e);
        \\}
        \\extern fn entry() -> usize { @sizeOf(@typeOf(foo)) }
        \\comptime {@export("entry", entry);}
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
        \\const builtin = @import("builtin");
        \\extern fn entry() {
        \\    const foo = builtin.Arch.x86;
        \\}
        \\comptime {@export("entry", entry);}
    , ".tmp_source.zig:3:29: error: container 'Arch' has no member called 'x86'");

    cases.add("int to ptr of 0 bits",
        \\extern fn foo() {
        \\    var x: usize = 0x1000;
        \\    var y: &void = @intToPtr(&void, x);
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:3:31: error: type '&void' has 0 bits and cannot store information");

    cases.add("@fieldParentPtr - non struct",
        \\const Foo = i32;
        \\extern fn foo(a: &i32) -> &Foo {
        \\    return @fieldParentPtr(Foo, "a", a);
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:3:28: error: expected struct type, found 'i32'");

    cases.add("@fieldParentPtr - bad field name",
        \\const Foo = struct {
        \\    derp: i32,
        \\};
        \\extern fn foo(a: &i32) -> &Foo {
        \\    return @fieldParentPtr(Foo, "a", a);
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:5:33: error: struct 'Foo' has no field 'a'");

    cases.add("@fieldParentPtr - field pointer is not pointer",
        \\const Foo = struct {
        \\    a: i32,
        \\};
        \\extern fn foo(a: i32) -> &Foo {
        \\    return @fieldParentPtr(Foo, "a", a);
        \\}
        \\comptime {@export("foo", foo);}
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
        \\extern fn foo() -> usize {
        \\    return @offsetOf(Foo, "a");
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:3:22: error: expected struct type, found 'i32'");

    cases.add("@offsetOf - bad field name",
        \\const Foo = struct {
        \\    derp: i32,
        \\};
        \\extern fn foo() -> usize {
        \\    return @offsetOf(Foo, "a");
        \\}
        \\comptime {@export("foo", foo);}
    , ".tmp_source.zig:5:27: error: struct 'Foo' has no field 'a'");

    cases.addExe("missing main fn in executable",
        \\
    , "error: no member named 'main' in '");

    cases.addExe("private main fn",
        \\fn main() {}
    ,
        "error: 'main' is private",
        ".tmp_source.zig:1:1: note: declared here");

    cases.add("returning address of local variable - simple",
        \\extern fn foo() -> &i32 {
        \\    var a: i32 = undefined;
        \\    return &a;
        \\}
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:3:13: error: function returns address of local variable");

    cases.add("returning address of local variable - phi",
        \\extern fn foo(c: bool) -> &i32 {
        \\    var a: i32 = undefined;
        \\    var b: i32 = undefined;
        \\    return if (c) &a else &b;
        \\}
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:4:12: error: function returns address of local variable");

    cases.add("inner struct member shadowing outer struct member",
        \\fn A() -> type {
        \\    struct {
        \\        b: B(),
        \\
        \\        const Self = this;
        \\
        \\        fn B() -> type {
        \\            struct {
        \\                const Self = this;
        \\            }
        \\        }
        \\    }
        \\}
        \\comptime {
        \\    assert(A().B().Self != A().Self);
        \\}
        \\fn assert(ok: bool) {
        \\    if (!ok) unreachable;
        \\}
    ,
        ".tmp_source.zig:9:17: error: redefinition of 'Self'",
        ".tmp_source.zig:5:9: note: previous definition is here");

    cases.add("while expected bool, got nullable",
        \\extern fn foo() {
        \\    while (bar()) {}
        \\}
        \\fn bar() -> ?i32 { 1 }
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:2:15: error: expected type 'bool', found '?i32'");

    cases.add("while expected bool, got error union",
        \\extern fn foo() {
        \\    while (bar()) {}
        \\}
        \\fn bar() -> %i32 { 1 }
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:2:15: error: expected type 'bool', found '%i32'");

    cases.add("while expected nullable, got bool",
        \\extern fn foo() {
        \\    while (bar()) |x| {}
        \\}
        \\fn bar() -> bool { true }
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:2:15: error: expected nullable type, found 'bool'");

    cases.add("while expected nullable, got error union",
        \\extern fn foo() {
        \\    while (bar()) |x| {}
        \\}
        \\fn bar() -> %i32 { 1 }
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:2:15: error: expected nullable type, found '%i32'");

    cases.add("while expected error union, got bool",
        \\extern fn foo() {
        \\    while (bar()) |x| {} else |err| {}
        \\}
        \\fn bar() -> bool { true }
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:2:15: error: expected error union type, found 'bool'");

    cases.add("while expected error union, got nullable",
        \\extern fn foo() {
        \\    while (bar()) |x| {} else |err| {}
        \\}
        \\fn bar() -> ?i32 { 1 }
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:2:15: error: expected error union type, found '?i32'");

    cases.add("inline fn calls itself indirectly",
        \\extern fn foo() {
        \\    bar();
        \\}
        \\inline fn bar() {
        \\    baz();
        \\    quux();
        \\}
        \\inline fn baz() {
        \\    bar();
        \\    quux();
        \\}
        \\extern fn quux();
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:4:8: error: unable to inline function");

    cases.add("save reference to inline function",
        \\extern fn foo() {
        \\    quux(@ptrToInt(bar));
        \\}
        \\inline fn bar() { }
        \\extern fn quux(usize);
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:4:8: error: unable to inline function");

    cases.add("signed integer division",
        \\extern fn foo(a: i32, b: i32) -> i32 {
        \\    a / b
        \\}
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:2:7: error: division with 'i32' and 'i32': signed integers must use @divTrunc, @divFloor, or @divExact");

    cases.add("signed integer remainder division",
        \\extern fn foo(a: i32, b: i32) -> i32 {
        \\    a % b
        \\}
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:2:7: error: remainder division with 'i32' and 'i32': signed integers and floats must use @rem or @mod");

    cases.add("cast negative value to unsigned integer",
        \\comptime {
        \\    const value: i32 = -1;
        \\    const unsigned = u32(value);
        \\}
    ,
        ".tmp_source.zig:3:25: error: attempt to cast negative value to unsigned integer");

    cases.add("compile-time division by zero",
        \\comptime {
        \\    const a: i32 = 1;
        \\    const b: i32 = 0;
        \\    const c = a / b;
        \\}
    ,
        ".tmp_source.zig:4:17: error: division by zero is undefined");

    cases.add("compile-time remainder division by zero",
        \\comptime {
        \\    const a: i32 = 1;
        \\    const b: i32 = 0;
        \\    const c = a % b;
        \\}
    ,
        ".tmp_source.zig:4:17: error: division by zero is undefined");

    cases.add("compile-time integer cast truncates bits",
        \\comptime {
        \\    const spartan_count: u16 = 300;
        \\    const byte = u8(spartan_count);
        \\}
    ,
        ".tmp_source.zig:3:20: error: cast from 'u16' to 'u8' truncates bits");

    cases.add("@setDebugSafety twice for same scope",
        \\extern fn foo() {
        \\    @setDebugSafety(this, false);
        \\    @setDebugSafety(this, false);
        \\}
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:3:5: error: debug safety set twice for same scope",
        ".tmp_source.zig:2:5: note: first set here");

    cases.add("@setFloatMode twice for same scope",
        \\extern fn foo() {
        \\    @setFloatMode(this, @import("builtin").FloatMode.Optimized);
        \\    @setFloatMode(this, @import("builtin").FloatMode.Optimized);
        \\}
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:3:5: error: float mode set twice for same scope",
        ".tmp_source.zig:2:5: note: first set here");

    cases.add("array access of type",
        \\extern fn foo() {
        \\    var b: u8[40] = undefined;
        \\}
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:2:14: error: array access of non-array type 'type'");

    cases.add("cannot break out of defer expression",
        \\extern fn foo() {
        \\    while (true) {
        \\        defer {
        \\            break;
        \\        }
        \\    }
        \\}
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:4:13: error: cannot break out of defer expression");

    cases.add("cannot continue out of defer expression",
        \\extern fn foo() {
        \\    while (true) {
        \\        defer {
        \\            continue;
        \\        }
        \\    }
        \\}
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:4:13: error: cannot continue out of defer expression");

    cases.add("cannot goto out of defer expression",
        \\extern fn foo() {
        \\    defer {
        \\        goto label;
        \\    };
        \\label:
        \\}
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:3:9: error: cannot goto out of defer expression");

    cases.add("calling a var args function only known at runtime",
        \\var foos = []fn(...) { foo1, foo2 };
        \\
        \\fn foo1(args: ...) {}
        \\fn foo2(args: ...) {}
        \\
        \\pub fn main() -> %void {
        \\    foos[0]();
        \\}
    ,
        ".tmp_source.zig:7:9: error: calling a generic function requires compile-time known function value");

    cases.add("calling a generic function only known at runtime",
        \\var foos = []fn(var) { foo1, foo2 };
        \\
        \\fn foo1(arg: var) {}
        \\fn foo2(arg: var) {}
        \\
        \\pub fn main() -> %void {
        \\    foos[0](true);
        \\}
    ,
        ".tmp_source.zig:7:9: error: calling a generic function requires compile-time known function value");

    cases.add("@compileError shows traceback of references that caused it",
        \\const foo = @compileError("aoeu");
        \\
        \\const bar = baz + foo;
        \\const baz = 1;
        \\
        \\extern fn entry() -> i32 {
        \\    return bar;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:1:13: error: aoeu",
        ".tmp_source.zig:3:19: note: referenced here",
        ".tmp_source.zig:7:12: note: referenced here");

    cases.add("instantiating an undefined value for an invalid struct that contains itself",
        \\const Foo = struct {
        \\    x: Foo,
        \\};
        \\
        \\var foo: Foo = undefined;
        \\
        \\extern fn entry() -> usize {
        \\    return @sizeOf(@typeOf(foo.x));
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:1:13: error: struct 'Foo' contains itself");

    cases.add("float literal too large error",
        \\comptime {
        \\    const a = 0x1.0p16384;
        \\}
    ,
        ".tmp_source.zig:2:15: error: float literal out of range of any type");

    cases.add("float literal too small error (denormal)",
        \\comptime {
        \\    const a = 0x1.0p-16384;
        \\}
    ,
        ".tmp_source.zig:2:15: error: float literal out of range of any type");

    cases.add("explicit cast float literal to integer when there is a fraction component",
        \\extern fn entry() -> i32 {
        \\    i32(12.34)
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:9: error: fractional component prevents float value 12.340000 from being casted to type 'i32'");

    cases.add("non pointer given to @ptrToInt",
        \\extern fn entry(x: i32) -> usize {
        \\    @ptrToInt(x)
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:15: error: expected pointer, found 'i32'");

    cases.add("@shlExact shifts out 1 bits",
        \\comptime {
        \\    const x = @shlExact(u8(0b01010101), 2);
        \\}
    ,
        ".tmp_source.zig:2:15: error: operation caused overflow");

    cases.add("@shrExact shifts out 1 bits",
        \\comptime {
        \\    const x = @shrExact(u8(0b10101010), 2);
        \\}
    ,
        ".tmp_source.zig:2:15: error: exact shift shifted out 1 bits");

    cases.add("shifting without int type or comptime known",
        \\extern fn entry(x: u8) -> u8 {
        \\    return 0x11 << x;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:17: error: LHS of shift must be an integer type, or RHS must be compile-time known");

    cases.add("shifting RHS is log2 of LHS int bit width",
        \\extern fn entry(x: u8, y: u8) -> u8 {
        \\    return x << y;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:17: error: expected type 'u3', found 'u8'");

    cases.add("globally shadowing a primitive type",
        \\const u16 = @intType(false, 8);
        \\extern fn entry() {
        \\    const a: u16 = 300;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:1:1: error: declaration shadows type 'u16'");

    cases.add("implicitly increasing pointer alignment",
        \\const Foo = packed struct {
        \\    a: u8,
        \\    b: u32,
        \\};
        \\
        \\extern fn entry() {
        \\    var foo = Foo { .a = 1, .b = 10 };
        \\    bar(&foo.b);
        \\}
        \\
        \\fn bar(x: &u32) {
        \\    *x += 1;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:8:13: error: expected type '&u32', found '&align(1) u32'");

    cases.add("implicitly increasing slice alignment",
        \\const Foo = packed struct {
        \\    a: u8,
        \\    b: u32,
        \\};
        \\
        \\extern fn entry() {
        \\    var foo = Foo { .a = 1, .b = 10 };
        \\    foo.b += 1;
        \\    bar((&foo.b)[0..1]);
        \\}
        \\
        \\fn bar(x: []u32) {
        \\    x[0] += 1;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:9:17: error: expected type '[]u32', found '[]align(1) u32'");

    cases.add("increase pointer alignment in @ptrCast",
        \\extern fn entry() -> u32 {
        \\    var bytes: [4]u8 = []u8{0x01, 0x02, 0x03, 0x04};
        \\    const ptr = @ptrCast(&u32, &bytes[0]);
        \\    return *ptr;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:3:17: error: cast increases pointer alignment",
        ".tmp_source.zig:3:38: note: '&u8' has alignment 1",
        ".tmp_source.zig:3:27: note: '&u32' has alignment 4");

    cases.add("increase pointer alignment in slice resize",
        \\extern fn entry() -> u32 {
        \\    var bytes = []u8{0x01, 0x02, 0x03, 0x04};
        \\    return ([]u32)(bytes[0..])[0];
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:3:19: error: cast increases pointer alignment",
        ".tmp_source.zig:3:19: note: '[]u8' has alignment 1",
        ".tmp_source.zig:3:19: note: '[]u32' has alignment 4");

    cases.add("@alignCast expects pointer or slice",
        \\extern fn entry() {
        \\    @alignCast(4, u32(3))
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:22: error: expected pointer or slice, found 'u32'");

    cases.add("passing an under-aligned function pointer",
        \\extern fn entry() {
        \\    testImplicitlyDecreaseFnAlign(alignedSmall, 1234);
        \\}
        \\fn testImplicitlyDecreaseFnAlign(ptr: fn () align(8) -> i32, answer: i32) {
        \\    if (ptr() != answer) unreachable;
        \\}
        \\fn alignedSmall() align(4) -> i32 { 1234 }
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:35: error: expected type 'fn() align(8) -> i32', found 'fn() align(4) -> i32'");

    cases.add("passing a not-aligned-enough pointer to cmpxchg",
        \\const AtomicOrder = @import("builtin").AtomicOrder;
        \\extern fn entry() -> bool {
        \\    var x: i32 align(1) = 1234;
        \\    while (!@cmpxchg(&x, 1234, 5678, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) {}
        \\    return x == 5678;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:4:23: error: expected pointer alignment of at least 4, found 1");

    cases.add("wrong size to an array literal",
        \\comptime {
        \\    const array = [2]u8{1, 2, 3};
        \\}
    ,
        ".tmp_source.zig:2:24: error: expected [2]u8 literal, found [3]u8 literal");

    cases.add("@setEvalBranchQuota in non-root comptime execution context",
        \\comptime {
        \\    foo();
        \\}
        \\fn foo() {
        \\    @setEvalBranchQuota(1001);
        \\}
    ,
        ".tmp_source.zig:5:5: error: @setEvalBranchQuota must be called from the top of the comptime stack",
        ".tmp_source.zig:2:8: note: called from here",
        ".tmp_source.zig:1:10: note: called from here");

    cases.add("wrong pointer implicitly casted to pointer to @OpaqueType()",
        \\const Derp = @OpaqueType();
        \\extern fn bar(d: &Derp);
        \\extern fn foo() {
        \\    const x = u8(1);
        \\    bar(@ptrCast(&c_void, &x));
        \\}
        \\comptime {@export("foo", foo);}
    ,
        ".tmp_source.zig:5:9: error: expected type '&Derp', found '&c_void'");

    cases.add("non-const variables of things that require const variables",
        \\const Opaque = @OpaqueType();
        \\
        \\extern fn entry(opaque: &Opaque) {
        \\   var m2 = &2;
        \\   const y: u32 = *m2;
        \\
        \\   var a = undefined;
        \\   var b = 1;
        \\   var c = 1.0;
        \\   var d = this;
        \\   var e = null;
        \\   var f = *opaque;
        \\   var g = i32;
        \\   var h = @import("std");
        \\   var i = (Foo {}).bar;
        \\
        \\   var z: noreturn = return;
        \\}
        \\
        \\const Foo = struct {
        \\    fn bar(self: &const Foo) {}
        \\};
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:4:4: error: variable of type '&const (integer literal)' must be const or comptime",
        ".tmp_source.zig:7:4: error: variable of type '(undefined)' must be const or comptime",
        ".tmp_source.zig:8:4: error: variable of type '(integer literal)' must be const or comptime",
        ".tmp_source.zig:9:4: error: variable of type '(float literal)' must be const or comptime",
        ".tmp_source.zig:10:4: error: variable of type '(block)' must be const or comptime",
        ".tmp_source.zig:11:4: error: variable of type '(null)' must be const or comptime",
        ".tmp_source.zig:12:4: error: variable of type 'Opaque' must be const or comptime",
        ".tmp_source.zig:13:4: error: variable of type 'type' must be const or comptime",
        ".tmp_source.zig:14:4: error: variable of type '(namespace)' must be const or comptime",
        ".tmp_source.zig:15:4: error: variable of type '(bound fn(&const Foo))' must be const or comptime",
        ".tmp_source.zig:17:4: error: unreachable code");

    cases.add("wrong types given to atomic order args in cmpxchg",
        \\extern fn entry() {
        \\    var x: i32 = 1234;
        \\    while (!@cmpxchg(&x, 1234, 5678, u32(1234), u32(1234))) {}
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:3:41: error: expected type 'AtomicOrder', found 'u32'");

    cases.add("struct with invalid field",
        \\const std = @import("std");
        \\const Allocator = std.mem.Allocator;
        \\const ArrayList = std.ArrayList;
        \\
        \\const HeaderWeight = enum {
        \\    H1, H2, H3, H4, H5, H6,
        \\};
        \\
        \\const MdText = ArrayList(u8);
        \\
        \\const MdNode = union(enum) {
        \\    Header: struct {
        \\        text: MdText,
        \\        weight: HeaderValue,
        \\    },
        \\};
        \\
        \\extern fn entry() {
        \\    const a = MdNode.Header {
        \\        .text = MdText.init(&std.debug.global_allocator),
        \\        .weight = HeaderWeight.H1,
        \\    };
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:14:17: error: use of undeclared identifier 'HeaderValue'");

    cases.add("@setAlignStack outside function",
        \\comptime {
        \\    @setAlignStack(16);
        \\}
    ,
        ".tmp_source.zig:2:5: error: @setAlignStack outside function");

    cases.add("@setAlignStack in naked function",
        \\nakedcc fn entry() {
        \\    @setAlignStack(16);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:5: error: @setAlignStack in naked function");

    cases.add("@setAlignStack in inline function",
        \\extern fn entry() {
        \\    foo();
        \\}
        \\inline fn foo() {
        \\    @setAlignStack(16);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:5:5: error: @setAlignStack in inline function");

    cases.add("@setAlignStack set twice",
        \\extern fn entry() {
        \\    @setAlignStack(16);
        \\    @setAlignStack(16);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:3:5: error: alignstack set twice",
        ".tmp_source.zig:2:5: note: first set here");

    cases.add("@setAlignStack too big",
        \\extern fn entry() {
        \\    @setAlignStack(511 + 1);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:5: error: attempt to @setAlignStack(512); maximum is 256");

    cases.add("storing runtime value in compile time variable then using it",
        \\const Mode = @import("builtin").Mode;
        \\
        \\fn Free(comptime filename: []const u8) -> TestCase {
        \\    TestCase {
        \\        .filename = filename,
        \\        .problem_type = ProblemType.Free,
        \\    }
        \\}
        \\
        \\fn LibC(comptime filename: []const u8) -> TestCase {
        \\    TestCase {
        \\        .filename = filename,
        \\        .problem_type = ProblemType.LinkLibC,
        \\    }
        \\}
        \\
        \\const TestCase = struct {
        \\    filename: []const u8,
        \\    problem_type: ProblemType,
        \\};
        \\
        \\const ProblemType = enum {
        \\    Free,
        \\    LinkLibC,
        \\};
        \\
        \\extern fn entry() {
        \\    const tests = []TestCase {
        \\        Free("001"),
        \\        Free("002"),
        \\        LibC("078"),
        \\        Free("116"),
        \\        Free("117"),
        \\    };
        \\
        \\    for ([]Mode { Mode.Debug, Mode.ReleaseSafe, Mode.ReleaseFast }) |mode| {
        \\        inline for (tests) |test_case| {
        \\            const foo = test_case.filename ++ ".zig";
        \\        }
        \\    }
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:37:16: error: cannot store runtime value in compile time variable");

    cases.add("field access of opaque type",
        \\const MyType = @OpaqueType();
        \\
        \\extern fn entry() -> bool {
        \\    var x: i32 = 1;
        \\    return bar(@ptrCast(&MyType, &x));
        \\}
        \\
        \\fn bar(x: &MyType) -> bool {
        \\    return x.blah;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:9:13: error: type '&MyType' does not support field access");

    cases.add("carriage return special case",
        "fn test() -> bool {\r\n" ++
        "   true\r\n" ++
        "}\r\n"
    ,
        ".tmp_source.zig:1:20: error: invalid carriage return, only '\\n' line endings are supported");

    cases.add("non-printable invalid character",
        "\xff\xfe" ++
        \\fn test() -> bool {\r
        \\    true\r
        \\}
    ,
        ".tmp_source.zig:1:1: error: invalid character: '\\xff'");

    cases.add("non-printable invalid character with escape alternative",
        "fn test() -> bool {\n" ++
        "\ttrue\n" ++
        "}\n"
    ,
        ".tmp_source.zig:2:1: error: invalid character: '\\t'");

    cases.add("@ArgType given non function parameter",
        \\comptime {
        \\    _ = @ArgType(i32, 3);
        \\}
    ,
        ".tmp_source.zig:2:18: error: expected function, found 'i32'");

    cases.add("@ArgType arg index out of bounds",
        \\comptime {
        \\    _ = @ArgType(@typeOf(add), 2);
        \\}
        \\fn add(a: i32, b: i32) -> i32 { return a + b; }
    ,
        ".tmp_source.zig:2:32: error: arg index 2 out of bounds; 'fn(i32, i32) -> i32' has 2 arguments");

    cases.add("@memberType on unsupported type",
        \\comptime {
        \\    _ = @memberType(i32, 0);
        \\}
    ,
        ".tmp_source.zig:2:21: error: type 'i32' does not support @memberType");

    cases.add("@memberType on enum",
        \\comptime {
        \\    _ = @memberType(Foo, 0);
        \\}
        \\const Foo = enum {A,};
    ,
        ".tmp_source.zig:2:21: error: type 'Foo' does not support @memberType");

    cases.add("@memberType struct out of bounds",
        \\comptime {
        \\    _ = @memberType(Foo, 0);
        \\}
        \\const Foo = struct {};
    ,
        ".tmp_source.zig:2:26: error: member index 0 out of bounds; 'Foo' has 0 members");

    cases.add("@memberType union out of bounds",
        \\comptime {
        \\    _ = @memberType(Foo, 1);
        \\}
        \\const Foo = union {A: void,};
    ,
        ".tmp_source.zig:2:26: error: member index 1 out of bounds; 'Foo' has 1 members");

    cases.add("@memberName on unsupported type",
        \\comptime {
        \\    _ = @memberName(i32, 0);
        \\}
    ,
        ".tmp_source.zig:2:21: error: type 'i32' does not support @memberName");

    cases.add("@memberName struct out of bounds",
        \\comptime {
        \\    _ = @memberName(Foo, 0);
        \\}
        \\const Foo = struct {};
    ,
        ".tmp_source.zig:2:26: error: member index 0 out of bounds; 'Foo' has 0 members");

    cases.add("@memberName enum out of bounds",
        \\comptime {
        \\    _ = @memberName(Foo, 1);
        \\}
        \\const Foo = enum {A,};
    ,
        ".tmp_source.zig:2:26: error: member index 1 out of bounds; 'Foo' has 1 members");

    cases.add("@memberName union out of bounds",
        \\comptime {
        \\    _ = @memberName(Foo, 1);
        \\}
        \\const Foo = union {A:i32,};
    ,
        ".tmp_source.zig:2:26: error: member index 1 out of bounds; 'Foo' has 1 members");

    cases.add("calling var args extern function, passing array instead of pointer",
        \\extern fn entry() {
        \\    foo("hello");
        \\}
        \\pub extern fn foo(format: &const u8, ...);
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:9: error: expected type '&const u8', found '[5]u8'");

    cases.add("constant inside comptime function has compile error",
        \\const ContextAllocator = MemoryPool(usize);
        \\
        \\pub fn MemoryPool(comptime T: type) -> type {
        \\    const free_list_t = @compileError("aoeu");
        \\
        \\    struct {
        \\        free_list: free_list_t,
        \\    }
        \\}
        \\
        \\extern fn entry() {
        \\    var allocator: ContextAllocator = undefined;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:4:25: error: aoeu",
        ".tmp_source.zig:1:36: note: called from here",
        ".tmp_source.zig:12:20: note: referenced here");

    cases.add("specify enum tag type that is too small",
        \\const Small = enum (u2) {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\    Five,
        \\};
        \\
        \\extern fn entry() {
        \\    var x = Small.One;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:1:20: error: 'u2' too small to hold all bits; must be at least 'u3'");

    cases.add("specify non-integer enum tag type",
        \\const Small = enum (f32) {
        \\    One,
        \\    Two,
        \\    Three,
        \\};
        \\
        \\extern fn entry() {
        \\    var x = Small.One;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:1:20: error: expected integer, found 'f32'");

    cases.add("implicitly casting enum to tag type",
        \\const Small = enum(u2) {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\};
        \\
        \\extern fn entry() {
        \\    var x: u2 = Small.Two;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:9:22: error: expected type 'u2', found 'Small'");

    cases.add("explicitly casting enum to non tag type",
        \\const Small = enum(u2) {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\};
        \\
        \\extern fn entry() {
        \\    var x = u3(Small.Two);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:9:15: error: enum to integer cast to 'u3' instead of its tag type, 'u2'");

    cases.add("explicitly casting non tag type to enum",
        \\const Small = enum(u2) {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\};
        \\
        \\extern fn entry() {
        \\    var y = u3(3);
        \\    var x = Small(y);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:10:18: error: integer to enum cast from 'u3' instead of its tag type, 'u2'");

    cases.add("non unsigned integer enum tag type",
        \\const Small = enum(i2) {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\};
        \\
        \\extern fn entry() {
        \\    var y = Small.Two;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:1:19: error: expected unsigned integer, found 'i2'");

    cases.add("struct fields with value assignments",
        \\const MultipleChoice = struct {
        \\    A: i32 = 20,
        \\};
        \\extern fn entry() {
        \\        var x: MultipleChoice = undefined;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:14: error: enums, not structs, support field assignment");

    cases.add("union fields with value assignments",
        \\const MultipleChoice = union {
        \\    A: i32 = 20,
        \\};
        \\extern fn entry() {
        \\    var x: MultipleChoice = undefined;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:14: error: non-enum union field assignment",
        ".tmp_source.zig:1:24: note: consider 'union(enum)' here");

    cases.add("enum with 0 fields",
        \\const Foo = enum {};
        \\extern fn entry() -> usize {
        \\    return @sizeOf(Foo);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:1:13: error: enums must have 1 or more fields");

    cases.add("union with 0 fields",
        \\const Foo = union {};
        \\extern fn entry() -> usize {
        \\    return @sizeOf(Foo);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:1:13: error: unions must have 1 or more fields");

    cases.add("enum value already taken",
        \\const MultipleChoice = enum(u32) {
        \\    A = 20,
        \\    B = 40,
        \\    C = 60,
        \\    D = 1000,
        \\    E = 60,
        \\};
        \\extern fn entry() {
        \\    var x = MultipleChoice.C;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:6:9: error: enum tag value 60 already taken",
        ".tmp_source.zig:4:9: note: other occurrence here");

    cases.add("union with specified enum omits field",
        \\const Letter = enum {
        \\    A,
        \\    B,
        \\    C,
        \\};
        \\const Payload = union(Letter) {
        \\    A: i32,
        \\    B: f64,
        \\};
        \\extern fn entry() -> usize {
        \\    return @sizeOf(Payload);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:6:17: error: enum field missing: 'C'",
        ".tmp_source.zig:4:5: note: declared here");

    cases.add("@TagType when union has no attached enum",
        \\const Foo = union {
        \\    A: i32,
        \\};
        \\extern fn entry() {
        \\    const x = @TagType(Foo);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:5:24: error: union 'Foo' has no tag",
        ".tmp_source.zig:1:13: note: consider 'union(enum)' here");

    cases.add("non-integer tag type to automatic union enum",
        \\const Foo = union(enum(f32)) {
        \\    A: i32,
        \\};
        \\extern fn entry() {
        \\    const x = @TagType(Foo);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:1:23: error: expected integer tag type, found 'f32'");

    cases.add("non-enum tag type passed to union",
        \\const Foo = union(u32) {
        \\    A: i32,
        \\};
        \\extern fn entry() {
        \\    const x = @TagType(Foo);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:1:18: error: expected enum tag type, found 'u32'");

    cases.add("union auto-enum value already taken",
        \\const MultipleChoice = union(enum(u32)) {
        \\    A = 20,
        \\    B = 40,
        \\    C = 60,
        \\    D = 1000,
        \\    E = 60,
        \\};
        \\extern fn entry() {
        \\    var x = MultipleChoice { .C = {} };
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:6:9: error: enum tag value 60 already taken",
        ".tmp_source.zig:4:9: note: other occurrence here");

    cases.add("union enum field does not match enum",
        \\const Letter = enum {
        \\    A,
        \\    B,
        \\    C,
        \\};
        \\const Payload = union(Letter) {
        \\    A: i32,
        \\    B: f64,
        \\    C: bool,
        \\    D: bool,
        \\};
        \\extern fn entry() {
        \\    var a = Payload {.A = 1234};
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:10:5: error: enum field not found: 'D'",
        ".tmp_source.zig:1:16: note: enum declared here");

    cases.add("field type supplied in an enum",
        \\const Letter = enum {
        \\    A: void,
        \\    B,
        \\    C,
        \\};
        \\extern fn entry() {
        \\    var b = Letter.B;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:8: error: structs and unions, not enums, support field types",
        ".tmp_source.zig:1:16: note: consider 'union(enum)' here");

    cases.add("struct field missing type",
        \\const Letter = struct {
        \\    A,
        \\};
        \\extern fn entry() {
        \\    var a = Letter { .A = {} };
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:5: error: struct field missing type");

    cases.add("extern union field missing type",
        \\const Letter = extern union {
        \\    A,
        \\};
        \\extern fn entry() {
        \\    var a = Letter { .A = {} };
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:2:5: error: union field missing type");

    cases.add("extern union given enum tag type",
        \\const Letter = enum {
        \\    A,
        \\    B,
        \\    C,
        \\};
        \\const Payload = extern union(Letter) {
        \\    A: i32,
        \\    B: f64,
        \\    C: bool,
        \\};
        \\extern fn entry() {
        \\    var a = Payload { .A = { 1234 } };
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:6:29: error: extern union does not support enum tag type");

    cases.add("packed union given enum tag type",
        \\const Letter = enum {
        \\    A,
        \\    B,
        \\    C,
        \\};
        \\const Payload = packed union(Letter) {
        \\    A: i32,
        \\    B: f64,
        \\    C: bool,
        \\};
        \\extern fn entry() {
        \\    var a = Payload { .A = { 1234 } };
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:6:29: error: packed union does not support enum tag type");

    cases.add("switch on union with no attached enum",
        \\const Payload = union {
        \\    A: i32,
        \\    B: f64,
        \\    C: bool,
        \\};
        \\extern fn entry() {
        \\    const a = Payload { .A = { 1234 } };
        \\    foo(a);
        \\}
        \\fn foo(a: &const Payload) {
        \\    switch (*a) {
        \\        Payload.A => {},
        \\        else => unreachable,
        \\    }
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:11:13: error: switch on union which has no attached enum",
        ".tmp_source.zig:1:17: note: consider 'union(enum)' here");

    cases.add("enum in field count range but not matching tag",
        \\const Foo = enum(u32) {
        \\    A = 10,
        \\    B = 11,
        \\};
        \\extern fn entry() {
        \\    var x = Foo(0);
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:6:16: error: enum 'Foo' has no tag matching integer value 0",
        ".tmp_source.zig:1:13: note: 'Foo' declared here");

    cases.add("comptime cast enum to union but field has payload",
        \\const Letter = enum { A, B, C };
        \\const Value = union(Letter) {
        \\    A: i32,
        \\    B,
        \\    C,
        \\};
        \\extern fn entry() {
        \\    var x: Value = Letter.A;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:8:26: error: cast to union 'Value' must initialize 'i32' field 'A'",
        ".tmp_source.zig:3:5: note: field 'A' declared here");

    cases.add("runtime cast to union which has non-void fields",
        \\const Letter = enum { A, B, C };
        \\const Value = union(Letter) {
        \\    A: i32,
        \\    B,
        \\    C,
        \\};
        \\extern fn entry() {
        \\    foo(Letter.A);
        \\}
        \\fn foo(l: Letter) {
        \\    var x: Value = l;
        \\}
        \\comptime {@export("entry", entry);}
    ,
        ".tmp_source.zig:11:20: error: runtime cast to union 'Value' which has non-void fields",
        ".tmp_source.zig:3:5: note: field 'A' has type 'i32'");

    cases.addCase({
        const tc = cases.create("export collision",
            \\const foo = @import("foo.zig");
            \\
            \\comptime {@export("bar", bar);}
            \\extern fn bar() -> usize {
            \\    return foo.baz;
            \\}
        ,
            "foo.zig:2:11: error: exported symbol collision: 'bar'",
            ".tmp_source.zig:3:11: note: other symbol is here");

        tc.addSourceFile("foo.zig",
            \\extern fn bar() {}
            \\comptime {@export("bar", bar);}
            \\pub const baz = 1234;
        );

        tc
    });

}

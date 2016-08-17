# Official Style Guide

These conventions are not enforced by the compiler, but they are shipped in
this documentation along with the compiler in order to provide a point of
reference, should anyone wish to point to an authority on agreed upon Zig
coding style.

## Whitespace

 * 4 space indentation
 * Open braces on same line, unless you need to wrap.
 * If a list of things is longer than 2, put each item on its own line and
   exercise the abilty to put an extra comma at the end.
 * Line length: aim for 100; use common sense.

## Names

Roughly speaking: `camelCaseFunctionName`, `TitleCaseTypeName`,
`snake_case_variable_name`. More precisely:

 * If `x` is a `struct` (or an alias of a `struct`), then `x` should be `TitleCase`.
 * If `x` otherwise identifies a type, `x` should have `snake_case`.
 * If `x` is callable, and `x`'s return type is `type`, then `x` should be `TitleCase`.
 * If `x` is otherwise callable, then `x` should be `camelCase`.
 * Otherwise, `x` should be `snake_case`.

Acronyms, initialisms, proper nouns, or any other word that has capitalization
rules in written English are subject to naming conventions just like any other
word. Even acronyms that are only 2 letters long are subject to these
conventions.

Examples:

```zig
const namespace_name = @import("dir_name/file_name.zig");
var global_var: i32;
const const_name = 42;
const primitive_type_alias = f32;
const string_alias = []u8;

struct StructName {}
const StructAlias = StructName;

fn functionName(param_name: TypeName) {
    var functionPointer = functionName;
    functionPointer();
    functionPointer = otherFunction;
    functionPointer();
}
const functionAlias = functionName;

fn ListTemplateFunction(ChildType: type, inline fixed_size: usize) -> type {
    struct ShortList(T: type, n: usize) {
        field_name: [n]T,
        fn methodName() {}
    }
    return List(ChildType, fixed_size);
}

// The word XML loses its casing when used in Zig identifiers.
const xml_document =
    \\<?xml version="1.0" encoding="UTF-8"?>
    \\<document>
    \\</document>
    ;
struct XmlParser {}

// The initials BE (Big Endian) are just another word in Zig identifier names.
fn readU32Be() -> u32 {}
```

See Zig standard library for examples.

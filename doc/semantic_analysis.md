# How Semantic Analysis Works

We start with a set of files. Typically the user only has one entry point file,
which imports the other files they want to use. However, the compiler may
choose to add more files to the compilation, for example bootstrap.zig which
contains the code that calls main.

Our goal now is to treat everything that is marked with the `export` keyword
as a root node, and then then parse and semantically analyze as little as
possible in order to fulfill these exports.

So, some parts of the code very well may have uncaught semantic errors, but as
long as the code is not referenced in any way, the compiler will not complain
because the code may as well not exist. This is similar to the fact that code
excluded from compilation with an `#ifdef` in C is not analyzed. Avoiding
analyzing unused code will save compilation time - one of Zig's goals.

So, for each file, we iterate over the top level declarations. The set of top
level declarations are:

 * Function Definition
 * Global Variable Declaration
 * Container Declaration (struct or enum)
 * Type Declaration
 * Error Value Declaration
 * Use Declaration

Each of these can have `export` attached to them except for error value
declarations and use declarations.

When we see a top level declaration during this iteration, we determine its
unique name identifier within the file. For example, for a function definition,
the unique name identifier is simply its name. Using this name we add the top
level declaration to a map.

If the top level declaration is exported, we add it to a set of exported top
level identifiers.

If the top level declaration is a use declaration, we add it to a set of use
declarations.

If the top level declaration is an error value declaration, we assign it a value
and increment the count of error values.

After this preliminary iteration over the top level declarations, we iterate
over the use declarations and resolve them. To resolve a use declaration, we
analyze the associated expression, verify that its type is the namespace type,
and then add all the items from the namespace into the top level declaration
map for the current file.

To analyze an expression, we recurse the abstract syntax tree of the
expression. Whenever we must look up a symbol, if the symbol exists already,
we can use it. Otherwise, we look it up in the top level declaration map.
If it exists, we can use it. Otherwise, we interrupt resolving this use
declaration to resolve the next one. If a dependency loop is detected, emit
an error. If all use declarations are resolved yet the symbol we need still
does not exist, emit an error.

To analyze an `@import` expression, find the referenced file, parse it, and
add it to the set of files to perform semantic analysis on.

Proceed through the rest of the use declarations the same way.

If we make it through the use declarations without an error, then we have a
complete map of all globals that exist in the current file.

Next we iterate over the set of exported top level declarations.

If it's a function definition, add it to the set of exported function
definitions and resolve the function prototype only. Otherwise, resolve the
top level declaration completely. This may involve recursively resolving other
top level declarations that expressions depend on.

Finally, iterate over the set of exported function definitions and analyze the
bodies.

# `dbg(…)`

[![Build Status](https://travis-ci.org/sharkdp/dbg-macro.svg?branch=master)](https://travis-ci.org/sharkdp/dbg-macro) [![Build status](https://ci.appveyor.com/api/projects/status/vmo9rw4te2wifkul/branch/master?svg=true)](https://ci.appveyor.com/project/sharkdp/dbg-macro) [![Try it online](https://img.shields.io/badge/try-online-f34b7d.svg)](https://repl.it/@sharkdp/dbg-macro-demo) [![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](dbg.h)

*A macro for `printf`-style debugging fans.*

Debuggers are great. But sometimes you just don't have the time or patience to set
up everything correctly and just want a quick way to inspect some values at runtime.

This projects provides a [single header file](dbg.h) with a `dbg(…)`
macro that can be used in all circumstances where you would typically write
`printf("…", …)` or `std::cout << …`. But it comes with a few extras.

## Examples

``` c++
#include <vector>
#include <dbg.h>

// You can use "dbg(..)" in expressions:
int factorial(int n) {
  if (dbg(n <= 1)) {
    return dbg(1);
  } else {
    return dbg(n * factorial(n - 1));
  }
}

int main() {
  std::string message = "hello";
  dbg(message);  // [example.cpp:15 (main)] message = "hello" (std::string)

  const int a = 2;
  const int b = dbg(3 * a) + 1;  // [example.cpp:18 (main)] 3 * a = 6 (int)

  std::vector<int> numbers{b, 13, 42};
  dbg(numbers);  // [example.cpp:21 (main)] numbers = {7, 13, 42} (size: 3) (std::vector<int>)

  dbg("this line is executed");  // [example.cpp:23 (main)] this line is executed

  factorial(4);

  return 0;
}
```

The code above produces this output ([try it yourself](https://repl.it/@sharkdp/dbg-macro-demo)):

![dbg(…) macro output](https://i.imgur.com/NHEYk9A.png)

## Features

 * Easy to read, colorized output (colors auto-disable when the output is not an interactive terminal)
 * Prints file name, line number, function name and the original expression
 * Adds type information for the printed-out value
 * Specialized pretty-printers for containers, pointers, string literals, enums, `std::optional`, etc.
 * Can be used inside expressions (passing through the original value)
 * The `dbg.h` header issues a compiler warning when included (so you don't forget to remove it).
 * Compatible and tested with C++11, C++14 and C++17.

## Installation

To make this practical, the `dbg.h` header should to be readily available from all kinds of different
places and in all kinds of environments. The quick & dirty way is to actually copy the header file
to `/usr/include` or to clone the repository and symlink `dbg.h` to `/usr/include/dbg.h`.
``` bash
git clone https://github.com/sharkdp/dbg-macro
sudo ln -s $(readlink -f dbg-macro/dbg.h) /usr/include/dbg.h
```
If you don't want to make untracked changes to your filesystem, check below if there is a package for
your operating system or package manager.

### On Arch Linux

You can install [`dbg-macro` from the AUR](https://aur.archlinux.org/packages/dbg-macro/):
``` bash
yay -S dbg-macro
```

### With vcpkg

You can install the [`dbg-macro` port](https://github.com/microsoft/vcpkg/tree/master/ports/dbg-macro) via:
``` bash
vcpkg install dbg-macro
```

## Configuration

* Set the `DBG_MACRO_DISABLE` flag to disable the `dbg(…)` macro (i.e. to make it a no-op).
* Set the `DBG_MACRO_NO_WARNING` flag to disable the *"'dbg.h' header is included in your code base"* warnings.

## Advanced features

### Hexadecimal, octal and binary format

If you want to format integers in hexadecimal, octal or binary representation, you can
simply wrap them in `dbg::hex(…)`, `dbg::oct(…)` or `dbg::bin(…)`:
```c++
const uint32_t secret = 12648430;
dbg(dbg::hex(secret));
```

### Printing type names

`dbg(…)` already prints the type for each value in parenthesis (see screenshot above). But
sometimes you just want to print a type (maybe because you don't have a value for that type).
In this case, you can use the `dbg::type<T>()` helper to pretty-print a given type `T`.
For example:
```c++
template <typename T>
void my_function_template() {
  using MyDependentType = typename std::remove_reference<T>::type&&;
  dbg(dbg::type<MyDependentType>());
}
```

### Print the current time

To print a timestamp, you can use the `dbg::time()` helper:
```c++
dbg(dbg::time());
```

### Customization

If you want `dbg(…)` to work for your custom datatype, you can simply overload `operator<<` for
`std::ostream&`:
```c++
std::ostream& operator<<(std::ostream& out, const user_defined_type& v) {
  out << "…";
  return out;
}
```

If you want to modify the type name that is printed by `dbg(…)`, you can add a custom
`get_type_name` overload:
```c++
// Customization point for type information
namespace dbg {
    std::string get_type_name(type_tag<bool>) {
        return "truth value";
    }
}
```

## Development

If you want to contribute to `dbg-macro`, here is how you can build the tests and demos:

Make sure that the submodule(s) are up to date:
```bash
git submodule update --init
```

Then, use the typical `cmake` workflow. Usage of `-DCMAKE_CXX_STANDARD=17` is optional,
but recommended in order to have the largest set of features enabled:
```bash
mkdir build
cd build
cmake .. -DCMAKE_CXX_STANDARD=17
make
```

To run the tests, simply call:
```bash
make test
```
You can find the unit tests in `tests/basic.cpp`.

## Acknowledgement

This project is inspired by Rusts [`dbg!(…)` macro](https://doc.rust-lang.org/std/macro.dbg.html).

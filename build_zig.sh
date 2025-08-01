#!/bin/bash
~/zig/master/files/zig build -p stage3 --search-prefix "$(brew --prefix llvm@20)" --zig-lib-dir "$(realpath lib)" -Ddebug-extensions=true -Denable-llvm=true

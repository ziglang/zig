#!/bin/bash

# Copies the 'demangle' library, excluding 'DemangleConfig.h', to llvm. If no
# llvm directory is specified, then assume a monorepo layout.

set -e

FILES="ItaniumDemangle.h StringView.h Utility.h README.txt"
LLVM_DEMANGLE_DIR=$1

if [[ -z "$LLVM_DEMANGLE_DIR" ]]; then
    LLVM_DEMANGLE_DIR="../../../llvm/include/llvm/Demangle"
fi

if [[ ! -d "$LLVM_DEMANGLE_DIR" ]]; then
    echo "No such directory: $LLVM_DEMANGLE_DIR" >&2
    exit 1
fi

read -p "This will overwrite the copies of $FILES in $LLVM_DEMANGLE_DIR; are you sure? [y/N]" -n 1 -r ANSWER
echo

if [[ $ANSWER =~ ^[Yy]$ ]]; then
    for I in $FILES ; do
        cp $I $LLVM_DEMANGLE_DIR/$I
    done
fi

#!/bin/env bash

set -x
set -e

TESTDIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
BUILDDIR="${TESTDIR}/build"

cmake -B "${BUILDDIR}" "${TESTDIR}"
rm -rf "${BUILDDIR}"
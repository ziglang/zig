# REQUIRES: x86

## The test file contains an STT_TLS symbol but has no TLS section.
# RUN: not ld.lld %S/Inputs/tls-symbol.elf -o /dev/null 2>&1 | FileCheck %s
# CHECK: has an STT_TLS symbol but doesn't have an SHF_TLS section

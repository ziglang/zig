# -*- Python -*-

import os
import platform
import re
import subprocess
import locale

import lit.formats
import lit.util

from lit.llvm import llvm_config

# Configuration file for the 'lit' test runner.

# name: The name of this test suite.
config.name = 'lld'

# testFormat: The test format to use to interpret tests.
#
# For now we require '&&' between commands, until they get globally killed and
# the test runner updated.
config.test_format = lit.formats.ShTest(not llvm_config.use_lit_shell)

# suffixes: A list of file extensions to treat as test files.
config.suffixes = ['.ll', '.s', '.test', '.yaml', '.objtxt']

# excludes: A list of directories to exclude from the testsuite. The 'Inputs'
# subdirectories contain auxiliary inputs for various tests in their parent
# directories.
config.excludes = ['Inputs']

# test_source_root: The root path where tests are located.
config.test_source_root = os.path.dirname(__file__)

config.test_exec_root = os.path.join(config.lld_obj_root, 'test')

llvm_config.use_default_substitutions()
llvm_config.use_lld()

tool_patterns = [
    'llc', 'llvm-as', 'llvm-mc', 'llvm-nm',
    'llvm-objdump', 'llvm-pdbutil', 'llvm-readobj', 'obj2yaml', 'yaml2obj']

llvm_config.add_tool_substitutions(tool_patterns)

# When running under valgrind, we mangle '-vg' onto the end of the triple so we
# can check it with XFAIL and XTARGET.
if lit_config.useValgrind:
    config.target_triple += '-vg'

# Running on ELF based *nix
if platform.system() in ['FreeBSD', 'Linux']:
    config.available_features.add('system-linker-elf')

# Set if host-cxxabi's demangler can handle target's symbols.
if platform.system() not in ['Windows']:
    config.available_features.add('demangler')

llvm_config.feature_config(
    [('--build-mode', {'DEBUG': 'debug'}),
     ('--assertion-mode', {'ON': 'asserts'}),
     ('--targets-built', {'AArch64': 'aarch64',
                          'AMDGPU': 'amdgpu',
                          'ARM': 'arm',
                          'AVR': 'avr',
                          'Mips': 'mips',
                          'PowerPC': 'ppc',
                          'Sparc': 'sparc',
                          'WebAssembly': 'wasm',
                          'X86': 'x86'})
     ])

# Set a fake constant version so that we get consitent output.
config.environment['LLD_VERSION'] = 'LLD 1.0'

# Indirectly check if the mt.exe Microsoft utility exists by searching for
# cvtres, which always accompanies it.  Alternatively, check if we can use
# libxml2 to merge manifests.
if (lit.util.which('cvtres', config.environment['PATH'])) or \
        (config.llvm_libxml2_enabled == '1'):
    config.available_features.add('manifest_tool')

if (config.llvm_libxml2_enabled == '1'):
    config.available_features.add('libxml2')

tar_executable = lit.util.which('tar', config.environment['PATH'])
if tar_executable:
    tar_version = subprocess.Popen(
        [tar_executable, '--version'], stdout=subprocess.PIPE, env={'LANG': 'C'})
    if 'GNU tar' in tar_version.stdout.read().decode():
        config.available_features.add('gnutar')
    tar_version.wait()

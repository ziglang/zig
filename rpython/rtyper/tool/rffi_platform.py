#! /usr/bin/env python

import os
import sys
import struct
import py
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem import rffi
from rpython.rtyper.lltypesystem import llmemory
from rpython.tool.gcc_cache import build_executable_cache, try_compile_cache
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator.platform import CompilationError
from rpython.tool.udir import udir
from rpython.rlib.rarithmetic import r_uint, r_longlong, r_ulonglong, intmask, LONG_BIT

# ____________________________________________________________
#
# Helpers for simple cases

def eci_from_header(c_header_source, include_dirs=None, libraries=None):
    if include_dirs is None:
        include_dirs = []
    if libraries is None:
        libraries = []
    return ExternalCompilationInfo(
        post_include_bits=[c_header_source],
        include_dirs=include_dirs,
        libraries=libraries,
    )

def getstruct(name, c_header_source, interesting_fields):
    class CConfig:
        _compilation_info_ = eci_from_header(c_header_source)
        STRUCT = Struct(name, interesting_fields)
    return configure(CConfig)['STRUCT']

def getsimpletype(name, c_header_source, ctype_hint=rffi.INT):
    class CConfig:
        _compilation_info_ = eci_from_header(c_header_source)
        TYPE = SimpleType(name, ctype_hint)
    return configure(CConfig)['TYPE']

def getconstantinteger(name, c_header_source):
    class CConfig:
        _compilation_info_ = eci_from_header(c_header_source)
        CONST = ConstantInteger(name)
    return configure(CConfig)['CONST']

def getdefined(macro, c_header_source):
    class CConfig:
        _compilation_info_ = eci_from_header(c_header_source)
        DEFINED = Defined(macro)
    return configure(CConfig)['DEFINED']

def getdefineddouble(macro, c_header_source):
    class CConfig:
        _compilation_info_ = eci_from_header(c_header_source)
        DEFINED = DefinedConstantDouble(macro)
    return configure(CConfig)['DEFINED']

def getdefinedinteger(macro, c_header_source):
    class CConfig:
        _compilation_info_ = eci_from_header(c_header_source)
        DEFINED = DefinedConstantInteger(macro)
    return configure(CConfig)['DEFINED']

def getdefinedstring(macro, c_header_source):
    class CConfig:
        _compilation_info_ = eci_from_header(c_header_source)
        DEFINED = DefinedConstantString(macro)
    return configure(CConfig)['DEFINED']

def getintegerfunctionresult(function, args=None, c_header_source='', includes=[]):
    class CConfig:
        _compilation_info_ = eci_from_header(c_header_source)
        RESULT = IntegerFunctionResult(function, args)
    if includes:
        CConfig._compilation_info_.includes = includes
    return configure(CConfig)['RESULT']

def has(name, c_header_source, include_dirs=None, libraries=None):
    class CConfig:
        _compilation_info_ = \
            eci_from_header(c_header_source, include_dirs, libraries)
        HAS = Has(name)
    return configure(CConfig)['HAS']

def verify_eci(eci):
    """Check if a given ExternalCompilationInfo compiles and links.
    If not, raises CompilationError."""
    class CConfig:
        _compilation_info_ = eci
        WORKS = Works()
    configure(CConfig)

def checkcompiles(expression, c_header_source, include_dirs=None):
    """Check if expression compiles. If not, returns False"""
    return has(expression, c_header_source, include_dirs)

def sizeof(name, eci, **kwds):
    class CConfig:
        _compilation_info_ = eci
        SIZE = SizeOf(name)
    for k, v in kwds.items():
        setattr(CConfig, k, v)
    return configure(CConfig)['SIZE']

def memory_alignment():
    """Return the alignment (in bytes) of memory allocations.
    This is enough to make sure a structure with pointers and 'double'
    fields is properly aligned."""
    global _memory_alignment
    if _memory_alignment is None:
        if sys.platform == 'win32':
            _memory_alignment = LONG_BIT // 8
        else:
            S = getstruct('struct memory_alignment_test', """
               struct memory_alignment_test {
                   double d;
                   void* p;
               };
            """, [])
            result = S._hints['align']
            assert result & (result-1) == 0, "not a power of two??"
            _memory_alignment = result
    return _memory_alignment
_memory_alignment = None

# ____________________________________________________________
#
# General interface

class ConfigResult:
    def __init__(self, eci, info):
        self.eci = eci
        self.info = info
        self.result = {}

    def get_entry_result(self, entry):
        try:
            return self.result[entry]
        except KeyError:
            pass
        info = self.info[entry]
        self.result[entry] = entry.build_result(info, self)
        return self.result[entry]


class _CWriter(object):
    """ A simple class which aggregates config parts
    """
    def __init__(self, eci):
        self.path = uniquefilepath()
        self.f = self.path.open("w")
        self.eci = eci

    def write_header(self):
        f = self.f
        self.eci.write_c_header(f)
        print >> f, C_HEADER
        print >> f

    def write_entry(self, key, entry):
        f = self.f
        print >> f, 'void dump_section_%s(void) {' % (key,)
        for line in entry.prepare_code():
            if line and line[0] != '#':
                line = '\t' + line
            print >> f, line
        print >> f, '}'
        print >> f

    def write_entry_main(self, key):
        print >> self.f, '\tprintf("-+- %s\\n");' % (key,)
        print >> self.f, '\tdump_section_%s();' % (key,)
        print >> self.f, '\tprintf("---\\n");'

    def start_main(self):
        print >> self.f, 'int main(int argc, char *argv[]) {'

    def close(self):
        f = self.f
        print >> f, '\treturn 0;'
        print >> f, '}'
        f.close()

    def ask_gcc(self, question):
        self.start_main()
        self.f.write(question + "\n")
        self.close()
        try_compile_cache([self.path], self.eci)

def configure(CConfig, ignore_errors=False):
    """Examine the local system by running the C compiler.
    The CConfig class contains CConfigEntry attribues that describe
    what should be inspected; configure() returns a dict mapping
    names to the results.
    """
    for attr in ['_includes_', '_libraries_', '_sources_', '_library_dirs_',
                 '_include_dirs_', '_header_']:
        assert not hasattr(CConfig, attr), \
            "Found legacy attribute %s on CConfig" % attr

    eci = CConfig._compilation_info_
    entries = {}
    for key in dir(CConfig):
        value = getattr(CConfig, key)
        if isinstance(value, CConfigEntry):
            entries[key] = value

    res = {}
    if entries:   # can be empty if there are only CConfigSingleEntries
        results = configure_entries(
            entries.values(), eci, ignore_errors=ignore_errors)
        for name, result in zip(entries, results):
            res[name] = result

    for key in dir(CConfig):
        value = getattr(CConfig, key)
        if isinstance(value, CConfigSingleEntry):
            writer = _CWriter(eci)
            writer.write_header()
            res[key] = value.question(writer.ask_gcc)

    return res


def configure_entries(entries, eci, ignore_errors=False):
    writer = _CWriter(eci)
    writer.write_header()
    for i, entry in enumerate(entries):
        writer.write_entry(str(i), entry)

    writer.start_main()
    for i, entry in enumerate(entries):
        writer.write_entry_main(str(i))
    writer.close()

    infolist = list(run_example_code(
        writer.path, eci, ignore_errors=ignore_errors))
    assert len(infolist) == len(entries)

    resultinfo = {}
    for info, entry in zip(infolist, entries):
        resultinfo[entry] = info

    result = ConfigResult(eci, resultinfo)
    for entry in entries:
        yield result.get_entry_result(entry)

# ____________________________________________________________


class CConfigEntry(object):
    "Abstract base class."


class Struct(CConfigEntry):
    """An entry in a CConfig class that stands for an externally
    defined structure.
    """
    def __init__(self, name, interesting_fields, ifdef=None, adtmeths={}):
        self.name = name
        self.interesting_fields = interesting_fields
        self.ifdef = ifdef
        self.adtmeths = adtmeths

    def prepare_code(self):
        if self.ifdef is not None:
            yield '#ifdef %s' % (self.ifdef,)
        yield 'typedef %s platcheck_t;' % (self.name,)
        yield 'typedef struct {'
        yield '    char c;'
        yield '    platcheck_t s;'
        yield '} platcheck2_t;'
        yield ''
        yield 'platcheck_t s;'
        if self.ifdef is not None:
            yield 'dump("defined", 1);'
        yield 'dump("align", offsetof(platcheck2_t, s));'
        yield 'dump("size",  sizeof(platcheck_t));'
        for fieldname, fieldtype in self.interesting_fields:
            yield 'dump("fldofs %s", offsetof(platcheck_t, %s));'%(
                fieldname, fieldname)
            yield 'dump("fldsize %s",   sizeof(s.%s));' % (
                fieldname, fieldname)
            if fieldtype in integer_class:
                yield 's.%s = 0; s.%s = ~s.%s;' % (fieldname,
                                                   fieldname,
                                                   fieldname)
                yield 'dump("fldunsigned %s", s.%s > 0);' % (fieldname,
                                                             fieldname)
        if self.ifdef is not None:
            yield '#else'
            yield 'dump("defined", 0);'
            yield '#endif'

    def build_result(self, info, config_result):
        if self.ifdef is not None:
            if not info['defined']:
                return None
        layout = [None] * info['size']
        for fieldname, fieldtype in self.interesting_fields:
            if isinstance(fieldtype, Struct):
                offset = info['fldofs '  + fieldname]
                size   = info['fldsize ' + fieldname]
                c_fieldtype = config_result.get_entry_result(fieldtype)
                layout_addfield(layout, offset, c_fieldtype, fieldname)
            else:
                offset = info['fldofs '  + fieldname]
                size   = info['fldsize ' + fieldname]
                sign   = info.get('fldunsigned ' + fieldname, False)
                if is_array_nolength(fieldtype):
                    pass       # ignore size and sign
                elif (size, sign) != rffi.size_and_sign(fieldtype):
                    fieldtype = fixup_ctype(fieldtype, fieldname, (size, sign))
                layout_addfield(layout, offset, fieldtype, fieldname)

        n = 0
        padfields = []
        for i, cell in enumerate(layout):
            if cell is not None:
                continue
            name = '_pad%d' % (n,)
            layout_addfield(layout, i, rffi.UCHAR, name)
            padfields.append('c_' + name)
            n += 1

        # build the lltype Structure
        seen = {}
        fields = []
        fieldoffsets = []
        for offset, cell in enumerate(layout):
            if cell in seen:
                continue
            fields.append((cell.name, cell.ctype))
            fieldoffsets.append(offset)
            seen[cell] = True

        allfields = tuple(['c_' + name for name, _ in fields])
        padfields = tuple(padfields)
        name = self.name
        eci = config_result.eci
        padding_drop = PaddingDrop(name, allfields, padfields, eci)
        hints = {'align': info['align'],
                 'size': info['size'],
                 'fieldoffsets': tuple(fieldoffsets),
                 'padding': padfields,
                 'get_padding_drop': padding_drop,
                 'eci': eci}
        if name.startswith('struct '):
            name = name[7:]
        else:
            hints['typedef'] = True
        kwds = {'hints': hints, 'adtmeths': self.adtmeths}
        return rffi.CStruct(name, *fields, **kwds)

class SimpleType(CConfigEntry):
    """An entry in a CConfig class that stands for an externally
    defined simple numeric type.
    """
    def __init__(self, name, ctype_hint=rffi.INT, ifdef=None):
        self.name = name
        self.ctype_hint = ctype_hint
        self.ifdef = ifdef

    def prepare_code(self):
        if self.ifdef is not None:
            yield '#ifdef %s' % (self.ifdef,)
        yield 'typedef %s platcheck_t;' % (self.name,)
        yield ''
        yield 'platcheck_t x;'
        if self.ifdef is not None:
            yield 'dump("defined", 1);'
        yield 'dump("size",  sizeof(platcheck_t));'
        if self.ctype_hint in integer_class:
            yield 'x = 0; x = ~x;'
            yield 'dump("unsigned", x > 0);'
        if self.ifdef is not None:
            yield '#else'
            yield 'dump("defined", 0);'
            yield '#endif'

    def build_result(self, info, config_result):
        if self.ifdef is not None and not info['defined']:
            return None
        size = info['size']
        sign = info.get('unsigned', False)
        ctype = self.ctype_hint
        if (size, sign) != rffi.size_and_sign(ctype):
            ctype = fixup_ctype(ctype, self.name, (size, sign))
        return ctype


class ConstantInteger(CConfigEntry):
    """An entry in a CConfig class that stands for an externally
    defined integer constant.
    """
    def __init__(self, name):
        self.name = name

    def prepare_code(self):
        yield 'if ((%s) <= 0) {' % (self.name,)
        yield '    long long x = (long long)(%s);' % (self.name,)
        yield '    printf("value: %lld\\n", x);'
        yield '} else {'
        yield '    unsigned long long x = (unsigned long long)(%s);' % (
                        self.name,)
        yield '    printf("value: %llu\\n", x);'
        yield '}'

    def build_result(self, info, config_result):
        return expose_value_as_rpython(info['value'])

class IntegerFunctionResult(CConfigEntry):
    """An entry in a CConfig class that stands for an externally
    defined integer constant.
    """
    def __init__(self, name, args=None):
        self.name = name
        self.args = args if args else []

    def prepare_code(self):
        yield 'long int result = %s(%s);' % (self.name,
                            ', '.join([str(s) for s in self.args]))
        yield 'if ((result) <= 0) {'
        yield '    long long x = (long long)(result);'
        yield '    printf("value: %lld\\n", x);'
        yield '} else {'
        yield '    unsigned long long x = (unsigned long long)(result);'
        yield '    printf("value: %llu\\n", x);'
        yield '}'

    def build_result(self, info, config_result):
        return expose_value_as_rpython(info['value'])

class DefinedConstantInteger(CConfigEntry):
    """An entry in a CConfig class that stands for an externally
    defined integer constant. If not #defined the value will be None.
    """
    def __init__(self, macro):
        self.name = self.macro = macro

    def prepare_code(self):
        yield '#ifdef %s' % self.macro
        yield 'dump("defined", 1);'
        yield 'if ((%s) <= 0) {' % (self.macro,)
        yield '    long long x = (long long)(%s);' % (self.macro,)
        yield '    printf("value: %lld\\n", x);'
        yield '} else {'
        yield '    unsigned long long x = (unsigned long long)(%s);' % (
                        self.macro,)
        yield '    printf("value: %llu\\n", x);'
        yield '}'
        yield '#else'
        yield 'dump("defined", 0);'
        yield '#endif'

    def build_result(self, info, config_result):
        if info["defined"]:
            return expose_value_as_rpython(info['value'])
        return None

class DefinedConstantDouble(CConfigEntry):

    def __init__(self, macro):
        self.name = self.macro = macro

    def prepare_code(self):
        yield '#ifdef %s' % (self.macro,)
        yield 'int i;'
        yield 'double x = %s;' % (self.macro,)
        yield 'unsigned char *p = (unsigned char *)&x;'
        yield 'dump("defined", 1);'
        yield 'for (i = 0; i < 8; i++) {'
        yield ' printf("value_%d: %d\\n", i, p[i]);'
        yield '}'
        yield '#else'
        yield 'dump("defined", 0);'
        yield '#endif'

    def build_result(self, info, config_result):
        if info["defined"]:
            data = [chr(info["value_%d" % (i,)]) for i in range(8)]
            # N.B. This depends on IEEE 754 being implemented.
            return struct.unpack("d", ''.join(data))[0]
        return None

class DefinedConstantString(CConfigEntry):
    """
    """
    def __init__(self, macro, name=None):
        self.macro = macro
        self.name = name or macro

    def prepare_code(self):
        yield '#ifdef %s' % self.macro
        yield 'int i;'
        yield 'const char *p = %s;' % self.name
        yield 'dump("defined", 1);'
        yield 'for (i = 0; p[i] != 0; i++ ) {'
        yield '  printf("value_%d: %d\\n", i, (int)(unsigned char)p[i]);'
        yield '}'
        yield '#else'
        yield 'dump("defined", 0);'
        yield '#endif'

    def build_result(self, info, config_result):
        if info["defined"]:
            string = ''
            d = 0
            while info.has_key('value_%d' % d):
                string += chr(info['value_%d' % d])
                d += 1
            return string
        return None


class Defined(CConfigEntry):
    """A boolean, corresponding to an #ifdef.
    """
    def __init__(self, macro):
        self.macro = macro
        self.name = macro

    def prepare_code(self):
        yield '#ifdef %s' % (self.macro,)
        yield 'dump("defined", 1);'
        yield '#else'
        yield 'dump("defined", 0);'
        yield '#endif'

    def build_result(self, info, config_result):
        return bool(info['defined'])

class CConfigSingleEntry(object):
    """ An abstract class of type which requires
    gcc succeeding/failing instead of only asking
    """
    pass

class Has(CConfigSingleEntry):
    def __init__(self, name):
        self.name = name

    def question(self, ask_gcc):
        try:
            ask_gcc('(void)' + self.name + ';')
            return True
        except CompilationError:
            return False

class Works(CConfigSingleEntry):
    def question(self, ask_gcc):
        ask_gcc("")

class SizeOf(CConfigEntry):
    """An entry in a CConfig class that stands for
    some external opaque type
    """
    def __init__(self, name):
        self.name = name

    def prepare_code(self):
        yield 'dump("size",  sizeof(%s));' % self.name

    def build_result(self, info, config_result):
        return info['size']

# ____________________________________________________________

class PaddingDrop(object):
    # Compute (lazily) the padding_drop for a structure.
    # See test_generate_padding for more information.
    cache = None

    def __init__(self, name, allfields, padfields, eci):
        self.name = name
        self.allfields = allfields
        self.padfields = padfields
        self.eci = eci

    def __call__(self, types):
        if self.cache is None:
            self.compute_now(types)
        return self.cache

    def compute_now(self, types):
        # Some simplifying assumptions there.  We assume that all fields
        # are either integers or pointers, so can be written in C as '0'.
        # We also assume that the C backend gives us in 'types' a dictionary
        # mapping non-padding field names to their C type (without '@').
        drops = []
        staticfields = []
        consecutive_pads = []
        for fieldname in self.allfields:
            if fieldname in self.padfields:
                consecutive_pads.append(fieldname)
                continue
            staticfields.append(types[fieldname])
            if consecutive_pads:
                # In that case we have to ask: how many of these pads are
                # really needed?  The correct answer might be between none
                # and all of the pads listed in 'consecutive_pads'.
                for i in range(len(consecutive_pads)+1):
                    class CConfig:
                        _compilation_info_ = self.eci
                        FIELDLOOKUP = _PaddingDropFieldLookup(self.name,
                                                              staticfields,
                                                              fieldname)
                    try:
                        got = configure(CConfig)['FIELDLOOKUP']
                        if got == 1:
                            break     # found
                    except CompilationError:
                        pass
                    staticfields.insert(-1, None)
                else:
                    raise Exception("could not determine the detailed field"
                                    " layout of %r" % (self.name,))
                # succeeded with 'i' pads.  Drop all pads beyond that.
                drops += consecutive_pads[i:]
            consecutive_pads = []
        drops += consecutive_pads   # drop the final pads too
        self.cache = drops

class _PaddingDropFieldLookup(CConfigEntry):
    def __init__(self, name, staticfields, fieldname):
        self.name = name
        self.staticfields = staticfields
        self.fieldname = fieldname

    def prepare_code(self):
        yield 'typedef %s platcheck_t;' % (self.name,)
        yield 'static platcheck_t s = {'
        for i, type in enumerate(self.staticfields):
            if i == len(self.staticfields)-1:
                value = -1
            else:
                value = 0
            if type:
                yield '\t(%s)%s,' % (type, value)
            else:
                yield '\t%s,' % (value,)
        yield '};'
        fieldname = self.fieldname
        assert fieldname.startswith('c_')
        yield 'dump("fieldlookup", s.%s != 0);' % (fieldname[2:],)

    def build_result(self, info, config_result):
        return info['fieldlookup']

# ____________________________________________________________
#
# internal helpers

def uniquefilepath(LAST=[0]):
    i = LAST[0]
    LAST[0] += 1
    return udir.join('platcheck_%d.c' % i)

integer_class = [rffi.SIGNEDCHAR, rffi.UCHAR, rffi.CHAR,
                 rffi.SHORT, rffi.USHORT,
                 rffi.INT, rffi.UINT,
                 rffi.LONG, rffi.ULONG,
                 rffi.LONGLONG, rffi.ULONGLONG]
# XXX SIZE_T?

float_class = [rffi.DOUBLE]

def _sizeof(tp):
    # XXX don't use this!  internal purpose only, not really a sane logic
    if isinstance(tp, lltype.Struct):
        return sum([_sizeof(i) for i in tp._flds.values()])
    return rffi.sizeof(tp)

class Field(object):
    def __init__(self, name, ctype):
        self.name = name
        self.ctype = ctype
    def __repr__(self):
        return '<field %s: %s>' % (self.name, self.ctype)

def is_array_nolength(TYPE):
    return isinstance(TYPE, lltype.Array) and TYPE._hints.get('nolength', False)

def layout_addfield(layout, offset, ctype, prefix):
    if is_array_nolength(ctype):
        size = len(layout) - offset    # all the rest of the struct
    else:
        size = _sizeof(ctype)
    name = prefix
    i = 0
    while name in layout:
        i += 1
        name = '%s_%d' % (prefix, i)
    field = Field(name, ctype)
    for i in range(offset, offset+size):
        assert layout[i] is None, "%s overlaps %r" % (name, layout[i])
        layout[i] = field
    return field

def fixup_ctype(fieldtype, fieldname, expected_size_and_sign):
    for typeclass in [integer_class, float_class]:
        if fieldtype in typeclass:
            for ctype in typeclass:
                if rffi.size_and_sign(ctype) == expected_size_and_sign:
                    return ctype
    if isinstance(fieldtype, lltype.FixedSizeArray):
        size, _ = expected_size_and_sign
        return lltype.FixedSizeArray(fieldtype.OF, size/_sizeof(fieldtype.OF))
    raise TypeError("conflict between translating python and compiler field"
                    " type %r for symbol %r, expected size+sign %r" % (
                        fieldtype, fieldname, expected_size_and_sign))

def expose_value_as_rpython(value):
    if intmask(value) == value:
        return value
    if r_uint(value) == value:
        return r_uint(value)
    try:
        if r_longlong(value) == value:
            return r_longlong(value)
    except OverflowError:
        pass
    if r_ulonglong(value) == value:
        return r_ulonglong(value)
    raise OverflowError("value %d does not fit into any RPython integer type"
                        % (value,))

C_HEADER = """
#include <stdio.h>
#include <stddef.h>   /* for offsetof() */

void dump(char* key, int value) {
    printf("%s: %d\\n", key, value);
}
"""

def run_example_code(filepath, eci, ignore_errors=False):
    eci = eci.convert_sources_to_files()
    files = [filepath]
    output = build_executable_cache(files, eci, ignore_errors=ignore_errors)
    if not output.startswith('-+- '):
        raise Exception("run_example_code failed!\nlocals = %r" % (locals(),))
    section = None
    for line in output.splitlines():
        line = line.strip()
        if line.startswith('-+- '):      # start of a new section
            section = {}
        elif line == '---':              # section end
            assert section is not None
            yield section
            section = None
        elif line:
            assert section is not None
            key, value = line.split(': ')
            section[key] = int(value)

# ____________________________________________________________

from os.path import dirname
import rpython

PYPY_EXTERNAL_DIR = py.path.local(dirname(rpython.__file__)).join('..', '..')
# XXX make this configurable
if sys.platform == 'win32':
    for libdir in [
        py.path.local('c:/buildslave/support'), # on the bigboard buildbot
        py.path.local('d:/myslave'), # on the snakepit buildbot
        ]:
        if libdir.check():
            PYPY_EXTERNAL_DIR = libdir
            break

def configure_external_library(name, eci, configurations,
                               symbol=None, _cache={}):
    """try to find the external library.
    On Unix, this simply tests and returns the given eci.

    On Windows, various configurations may be tried to compile the
    given eci object.  These configurations are a list of dicts,
    containing:

    - prefix: if an absolute path, will prefix each include and
              library directories.  If a relative path, the external
              directory is searched for directories which names start
              with the prefix.  The last one in alphabetical order
              chosen, and becomes the prefix.

    - include_dir: prefix + include_dir is added to the include directories

    - library_dir: prefix + library_dir is added to the library directories
    """

    if sys.platform != 'win32':
        configurations = []

    key = (name, eci)
    try:
        return _cache[key]
    except KeyError:
        last_error = None

        # Always try the default configuration
        if {} not in configurations:
            configurations.append({})

        for configuration in configurations:
            prefix = configuration.get('prefix', '')
            include_dir = configuration.get('include_dir', '')
            library_dir = configuration.get('library_dir', '')

            if prefix and not os.path.isabs(prefix):
                import glob

                entries = glob.glob(str(PYPY_EXTERNAL_DIR.join(prefix + '*')))
                if entries:
                    # Get last version
                    prefix = sorted(entries)[-1]
                else:
                    continue

            include_dir = os.path.join(prefix, include_dir)
            library_dir = os.path.join(prefix, library_dir)

            eci_lib = ExternalCompilationInfo(
                include_dirs=include_dir and [include_dir] or [],
                library_dirs=library_dir and [library_dir] or [],
                )
            eci_lib = eci_lib.merge(eci)

            # verify that this eci can be compiled
            try:
                verify_eci(eci_lib)
            except CompilationError as e:
                last_error = e
            else:
                _cache[key] = eci_lib
                return eci_lib

        # Nothing found
        if last_error:
            raise last_error
        else:
            raise CompilationError("Library %s is not installed" % (name,))

def configure_boehm(platform=None):
    if platform is None:
        from rpython.translator.platform import platform
    if sys.platform == 'win32':
        import platform as host_platform # just to ask for the arch. Confusion-alert!
        if host_platform.architecture()[0] == '32bit':
            library_dir = 'Release'
            libraries = ['gc']
            includes=['gc.h']
        else:
            library_dir = ''
            libraries = ['gc64_dll']
            includes = ['gc.h']
        # since config_external_library does not use a platform kwarg,
        # somehow using a platform kw arg make the merge fail in
        # config_external_library
        platform = None
    else:
        library_dir = ''
        libraries = ['gc']
        includes=['gc/gc.h']
    try:
        eci = ExternalCompilationInfo.from_pkg_config('bdw-gc')
        eci.includes += tuple(includes)
        return eci
    except ImportError:
        eci = ExternalCompilationInfo(
            platform=platform,
            includes=includes,
            libraries=libraries,
        )
    return configure_external_library(
        'gc', eci,
        [dict(prefix='gc-', include_dir='include', library_dir=library_dir)],
        symbol='GC_init')

if __name__ == '__main__':
    doc = """Example:

       rffi_platform.py  -h sys/types.h  -h netinet/in.h
                           'struct sockaddr_in'
                           sin_port  INT
    """
    import getopt
    opts, args = getopt.gnu_getopt(sys.argv[1:], 'h:')
    if not args:
        print >> sys.stderr, doc
    else:
        assert len(args) % 2 == 1
        headers = []
        for opt, value in opts:
            if opt == '-h':
                headers.append('#include <%s>' % (value,))
        name = args[0]
        fields = []
        for i in range(1, len(args), 2):
            ctype = getattr(rffi, args[i+1])
            fields.append((args[i], ctype))

        S = getstruct(name, '\n'.join(headers), fields)

        for name in S._names:
            print name, getattr(S, name)

import sys
from itertools import izip
from collections import OrderedDict

from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rlib.rfile import FILEP
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper.tool import rfficache, rffi_platform
from rpython.flowspace.model import Constant, const
from rpython.flowspace.specialcase import register_flow_sc
from rpython.flowspace.flowcontext import FlowingError

from . import model
from .cparser import Parser


CNAME_TO_LLTYPE = {
    'char': rffi.CHAR,
    'double': rffi.DOUBLE, 'long double': rffi.LONGDOUBLE,
    'float': rffi.FLOAT, 'FILE': FILEP.TO}

def add_inttypes():
    for name in rffi.TYPES:
        if name.startswith('unsigned'):
            rname = 'u' + name[9:]
        else:
            rname = name
        rname = rname.replace(' ', '').upper()
        CNAME_TO_LLTYPE[name] = rfficache.platform.types[rname]

add_inttypes()
CNAME_TO_LLTYPE['int'] = rffi.INT_real
CNAME_TO_LLTYPE['wchar_t'] = lltype.UniChar
if 'ssize_t' not in CNAME_TO_LLTYPE:  # on Windows
    CNAME_TO_LLTYPE['ssize_t'] = rffi.SIGNED

def cname_to_lltype(name):
    return CNAME_TO_LLTYPE[name]

class DelayedStruct(object):
    def __init__(self, name, fields, TYPE):
        self.struct_name = name
        self.type_name = None
        self.fields = fields
        self.TYPE = TYPE

    def get_type_name(self):
        if self.type_name is not None:
            return self.type_name
        elif not self.struct_name.startswith('$'):
            return 'struct %s' % self.struct_name
        else:
            raise ValueError('Anonymous struct')

    def __repr__(self):
        return "<struct {struct_name}>".format(**vars(self))


class CTypeSpace(object):
    def __init__(self, parser=None, definitions=None, macros=None,
                 headers=None, includes=None, include_dirs=None):
        self.definitions = definitions if definitions is not None else {}
        self.macros = macros if macros is not None else {}
        self.structs = {}
        self.ctx = parser if parser else Parser()
        self.headers = headers if headers is not None else ['sys/types.h']
        self.parsed_headers = []
        self.sources = []
        self._config_entries = OrderedDict()
        self.includes = []
        self.struct_typedefs = {}
        self._handled = set()
        self._frozen = False
        self._cdecl_type_cache = {}  # {cdecl: TYPE} cache
        if includes is not None:
            for header in includes:
                self.include(header)
        if include_dirs is not None:
            self.include_dirs = include_dirs[:]
        else:
            self.include_dirs = []

    def include(self, other):
        self.ctx.include(other.ctx)
        self.structs.update(other.structs)
        self.includes.append(other)

    def parse_source(self, source, configure=True):
        self.sources.append(source)
        self.ctx.parse(source)
        if configure:
            self.configure_types()

    def parse_header(self, header_path, configure=True):
        self.headers.append(str(header_path))
        self.parsed_headers.append(header_path)
        self.ctx.parse(header_path.read())
        if configure:
            self.configure_types()

    def add_typedef(self, name, obj, quals):
        assert name not in self.definitions
        tp = self.convert_type(obj, quals)
        if isinstance(tp, DelayedStruct):
            if tp.type_name is None:
                tp.type_name = name
            tp = self.realize_struct(tp)
            self.structs[obj.realtype] = tp
        self.definitions[name] = tp

    def add_macro(self, name, value):
        assert name not in self.macros
        self.macros[name] = value

    def add_struct(self, name, obj, quals):
        tp = self.convert_type(obj, quals)
        if isinstance(tp, DelayedStruct):
            tp = self.realize_struct(tp)
        self.structs[obj] = tp

    def new_struct(self, obj):
        if obj.name == '_IO_FILE':  # cffi weirdness
            return cname_to_lltype('FILE')
        struct = DelayedStruct(obj.name, None, lltype.ForwardReference())
        # Cache it early, to avoid infinite recursion
        self.structs[obj] = struct
        if obj.fldtypes is not None:
            struct.fields = zip(
                obj.fldnames,
                [self.convert_field(field) for field in obj.fldtypes])
        return struct

    def convert_field(self, obj):
        tp = self.convert_type(obj)
        if isinstance(tp, DelayedStruct):
            tp = tp.TYPE
        elif isinstance(tp, type) and issubclass(tp, Enum):
            tp = rffi.INT_real
        return tp

    def realize_struct(self, struct):
        type_name = struct.get_type_name()
        if struct.fields is None:
            raise ValueError('Missing definition for %s' % type_name)
        entry = rffi_platform.Struct(type_name, struct.fields)
        self._config_entries[entry] = struct.TYPE
        return struct.TYPE

    def build_eci(self):
        all_sources = []
        for cts in self.includes:
            all_sources.extend(cts.sources)
        all_sources.extend(self.sources)
        all_headers = self.headers
        for x in self.includes:
            for hdr in x.headers:
                if hdr not in all_headers:
                    all_headers.append(hdr)
        if sys.platform == 'win32':
            if sys.maxint > 2**32:
                compile_extra = ['-Dssize_t=__int64']
            else:
                compile_extra = ['-Dssize_t=long']
        else:
            compile_extra = []
        return ExternalCompilationInfo(
            post_include_bits=all_sources, includes=all_headers,
            compile_extra=compile_extra,
            include_dirs=self.include_dirs)

    def configure_types(self):
        for name, (obj, quals) in self.ctx._declarations.iteritems():
            if obj in self.ctx._included_declarations:
                continue
            if name in self._handled:
                continue
            self._handled.add(name)
            if name.startswith('typedef '):
                name = name[8:]
                self.add_typedef(name, obj, quals)
            elif name.startswith('macro '):
                name = name[6:]
                self.add_macro(name, obj)
            elif name.startswith('struct '):
                name = name[7:]
                self.add_struct(name, obj, quals)
        if not self._config_entries:
            return
        eci = self.build_eci()

        while self._config_entries:
            configure_now = []
            for entry in self._config_entries:
                if self._can_configure(entry):
                    configure_now.append(entry)
            if not configure_now:
                raise ValueError("configure_types() cannot make progress. "
                                 "Maybe the cdef is invalid?")
            result = rffi_platform.configure_entries(configure_now, eci)
            for entry, TYPE in izip(configure_now, result):
                # hack: prevent the source from being pasted into common_header.h
                del TYPE._hints['eci']
                self._config_entries[entry].become(TYPE)
                del self._config_entries[entry]

    def _can_configure(self, entry):
        if isinstance(entry, rffi_platform.Struct):
            # A struct containing a nested struct can only be configured if
            # the inner one has already been configured.
            for fieldname, fieldtype in entry.interesting_fields:
                if isinstance(fieldtype, lltype.ForwardReference):
                    return False
        return True

    def convert_type(self, obj, quals=0):
        if isinstance(obj, model.DefinedType):
            return self.convert_type(obj.realtype, obj.quals)
        if isinstance(obj, model.PrimitiveType):
            return cname_to_lltype(obj.name)
        elif isinstance(obj, model.StructType):
            if obj in self.structs:
                return self.structs[obj]
            return self.new_struct(obj)
        elif isinstance(obj, model.PointerType):
            TO = self.convert_type(obj.totype)
            if TO is lltype.Void:
                return rffi.VOIDP
            elif isinstance(TO, DelayedStruct):
                TO = TO.TYPE
            if isinstance(TO, lltype.ContainerType):
                return lltype.Ptr(TO)
            else:
                if obj.quals & model.Q_CONST:
                    return lltype.Ptr(lltype.Array(
                        TO, hints={'nolength': True, 'render_as_const': True}))
                else:
                    return rffi.CArrayPtr(TO)
        elif isinstance(obj, model.FunctionPtrType):
            if obj.ellipsis:
                raise NotImplementedError
            args = [self.convert_type(arg) for arg in obj.args]
            res = self.convert_type(obj.result)
            return lltype.Ptr(lltype.FuncType(args, res))
        elif isinstance(obj, model.VoidType):
            return lltype.Void
        elif isinstance(obj, model.ArrayType):
            return rffi.CFixedArray(self.convert_type(obj.item), obj.length)
        elif isinstance(obj, model.EnumType):
            enum = type(obj.forcename, (Enum,), {})
            for key, value in zip(obj.enumerators, obj.enumvalues):
                setattr(enum, key, value)
            return enum
        else:
            raise NotImplementedError

    def gettype(self, cdecl):
        try:
            return self._cdecl_type_cache[cdecl]
        except KeyError:
            result = self._real_gettype(cdecl)
            self._cdecl_type_cache[cdecl] = result
            return result

    def _real_gettype(self, cdecl):
        obj = self.ctx.parse_type(cdecl)
        result = self.convert_type(obj)
        if isinstance(result, DelayedStruct):
            result = result.TYPE
        return result

    def cast(self, cdecl, value):
        return rffi.cast(self.gettype(cdecl), value)

    def parse_func(self, cdecl):
        cdecl = cdecl.strip()
        if cdecl[-1] != ';':
            cdecl += ';'
        ast, _, _ = self.ctx._parse(cdecl)
        decl = ast.ext[-1]
        tp, quals = self.ctx._get_type_and_quals(decl.type, name=decl.name)
        return FunctionDeclaration(decl.name, tp)

    def _freeze_(self):
        if self._frozen:
            return True

        @register_flow_sc(self.cast)
        def sc_cast(ctx, v_decl, v_arg):
            if not isinstance(v_decl, Constant):
                raise FlowingError(
                    "The first argument of cts.cast() must be a constant.")
            TP = self.gettype(v_decl.value)
            return ctx.appcall(rffi.cast, const(TP), v_arg)

        @register_flow_sc(self.gettype)
        def sc_gettype(ctx, v_decl):
            if not isinstance(v_decl, Constant):
                raise FlowingError(
                    "The argument of cts.gettype() must be a constant.")
            return const(self.gettype(v_decl.value))

        self._frozen = True
        return True

class Enum(object):
    pass

class FunctionDeclaration(object):
    def __init__(self, name, tp):
        self.name = name
        self.tp = tp

    def get_llargs(self, cts):
        return [cts.convert_type(arg) for arg in self.tp.args]

    def get_llresult(self, cts):
        return cts.convert_type(self.tp.result)

def parse_source(source, includes=None, headers=None, configure_now=True):
    cts = CTypeSpace(headers=headers, includes=includes)
    cts.parse_source(source)
    return cts

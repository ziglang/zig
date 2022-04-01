import math
from rpython.rtyper.lltypesystem.lltype import (Struct, Array, FixedSizeArray,
    FuncType, typeOf, GcStruct, GcArray, RttiStruct, ContainerType, parentlink,
    Void, OpaqueType, Float, RuntimeTypeInfo, getRuntimeTypeInfo, Char,
    _subarray)
from rpython.rtyper.lltypesystem import llmemory, llgroup
from rpython.translator.c.funcgen import make_funcgen
from rpython.translator.c.support import USESLOTS # set to False if necessary while refactoring
from rpython.translator.c.support import cdecl, forward_cdecl, somelettersfrom
from rpython.translator.c.support import c_char_array_constant, barebonearray
from rpython.translator.c.primitive import PrimitiveType, name_signed
from rpython.rlib import exports, objectmodel
from rpython.rlib.rfloat import isfinite


def needs_gcheader(gctransformer, T):
    if getattr(gctransformer, 'NO_HEADER', False):   # for boehm
        return False
    if not isinstance(T, ContainerType):
        return False
    if T._gckind != 'gc':
        return False
    if isinstance(T, GcStruct):
        if T._first_struct() != (None, None):
            return False   # gcheader already in the first field
    return True

class Node(object):
    __slots__ = ("db", )

    def __init__(self, db):
        self.db = db

class NodeWithDependencies(Node):
    __slots__ = ("dependencies", )

    def __init__(self, db):
        Node.__init__(self, db)
        self.dependencies = set()

class StructDefNode(NodeWithDependencies):
    typetag = 'struct'
    extra_union_for_varlength = True

    def __init__(self, db, STRUCT, varlength=None):
        NodeWithDependencies.__init__(self, db)
        self.STRUCT = STRUCT
        self.LLTYPE = STRUCT
        self.varlength = varlength
        if varlength is None:
            basename = STRUCT._name
            with_number = True
        else:
            basename = db.gettypedefnode(STRUCT).barename
            basename = '%s_len%d' % (basename, varlength)
            with_number = False
        if STRUCT._hints.get('union'):
            self.typetag = 'union'
            assert STRUCT._gckind == 'raw'   # not supported: "GcUnion"
        if STRUCT._hints.get('typedef'):
            self.typetag = ''
            assert STRUCT._hints.get('external')
        if self.STRUCT._hints.get('external'):      # XXX hack
            self.forward_decl = None
        if STRUCT._hints.get('c_name'):
            self.barename = self.name = STRUCT._hints['c_name']
            self.c_struct_field_name = self.verbatim_field_name
        else:
            (self.barename,
             self.name) = db.namespace.uniquename(basename,
                                                  with_number=with_number,
                                                  bare=True)
            self.prefix = somelettersfrom(STRUCT._name) + '_'
        #
        self.fieldnames = STRUCT._names
        if STRUCT._hints.get('typeptr', False):
            if db.gcpolicy.need_no_typeptr():
                assert self.fieldnames == ('typeptr',)
                self.fieldnames = ()
        #
        self.fulltypename = '%s %s @' % (self.typetag, self.name)

    def setup(self):
        # this computes self.fields
        if self.STRUCT._hints.get('external'):      # XXX hack
            self.fields = None    # external definition only
            return
        self.fields = []
        db = self.db
        STRUCT = self.STRUCT
        if self.varlength is not None:
            self.normalizedtypename = db.gettype(STRUCT, who_asks=self)
        if needs_gcheader(db.gctransformer, self.STRUCT):
            HDR = db.gcpolicy.struct_gcheader_definition(self)
            if HDR is not None:
                gc_field = ("_gcheader", db.gettype(HDR, who_asks=self))
                self.fields.append(gc_field)
        for name in self.fieldnames:
            T = self.c_struct_field_type(name)
            if name == STRUCT._arrayfld:
                typename = db.gettype(T, varlength=self.varlength,
                                         who_asks=self)
            else:
                typename = db.gettype(T, who_asks=self)
            self.fields.append((self.c_struct_field_name(name), typename))
        self.computegcinfo(self.db.gcpolicy)

    def computegcinfo(self, gcpolicy):
        # let the gcpolicy do its own setup
        self.gcinfo = None   # unless overwritten below
        rtti = None
        STRUCT = self.STRUCT
        if isinstance(STRUCT, RttiStruct):
            try:
                rtti = getRuntimeTypeInfo(STRUCT)
            except ValueError:
                pass
        if self.varlength is None:
            gcpolicy.struct_setup(self, rtti)
        return self.gcinfo

    def gettype(self):
        return self.fulltypename

    def c_struct_field_name(self, name):
        # occasionally overridden in __init__():
        #    self.c_struct_field_name = self.verbatim_field_name
        return self.prefix + name

    def verbatim_field_name(self, name):
        assert name.startswith('c_')   # produced in this way by rffi
        return name[2:]

    def c_struct_field_type(self, name):
        return self.STRUCT._flds[name]

    def access_expr(self, baseexpr, fldname):
        fldname = self.c_struct_field_name(fldname)
        return '%s.%s' % (baseexpr, fldname)

    def ptr_access_expr(self, baseexpr, fldname, baseexpr_is_const=False):
        fldname = self.c_struct_field_name(fldname)
        if baseexpr_is_const:
            return '%s->%s' % (baseexpr, fldname)
        return 'RPyField(%s, %s)' % (baseexpr, fldname)

    def definition(self):
        if self.fields is None:   # external definition only
            return
        yield '%s %s {' % (self.typetag, self.name)
        is_empty = True
        for name, typename in self.fields:
            line = '%s;' % cdecl(typename, name)
            if typename == PrimitiveType[Void]:
                line = '/* %s */' % line
            else:
                if is_empty and typename.endswith('[RPY_VARLENGTH]'):
                    yield '\tRPY_DUMMY_VARLENGTH'
                is_empty = False
            yield '\t' + line
        if is_empty:
            yield '\t' + 'char _dummy; /* this struct is empty */'
        yield '};'
        if self.varlength is not None:
            assert self.typetag == 'struct'
            yield 'union %su {' % self.name
            yield '  struct %s a;' % self.name
            yield '  %s;' % cdecl(self.normalizedtypename, 'b')
            yield '};'

    def visitor_lines(self, prefix, on_field):
        for name in self.fieldnames:
            FIELD_T = self.c_struct_field_type(name)
            cname = self.c_struct_field_name(name)
            for line in on_field('%s.%s' % (prefix, cname),
                                 FIELD_T):
                yield line


def deflength(varlength):
    if varlength is None:
        return 'RPY_VARLENGTH'
    elif varlength == 0:
        return 'RPY_LENGTH0'
    else:
        return varlength

class ArrayDefNode(NodeWithDependencies):
    typetag = 'struct'
    extra_union_for_varlength = True

    def __init__(self, db, ARRAY, varlength=None):
        NodeWithDependencies.__init__(self, db)
        self.ARRAY = ARRAY
        self.LLTYPE = ARRAY
        self.gcfields = []
        self.varlength = varlength
        if varlength is None:
            basename = 'array'
            with_number = True
        else:
            basename = db.gettypedefnode(ARRAY).barename
            basename = '%s_len%d' % (basename, varlength)
            with_number = False
        (self.barename,
         self.name) = db.namespace.uniquename(basename, with_number=with_number,
                                              bare=True)
        self.fulltypename =  '%s %s @' % (self.typetag, self.name)
        self.fullptrtypename = '%s %s *@' % (self.typetag, self.name)

    def setup(self):
        if hasattr(self, 'itemtypename'):
            return      # setup() was already called, likely by __init__
        db = self.db
        ARRAY = self.ARRAY
        self.computegcinfo(db.gcpolicy)
        if self.varlength is not None:
            self.normalizedtypename = db.gettype(ARRAY, who_asks=self)
        if needs_gcheader(db.gctransformer, ARRAY):
            HDR = db.gcpolicy.array_gcheader_definition(self)
            if HDR is not None:
                gc_field = ("_gcheader", db.gettype(HDR, who_asks=self))
                self.gcfields.append(gc_field)
        self.itemtypename = db.gettype(ARRAY.OF, who_asks=self)

    def computegcinfo(self, gcpolicy):
        # let the gcpolicy do its own setup
        self.gcinfo = None   # unless overwritten below
        if self.varlength is None:
            gcpolicy.array_setup(self)
        return self.gcinfo

    def gettype(self):
        return self.fulltypename

    def getptrtype(self):
        return self.fullptrtypename

    def access_expr(self, baseexpr, index):
        return '%s.items[%s]' % (baseexpr, index)
    access_expr_varindex = access_expr

    def ptr_access_expr(self, baseexpr, index, dummy=False):
        assert 0 <= index <= sys.maxint, "invalid constant index %r" % (index,)
        return self.itemindex_access_expr(baseexpr, index)

    def itemindex_access_expr(self, baseexpr, indexexpr):
        if self.ARRAY._hints.get('nolength', False):
            return 'RPyNLenItem(%s, %s)' % (baseexpr, indexexpr)
        else:
            return 'RPyItem(%s, %s)' % (baseexpr, indexexpr)

    def definition(self):
        yield 'struct %s {' % self.name
        for fname, typename in self.gcfields:
            yield '\t' + cdecl(typename, fname) + ';'
        if not self.ARRAY._hints.get('nolength', False):
            yield '\tSigned length;'
        varlength = self.varlength
        if varlength is not None:
            varlength += self.ARRAY._hints.get('extra_item_after_alloc', 0)
        line = '%s;' % cdecl(self.itemtypename,
                             'items[%s]' % deflength(varlength))
        if self.ARRAY.OF is Void:    # strange
            line = '/* array of void */'
            if self.ARRAY._hints.get('nolength', False):
                line = 'char _dummy; ' + line
        yield '\t' + line
        yield '};'
        if self.varlength is not None:
            yield 'union %su {' % self.name
            yield '  struct %s a;' % self.name
            yield '  %s;' % cdecl(self.normalizedtypename, 'b')
            yield '};'

    def visitor_lines(self, prefix, on_item):
        assert self.varlength is None
        ARRAY = self.ARRAY
        # we need a unique name for this C variable, or at least one that does
        # not collide with the expression in 'prefix'
        i = 0
        varname = 'p0'
        while prefix.find(varname) >= 0:
            i += 1
            varname = 'p%d' % i
        body = list(on_item('(*%s)' % varname, ARRAY.OF))
        if body:
            yield '{'
            yield '\t%s = %s.items;' % (cdecl(self.itemtypename, '*' + varname),
                                        prefix)
            yield '\t%s = %s + %s.length;' % (cdecl(self.itemtypename,
                                                    '*%s_end' % varname),
                                              varname,
                                              prefix)
            yield '\twhile (%s != %s_end) {' % (varname, varname)
            for line in body:
                yield '\t\t' + line
            yield '\t\t%s++;' % varname
            yield '\t}'
            yield '}'


class BareBoneArrayDefNode(NodeWithDependencies):
    """For 'simple' array types which don't need a length nor GC headers.
    Implemented directly as a C array instead of a struct with an items field.
    rffi kind of expects such arrays to be 'bare' C arrays.
    """
    gcinfo = None
    name = None
    forward_decl = None
    extra_union_for_varlength = False

    def __init__(self, db, ARRAY, varlength=None):
        NodeWithDependencies.__init__(self, db)
        self.ARRAY = ARRAY
        self.LLTYPE = ARRAY
        self.varlength = varlength
        contained_type = ARRAY.OF
        # There is no such thing as an array of voids:
        # we use a an array of chars instead; only the pointer can be void*.
        self.itemtypename = db.gettype(contained_type, who_asks=self)
        self.fulltypename = self.itemtypename.replace('@', '(@)[%s]' %
                                                      deflength(varlength))
        if ARRAY._hints.get("render_as_void"):
            self.fullptrtypename = 'void *@'
        else:
            self.fullptrtypename = self.itemtypename.replace('@', '*@')
            if ARRAY._hints.get("render_as_const"):
                self.fullptrtypename = 'const ' + self.fullptrtypename

    def setup(self):
        """Array loops are forbidden by ForwardReference.become() because
        there is no way to declare them in C."""

    def gettype(self):
        return self.fulltypename

    def getptrtype(self):
        return self.fullptrtypename

    def access_expr(self, baseexpr, index):
        return '%s[%d]' % (baseexpr, index)
    access_expr_varindex = access_expr

    def ptr_access_expr(self, baseexpr, index, dummy=False):
        assert 0 <= index <= sys.maxint, "invalid constant index %r" % (index,)
        return self.itemindex_access_expr(baseexpr, index)

    def itemindex_access_expr(self, baseexpr, indexexpr):
        if self.ARRAY._hints.get("render_as_void"):
            return 'RPyBareItem((char*)%s, %s)' % (baseexpr, indexexpr)
        else:
            return 'RPyBareItem(%s, %s)' % (baseexpr, indexexpr)

    def definition(self):
        return []    # no declaration is needed

    def visitor_lines(self, prefix, on_item):
        raise Exception("cannot visit C arrays - don't know the length")


class FixedSizeArrayDefNode(NodeWithDependencies):
    gcinfo = None
    name = None
    typetag = 'struct'
    extra_union_for_varlength = False

    def __init__(self, db, FIXEDARRAY):
        NodeWithDependencies.__init__(self, db)
        self.FIXEDARRAY = FIXEDARRAY
        self.LLTYPE = FIXEDARRAY
        self.itemtypename = db.gettype(FIXEDARRAY.OF, who_asks=self)
        self.fulltypename = self.itemtypename.replace('@', '(@)[%d]' %
                                                      FIXEDARRAY.length)
        self.fullptrtypename = self.itemtypename.replace('@', '*@')

    def setup(self):
        """Loops are forbidden by ForwardReference.become() because
        there is no way to declare them in C."""

    def gettype(self):
        return self.fulltypename

    def getptrtype(self):
        return self.fullptrtypename

    def access_expr(self, baseexpr, index, dummy=False):
        if not isinstance(index, int):
            assert index.startswith('item')
            index = int(index[4:])
        if not (0 <= index < self.FIXEDARRAY.length):
            raise IndexError("refusing to generate a statically out-of-bounds"
                             " array indexing")
        return '%s[%d]' % (baseexpr, index)

    ptr_access_expr = access_expr

    def access_expr_varindex(self, baseexpr, index):
        return '%s[%s]' % (baseexpr, index)

    def itemindex_access_expr(self, baseexpr, indexexpr):
        return 'RPyFxItem(%s, %s, %d)' % (baseexpr, indexexpr,
                                          self.FIXEDARRAY.length)

    def definition(self):
        return []    # no declaration is needed

    def visitor_lines(self, prefix, on_item):
        FIXEDARRAY = self.FIXEDARRAY
        # we need a unique name for this C variable, or at least one that does
        # not collide with the expression in 'prefix'
        i = 0
        varname = 'p0'
        while prefix.find(varname) >= 0:
            i += 1
            varname = 'p%d' % i
        body = list(on_item('(*%s)' % varname, FIXEDARRAY.OF))
        if body:
            yield '{'
            yield '\t%s = %s;' % (cdecl(self.itemtypename, '*' + varname),
                                  prefix)
            yield '\t%s = %s + %d;' % (cdecl(self.itemtypename,
                                             '*%s_end' % varname),
                                       varname,
                                       FIXEDARRAY.length)
            yield '\twhile (%s != %s_end) {' % (varname, varname)
            for line in body:
                yield '\t\t' + line
            yield '\t\t%s++;' % varname
            yield '\t}'
            yield '}'


class ExtTypeOpaqueDefNode(NodeWithDependencies):
    """For OpaqueTypes created with the hint render_structure."""
    typetag = 'struct'

    def __init__(self, db, T):
        NodeWithDependencies.__init__(self, db)
        self.T = T
        self.name = 'RPyOpaque_%s' % (T.tag,)

    def setup(self):
        pass

    def definition(self):
        return []

# ____________________________________________________________


class ContainerNode(Node):
    if USESLOTS:      # keep the number of slots down!
        __slots__ = """db obj
                       typename implementationtypename
                        name
                        _funccodegen_owner
                        globalcontainer""".split()
    eci_name = '_compilation_info'

    def __init__(self, db, T, obj):
        Node.__init__(self, db)
        self.obj = obj
        self.typename = db.gettype(T)  #, who_asks=self)
        self.implementationtypename = db.gettype(
            T, varlength=self.getvarlength())
        parent, parentindex = parentlink(obj)
        if obj in exports.EXPORTS_obj2name:
            self.name = exports.EXPORTS_obj2name[obj]
            self.globalcontainer = 2    # meh
        elif parent is None:
            self.name = db.namespace.uniquename('g_' + self.basename())
            self.globalcontainer = True
        else:
            self.globalcontainer = False
            parentnode = db.getcontainernode(parent)
            defnode = db.gettypedefnode(parentnode.getTYPE())
            self.name = defnode.access_expr(parentnode.name, parentindex)
        if self.typename != self.implementationtypename:
            if db.gettypedefnode(T).extra_union_for_varlength:
                self.name += '.b'
        self._funccodegen_owner = None

    def getptrname(self):
        return '(&%s)' % self.name

    def getTYPE(self):
        return typeOf(self.obj)

    def is_thread_local(self):
        T = self.getTYPE()
        return hasattr(T, "_hints") and T._hints.get('thread_local')

    def is_exported(self):
        return self.globalcontainer == 2    # meh

    def compilation_info(self):
        return getattr(self.obj, self.eci_name, None)

    def get_declaration(self):
        if self.name[-2:] == '.b':
            # xxx fish fish
            assert self.implementationtypename.startswith('struct ')
            assert self.implementationtypename.endswith(' @')
            uniontypename = 'union %su @' % self.implementationtypename[7:-2]
            return uniontypename, self.name[:-2], True
        else:
            return self.implementationtypename, self.name, False

    def forward_declaration(self):
        if llgroup.member_of_group(self.obj):
            return
        type, name, is_union = self.get_declaration()
        yield '%s;' % (
            forward_cdecl(type, name, self.db.standalone,
                          is_thread_local=self.is_thread_local(),
                          is_exported=self.is_exported()))

    def implementation(self):
        if llgroup.member_of_group(self.obj):
            return []
        lines = list(self.initializationexpr())
        type, name, is_union = self.get_declaration()
        if is_union and len(lines) < 2:
            # a union with length 0
            lines[0] = cdecl(type, name, self.is_thread_local())
        else:
            if is_union:
                lines[0] = '{ ' + lines[0]    # extra braces around the 'a' part
                lines[-1] += ' }'             # of the union
            lines[0] = '%s = %s' % (
                cdecl(type, name, self.is_thread_local()),
                lines[0])
        lines[-1] += ';'
        return lines

    def startupcode(self):
        return []

    def getvarlength(self):
        return None

assert not USESLOTS or '__dict__' not in dir(ContainerNode)

class StructNode(ContainerNode):
    nodekind = 'struct'
    if USESLOTS:
        __slots__ = ('gc_init',)

    def __init__(self, db, T, obj):
        ContainerNode.__init__(self, db, T, obj)
        gct = self.db.gctransformer
        if needs_gcheader(gct, T):
            if gct is not None:
                self.gc_init = gct.gcheader_initdata(self.obj)
            else:
                self.gc_init = None

    def basename(self):
        T = self.getTYPE()
        return T._name

    def enum_dependencies(self):
        T = self.getTYPE()
        for name in T._names:
            yield getattr(self.obj, name)

    def getvarlength(self):
        T = self.getTYPE()
        if T._arrayfld is None:
            return None
        else:
            array = getattr(self.obj, T._arrayfld)
            return len(array.items)

    def initializationexpr(self, decoration=''):
        T = self.getTYPE()
        is_empty = True
        defnode = self.db.gettypedefnode(T)

        data = []

        if needs_gcheader(self.db.gctransformer, T):
            data.append(('gcheader', self.gc_init))

        for name in defnode.fieldnames:
            data.append((name, getattr(self.obj, name)))

        if T._hints.get('remove_hash'):
            # hack for rstr.STR and UNICODE: remove their .hash value
            # and write 0 in the C sources, if we're using a non-default
            # hash function.
            if hasattr(self.db.translator, 'll_hash_string'):
                i = 0
                while data[i][0] != 'hash':
                    i += 1
                data[i] = ('hash', 0)

        # Reasonably, you should only initialise one of the fields of a union
        # in C.  This is possible with the syntax '.fieldname value' or
        # '.fieldname = value'.  But here we don't know which of the
        # fields need initialization, so XXX we pick the first one
        # arbitrarily.
        if T._hints.get('union'):
            data = data[0:1]

        if 'get_padding_drop' in T._hints:
            d = {}
            for name, _ in data:
                T1 = defnode.c_struct_field_type(name)
                typename = self.db.gettype(T1)
                d[name] = cdecl(typename, '')
            padding_drop = T._hints['get_padding_drop'](d)
        else:
            padding_drop = []
        type, name, is_union = self.get_declaration()
        if is_union and self.getvarlength() < 1 and len(data) < 2:
            # an empty union
            yield ''
            return

        yield '{'
        for name, value in data:
            if name in padding_drop:
                continue
            c_expr = defnode.access_expr(self.name, name)
            lines = generic_initializationexpr(self.db, value, c_expr,
                                               decoration + name)
            for line in lines:
                yield '\t' + line
            if not lines[0].startswith('/*'):
                is_empty = False
        if is_empty:
            yield '\t%s' % '0,'
        yield '}'

assert not USESLOTS or '__dict__' not in dir(StructNode)


class ArrayNode(ContainerNode):
    nodekind = 'array'
    if USESLOTS:
        __slots__ = ('gc_init',)

    def __init__(self, db, T, obj):
        ContainerNode.__init__(self, db, T, obj)
        gct = self.db.gctransformer
        if needs_gcheader(gct, T):
            if gct is not None:
                self.gc_init = gct.gcheader_initdata(self.obj)
            else:
                self.gc_init = None

    def getptrname(self):
        if barebonearray(self.getTYPE()):
            return self.name
        return ContainerNode.getptrname(self)

    def basename(self):
        return 'array'

    def enum_dependencies(self):
        return self.obj.items

    def getvarlength(self):
        return len(self.obj.items)

    def initializationexpr(self, decoration=''):
        T = self.getTYPE()
        yield '{'
        if needs_gcheader(self.db.gctransformer, T):
            lines = generic_initializationexpr(self.db, self.gc_init, 'gcheader',
                                               '%sgcheader' % (decoration,))
            for line in lines:
                yield line
        if T._hints.get('nolength', False):
            length = ''
        else:
            length = '%d, ' % len(self.obj.items)
        if T.OF is Void or len(self.obj.items) == 0:
            yield '\t%s' % length.rstrip(', ')
            yield '}'
        elif T.OF == Char:
            if len(self.obj.items) and self.obj.items[0] is None:
                s = ''.join([self.obj.getitem(i) for i in range(len(self.obj.items))])
            else:
                s = ''.join(self.obj.items)
            array_constant = c_char_array_constant(s)
            if array_constant.startswith('{') and barebonearray(T):
                assert array_constant.endswith('}')
                array_constant = array_constant[1:-1].strip()
            yield '\t%s%s' % (length, array_constant)
            yield '}'
        else:
            barebone = barebonearray(T)
            if not barebone:
                yield '\t%s{' % length
            for j in range(len(self.obj.items)):
                value = self.obj.items[j]
                basename = self.name
                if basename.endswith('.b'):
                    basename = basename[:-2] + '.a'
                lines = generic_initializationexpr(self.db, value,
                                                '%s.items[%d]' % (basename, j),
                                                '%s%d' % (decoration, j))
                for line in lines:
                    yield '\t' + line
            if not barebone:
                yield '} }'
            else:
                yield '}'

assert not USESLOTS or '__dict__' not in dir(ArrayNode)

class FixedSizeArrayNode(ContainerNode):
    nodekind = 'array'
    if USESLOTS:
        __slots__ = ()

    def getptrname(self):
        if not isinstance(self.obj, _subarray):   # XXX hackish
            return self.name
        return ContainerNode.getptrname(self)

    def basename(self):
        T = self.getTYPE()
        return T._name

    def enum_dependencies(self):
        for i in range(self.obj.getlength()):
            yield self.obj.getitem(i)

    def getvarlength(self):
        return None    # not variable-sized!

    def initializationexpr(self, decoration=''):
        T = self.getTYPE()
        assert self.typename == self.implementationtypename  # not var-sized
        yield '{'
        # _names == ['item0', 'item1', ...]
        for j, name in enumerate(T._names):
            value = getattr(self.obj, name)
            lines = generic_initializationexpr(self.db, value,
                                               '%s[%d]' % (self.name, j),
                                               '%s%d' % (decoration, j))
            for line in lines:
                yield '\t' + line
        yield '}'

def generic_initializationexpr(db, value, access_expr, decoration):
    if isinstance(typeOf(value), ContainerType):
        node = db.getcontainernode(value)
        lines = list(node.initializationexpr(decoration+'.'))
        lines[-1] += ','
        return lines
    else:
        comma = ','
        if typeOf(value) == Float and not isfinite(value):
            db.late_initializations.append(('%s' % access_expr, db.get(value)))
            if math.isinf(value):
                name = '-+'[value > 0] + 'inf'
            else:
                name = 'NaN'
            expr = '0.0 /* patched later with %s */' % (name,)
        else:
            expr = db.get(value)
            if typeOf(value) is Void:
                comma = ''
        expr += comma
        i = expr.find('\n')
        if i < 0:
            i = len(expr)
        expr = '%s\t/* %s */%s' % (expr[:i], decoration, expr[i:])
        return expr.split('\n')

# ____________________________________________________________


class FuncNodeBase(ContainerNode):
    nodekind = 'func'
    eci_name = 'compilation_info'
    # there not so many node of this kind, slots should not
    # be necessary
    def __init__(self, db, T, obj, ptrname):
        Node.__init__(self, db)
        self.globalcontainer = True
        self.T = T
        self.obj = obj
        self.name = ptrname
        self.typename = db.gettype(T)  #, who_asks=self)

    def getptrname(self):
        return self.name

    def basename(self):
        return self.obj._name


class FuncNode(FuncNodeBase):
    def __init__(self, db, T, obj, ptrname):
        FuncNodeBase.__init__(self, db, T, obj, ptrname)
        exception_policy = getattr(obj, 'exception_policy', None)
        self.funcgen = make_funcgen(obj.graph, db, exception_policy, ptrname)
        argnames = self.funcgen.argnames()
        self.implementationtypename = db.gettype(T, argnames=argnames)
        self._funccodegen_owner = self.funcgen

    def enum_dependencies(self):
        return self.funcgen.allconstantvalues()

    def forward_declaration(self):
        callable = getattr(self.obj, '_callable', None)
        is_exported = getattr(callable, 'exported_symbol', False)
        yield '%s;' % (
            forward_cdecl(self.implementationtypename,
                self.name, self.db.standalone, is_exported=is_exported))

    def graphs_to_patch(self):
        return self.funcgen.graphs_to_patch()

    def implementation(self):
        funcgen = self.funcgen
        funcgen.implementation_begin()
        # recompute implementationtypename as the argnames may have changed
        argnames = funcgen.argnames()
        implementationtypename = self.db.gettype(self.T, argnames=argnames)
        yield '%s {' % cdecl(implementationtypename, self.name)
        #
        # declare the local variables
        #
        localnames = list(funcgen.cfunction_declarations())
        lengths = [len(a) for a in localnames]
        lengths.append(9999)
        start = 0
        while start < len(localnames):
            # pack the local declarations over as few lines as possible
            total = lengths[start] + 8
            end = start + 1
            while total + lengths[end] < 77:
                total += lengths[end] + 1
                end += 1
            yield '\t' + ' '.join(localnames[start:end])
            start = end
        #
        # generate the body itself
        #
        bodyiter = funcgen.cfunction_body()
        for line in bodyiter:
            # performs some formatting on the generated body:
            # indent normal lines with tabs; indent labels less than the rest
            if line.endswith(':'):
                if line.startswith('err'):
                    try:
                        nextline = bodyiter.next()
                    except StopIteration:
                        nextline = ''
                    # merge this 'err:' label with the following line
                    line = '\t%s\t%s' % (line, nextline)
                else:
                    line = '    ' + line
            elif line:
                line = '\t' + line
            yield line

        yield '}'
        del bodyiter
        funcgen.implementation_end()

class ExternalFuncNode(FuncNodeBase):
    def __init__(self, db, T, obj, ptrname):
        FuncNodeBase.__init__(self, db, T, obj, ptrname)
        self._funccodegen_owner = None

    def enum_dependencies(self):
        return []

    def forward_declaration(self):
        return []

    def implementation(self):
        return []

def new_funcnode(db, T, obj, forcename=None):
    from rpython.rtyper.rtyper import llinterp_backend
    if db.sandbox:
        if (getattr(obj, 'external', None) is not None and
                not obj._safe_not_sandboxed):
            from rpython.translator.sandbox import rsandbox
            obj.__dict__['graph'] = rsandbox.get_sandbox_stub(
                obj, db.translator.rtyper)
            obj.__dict__.pop('_safe_not_sandboxed', None)
            obj.__dict__.pop('external', None)
    if forcename:
        name = forcename
    else:
        name = _select_name(db, obj)
    if hasattr(obj, 'graph'):
        return FuncNode(db, T, obj, name)
    elif getattr(obj, 'external', None) is not None:
        assert obj.external == 'C'
        if db.sandbox:
            assert obj._safe_not_sandboxed
        return ExternalFuncNode(db, T, obj, name)
    elif hasattr(obj._callable, "c_name"):
        return ExternalFuncNode(db, T, obj, name)  # this case should only be used for entrypoints
    elif db.translator.rtyper.backend is llinterp_backend:
        # on llinterp, anything goes
        return ExternalFuncNode(db, T, obj, name)
    else:
        raise ValueError("don't know how to generate code for %r" % (obj,))


def _select_name(db, obj):
    try:
        return obj._callable.c_name
    except AttributeError:
        pass
    if getattr(obj, 'external', None) == 'C':
        return obj._name
    return db.namespace.uniquename('g_' + obj._name)


class ExtType_OpaqueNode(ContainerNode):
    nodekind = 'rpyopaque'

    def enum_dependencies(self):
        return []

    def initializationexpr(self, decoration=''):
        T = self.getTYPE()
        raise NotImplementedError(
            'seeing an unexpected prebuilt object: %s' % (T.tag,))

    def startupcode(self):
        T = self.getTYPE()
        args = [self.getptrname()]
        # XXX how to make this code more generic?
        if T.tag == 'ThreadLock':
            lock = self.obj.externalobj
            if lock.locked():
                args.append('1')
            else:
                args.append('0')
        yield 'RPyOpaque_SETUP_%s(%s);' % (T.tag, ', '.join(args))


def opaquenode_factory(db, T, obj):
    if T == RuntimeTypeInfo:
        return db.gcpolicy.rtti_node_factory()(db, T, obj)
    if T._hints.get("render_structure", False):
        return ExtType_OpaqueNode(db, T, obj)
    raise Exception("don't know about %r" % (T,))


def weakrefnode_factory(db, T, obj):
    assert isinstance(obj, llmemory._wref)
    ptarget = obj._dereference()
    wrapper = db.gcpolicy.convert_weakref_to(ptarget)
    container = wrapper._obj
    #obj._converted_weakref = container     # hack for genllvm :-/
    return db.getcontainernode(container, _dont_write_c_code=False)

class GroupNode(ContainerNode):
    nodekind = 'group'
    count_members = None

    def __init__(self, *args):
        ContainerNode.__init__(self, *args)
        self.implementationtypename = 'struct group_%s_s @' % self.name

    def basename(self):
        return self.obj.name

    def enum_dependencies(self):
        # note: for the group used by the GC, it can grow during this phase,
        # which means that we might not return all members yet.  This is fixed
        # by get_finish_tables() in rpython.memory.gctransform.framework.
        for member in self.obj.members:
            yield member._as_ptr()

    def _fix_members(self):
        if self.obj.outdated:
            raise Exception(self.obj.outdated)
        if self.count_members is None:
            self.count_members = len(self.obj.members)
        else:
            # make sure no new member showed up, because it's too late
            assert len(self.obj.members) == self.count_members

    def forward_declaration(self):
        self._fix_members()
        yield ''
        ctype = ['%s {' % cdecl(self.implementationtypename, '')]
        for i, member in enumerate(self.obj.members):
            structtypename = self.db.gettype(typeOf(member))
            ctype.append('\t%s;' % cdecl(structtypename, 'member%d' % i))
        ctype.append('} @')
        ctype = '\n'.join(ctype)
        yield '%s;' % (
            forward_cdecl(ctype, self.name, self.db.standalone,
                          self.is_thread_local()))
        yield '#include "src/llgroup.h"'
        yield 'PYPY_GROUP_CHECK_SIZE(%s)' % (self.name,)
        for i, member in enumerate(self.obj.members):
            structnode = self.db.getcontainernode(member)
            yield '#define %s %s.member%d' % (structnode.name,
                                              self.name, i)
        yield ''

    def initializationexpr(self):
        self._fix_members()
        lines = ['{']
        lasti = len(self.obj.members) - 1
        for i, member in enumerate(self.obj.members):
            structnode = self.db.getcontainernode(member)
            lines1 = list(structnode.initializationexpr())
            lines1[0] += '\t/* member%d: %s */' % (i, structnode.name)
            if i != lasti:
                lines1[-1] += ','
            lines.extend(lines1)
        lines.append('}')
        return lines


ContainerNodeFactory = {
    Struct:       StructNode,
    GcStruct:     StructNode,
    Array:        ArrayNode,
    GcArray:      ArrayNode,
    FixedSizeArray: FixedSizeArrayNode,
    FuncType:     new_funcnode,
    OpaqueType:   opaquenode_factory,
    llmemory._WeakRefType: weakrefnode_factory,
    llgroup.GroupType: GroupNode,
}

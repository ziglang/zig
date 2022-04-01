from rpython.annotator.model import SomeInstance, s_None
from rpython.annotator.listdef import s_list_of_strings
from rpython.rlib.objectmodel import (instantiate, we_are_translated, specialize,
    not_rpython)
from rpython.rlib.nonconst import NonConstant
from rpython.rlib.rarithmetic import r_uint, r_singlefloat
from rpython.rlib.debug import make_sure_not_resized
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.lltypesystem import lltype
from rpython.tool.sourcetools import compile2, func_with_new_name
from rpython.translator.translator import TranslationContext
from rpython.translator.c.genc import CStandaloneBuilder

from pypy.tool.option import make_config
from pypy.interpreter import argument, gateway
from pypy.interpreter.baseobjspace import W_Root, ObjSpace, SpaceCache
from pypy.interpreter.buffer import StringBuffer, SimpleView
from pypy.interpreter.mixedmodule import MixedModule
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from pypy.objspace.std.sliceobject import W_SliceObject


class W_MyObject(W_Root):
    typedef = None

    def getdict(self, space):
        return w_obj_or_none()

    def getdictvalue(self, space, attr):
        attr + "xx"   # check that it's a string
        return w_obj_or_none()

    def setdictvalue(self, space, attr, w_value):
        attr + "xx"   # check that it's a string
        is_root(w_value)
        return NonConstant(True)

    def deldictvalue(self, space, attr):
        attr + "xx"   # check that it's a string
        return NonConstant(True)

    def setdict(self, space, w_dict):
        is_root(w_dict)

    def setclass(self, space, w_subtype):
        is_root(w_subtype)

    def buffer_w(self, space, flags):
        return SimpleView(StringBuffer("foobar"), w_obj=self)

    def text_w(self, space):
        return NonConstant("foobar")
    bytes_w = text_w

    def utf8_w(self, space):
        return NonConstant("foobar")

    def int_w(self, space, allow_conversion=True):
        return NonConstant(-42)

    def uint_w(self, space):
        return r_uint(NonConstant(42))

    def bigint_w(self, space, allow_conversion=True):
        from rpython.rlib.rbigint import rbigint
        x = 42
        if we_are_translated():
            x = NonConstant(x)
        return rbigint.fromint(x)

class W_MyListObj(W_MyObject):
    def append(self, w_other):
        pass

class W_UnicodeObject(W_MyObject):
    _length = 21
    _utf8 = 'foobar'

    def _index_to_byte(self, at):
        return NonConstant(42)

    def _len(self):
        return self._length

    def eq_w(self, w_other):
        return NonConstant(True)


class W_MyType(W_MyObject):
    name = "foobar"
    flag_map_or_seq = '?'
    hasuserdel = False

    def __init__(self):
        self.mro_w = [w_some_obj(), w_some_obj()]
        self.dict_w = {'__str__': w_some_obj()}
        self.hasuserdel = True

    def get_module(self):
        return w_some_obj()

    def getname(self, space):
        return self.name

def w_some_obj():
    if NonConstant(False):
        return W_Root()
    return W_MyObject()

def w_obj_or_none():
    if NonConstant(False):
        return None
    return w_some_obj()

def w_some_type():
    return W_MyType()

def is_root(w_obj):
    assert isinstance(w_obj, W_Root)
is_root.expecting = W_Root

def is_arguments(arg):
    assert isinstance(arg, argument.Arguments)
is_arguments.expecting = argument.Arguments


class Entry(ExtRegistryEntry):
    _about_ = is_root, is_arguments

    def compute_result_annotation(self, s_w_obj):
        cls = self.instance.expecting
        s_inst = SomeInstance(self.bookkeeper.getuniqueclassdef(cls),
                              can_be_None=True)
        assert s_inst.contains(s_w_obj)
        return s_None

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.inputconst(lltype.Void, None)

# ____________________________________________________________


BUILTIN_TYPES = ['int', 'float', 'tuple', 'list', 'dict', 'bytes',
                 'unicode', 'complex', 'slice', 'bool', 'text', 'object',
                 'set', 'frozenset', 'bytearray', 'memoryview']

INTERP_TYPES = ['function', 'builtin_function', 'module', 'getset_descriptor',
                'instance', 'classobj']

class FakeObjSpace(ObjSpace):
    is_fake_objspace = True

    def __init__(self, config=None):
        self._seen_extras = []
        ObjSpace.__init__(self, config=config)
        self.setup()

        # Be sure to annotate W_SliceObject constructor.
        # In Python2, this is triggered by W_InstanceObject.__getslice__.
        def build_slice():
            self.newslice(self.w_None, self.w_None, self.w_None)
        def attach_list_strategy():
            # this is needed for modules which interacts directly with
            # std.listobject.W_ListObject, e.g. after an isinstance check. For
            # example, _hpy_universal. We need to attach a couple of attributes
            # so that the annotator annotates them with the correct types
            from pypy.objspace.std.listobject import W_ListObject, ObjectListStrategy
            space = self
            w_obj = w_some_obj()
            if isinstance(w_obj, W_ListObject):
                w_obj.space = space
                w_obj.strategy = ObjectListStrategy(space)
                list_w = [w_some_obj(), w_some_obj()]
                w_obj.lstorage = w_obj.strategy.erase(list_w)

        self._seen_extras.append(build_slice)
        self._seen_extras.append(attach_list_strategy)

    def _freeze_(self):
        return True

    def view_as_kwargs(self, w_obj):
        return [W_UnicodeObject()] * 3, [W_UnicodeObject()] * 3

    UnicodeObjectCls = W_UnicodeObject

    def float_w(self, w_obj, allow_conversion=True):
        is_root(w_obj)
        return NonConstant(42.5)

    def is_true(self, w_obj):
        is_root(w_obj)
        return NonConstant(False)

    def hash_w(self, w_obj):
        return NonConstant(32)

    def len_w(self, w_obj):
        return NonConstant(37)

    def utf8_len_w(self, space):
        return NonConstant((NonConstant("utf8len_foobar"), NonConstant(14)))

    @not_rpython
    def unwrap(self, w_obj):
        raise NotImplementedError

    def newdict(self, module=False, instance=False, kwargs=False,
                strdict=False):
        return w_some_obj()

    def newtuple(self, list_w):
        make_sure_not_resized(list_w)
        for w_x in list_w:
            is_root(w_x)
        return w_some_obj()

    def newset(self, list_w=None):
        if list_w is not None:
            for w_x in list_w:
                is_root(w_x)
        return w_some_obj()
    newfrozenset = newset

    def newlist(self, list_w):
        # make sure that the annotator thinks that the list is resized
        list_w.append(W_Root())
        #
        for w_x in list_w:
            is_root(w_x)
        return W_MyListObj()

    def newslice(self, w_start, w_end, w_step):
        is_root(w_start)
        is_root(w_end)
        is_root(w_step)
        W_SliceObject(w_start, w_end, w_step)
        return w_some_obj()

    @specialize.argtype(1)
    def newint(self, x):
        return w_some_obj()

    def newlong(self, x):
        return w_some_obj()

    @specialize.argtype(1)
    def newlong_from_rarith_int(self, x):
        return w_some_obj()

    def newfloat(self, x):
        return w_some_obj()

    def newcomplex(self, x, y):
        return w_some_obj()

    def newlong_from_rbigint(self, x):
        return w_some_obj()

    def newseqiter(self, x):
        return w_some_obj()

    def newmemoryview(self, x):
        return w_some_obj()

    @not_rpython
    def marshal_w(self, w_obj):
        raise NotImplementedError

    def newbytes(self, x):
        return w_some_obj()

    def newutf8(self, x, l):
        return W_UnicodeObject()

    def eq_w(self, obj1, obj2):
        return NonConstant(True)

    @specialize.argtype(1)
    def newtext(self, x, lgt=-1):
        return W_UnicodeObject()
    newtext_or_none = newtext
    newfilename = newtext

    @not_rpython
    def wrap(self, x):
        if not we_are_translated():
            if isinstance(x, W_Root):
                x.spacebind(self)
        if isinstance(x, r_singlefloat):
            self._wrap_not_rpython(x)
        if isinstance(x, list):
            if x == []: # special case: it is used e.g. in sys/__init__.py
                return w_some_obj()
            raise NotImplementedError
        return w_some_obj()

    @not_rpython
    def _see_interp2app(self, interp2app):
        """Called by GatewayCache.build()"""
        activation = interp2app._code.activation
        def check():
            scope_w = [w_some_obj()] * NonConstant(42)
            w_result = activation._run(self, scope_w)
            is_root(w_result)
        check = func_with_new_name(check, 'check__' + interp2app.name)
        self._seen_extras.append(check)

    @not_rpython
    def _see_getsetproperty(self, getsetproperty):
        """Called by GetSetProperty.spacebind()"""
        space = self
        def checkprop():
            getsetproperty.fget(getsetproperty, space, w_some_obj())
            if getsetproperty.fset is not None:
                getsetproperty.fset(getsetproperty, space, w_some_obj(),
                                    w_some_obj())
            if getsetproperty.fdel is not None:
                getsetproperty.fdel(getsetproperty, space, w_some_obj())
        if not getsetproperty.name.startswith('<'):
            checkprop = func_with_new_name(checkprop,
                                           'checkprop__' + getsetproperty.name)
        self._seen_extras.append(checkprop)

    def call_obj_args(self, w_callable, w_obj, args):
        is_root(w_callable)
        is_root(w_obj)
        is_arguments(args)
        return w_some_obj()

    def call(self, w_callable, w_args, w_kwds=None):
        is_root(w_callable)
        is_root(w_args)
        is_root(w_kwds)
        return w_some_obj()

    def call_function(self, w_func, *args_w):
        is_root(w_func)
        for w_arg in list(args_w):
            is_root(w_arg)
        return w_some_obj()

    def call_args(self, w_func, args):
        is_root(w_func)
        is_arguments(args)
        return w_some_obj()

    def get_and_call_function(space, w_descr, w_obj, *args_w):
        args = argument.Arguments(space, list(args_w))
        w_impl = space.get(w_descr, w_obj)
        return space.call_args(w_impl, args)

    def gettypefor(self, cls):
        return self.gettypeobject(cls.typedef)

    def gettypeobject(self, typedef):
        assert typedef is not None
        see_typedef(self, typedef)
        return w_some_type()

    def getitem(self, w_obj, w_name):
        is_root(w_obj)
        is_root(w_name)
        if isinstance(w_obj, FakeModules):
            # For reset_lazy_initial_values,
            # need to pretend we return a MixedModule object
            return FakeMixedModule()
        return w_some_type()

    def type(self, w_obj):
        return w_some_type()

    def lookup_in_type_where(self, w_type, key):
        return w_some_obj(), w_some_obj()

    def issubtype_w(self, w_sub, w_type):
        is_root(w_sub)
        is_root(w_type)
        return NonConstant(True)

    def isinstance_w(self, w_inst, w_type):
        is_root(w_inst)
        is_root(w_type)
        return NonConstant(True)

    def unpackiterable(self, w_iterable, expected_length=-1):
        is_root(w_iterable)
        if expected_length < 0:
            expected_length = 3
        return [w_some_obj()] * expected_length

    def unpackcomplex(self, w_complex):
        is_root(w_complex)
        return 1.1, 2.2

    @specialize.arg(1)
    def allocate_instance(self, cls, w_subtype):
        is_root(w_subtype)
        return instantiate(cls)

    def decode_index(self, w_index_or_slice, seqlength):
        is_root(w_index_or_slice)
        return (NonConstant(42), NonConstant(42), NonConstant(42))

    def decode_index4(self, w_index_or_slice, seqlength):
        is_root(w_index_or_slice)
        return (NonConstant(42), NonConstant(42),
                NonConstant(42), NonConstant(42))

    def exec_(self, *args, **kwds):
        pass

    def createexecutioncontext(self):
        ec = ObjSpace.createexecutioncontext(self)
        ec._py_repr = None
        return ec

    def unicode_from_object(self, w_obj):
        return w_some_obj()

    def encode_unicode_object(self, w_unicode, encoding, errors):
        return w_some_obj()

    def _try_fetch_pycode(self, w_func):
        return None

    def is_generator(self, w_obj):
        return NonConstant(False)

    def is_iterable(self, w_obj):
        return NonConstant(False)

    def lookup_in_type(self, w_type, name):
        return w_some_obj()

    def warn(self, w_msg, w_warningcls, stacklevel=2):
        pass

    def _try_buffer_w(self, w_obj, flags):
        return w_obj.buffer_w(self, flags)

    # ----------

    def translates(self, func=None, argtypes=None, seeobj_w=[],
                   extra_func=None, c_compile=False,
                   **kwds):
        config = make_config(None, **kwds)
        if func is not None:
            if argtypes is None:
                nb_args = func.func_code.co_argcount
                argtypes = [W_Root] * nb_args
        #
        t = TranslationContext(config=config)
        self.t = t     # for debugging
        ann = t.buildannotator()

        def entry_point(argv):
            self.threadlocals.enter_thread(self)
            W_SliceObject(w_some_obj(), w_some_obj(), w_some_obj())
            if extra_func:
                extra_func(self)
            return 0
        ann.build_types(entry_point, [s_list_of_strings], complete_now=False)
        if func is not None:
            ann.build_types(func, argtypes, complete_now=False)
        if seeobj_w:
            def seeme(n):
                return seeobj_w[n]
            ann.build_types(seeme, [int], complete_now=False)
        #
        # annotate all _seen_extras, knowing that annotating some may
        # grow the list
        done = 0
        while done < len(self._seen_extras):
            #print self._seen_extras
            ann.build_types(self._seen_extras[done], [],
                            complete_now=False)
            ann.complete_pending_blocks()
            done += 1
        ann.complete()
        assert done == len(self._seen_extras)
        #t.viewcg()
        t.buildrtyper().specialize()
        t.checkgraphs()
        from rpython.translator.backendopt.all import backend_optimizations
        backend_optimizations(t, replace_we_are_jitted=True)
        if c_compile:
            cbuilder = CStandaloneBuilder(t, entry_point, t.config)
            cbuilder.generate_source(defines=cbuilder.DEBUG_DEFINES)
            cbuilder.compile()
            return t, cbuilder


    def setup(space):
        from pypy.module.exceptions import interp_exceptions
        obj_space_exceptions = ObjSpace.ExceptionTable
        # Add subclasses of the ExceptionTable errors
        for name, exc in interp_exceptions.__dict__.items():
            if (isinstance(exc, type) and
                issubclass(exc, interp_exceptions.W_BaseException)):
                name = name.replace("W_", "")
                if name not in obj_space_exceptions:
                    obj_space_exceptions.append(name)

        for name in (ObjSpace.ConstantTable +
                     obj_space_exceptions +
                     BUILTIN_TYPES):
            if name != "str":
                setattr(space, 'w_' + name, w_some_obj())
        space.w_bytes = w_some_obj()
        space.w_text = w_some_obj()
        space.w_type = w_some_type()
        #
        for (name, _, arity, _) in ObjSpace.MethodTable:
            if name in ('type', 'getitem'):
                continue
            args = ['w_%d' % i for i in range(arity)]
            params = args[:]
            d = {'is_root': is_root,
                 'w_some_obj': w_some_obj}
            if name in ('get',):
                params[-1] += '=None'
            exec compile2("""\
                def meth(%s):
                    %s
                    return w_some_obj()
            """ % (', '.join(params),
                   '; '.join(['is_root(%s)' % arg for arg in args]))) in d
            meth = func_with_new_name(d['meth'], name)
            setattr(space, name, meth)
        #
        for name in ObjSpace.IrregularOpTable:
            assert hasattr(space, name)    # missing?


# ____________________________________________________________

@specialize.memo()
def see_typedef(space, typedef):
    assert isinstance(typedef, TypeDef)
    if typedef.name not in BUILTIN_TYPES and typedef.name not in INTERP_TYPES:
        print
        print '------ seeing typedef %r ------' % (typedef.name,)
        for name, value in typedef.rawdict.items():
            space.wrap(value)

class FakeCompiler(object):
    def compile(self, code, name, mode, flags, optimize=-1):
        return FakePyCode()
FakeObjSpace.default_compiler = FakeCompiler()

class FakePyCode(W_Root):
    def exec_code(self, space, w_globals, w_locals):
        return W_Root()

class FakeMixedModule(MixedModule):
    def __init__(self):
        pass

class FakeModules(W_Root):
    pass

class FakeModule(W_Root):
    def __init__(self):
        self.w_dict = w_some_obj()
    def get(self, name):
        name + "xx"   # check that it's a string
        return FakeModules()
    def setmodule(self, w_mod):
        is_root(w_mod)
FakeObjSpace.sys = FakeModule()
FakeObjSpace.sys.filesystemencoding = 'foobar'
FakeObjSpace.sys.defaultencoding = 'ascii'
FakeObjSpace.sys.dlopenflags = 123
FakeObjSpace.builtin = FakeModule()

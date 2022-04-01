import __builtin__
from pypy.interpreter import special
from pypy.interpreter.baseobjspace import ObjSpace, W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.function import Function, Method, FunctionWithFixedCode
from pypy.interpreter.typedef import get_unique_interplevel_subclass
from pypy.interpreter.unicodehelper import decode_utf8sp
from pypy.objspace.std import frame, transparent, callmethod
from pypy.objspace.descroperation import (
    DescrOperation, get_attribute_name, raiseattrerror)
from rpython.rlib.objectmodel import instantiate, specialize, is_annotation_constant
from rpython.rlib.debug import make_sure_not_resized
from rpython.rlib.rarithmetic import base_int, widen, is_valid_int
from rpython.rlib.objectmodel import import_from_mixin, we_are_translated
from rpython.rlib.objectmodel import not_rpython
from rpython.rlib import jit, rutf8, types
from rpython.rlib.signature import signature, finishsigs

# Object imports
from pypy.objspace.std.boolobject import W_BoolObject
from pypy.objspace.std.bytearrayobject import W_BytearrayObject
from pypy.objspace.std.bytesobject import W_BytesObject
from pypy.objspace.std.complexobject import W_ComplexObject
from pypy.objspace.std.dictmultiobject import W_DictMultiObject, W_DictObject
from pypy.objspace.std.floatobject import W_FloatObject
from pypy.objspace.std.intobject import (
    W_AbstractIntObject, W_IntObject, setup_prebuilt, wrapint)
from pypy.objspace.std.iterobject import W_AbstractSeqIterObject, W_SeqIterObject
from pypy.objspace.std.iterobject import W_FastUnicodeIterObject
from pypy.objspace.std.listobject import W_ListObject
from pypy.objspace.std.longobject import W_LongObject, newlong
from pypy.objspace.std.memoryobject import W_MemoryView
from pypy.objspace.std.noneobject import W_NoneObject
from pypy.objspace.std.objectobject import W_ObjectObject
from pypy.objspace.std.setobject import W_SetObject, W_FrozensetObject
from pypy.objspace.std.sliceobject import W_SliceObject
from pypy.objspace.std.tupleobject import W_AbstractTupleObject, W_TupleObject
from pypy.objspace.std.typeobject import W_TypeObject, TypeCache
from pypy.objspace.std.unicodeobject import W_UnicodeObject

@finishsigs
class StdObjSpace(ObjSpace):
    """The standard object space, implementing a general-purpose object
    library in Restricted Python."""
    import_from_mixin(DescrOperation)

    @not_rpython
    def initialize(self):
        """only for initializing the space

        Setup all the object types and implementations.
        """

        setup_prebuilt(self)
        self.FrameClass = frame.build_frame(self)
        self.StringObjectCls = W_BytesObject
        self.UnicodeObjectCls = W_UnicodeObject
        self.IntObjectCls = W_IntObject
        self.FloatObjectCls = W_FloatObject

        # singletons
        self.w_None = W_NoneObject.w_None
        self.w_False = W_BoolObject.w_False
        self.w_True = W_BoolObject.w_True
        self.w_NotImplemented = self.wrap(special.NotImplemented())
        self.w_Ellipsis = self.wrap(special.Ellipsis())

        # types
        builtin_type_classes = {
            W_BoolObject.typedef: W_BoolObject,
            W_BytearrayObject.typedef: W_BytearrayObject,
            W_BytesObject.typedef: W_BytesObject,
            W_ComplexObject.typedef: W_ComplexObject,
            W_DictMultiObject.typedef: W_DictMultiObject,
            W_FloatObject.typedef: W_FloatObject,
            W_IntObject.typedef: W_AbstractIntObject,
            W_AbstractSeqIterObject.typedef: W_AbstractSeqIterObject,
            W_ListObject.typedef: W_ListObject,
            W_MemoryView.typedef: W_MemoryView,
            W_NoneObject.typedef: W_NoneObject,
            W_ObjectObject.typedef: W_ObjectObject,
            W_SetObject.typedef: W_SetObject,
            W_FrozensetObject.typedef: W_FrozensetObject,
            W_SliceObject.typedef: W_SliceObject,
            W_TupleObject.typedef: W_TupleObject,
            W_TypeObject.typedef: W_TypeObject,
            W_UnicodeObject.typedef: W_UnicodeObject,
        }
        self.builtin_types = {}
        self._interplevel_classes = {}
        for typedef, cls in builtin_type_classes.items():
            w_type = self.gettypeobject(typedef)
            self.builtin_types[typedef.name] = w_type
            setattr(self, 'w_' + typedef.name, w_type)
            self._interplevel_classes[w_type] = cls
        # The loop above sets space.w_str and space.w_bytes.
        # We rename 'space.w_str' to 'space.w_unicode' and
        # 'space.w_text'.
        self.w_unicode = self.w_str
        self.w_text = self.w_str
        del self.w_str
        self.w_long = self.w_int
        self.w_dict.flag_map_or_seq = 'M'
        from pypy.objspace.std import dictproxyobject
        dictproxyobject._set_flag_map_or_seq(self)
        self.w_list.flag_map_or_seq = 'S'
        self.w_tuple.flag_map_or_seq = 'S'
        self.builtin_types['str'] = self.w_unicode
        self.builtin_types['bytes'] = self.w_bytes
        self.builtin_types["NotImplemented"] = self.w_NotImplemented
        self.builtin_types["Ellipsis"] = self.w_Ellipsis

        # exceptions & builtins
        self.make_builtins()

        # final setup
        self.setup_builtin_modules()
        # Adding transparent proxy call
        if self.config.objspace.std.withtproxy:
            transparent.setup(self)

    def get_builtin_types(self):
        return self.builtin_types

    def createexecutioncontext(self):
        # add space specific fields to execution context
        # note that this method must not call space methods that might need an
        # execution context themselves (e.g. nearly all space methods)
        ec = ObjSpace.createexecutioncontext(self)
        ec._py_repr = None
        return ec

    def get_objects_in_repr(self):
        from pypy.module.__pypy__.interp_identitydict import W_IdentityDict
        ec = self.getexecutioncontext()
        w_currently_in_repr = ec._py_repr
        if w_currently_in_repr is None:
            w_currently_in_repr = ec._py_repr = W_IdentityDict(self)
        return w_currently_in_repr

    def gettypefor(self, cls):
        return self.gettypeobject(cls.typedef)

    def gettypeobject(self, typedef):
        # typeobject.TypeCache maps a TypeDef instance to its
        # unique-for-this-space W_TypeObject instance
        assert typedef is not None
        return self.fromcache(TypeCache).getorbuild(typedef)

    @not_rpython # only for tests
    def wrap(self, x):
        """ Wraps the Python value 'x' into one of the wrapper classes. This
        should only be used for tests, in real code you need to use the
        explicit new* methods."""
        if x is None:
            return self.w_None
        if isinstance(x, OperationError):
            raise TypeError("attempt to wrap already wrapped exception: %s"%
                              (x,))
        if isinstance(x, int):
            if isinstance(x, bool):
                return self.newbool(x)
            else:
                return self.newint(x)
        if isinstance(x, str):
            return self.newtext(x)
        if isinstance(x, unicode):
            x = x.encode('utf8')
            lgt = rutf8.check_utf8(x, True)
            return self.newutf8(x, lgt)
        if isinstance(x, float):
            return W_FloatObject(x)
        if isinstance(x, W_Root):
            w_result = x.spacebind(self)
            #print 'wrapping', x, '->', w_result
            return w_result
        if isinstance(x, base_int):
            return self.newint(x)
        return self._wrap_not_rpython(x)

    def _wrap_string_old(self, x):
        # XXX should disappear soon
        print 'WARNING: space.wrap() called on a non-ascii byte string: %s' % (
            self.text_w(self.repr(self.newbytes(x))),)
        lst = []
        for ch in x:
            ch = ord(ch)
            if ch > 127:
                lst.append(u'\ufffd')
            else:
                lst.append(unichr(ch))
        unicode_x = u''.join(lst)
        return self.newtext(unicode_x)

    @not_rpython # only for tests
    def _wrap_not_rpython(self, x):
        # _____ this code is here to support testing only _____

        # we might get there in non-translated versions if 'x' is
        # a long that fits the correct range.
        if is_valid_int(x):
            return self.newint(x)

        return self._wrap_not_rpython(x)

    @not_rpython
    def _wrap_not_rpython(self, x):
        # _____ this code is here to support testing only _____

        # wrap() of a container works on CPython, but the code is
        # not RPython.  Don't use -- it is kept around mostly for tests.
        # Use instead newdict(), newlist(), newtuple().
        if isinstance(x, dict):
            items_w = [(self.wrap(k), self.wrap(v)) for (k, v) in x.iteritems()]
            r = self.newdict()
            r.initialize_content(items_w)
            return r
        if isinstance(x, tuple):
            wrappeditems = [self.wrap(item) for item in list(x)]
            return self.newtuple(wrappeditems)
        if isinstance(x, list):
            wrappeditems = [self.wrap(item) for item in x]
            return self.newlist(wrappeditems)

        # The following cases are even stranger.
        # Really really only for tests.
        if type(x) is long:
            return self.wraplong(x)
        if isinstance(x, slice):
            return W_SliceObject(self.wrap(x.start),
                                 self.wrap(x.stop),
                                 self.wrap(x.step))
        if isinstance(x, complex):
            return W_ComplexObject(x.real, x.imag)

        if isinstance(x, set):
            res = W_SetObject(self, self.newlist([self.wrap(item) for item in x]))
            return res

        if isinstance(x, frozenset):
            wrappeditems = [self.wrap(item) for item in x]
            return W_FrozensetObject(self, wrappeditems)

        if x is __builtin__.Ellipsis:
            # '__builtin__.Ellipsis' avoids confusion with special.Ellipsis
            return self.w_Ellipsis

        raise OperationError(self.w_RuntimeError,
            self.wrap("refusing to wrap cpython value %r" % (x,))
        )

    @not_rpython
    def wrap_exception_cls(self, x):
        if hasattr(self, 'w_' + x.__name__):
            w_result = getattr(self, 'w_' + x.__name__)
            return w_result
        return None

    @not_rpython
    def wraplong(self, x):
        if self.config.objspace.std.withsmalllong:
            from rpython.rlib.rarithmetic import r_longlong
            try:
                rx = r_longlong(x)
            except OverflowError:
                pass
            else:
                from pypy.objspace.std.smalllongobject import \
                                               W_SmallLongObject
                return W_SmallLongObject(rx)
        return W_LongObject.fromlong(x)

    @not_rpython
    def unwrap(self, w_obj):
        # _____ this code is here to support testing only _____
        if isinstance(w_obj, W_Root):
            return w_obj.unwrap(self)
        raise TypeError("cannot unwrap: %r" % w_obj)

    @specialize.argtype(1)
    def newint(self, intval):
        if self.config.objspace.std.withsmalllong and isinstance(intval, base_int):
            from pypy.objspace.std.smalllongobject import W_SmallLongObject
            from rpython.rlib.rarithmetic import r_longlong, r_ulonglong
            from rpython.rlib.rarithmetic import longlongmax
            if (not isinstance(intval, r_ulonglong)
                or intval <= r_ulonglong(longlongmax)):
                return W_SmallLongObject(r_longlong(intval))
        intval = widen(intval)
        if not isinstance(intval, int):
            return W_LongObject.fromrarith_int(intval)
        return wrapint(self, intval)

    def newfloat(self, floatval):
        return W_FloatObject(floatval)

    def newcomplex(self, realval, imagval):
        return W_ComplexObject(realval, imagval)

    def unpackcomplex(self, w_complex):
        from pypy.objspace.std.complexobject import unpackcomplex
        return unpackcomplex(self, w_complex)

    def newlong(self, val): # val is an int
        if self.config.objspace.std.withsmalllong:
            from pypy.objspace.std.smalllongobject import W_SmallLongObject
            return W_SmallLongObject.fromint(val)
        return W_LongObject.fromint(self, val)

    @specialize.argtype(1)
    def newlong_from_rarith_int(self, val): # val is an rarithmetic type
        return W_LongObject.fromrarith_int(val)

    def newlong_from_rbigint(self, val):
        try:
            return self.newint(val.toint())
        except OverflowError:
            return newlong(self, val)

    def newtuple(self, list_w):
        from pypy.objspace.std.tupleobject import wraptuple
        assert isinstance(list_w, list)
        make_sure_not_resized(list_w)
        return wraptuple(self, list_w)

    def newlist(self, list_w, sizehint=-1):
        assert not list_w or sizehint == -1
        return W_ListObject(self, list_w, sizehint)

    def newlist_bytes(self, list_s):
        return W_ListObject.newlist_bytes(self, list_s)

    def newlist_text(self, list_t):
        return self.newlist_utf8([decode_utf8sp(self, s)[0] for s in list_t], False)

    def newlist_utf8(self, list_u, is_ascii):
        if is_ascii:
            return W_ListObject.newlist_ascii(self, list_u)
        return ObjSpace.newlist_utf8(self, list_u, False)


    def newlist_int(self, list_i):
        return W_ListObject.newlist_int(self, list_i)

    def newlist_float(self, list_f):
        return W_ListObject.newlist_float(self, list_f)

    def newdict(self, module=False, instance=False, kwargs=False,
                strdict=False):
        return W_DictMultiObject.allocate_and_init_instance(
                self, module=module, instance=instance,
                strdict=strdict, kwargs=kwargs)

    def newdictproxy(self, w_dict):
        # e.g. for module/_sre/
        from pypy.objspace.std.dictproxyobject import W_DictProxyObject
        return W_DictProxyObject(w_dict)

    def newset(self, iterable_w=None):
        if iterable_w is None:
            return W_SetObject(self, None)
        return W_SetObject(self, self.newtuple(iterable_w))

    def newfrozenset(self, iterable_w=None):
        if iterable_w is None:
            return W_FrozensetObject(self, None)
        return W_FrozensetObject(self, self.newtuple(iterable_w))

    def newslice(self, w_start, w_end, w_step):
        return W_SliceObject(w_start, w_end, w_step)

    def newseqiter(self, w_obj):
        return W_SeqIterObject(w_obj)

    def newmemoryview(self, w_obj):
        return W_MemoryView(w_obj)

    def newmemoryview(self, view):
        return W_MemoryView(view)

    def newbytes(self, s):
        assert isinstance(s, bytes)
        return W_BytesObject(s)

    def newbytearray(self, l):
        return W_BytearrayObject(l)

    @specialize.arg_or_var(1, 2)
    def newtext(self, s, lgt=-1, unused=-1):
        # the unused argument can be from something like
        # newtext(*decode_utf8sp(space, code))
        if is_annotation_constant(s) and is_annotation_constant(lgt):
            return self._newtext_memo(s, lgt)
        assert isinstance(s, str)
        if lgt < 0:
            lgt = rutf8.codepoints_in_utf8(s)
        return W_UnicodeObject(s, lgt)

    def newtext_or_none(self, s, lgt=-1):
        if s is None:
            return self.w_None
        return self.newtext(s, lgt)

    @specialize.memo()
    def _newtext_memo(self, s, lgt):
        if s is None:
            return self.w_None # can happen during annotation
        # try to see whether we exist as an interned string, but don't intern
        # if not
        w_u = self.interned_strings.get(s)
        if w_u is not None:
            return w_u
        if lgt < 0:
            lgt = rutf8.codepoints_in_utf8(s)
        return W_UnicodeObject(s, lgt)

    def newutf8(self, utf8s, length):
        assert isinstance(utf8s, str)
        return W_UnicodeObject(utf8s, length)

    def newfilename(self, s):
        return self.fsdecode(self.newbytes(s))

    def type(self, w_obj):
        jit.promote(w_obj.__class__)
        return w_obj.getclass(self)

    def lookup(self, w_obj, name):
        w_type = self.type(w_obj)
        return w_type.lookup(name)
    lookup._annspecialcase_ = 'specialize:lookup'

    def lookup_in_type(self, w_type, name):
        w_src, w_descr = self.lookup_in_type_where(w_type, name)
        return w_descr

    def lookup_in_type_where(self, w_type, name):
        return w_type.lookup_where(name)
    lookup_in_type_where._annspecialcase_ = 'specialize:lookup_in_type_where'

    def lookup_in_type_starting_at(self, w_type, w_starttype, name):
        """ Only supposed to be used to implement super, w_starttype
        and w_type are the same as for super(starttype, type)
        """
        assert isinstance(w_type, W_TypeObject)
        assert isinstance(w_starttype, W_TypeObject)
        return w_type.lookup_starting_at(w_starttype, name)

    @specialize.arg(1)
    def allocate_instance(self, cls, w_subtype):
        """Allocate the memory needed for an instance of an internal or
        user-defined type, without actually __init__ializing the instance."""
        w_type = self.gettypeobject(cls.typedef)
        if self.is_w(w_type, w_subtype):
            instance = instantiate(cls)
        elif cls.typedef.acceptable_as_base_class:
            # the purpose of the above check is to avoid the code below
            # to be annotated at all for 'cls' if it is not necessary
            w_subtype = w_type.check_user_subclass(w_subtype)
            if cls.typedef.applevel_subclasses_base is not None:
                cls = cls.typedef.applevel_subclasses_base
            #
            subcls = get_unique_interplevel_subclass(self, cls)
            instance = instantiate(subcls)
            assert isinstance(instance, cls)
            instance.user_setup(self, w_subtype)
            if w_subtype.hasuserdel:
                self.finalizer_queue.register_finalizer(instance)
        else:
            raise oefmt(self.w_TypeError,
                        "%N.__new__(%N): only for the type %N",
                        w_type, w_subtype, w_type)
        return instance

    # two following functions are almost identical, but in fact they
    # have different return type. First one is a resizable list, second
    # one is not

    def _wrap_expected_length(self, expected, got):
        if got > expected:
            raise oefmt(self.w_ValueError,
                        "too many values to unpack (expected %d)", expected)
        else:
            raise oefmt(self.w_ValueError,
                        "not enough values to unpack (expected %d, got %d)",
                        expected, got)

    def unpackiterable(self, w_obj, expected_length=-1):
        if isinstance(w_obj, W_AbstractTupleObject) and self._uses_tuple_iter(w_obj):
            t = w_obj.getitems_copy()
        elif type(w_obj) is W_ListObject:
            t = w_obj.getitems_copy()
        else:
            return ObjSpace.unpackiterable(self, w_obj, expected_length)
        if expected_length != -1 and len(t) != expected_length:
            raise self._wrap_expected_length(expected_length, len(t))
        return t

    @specialize.arg(3)
    def fixedview(self, w_obj, expected_length=-1, unroll=False):
        """ Fast paths
        """
        if isinstance(w_obj, W_AbstractTupleObject) and self._uses_tuple_iter(w_obj):
            t = w_obj.tolist()
        elif type(w_obj) is W_ListObject:
            if unroll:
                t = w_obj.getitems_unroll()
            else:
                t = w_obj.getitems_fixedsize()
        else:
            if unroll:
                return make_sure_not_resized(ObjSpace.unpackiterable_unroll(
                    self, w_obj, expected_length))
            else:
                return make_sure_not_resized(ObjSpace.unpackiterable(
                    self, w_obj, expected_length)[:])
        if expected_length != -1 and len(t) != expected_length:
            raise self._wrap_expected_length(expected_length, len(t))
        return make_sure_not_resized(t)

    def fixedview_unroll(self, w_obj, expected_length):
        assert expected_length >= 0
        return self.fixedview(w_obj, expected_length, unroll=True)

    def listview_no_unpack(self, w_obj):
        if type(w_obj) is W_ListObject:
            return w_obj.getitems()
        elif isinstance(w_obj, W_AbstractTupleObject) and self._uses_tuple_iter(w_obj):
            return w_obj.getitems_copy()
        elif isinstance(w_obj, W_ListObject) and self._uses_list_iter(w_obj):
            return w_obj.getitems()
        else:
            return None

    def listview(self, w_obj, expected_length=-1):
        t = self.listview_no_unpack(w_obj)
        if t is None:
            return ObjSpace.unpackiterable(self, w_obj, expected_length)
        if expected_length != -1 and len(t) != expected_length:
            raise self._wrap_expected_length(expected_length, len(t))
        return t

    def listview_bytes(self, w_obj):
        # note: uses exact type checking for objects with strategies,
        # and isinstance() for others.  See test_listobject.test_uses_custom...
        if type(w_obj) is W_ListObject:
            return w_obj.getitems_bytes()
        if type(w_obj) is W_DictObject:
            return w_obj.listview_bytes()
        if type(w_obj) is W_SetObject or type(w_obj) is W_FrozensetObject:
            return w_obj.listview_bytes()
        if isinstance(w_obj, W_BytesObject):
            # Python3 considers bytes strings as a list of numbers.
            return None
        if isinstance(w_obj, W_ListObject) and self._uses_list_iter(w_obj):
            return w_obj.getitems_bytes()
        return None

    def listview_ascii(self, w_obj):
        # note: uses exact type checking for objects with strategies,
        # and isinstance() for others.  See test_listobject.test_uses_custom...
        if type(w_obj) is W_ListObject:
            return w_obj.getitems_ascii()
        if type(w_obj) is W_DictObject:
            return w_obj.listview_ascii()
        if type(w_obj) is W_SetObject or type(w_obj) is W_FrozensetObject:
            return w_obj.listview_ascii()
        if isinstance(w_obj, W_UnicodeObject) and self._uses_unicode_iter(w_obj):
            return w_obj.listview_ascii()
        if isinstance(w_obj, W_ListObject) and self._uses_list_iter(w_obj):
            return w_obj.getitems_ascii()
        return None

    def listview_int(self, w_obj):
        if type(w_obj) is W_ListObject:
            return w_obj.getitems_int()
        if type(w_obj) is W_DictObject:
            return w_obj.listview_int()
        if type(w_obj) is W_SetObject or type(w_obj) is W_FrozensetObject:
            return w_obj.listview_int()
        if type(w_obj) is W_BytesObject:
            # Python3 considers bytes strings as a list of numbers.
            return w_obj.listview_int()
        if isinstance(w_obj, W_ListObject) and self._uses_list_iter(w_obj):
            return w_obj.getitems_int()
        return None

    def listview_float(self, w_obj):
        if type(w_obj) is W_ListObject:
            return w_obj.getitems_float()
        # dict and set don't have FloatStrategy, so we can just ignore them
        # for now
        if isinstance(w_obj, W_ListObject) and self._uses_list_iter(w_obj):
            return w_obj.getitems_float()
        return None

    def view_as_kwargs(self, w_dict):
        # Tries to return (keys_list, values_list), or (None, None) if
        # it fails.  It can fail on some dict implementations, so don't
        # rely on it.  For dict subclasses, though, it never fails;
        # this emulates CPython's behavior which often won't call
        # custom __iter__() or keys() methods in dict subclasses.
        if isinstance(w_dict, W_DictObject):
            return w_dict.view_as_kwargs()
        return (None, None)

    def _uses_list_iter(self, w_obj):
        from pypy.objspace.descroperation import list_iter
        return self.lookup(w_obj, '__iter__') is list_iter(self)

    def _uses_tuple_iter(self, w_obj):
        from pypy.objspace.descroperation import tuple_iter
        return self.lookup(w_obj, '__iter__') is tuple_iter(self)

    def _uses_unicode_iter(self, w_obj):
        from pypy.objspace.descroperation import unicode_iter
        return self.lookup(w_obj, '__iter__') is unicode_iter(self)

    def sliceindices(self, w_slice, w_length):
        if isinstance(w_slice, W_SliceObject):
            a, b, c = w_slice.indices3(self, self.int_w(w_length))
            return (a, b, c)
        w_indices = self.getattr(w_slice, self.newtext('indices'))
        w_tup = self.call_function(w_indices, w_length)
        l_w = self.unpackiterable(w_tup)
        if not len(l_w) == 3:
            raise oefmt(self.w_ValueError, "Expected tuple of length 3")
        return self.int_w(l_w[0]), self.int_w(l_w[1]), self.int_w(l_w[2])

    _DescrOperation_is_true = is_true

    def is_true(self, w_obj):
        # a shortcut for performance
        if type(w_obj) is W_BoolObject:
            return bool(w_obj.intval)
        return self._DescrOperation_is_true(w_obj)

    def getattr(self, w_obj, w_name):
        # an optional shortcut for performance

        w_type = self.type(w_obj)
        w_descr = w_type.getattribute_if_not_from_object()
        if w_descr is not None:
            return self._handle_getattribute(w_descr, w_obj, w_name)

        # fast path: XXX this is duplicating most of the logic
        # from the default __getattribute__ and the getattr() method...
        name = get_attribute_name(self, w_obj, w_name)
        w_descr = w_type.lookup(name)
        e = None
        if w_descr is not None:
            w_get = None
            is_data = self.is_data_descr(w_descr)
            if is_data:
                w_get = self.lookup(w_descr, "__get__")
            if w_get is None:
                w_value = w_obj.getdictvalue(self, name)
                if w_value is not None:
                    return w_value
                if not is_data:
                    w_get = self.lookup(w_descr, "__get__")
            typ = type(w_descr)
            if typ is Function or typ is FunctionWithFixedCode:
                # This shortcut is necessary if w_obj is None.  Otherwise e.g.
                # None.__eq__ would return an unbound function because calling
                # __get__ with None as the first argument returns the attribute
                # as if it was accessed through the owner (type(None).__eq__).
                return Method(self, w_descr, w_obj)
            if w_get is not None:
                # __get__ is allowed to raise an AttributeError to trigger
                # use of __getattr__.
                try:
                    return self.get_and_call_function(w_get, w_descr, w_obj,
                                                      w_type)
                except OperationError as e:
                    if not e.match(self, self.w_AttributeError):
                        raise
            else:
                return w_descr
        else:
            w_value = w_obj.getdictvalue(self, name)
            if w_value is not None:
                return w_value

        w_descr = self.lookup(w_obj, '__getattr__')
        if w_descr is not None:
            return self.get_and_call_function(w_descr, w_obj, w_name)
        elif e is not None:
            raise e
        else:
            raiseattrerror(self, w_obj, w_name)

    def finditem_str(self, w_obj, key):
        """ Perform a getitem on w_obj with key (string). Returns found
        element or None on element not found.

        performance shortcut to avoid creating the OperationError(KeyError)
        and allocating W_BytesObject
        """
        if (isinstance(w_obj, W_DictMultiObject) and
                not w_obj.user_overridden_class):
            return w_obj.getitem_str(key)
        return ObjSpace.finditem_str(self, w_obj, key)

    def finditem(self, w_obj, w_key):
        """ Perform a getitem on w_obj with w_key (any object). Returns found
        element or None on element not found.

        performance shortcut to avoid creating the OperationError(KeyError).
        """
        if (isinstance(w_obj, W_DictMultiObject) and
                not w_obj.user_overridden_class):
            return w_obj.getitem(w_key)
        return ObjSpace.finditem(self, w_obj, w_key)

    def setitem_str(self, w_obj, key, w_value):
        """ Same as setitem, but takes string instead of any wrapped object
        """
        if (isinstance(w_obj, W_DictMultiObject) and
                not w_obj.user_overridden_class):
            w_obj.setitem_str(key, w_value)
        else:
            self.setitem(w_obj, self.newtext(key), w_value)

    def getindex_w(self, w_obj, w_exception, objdescr=None):
        if type(w_obj) is W_IntObject:
            return w_obj.intval
        return ObjSpace.getindex_w(self, w_obj, w_exception, objdescr)

    def unicode_from_object(self, w_obj):
        from pypy.objspace.std.unicodeobject import unicode_from_object
        return unicode_from_object(self, w_obj)

    def encode_unicode_object(self, w_unicode, encoding, errors):
        from pypy.objspace.std.unicodeobject import encode_object
        return encode_object(self, w_unicode, encoding, errors)

    def call_method(self, w_obj, methname, *arg_w):
        return callmethod.call_method_opt(self, w_obj, methname, *arg_w)

    def _type_issubtype(self, w_sub, w_type):
        if isinstance(w_sub, W_TypeObject) and isinstance(w_type, W_TypeObject):
            return w_sub.issubtype(w_type)
        raise oefmt(self.w_TypeError, "need type objects")

    @specialize.arg_or_var(2)
    def _type_isinstance(self, w_inst, w_type):
        if not isinstance(w_type, W_TypeObject):
            raise oefmt(self.w_TypeError, "need type object")
        if is_annotation_constant(w_type):
            cls = self._get_interplevel_cls(w_type)
            if cls is not None:
                assert w_inst is not None
                if isinstance(w_inst, cls):
                    return True
        return self.type(w_inst).issubtype(w_type)

    @specialize.memo()
    def _get_interplevel_cls(self, w_type):
        if not hasattr(self, "_interplevel_classes"):
            return None # before running initialize
        return self._interplevel_classes.get(w_type, None)

    @specialize.arg(2, 3)
    def is_overloaded(self, w_obj, tp, method):
        return (self.lookup(w_obj, method) is not
                self.lookup_in_type(tp, method))

    def getfulltypename(self, w_obj):
        w_type = self.type(w_obj)
        if w_type.is_heaptype():
            classname = w_type.getqualname(self)
            w_module = w_type.lookup("__module__")
            if w_module is not None:
                try:
                    modulename = self.utf8_w(w_module)
                except OperationError as e:
                    if not e.match(self, self.w_TypeError):
                        raise
                else:
                    classname = '%s.%s' % (modulename, classname)
        else:
            classname = w_type.name
        return classname

import weakref
from pypy.interpreter import gateway
from pypy.interpreter.baseobjspace import W_Root, SpaceCache
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.function import (
    Function, StaticMethod, ClassMethod, FunctionWithFixedCode)
from pypy.interpreter.typedef import (
    weakref_descr, GetSetProperty, dict_descr, Member, TypeDef)
from pypy.interpreter.astcompiler.misc import mangle
from pypy.module.__builtin__ import abstractinst

from rpython.rlib.jit import (promote, elidable_promote, we_are_jitted,
     elidable, dont_look_inside, unroll_safe)
from rpython.rlib.objectmodel import current_object_addr_as_int, compute_hash
from rpython.rlib.objectmodel import we_are_translated, not_rpython
from rpython.rlib.rarithmetic import intmask, r_uint
from rpython.rlib.rutf8 import CheckError, check_utf8, surrogate_in_utf8

class MutableCell(W_Root):
    def unwrap_cell(self, space):
        raise NotImplementedError("abstract base")

class ObjectMutableCell(MutableCell):
    def __init__(self, w_value=None):
        self.w_value = w_value

    def unwrap_cell(self, space):
        return self.w_value

    def __repr__(self):
        return "<ObjectMutableCell: %s>" % (self.w_value, )


class IntMutableCell(MutableCell):
    def __init__(self, intvalue):
        self.intvalue = intvalue

    def unwrap_cell(self, space):
        return space.newint(self.intvalue)

    def __repr__(self):
        return "<IntMutableCell: %s>" % (self.intvalue, )


def unwrap_cell(space, w_value):
    if isinstance(w_value, MutableCell):
        return w_value.unwrap_cell(space)
    return w_value

def write_cell(space, w_cell, w_value):
    from pypy.objspace.std.listobject import is_plain_int1, plain_int_w
    if w_cell is None:
        # attribute does not exist at all, write it without a cell first
        return w_value
    if isinstance(w_cell, ObjectMutableCell):
        w_cell.w_value = w_value
        return None
    elif isinstance(w_cell, IntMutableCell) and is_plain_int1(w_value):
        w_cell.intvalue = plain_int_w(space, w_value)
        return None
    elif space.is_w(w_cell, w_value):
        # If the new value and the current value are the same, don't
        # create a level of indirection, or mutate the version.
        return None
    if is_plain_int1(w_value):
        return IntMutableCell(plain_int_w(space, w_value))
    else:
        return ObjectMutableCell(w_value)

class VersionTag(object):
    pass

class MethodCache(object):

    def __init__(self, space):
        # Note: these attributes never change which object they contain,
        # so reading 'cache.versions' for example is constant-folded.
        # The actual list in 'cache.versions' is not a constant, of
        # course.
        SIZE = 1 << space.config.objspace.std.methodcachesizeexp
        self.versions = [None] * SIZE
        self.names = [None] * SIZE
        self.lookup_where = [(None, None)] * SIZE
        if space.config.objspace.std.withmethodcachecounter:
            self.hits = {}
            self.misses = {}

    def clear(self):
        None_None = (None, None)
        for i in range(len(self.versions)):
            self.versions[i] = None
        for i in range(len(self.names)):
            self.names[i] = None
        for i in range(len(self.lookup_where)):
            self.lookup_where[i] = None_None

    def _cleanup_(self):
        self.clear()

class _Global(object):
    weakref_warning_printed = False
_global = _Global()


class Layout(object):
    """A Layout is attached to every W_TypeObject to represent the
    layout of instances.  Some W_TypeObjects share the same layout.
    If a W_TypeObject is a base of another, then the layout of
    the first is either the same or a parent layout of the second.
    The Layouts have single inheritance, unlike W_TypeObjects.
    """
    _immutable_ = True

    def __init__(self, typedef, nslots, newslotnames=[], base_layout=None):
        self.typedef = typedef
        self.nslots = nslots
        self.newslotnames = newslotnames[:]    # make a fixed-size list
        self.base_layout = base_layout

    def issublayout(self, parent):
        while self is not parent:
            self = self.base_layout
            if self is None:
                return False
        return True

    def expand(self, hasdict, weakrefable):
        """Turn this Layout into a tuple.  If two classes get equal
        tuples, it means their instances have a fully compatible layout."""
        return (self.typedef, self.newslotnames, self.base_layout,
                hasdict, weakrefable)


# possible values of compares_by_identity_status
UNKNOWN = 0
COMPARES_BY_IDENTITY = 1
OVERRIDES_EQ_CMP_OR_HASH = 2

class W_TypeObject(W_Root):
    lazyloaders = {} # can be overridden by specific instances

    # the version_tag changes if the dict or the inheritance hierarchy changes
    # other changes to the type (e.g. the name) leave it unchanged
    _version_tag = None

    _immutable_fields_ = ["flag_heaptype",
                          "flag_cpytype",
                          "flag_abstract?",
                          "flag_sequence_bug_compat",
                          "flag_map_or_seq",    # '?' or 'M' or 'S'
                          "compares_by_identity_status?",
                          'hasuserdel',
                          'weakrefable',
                          'hasdict',
                          'layout?',
                          'terminator',
                          '_version_tag?',
                          'name?',
                          'mro_w?[*]',
                          'hasmro?',
                          ]

    # wether the class has an overridden __getattribute__
    # (False is a conservative default, fixed during real usage)
    uses_object_getattribute = False

    # for the IdentityDictStrategy
    compares_by_identity_status = UNKNOWN

    # used to cache the type's __new__ function
    w_new_function = None

    # set to True by cpyext _before_ it even calls __init__() below
    flag_cpytype = False

    @dont_look_inside
    def __init__(self, space, name, bases_w, dict_w,
                 overridetypedef=None, force_new_layout=False,
                 is_heaptype=True):
        self.space = space
        try:
            check_utf8(name, False)
        except CheckError as e:
            raise OperationError(space.w_UnicodeEncodeError,
                 space.newtuple([space.newtext('utf8'),
                                 space.newtext(name),
                                 space.newint(e.pos),
                                 space.newint(e.pos + 1),
                                 space.newtext('surrogates not allowed')]))
        self.name = name
        self.qualname = None
        self.bases_w = bases_w
        self.dict_w = dict_w
        self.hasdict = False
        self.hasuserdel = False
        self.weakrefable = False
        self.w_doc = space.w_None
        self.text_signature = None
        self.weak_subclasses = []
        self.flag_heaptype = is_heaptype
        self.flag_abstract = False
        self.flag_sequence_bug_compat = False
        self.flag_map_or_seq = '?'   # '?' means "don't know, check otherwise"

        self.layout = None  # the lines below may try to access self.layout

        # get and remove the __qualname__ from the dict *first*, so that if
        # e.g. a slot named "__qualname__" exists, the setup_user_defined_type
        # below will not see it
        self.qualname = self.getname(space)
        if self.flag_heaptype:
            w_qualname = self.dict_w.pop('__qualname__', None)
            if w_qualname is not None:
                if space.isinstance_w(w_qualname, space.w_unicode):
                    self.qualname = space.utf8_w(w_qualname)
                elif not self.flag_cpytype:
                    raise oefmt(space.w_TypeError,
                                "type __qualname__ must be a str, not %T",
                                w_qualname)

        if overridetypedef is not None:
            assert not force_new_layout
            layout = setup_builtin_type(self, overridetypedef)
        else:
            layout = setup_user_defined_type(self, force_new_layout)
        self.layout = layout

        if not is_mro_purely_of_types(self.mro_w):
            pass
        else:
            # the _version_tag should change, whenever the content of
            # dict_w of any of the types in the mro changes, or if the mro
            # itself changes
            self._version_tag = VersionTag()
        from pypy.objspace.std.mapdict import DictTerminator, NoDictTerminator
        # if the typedef has a dict, then the rpython-class does all the dict
        # management, which means from the point of view of mapdict there is no
        # dict.
        typedef = self.layout.typedef
        if (self.hasdict and not typedef.hasdict):
            self.terminator = DictTerminator(space, self)
        else:
            self.terminator = NoDictTerminator(space, self)

    @not_rpython
    def __repr__(self):
        return '<W_TypeObject %r at 0x%x>' % (self.name, id(self))

    def mutated(self, key):
        """
        The type is being mutated. key is either the string containing the
        specific attribute which is being deleted/set or None to indicate a
        generic mutation.
        """
        space = self.space
        assert self.is_heaptype() or self.is_cpytype()

        self.uses_object_getattribute = False
        # ^^^ conservative default, fixed during real usage

        if (key is None or key == '__eq__' or key == '__hash__'):
            self.compares_by_identity_status = UNKNOWN

        if space.config.objspace.std.newshortcut:
            self.w_new_function = None

        if self._version_tag is not None:
            self._version_tag = VersionTag()

        subclasses_w = self.get_subclasses()
        for w_subclass in subclasses_w:
            assert isinstance(w_subclass, W_TypeObject)
            w_subclass.mutated(key)

    def version_tag(self):
        if not we_are_jitted() or self.is_heaptype():
            return self._version_tag
        # prebuilt objects cannot get their version_tag changed
        return self._pure_version_tag()

    @elidable_promote()
    def _pure_version_tag(self):
        return self._version_tag

    def getattribute_if_not_from_object(self):
        """ this method returns the applevel __getattribute__ if that is not
        the one from object, in which case it returns None """
        from pypy.objspace.descroperation import object_getattribute
        if not we_are_jitted():
            if not self.uses_object_getattribute:
                # slow path: look for a custom __getattribute__ on the class
                w_descr = self.lookup('__getattribute__')
                # if it was not actually overriden in the class, we remember this
                # fact for the next time.
                if w_descr is object_getattribute(self.space):
                    if self.space._side_effects_ok():
                        self.uses_object_getattribute = True
                else:
                    return w_descr
            return None
        # in the JIT case, just use a lookup, because it is folded away
        # correctly using the version_tag
        w_descr = self.lookup('__getattribute__')
        if w_descr is not object_getattribute(self.space):
            return w_descr

    def has_object_getattribute(self):
        return self.getattribute_if_not_from_object() is None

    def compares_by_identity(self):
        from pypy.objspace.descroperation import object_hash, type_eq
        #
        if self.compares_by_identity_status != UNKNOWN:
            # fast path
            return self.compares_by_identity_status == COMPARES_BY_IDENTITY
        #
        default_hash = object_hash(self.space)
        my_eq = self.lookup('__eq__')
        overrides_eq = (my_eq and my_eq is not type_eq(self.space))
        overrides_eq_cmp_or_hash = (overrides_eq or
                                    self.lookup('__hash__') is not default_hash)
        if overrides_eq_cmp_or_hash:
            result = OVERRIDES_EQ_CMP_OR_HASH
        else:
            result = COMPARES_BY_IDENTITY
        if self.space._side_effects_ok():
            self.compares_by_identity_status = result
        return result == COMPARES_BY_IDENTITY

    def ready(self):
        for w_base in self.bases_w:
            if not isinstance(w_base, W_TypeObject):
                continue
            w_base.add_subclass(self)

    # compute a tuple that fully describes the instance layout
    def get_full_instance_layout(self):
        return self.layout.expand(self.hasdict, self.weakrefable)

    def compute_default_mro(self):
        return compute_C3_mro(self.space, self)

    def getdictvalue(self, space, attr):
        version_tag = self.version_tag()
        if version_tag is not None:
            return unwrap_cell(
                space,
                self._pure_getdictvalue_no_unwrapping(
                    space, version_tag, attr))
        w_value = self._getdictvalue_no_unwrapping(space, attr)
        return unwrap_cell(space, w_value)

    def _getdictvalue_no_unwrapping(self, space, attr):
        w_value = self.dict_w.get(attr, None)
        if self.lazyloaders and w_value is None:
            if attr in self.lazyloaders:
                # very clever next line: it forces the attr string
                # to be interned.
                space.new_interned_str(attr)
                loader = self.lazyloaders[attr]
                del self.lazyloaders[attr]
                w_value = loader()
                if w_value is not None:   # None means no such attribute
                    self.dict_w[attr] = w_value
                    return w_value
        return w_value

    @elidable
    def _pure_getdictvalue_no_unwrapping(self, space, version_tag, attr):
        return self._getdictvalue_no_unwrapping(space, attr)

    def setdictvalue(self, space, name, w_value):
        if not self.is_heaptype():
            raise oefmt(space.w_TypeError,
                        "can't set attributes on type object '%N'", self)
        if name == "__del__" and name not in self.dict_w:
            msg = ("a __del__ method added to an existing type will not be "
                   "called")
            space.warn(space.newtext(msg), space.w_RuntimeWarning)
        version_tag = self.version_tag()
        if version_tag is not None:
            w_curr = self._pure_getdictvalue_no_unwrapping(
                    space, version_tag, name)
            w_value = write_cell(space, w_curr, w_value)
            if w_value is None:
                return True
        self.mutated(name)
        self.dict_w[name] = w_value
        return True

    def deldictvalue(self, space, key):
        if self.lazyloaders:
            self._cleanup_()    # force un-lazification
        if not (self.is_heaptype() or self.is_cpytype()):
            raise oefmt(space.w_TypeError,
                        "can't delete attributes on type object '%N'", self)
        try:
            del self.dict_w[key]
        except KeyError:
            return False
        else:
            self.mutated(key)
            return True

    def lookup(self, name):
        # note that this doesn't call __get__ on the result at all
        space = self.space
        return self.lookup_where_with_method_cache(name)[1]

    def lookup_where(self, name):
        space = self.space
        return self.lookup_where_with_method_cache(name)

    @unroll_safe
    def lookup_starting_at(self, w_starttype, name):
        space = self.space
        look = False
        for w_class in self.mro_w:
            if w_class is w_starttype:
                look = True
            elif look:
                w_value = w_class.getdictvalue(space, name)
                if w_value is not None:
                    return w_value
        return None

    @unroll_safe
    def _lookup(self, key):
        # nowadays, only called from ../../tool/ann_override.py
        space = self.space
        for w_class in self.mro_w:
            w_value = w_class.getdictvalue(space, key)
            if w_value is not None:
                return w_value
        return None

    @unroll_safe
    def _lookup_where(self, key):
        # like _lookup() but also returns the parent class in which the
        # attribute was found
        space = self.space
        for w_class in self.mro_w:
            w_value = w_class.getdictvalue(space, key)
            if w_value is not None:
                return w_class, w_value
        return None, None

    def _lookup_where_all_typeobjects(self, key):
        # like _lookup_where(), but when we know that self.mro_w only
        # contains W_TypeObjects.  (It differs from _lookup_where() mostly
        # from a JIT point of view: it cannot invoke arbitrary Python code.)
        space = self.space
        for w_class in self.mro_w:
            assert isinstance(w_class, W_TypeObject)
            w_value = w_class._getdictvalue_no_unwrapping(space, key)
            if w_value is not None:
                return w_class, w_value
        return None, None

    def lookup_where_with_method_cache(self, name):
        space = self.space
        promote(self)
        version_tag = promote(self.version_tag())
        if version_tag is None:
            tup = self._lookup_where(name)
            return tup
        tup_w = self._pure_lookup_where_with_method_cache(name, version_tag)
        w_class, w_value = tup_w
        if isinstance(w_value, MutableCell):
            return w_class, w_value.unwrap_cell(space)
        return tup_w   # don't make a new tuple, reuse the old one

    @elidable
    def _pure_lookup_where_with_method_cache(self, name, version_tag):
        space = self.space
        cache = space.fromcache(MethodCache)
        SHIFT2 = r_uint.BITS - space.config.objspace.std.methodcachesizeexp
        SHIFT1 = SHIFT2 - 5
        version_tag_as_int = current_object_addr_as_int(version_tag)
        # ^^^Note: if the version_tag object is moved by a moving GC, the
        # existing method cache entries won't be found any more; new
        # entries will be created based on the new address.  The
        # assumption is that the version_tag object won't keep moving all
        # the time - so using the fast current_object_addr_as_int() instead
        # of a slower solution like hash() is still a good trade-off.
        hash_name = compute_hash(name)
        product = intmask(version_tag_as_int * hash_name)
        method_hash = (r_uint(product) ^ (r_uint(product) << SHIFT1)) >> SHIFT2
        # ^^^Note2: we used to just take product>>SHIFT2, but on 64-bit
        # platforms SHIFT2 is really large, and we loose too much information
        # that way (as shown by failures of the tests that typically have
        # method names like 'f' who hash to a number that has only ~33 bits).
        cached_version_tag = cache.versions[method_hash]
        if cached_version_tag is version_tag:
            cached_name = cache.names[method_hash]
            if cached_name == name:
                tup = cache.lookup_where[method_hash]
                if space.config.objspace.std.withmethodcachecounter:
                    cache.hits[name] = cache.hits.get(name, 0) + 1
#                print "hit", self, name
                return tup
        tup = self._lookup_where_all_typeobjects(name)
        if space._side_effects_ok():
            cache.versions[method_hash] = version_tag
            cache.names[method_hash] = name
            cache.lookup_where[method_hash] = tup
            if space.config.objspace.std.withmethodcachecounter:
                cache.misses[name] = cache.misses.get(name, 0) + 1
#        print "miss", self, name
        return tup

    def check_user_subclass(self, w_subtype):
        space = self.space
        if not isinstance(w_subtype, W_TypeObject):
            raise oefmt(space.w_TypeError,
                        "X is not a type object ('%T')", w_subtype)
        if not w_subtype.layout:
            raise oefmt(space.w_TypeError,
                "%N.__new__(%N): uninitialized type %N may not be instantiated yet.",
                self, w_subtype, w_subtype)
        if not w_subtype.issubtype(self):
            raise oefmt(space.w_TypeError,
                        "%N.__new__(%N): %N is not a subtype of %N",
                        self, w_subtype, w_subtype, self)
        if self.layout.typedef is not w_subtype.layout.typedef:
            raise oefmt(space.w_TypeError,
                        "%N.__new__(%N) is not safe, use %N.__new__()",
                        self, w_subtype, w_subtype)
        return w_subtype

    @not_rpython
    def _cleanup_(self):
        "Forces the lazy attributes to be computed."
        if 'lazyloaders' in self.__dict__:
            for attr in self.lazyloaders.keys():
                self.getdictvalue(self.space, attr)
            del self.lazyloaders

    def getdict(self, space):
        from pypy.objspace.std.classdict import ClassDictStrategy
        from pypy.objspace.std.dictmultiobject import W_DictObject
        if self.lazyloaders:
            self._cleanup_()    # force un-lazification
        strategy = space.fromcache(ClassDictStrategy)
        storage = strategy.erase(self)
        return W_DictObject(space, strategy, storage)

    def is_heaptype(self):
        return self.flag_heaptype

    def is_cpytype(self):
        return self.flag_cpytype

    def is_abstract(self):
        return self.flag_abstract

    def set_abstract(self, abstract):
        self.flag_abstract = bool(abstract)

    def issubtype(self, w_type):
        promote(self)
        promote(w_type)
        if we_are_jitted():
            version_tag1 = self.version_tag()
            version_tag2 = w_type.version_tag()
            if version_tag1 is not None and version_tag2 is not None:
                res = _pure_issubtype(self, w_type, version_tag1, version_tag2)
                return res
        return _issubtype(self, w_type)

    def get_module(self):
        space = self.space
        if self.is_heaptype():
            return self.getdictvalue(space, '__module__')
        elif self.is_cpytype():
            dot = self.name.rfind('.')
        else:
            dot = self.name.find('.')
        if dot >= 0:
            mod = self.name[:dot]
        else:
            mod = "builtins"
        return space.newtext(mod)

    def getname(self, space):
        if self.is_heaptype():
            result = self.name
        else:
            if self.is_cpytype():
                dot = self.name.rfind('.')
            else:
                dot = self.name.find('.')
            if dot >= 0:
                result = self.name[dot+1:]
            else:
                result = self.name
        return result

    def getqualname(self, space):
        return self.qualname

    def add_subclass(self, w_subclass):
        space = self.space
        if not space.config.translation.rweakref:
            # We don't have weakrefs!  In this case, every class stores
            # subclasses in a non-weak list.  ALL CLASSES LEAK!  To make
            # the user aware of this annoying fact, print a warning.
            if we_are_translated() and not _global.weakref_warning_printed:
                from rpython.rlib import debug
                debug.debug_print("Warning: no weakref support in this PyPy. "
                                  "All user-defined classes will leak!")
                _global.weakref_warning_printed = True

        assert isinstance(w_subclass, W_TypeObject)
        newref = weakref.ref(w_subclass)
        for i in range(len(self.weak_subclasses)):
            ref = self.weak_subclasses[i]
            if ref() is None:
                self.weak_subclasses[i] = newref
                return
        else:
            self.weak_subclasses.append(newref)

    def remove_subclass(self, w_subclass):
        space = self.space
        for i in range(len(self.weak_subclasses)):
            ref = self.weak_subclasses[i]
            if ref() is w_subclass:
                del self.weak_subclasses[i]
                return

    def get_subclasses(self):
        space = self.space
        subclasses_w = []
        for ref in self.weak_subclasses:
            w_ob = ref()
            if w_ob is not None:
                subclasses_w.append(w_ob)
        return subclasses_w

    # for now, weakref support for W_TypeObject is hard to get automatically
    _lifeline_ = None

    def getweakref(self):
        return self._lifeline_

    def setweakref(self, space, weakreflifeline):
        self._lifeline_ = weakreflifeline

    def delweakref(self):
        self._lifeline_ = None

    def descr_call(self, space, __args__):
        promote(self)
        # invoke the __new__ of the type
        if not we_are_jitted():
            # note that the annotator will figure out that self.w_new_function
            # can only be None if the newshortcut config option is not set
            w_newfunc = self.w_new_function
        else:
            # for the JIT it is better to take the slow path because normal lookup
            # is nicely optimized, but the self.w_new_function attribute is not
            # known to the JIT
            w_newfunc = None
        if w_newfunc is None:
            w_newtype, w_newdescr = self.lookup_where('__new__')
            if w_newdescr is None:    # see test_crash_mro_without_object_1
                raise oefmt(space.w_TypeError, "cannot create '%N' instances",
                            self)
            #
            # issue #2666
            if space.config.objspace.usemodules.cpyext:
                w_newtype, w_newdescr = self.hack_which_new_to_call(
                    w_newtype, w_newdescr)
            #
            w_newfunc = space.get(w_newdescr, space.w_None, w_type=self)
            if (space.config.objspace.std.newshortcut and
                not we_are_jitted() and space._side_effects_ok() and
                isinstance(w_newtype, W_TypeObject)):
                self.w_new_function = w_newfunc
        w_newobject = space.call_obj_args(w_newfunc, self, __args__)
        call_init = space.isinstance_w(w_newobject, self)

        # maybe invoke the __init__ of the type
        if (call_init and not (space.is_w(self, space.w_type) and
            not __args__.keyword_names_w and len(__args__.arguments_w) == 1)):
            w_descr = space.lookup(w_newobject, '__init__')
            if w_descr is not None:    # see test_crash_mro_without_object_2
                w_result = space.get_and_call_args(w_descr, w_newobject,
                                                   __args__)
                if not space.is_w(w_result, space.w_None):
                    raise oefmt(space.w_TypeError,
                                "__init__() should return None")
        return w_newobject

    def hack_which_new_to_call(self, w_newtype, w_newdescr):
        # issue #2666: for cpyext, we need to hack in order to reproduce
        # an "optimization" of CPython that actually changes behaviour
        # in corner cases.
        #
        # * Normally, we use the __new__ found in the MRO in the normal way.
        #
        # * If by chance this __new__ happens to be implemented as a C
        #   function, then instead, we discard it and use directly
        #   self.__base__.tp_new.
        #
        # * Most of the time this is the same (and faster for CPython), but
        #   it can fail if self.__base__ happens not to be the first base.
        #
        from pypy.module.cpyext.methodobject import W_PyCFunctionObject

        if isinstance(w_newdescr, W_PyCFunctionObject):
            return self._really_hack_which_new_to_call(w_newtype, w_newdescr)
        else:
            return w_newtype, w_newdescr

    def _really_hack_which_new_to_call(self, w_newtype, w_newdescr):
        # This logic is moved in yet another helper function that
        # is recursive.  We call this only if we see a
        # W_PyCFunctionObject.  That's a performance optimization
        # because in the common case, we won't call any function that
        # contains the stack checks.
        from pypy.module.cpyext.methodobject import W_PyCFunctionObject
        from pypy.module.cpyext.typeobject import is_tp_new_wrapper

        if (isinstance(w_newdescr, W_PyCFunctionObject) and
                w_newtype is not self and
                is_tp_new_wrapper(self.space, w_newdescr.ml)):
            w_bestbase = find_best_base(self.bases_w)
            if w_bestbase is not None:
                w_newtype, w_newdescr = w_bestbase.lookup_where('__new__')
                return w_bestbase._really_hack_which_new_to_call(w_newtype,
                                                                 w_newdescr)
        return w_newtype, w_newdescr

    def descr_repr(self, space):
        w_mod = self.get_module()
        if w_mod is None or not space.isinstance_w(w_mod, space.w_text):
            mod = None
        else:
            mod = space.utf8_w(w_mod)
        if mod is not None and mod != b'builtins':
            return space.newtext(b"<class '%s.%s'>" % (mod, self.getqualname(space)))
        else:
            return space.newtext("<class '%s'>" % (self.name,))

    def iterator_greenkey_printable(self):
        return self.name

    def descr_getattribute(self, space, w_name):
        name = space.text_w(w_name)
        w_descr = space.lookup(self, name)
        if w_descr is not None:
            if space.is_data_descr(w_descr):
                w_get = space.lookup(w_descr, "__get__")
                if w_get is not None:
                    return space.get_and_call_function(w_get, w_descr, self,
                                                       space.type(self))
        w_value = self.lookup(name)
        if w_value is not None:
            # __get__(None, type): turns e.g. functions into unbound methods
            return space.get(w_value, space.w_None, self)
        if w_descr is not None:
            return space.get(w_descr, self)
        raise oefmt(space.w_AttributeError,
                    "type object '%N' has no attribute %R", self, w_name)

    def descr_ne(self, space, w_other):
        if not isinstance(w_other, W_TypeObject):
            return space.w_NotImplemented
        return space.newbool(not space.is_w(self, w_other))


def descr__new__(space, w_typetype, __args__):
    """This is used to create user-defined classes only."""
    if len(__args__.arguments_w) not in (1, 3):
        if space.is_w(w_typetype, space.w_type):
            raise oefmt(space.w_TypeError,
                        "type.__new__() takes 1 or 3 arguments")
        else:
            raise oefmt(space.w_TypeError,
                        "%N.__new__() takes exactly 3 arguments (1 given)",
                        w_typetype)

    w_name = __args__.arguments_w[0]

    w_typetype = _precheck_for_new(space, w_typetype)

    # special case for type(x), but not Metaclass(x)
    if len(__args__.arguments_w) == 1:
        if space.is_w(w_typetype, space.w_type):
            return space.type(w_name)
        else:
            raise oefmt(space.w_TypeError,
                        "%N.__new__() takes exactly 3 arguments (1 given)",
                        w_typetype)
    w_bases = __args__.arguments_w[1]
    w_dict = __args__.arguments_w[2]
    return _create_new_type(space, w_typetype, w_name, w_bases, w_dict, __args__)


def _check_new_args(space, w_name, w_bases, w_dict):
    if not space.isinstance_w(w_name, space.w_text):
        raise oefmt(space.w_TypeError,
                    "type() argument 1 must be string, not %T", w_name)
    if not space.isinstance_w(w_bases, space.w_tuple):
        raise oefmt(space.w_TypeError,
                    "type() argument 2 must be tuple, not %T", w_bases)
    if not space.isinstance_w(w_dict, space.w_dict):
        raise oefmt(space.w_TypeError,
                    "type() argument 3 must be dict, not %T", w_dict)


def _create_new_type(space, w_typetype, w_name, w_bases, w_dict, __args__):
    if hasattr(space, 'is_fake_objspace'):
        # this is for the various test_ztranslation around: if we are using
        # the fake objspace, we don't want to annotate all the code which is
        # specific to StdObjSpace. We just return a "random" W_Root.
        return space.newlong(42)

    # this is in its own function because we want the special case 'type(x)'
    # above to be seen by the jit.
    _check_new_args(space, w_name, w_bases, w_dict)
    bases_w = space.fixedview(w_bases)
    for w_base in bases_w:
        if space.lookup(w_base, '__mro_entries__') is not None:
            raise oefmt(space.w_TypeError,
                        "type() doesn't support MRO entry resolution; "
                        "use types.new_class()")

    w_winner = _calculate_metaclass(space, w_typetype, bases_w)
    if not space.is_w(w_winner, w_typetype):
        newfunc = space.getattr(w_winner, space.newtext('__new__'))
        if not space.is_w(newfunc, space.getattr(space.w_type, space.newtext('__new__'))):
            return space.call_function(newfunc, w_winner, w_name, w_bases, w_dict)
        w_typetype = w_winner

    name = space.text_w(w_name)
    if '\x00' in name:
        raise oefmt(space.w_ValueError, "type name must not contain null characters")
    pos = surrogate_in_utf8(name)
    if pos >= 0:
        raise oefmt(space.w_ValueError, "can't encode character in position "
                    "%d, surrogates not allowed", pos)
    dict_w = {}
    dictkeys_w = space.listview(w_dict)
    for w_key in dictkeys_w:
        key = space.text_w(w_key)
        dict_w[key] = space.getitem(w_dict, w_key)
    w_type = space.allocate_instance(W_TypeObject, w_typetype)

    # store the w_type in __classcell__
    w_classcell = dict_w.get("__classcell__", None)
    if w_classcell:
        _store_type_in_classcell(space, w_type, w_classcell, dict_w)

    W_TypeObject.__init__(w_type, space, name, bases_w or [space.w_object],
                          dict_w, is_heaptype=True)


    w_type.ready()

    _set_names(space, w_type)
    _init_subclass(space, w_type, __args__)
    return w_type

def _calculate_metaclass(space, w_metaclass, bases_w):
    """Determine the most derived metatype"""
    w_winner = w_metaclass
    for base in bases_w:
        w_typ = space.type(base)
        if space.is_w(w_typ, space.w_classobj):
            continue # special-case old-style classes
        if space.issubtype_w(w_winner, w_typ):
            continue
        if space.issubtype_w(w_typ, w_winner):
            w_winner = w_typ
            continue
        msg = ("metaclass conflict: the metaclass of a derived class must be "
               "a (non-strict) subclass of the metaclasses of all its bases")
        raise oefmt(space.w_TypeError, msg)
    return w_winner

def _store_type_in_classcell(space, w_type, w_classcell, dict_w):
    from pypy.interpreter.nestedscope import Cell
    if isinstance(w_classcell, Cell):
        w_classcell.set(w_type)
    else:
        raise oefmt(space.w_TypeError,
                    "__classcell__ must be a nonlocal cell, not %T",
                    w_classcell)
    del dict_w['__classcell__']

def _calculate_metaclass(space, w_metaclass, bases_w):
    """Determine the most derived metatype"""
    w_winner = w_metaclass
    for base in bases_w:
        w_typ = space.type(base)
        if space.issubtype_w(w_winner, w_typ):
            continue
        if space.issubtype_w(w_typ, w_winner):
            w_winner = w_typ
            continue
        msg = ("metaclass conflict: the metaclass of a derived class must be "
               "a (non-strict) subclass of the metaclasses of all its bases")
        raise oefmt(space.w_TypeError, msg)
    return w_winner

def _precheck_for_new(space, w_type):
    if not isinstance(w_type, W_TypeObject):
        raise oefmt(space.w_TypeError, "X is not a type object (%T)", w_type)
    return w_type

def _set_names(space, w_type):

    for key, w_value in w_type.dict_w.items():
        w_meth = space.lookup(w_value, '__set_name__')
        if w_meth is not None:
            try:
                space.get_and_call_function(w_meth, w_value, w_type, space.newtext(key))
            except OperationError as e:
                e2 = oefmt(space.w_RuntimeError,
                           "Error calling __set_name__ on '%T' instance '%s' in '%N'",
                           w_value, key, w_type)
                e2.chain_exceptions_from_cause(space, e)
                raise e2

def _init_subclass(space, w_type, __args__):
    # bit of a mess, but I didn't feel like implementing the super logic
    w_super = space.getattr(space.builtin, space.newtext("super"))
    w_func = space.getattr(space.call_function(w_super, w_type, w_type),
                           space.newtext("__init_subclass__"))
    args = __args__.replace_arguments([])
    space.call_args(w_func, args)

def descr__init__(space, w_type, __args__):
    if len(__args__.arguments_w) not in (1, 3):
        raise oefmt(space.w_TypeError,
                    "type.__init__() takes 1 or 3 arguments")


# ____________________________________________________________

def _check(space, w_type, msg="descriptor is for 'type'"):
    if not isinstance(w_type, W_TypeObject):
        raise OperationError(space.w_TypeError, space.newtext(msg))
    return w_type


def descr_get__name__(space, w_type):
    w_type = _check(space, w_type)
    return space.newtext(w_type.getname(space))

def descr_set__name__(space, w_type, w_value):
    w_type = _check(space, w_type)
    if not w_type.is_heaptype():
        raise oefmt(space.w_TypeError, "can't set %N.__name__", w_type)
    if not space.isinstance_w(w_value, space.w_text):
        raise oefmt(space.w_TypeError,
                    "can only assign string to %N.__name__, not '%T'",
                    w_type, w_value)
    name = space.text_w(w_value)
    if '\x00' in name:
        raise oefmt(space.w_ValueError, "type name must not contain null characters")
    pos = surrogate_in_utf8(name)
    if pos >= 0:
        raise oefmt(space.w_ValueError, "can't encode character in position "
                    "%d, surrogates not allowed", pos)
    w_type.name = name

def descr_get__qualname__(space, w_type):
    w_type = _check(space, w_type)
    return space.newtext(w_type.getqualname(space))

def descr_set__qualname__(space, w_type, w_value):
    w_type = _check(space, w_type)
    if not w_type.is_heaptype():
        raise oefmt(space.w_TypeError, "can't set %N.__qualname__", w_type)
    if not space.isinstance_w(w_value, space.w_text):
        raise oefmt(space.w_TypeError,
                    "can only assign string to %N.__name__, not '%T'",
                    w_type, w_value)
    w_type.qualname = space.utf8_w(w_value)

def descr_get__mro__(space, w_type):
    w_type = _check(space, w_type)
    if w_type.hasmro:
        return space.newtuple(w_type.mro_w)
    else:
        return space.w_None

def descr_mro(space, w_type):
    """Return a type's method resolution order."""
    w_type = _check(space, w_type, "expected type")
    return space.newlist(w_type.compute_default_mro())

def descr_get__bases__(space, w_type):
    w_type = _check(space, w_type)
    return space.newtuple(w_type.bases_w)

def mro_subclasses(space, w_type, temp):
    old_mro_w = w_type.mro_w
    compute_mro(w_type)
    temp.append((w_type, old_mro_w, w_type.mro_w))
    for w_sc in w_type.get_subclasses():
        assert isinstance(w_sc, W_TypeObject)
        mro_subclasses(space, w_sc, temp)

def descr_set__bases__(space, w_type, w_value):
    # this assumes all app-level type objects are W_TypeObject
    w_type = _check(space, w_type)
    if not w_type.is_heaptype():
        raise oefmt(space.w_TypeError, "can't set %N.__bases__", w_type)
    if not space.isinstance_w(w_value, space.w_tuple):
        raise oefmt(space.w_TypeError,
                    "can only assign tuple to %N.__bases__, not %T",
                    w_type, w_value)
    newbases_w = space.fixedview(w_value)
    if len(newbases_w) == 0:
        raise oefmt(space.w_TypeError,
                    "can only assign non-empty tuple to %N.__bases__, not ()",
                    w_type)

    for w_newbase in newbases_w:
        if isinstance(w_newbase, W_TypeObject):
            if w_type in w_newbase.compute_default_mro():
                raise oefmt(space.w_TypeError,
                            "a __bases__ item causes an inheritance cycle")

    w_oldbestbase = check_and_find_best_base(space, w_type.bases_w)
    w_newbestbase = check_and_find_best_base(space, newbases_w)
    oldlayout = w_oldbestbase.get_full_instance_layout()
    newlayout = w_newbestbase.get_full_instance_layout()

    if oldlayout != newlayout:
        raise oefmt(space.w_TypeError,
                    "__bases__ assignment: '%N' object layout differs from "
                    "'%N'", w_newbestbase, w_oldbestbase)

    # invalidate the version_tag of all the current subclasses
    w_type.mutated(None)

    # now we can go ahead and change 'w_type.bases_w'
    saved_bases_w = w_type.bases_w
    temp = []
    try:
        for w_oldbase in saved_bases_w:
            if isinstance(w_oldbase, W_TypeObject):
                w_oldbase.remove_subclass(w_type)
        w_type.bases_w = newbases_w
        for w_newbase in newbases_w:
            if isinstance(w_newbase, W_TypeObject):
                w_newbase.add_subclass(w_type)
        # try to recompute all MROs
        mro_subclasses(space, w_type, temp)
    except:
        for cls, old_mro, new_mro in temp:
            if cls.mro_w is new_mro:      # don't revert if it changed again
                cls.mro_w = old_mro
        if w_type.bases_w is newbases_w:  # don't revert if it changed again
            w_type.bases_w = saved_bases_w
        raise
    if (w_type.version_tag() is not None and
        not is_mro_purely_of_types(w_type.mro_w)):
        # Disable method cache if the hierarchy isn't pure.
        w_type._version_tag = None
        for w_subclass in w_type.get_subclasses():
            if isinstance(w_subclass, W_TypeObject):
                w_subclass._version_tag = None

def descr__base(space, w_type):
    w_type = _check(space, w_type)
    return find_best_base(w_type.bases_w)

def descr__doc(space, w_type):
    if space.is_w(w_type, space.w_type):
        return space.newtext("""type(object) -> the object's type
type(name, bases, dict) -> a new type""")
    w_type = _check(space, w_type)
    if not w_type.is_heaptype():
        return w_type.w_doc
    w_result = w_type.getdictvalue(space, '__doc__')
    if w_result is None:
        return space.w_None
    else:
        return space.get(w_result, space.w_None, w_type)

def descr_set__doc(space, w_type, w_value):
    w_type = _check(space, w_type)
    if not w_type.is_heaptype():
        raise oefmt(space.w_TypeError, "can't set %N.__doc__", w_type)
    w_type.setdictvalue(space, '__doc__', w_value)

def type_get_txtsig(space, w_type):
    w_type = _check(space, w_type)
    if w_type.text_signature is None:
        return space.w_None
    return space.newtext(w_type.text_signature)

def descr__dir(space, w_type):
    from pypy.objspace.std.util import _classdir
    return space.call_function(space.w_list, _classdir(space, w_type))

def descr__flags(space, w_type):
    from copy_reg import _HEAPTYPE
    _CPYTYPE = 1 # used for non-heap types defined in C
    _ABSTRACT = 1 << 20
    #
    w_type = _check(space, w_type)
    flags = 0
    if w_type.flag_heaptype:
        flags |= _HEAPTYPE
    if w_type.flag_cpytype:
        flags |= _CPYTYPE
    if w_type.flag_abstract:
        flags |= _ABSTRACT
    return space.newint(flags)

def descr_get__module(space, w_type):
    w_type = _check(space, w_type)
    return w_type.get_module()

def descr_set__module(space, w_type, w_value):
    w_type = _check(space, w_type)
    w_type.setdictvalue(space, '__module__', w_value)

def descr_get___abstractmethods__(space, w_type):
    w_type = _check(space, w_type)
    # type itself has an __abstractmethods__ descriptor (this). Don't return it
    if not space.is_w(w_type, space.w_type):
        w_result = w_type.getdictvalue(space, "__abstractmethods__")
        if w_result is not None:
            return w_result
    raise oefmt(space.w_AttributeError, "__abstractmethods__")

def descr_set___abstractmethods__(space, w_type, w_new):
    w_type = _check(space, w_type)
    w_type.setdictvalue(space, "__abstractmethods__", w_new)
    w_type.set_abstract(space.is_true(w_new))

def descr_del___abstractmethods__(space, w_type):
    w_type = _check(space, w_type)
    if not w_type.deldictvalue(space, "__abstractmethods__"):
        raise oefmt(space.w_AttributeError, "__abstractmethods__")
    w_type.set_abstract(False)

def descr___subclasses__(space, w_type):
    """Return the list of immediate subclasses."""
    w_type = _check(space, w_type)
    return space.newlist(w_type.get_subclasses())

def descr___prepare__(space, __args__):
    return space.newdict(module=True)

# ____________________________________________________________

@gateway.unwrap_spec(w_obj=W_TypeObject)
def type_issubtype(w_obj, space, w_sub):
    return space.newbool(
        abstractinst.p_recursive_issubclass_w(space, w_sub, w_obj))

@gateway.unwrap_spec(w_obj=W_TypeObject)
def type_isinstance(w_obj, space, w_inst):
    return space.newbool(
        abstractinst.p_recursive_isinstance_type_w(space, w_inst, w_obj))

def type_get_dict(space, w_cls):
    w_cls = _check(space, w_cls)
    from pypy.objspace.std.dictproxyobject import W_DictProxyObject
    w_dict = w_cls.getdict(space)
    if w_dict is None:
        return space.w_None
    return W_DictProxyObject(w_dict)

W_TypeObject.typedef = TypeDef("type",
    __new__ = gateway.interp2app(descr__new__),
    __init__ = gateway.interp2app(descr__init__),
    __name__ = GetSetProperty(descr_get__name__, descr_set__name__),
    __qualname__ = GetSetProperty(descr_get__qualname__, descr_set__qualname__),
    __bases__ = GetSetProperty(descr_get__bases__, descr_set__bases__),
    __base__ = GetSetProperty(descr__base),
    __mro__ = GetSetProperty(descr_get__mro__),
    __dict__=GetSetProperty(type_get_dict),
    __doc__ = GetSetProperty(descr__doc, descr_set__doc, cls=W_TypeObject, name='__doc__'),
    __text_signature__=GetSetProperty(type_get_txtsig),
    __dir__ = gateway.interp2app(descr__dir),
    mro = gateway.interp2app(descr_mro),
    __flags__ = GetSetProperty(descr__flags),
    __module__ = GetSetProperty(descr_get__module, descr_set__module),
    __abstractmethods__ = GetSetProperty(descr_get___abstractmethods__,
                                         descr_set___abstractmethods__,
                                         descr_del___abstractmethods__),
    __subclasses__ = gateway.interp2app(descr___subclasses__),
    __weakref__ = weakref_descr,
    __instancecheck__ = gateway.interp2app(type_isinstance),
    __subclasscheck__ = gateway.interp2app(type_issubtype),

    __call__ = gateway.interp2app(W_TypeObject.descr_call),
    __repr__ = gateway.interp2app(W_TypeObject.descr_repr),
    __getattribute__ = gateway.interp2app(W_TypeObject.descr_getattribute),
    __ne__ = gateway.interp2app(W_TypeObject.descr_ne),
    __prepare__ = gateway.interp2app(descr___prepare__, as_classmethod=True),
)


# ____________________________________________________________
# Initialization of type objects

def find_best_base(bases_w):
    """The best base is one of the bases in the given list: the one
       whose layout a new type should use as a starting point.
    """
    w_bestbase = None
    for w_candidate in bases_w:
        if not isinstance(w_candidate, W_TypeObject):
            continue
        if not w_candidate.hasmro:
            raise oefmt(w_candidate.space.w_TypeError,
                        "Cannot extend an incomplete type '%N'", w_candidate)
        if w_bestbase is None:
            w_bestbase = w_candidate   # for now
            continue
        cand_layout = w_candidate.layout
        best_layout = w_bestbase.layout
        if (cand_layout is not best_layout and
            cand_layout.issublayout(best_layout)):
            w_bestbase = w_candidate
    return w_bestbase

def check_and_find_best_base(space, bases_w):
    """The best base is one of the bases in the given list: the one
       whose layout a new type should use as a starting point.
       This version checks that bases_w is an acceptable tuple of bases.
    """
    w_bestbase = find_best_base(bases_w)
    if w_bestbase is None:
        raise oefmt(space.w_TypeError,
                    "a new-style class can't have only classic bases")
    if not w_bestbase.layout.typedef.acceptable_as_base_class:
        raise oefmt(space.w_TypeError,
                    "type '%s' is not an acceptable base type", w_bestbase.name)

    # check that all other bases' layouts are "super-layouts" of the
    # bestbase's layout
    best_layout = w_bestbase.layout
    for w_base in bases_w:
        if isinstance(w_base, W_TypeObject):
            layout = w_base.layout
            if not best_layout.issublayout(layout):
                raise oefmt(space.w_TypeError,
                            "instance layout conflicts in multiple inheritance")
    return w_bestbase

def copy_flags_from_bases(w_self, w_bestbase):
    hasoldstylebase = False
    for w_base in w_self.bases_w:
        if not isinstance(w_base, W_TypeObject):
            hasoldstylebase = True
            continue
        w_self.hasdict = w_self.hasdict or w_base.hasdict
        w_self.hasuserdel = w_self.hasuserdel or w_base.hasuserdel
        w_self.weakrefable = w_self.weakrefable or w_base.weakrefable
    return hasoldstylebase

def slot_w(space, w_name):
    from pypy.objspace.std.unicodeobject import _isidentifier
    if not space.isinstance_w(w_name, space.w_text):
        raise oefmt(space.w_TypeError,
            "__slots__ items must be strings, not '%T'", w_name)
    s = space.utf8_w(w_name)
    if not _isidentifier(s):
        raise oefmt(space.w_TypeError, "__slots__ must be identifiers")
    return s

def create_all_slots(w_self, hasoldstylebase, w_bestbase, force_new_layout):
    from pypy.interpreter.miscutils import string_sort

    base_layout = w_bestbase.layout
    index_next_extra_slot = base_layout.nslots
    space = w_self.space
    dict_w = w_self.dict_w
    newslotnames = []
    if '__slots__' not in dict_w:
        wantdict = True
        wantweakref = True
    else:
        wantdict = False
        wantweakref = False
        w_slots = dict_w['__slots__']
        if space.isinstance_w(w_slots, space.w_text):
            slot_names_w = [w_slots]
        else:
            slot_names_w = space.unpackiterable(w_slots)
        for w_slot_name in slot_names_w:
            slot_name = slot_w(space, w_slot_name)
            if slot_name == '__dict__':
                if wantdict or w_bestbase.hasdict:
                    raise oefmt(space.w_TypeError,
                                "__dict__ slot disallowed: we already got one")
                wantdict = True
            elif slot_name == '__weakref__':
                if wantweakref or w_bestbase.weakrefable:
                    raise oefmt(space.w_TypeError,
                                "__weakref__ slot disallowed: we already got one")
                wantweakref = True
            else:
                newslotnames.append(slot_name)
        # Sort the list of names collected so far
        string_sort(newslotnames)
        # Try to create all slots in order.  The creation of some of
        # them might silently fail; then we delete the name from the
        # list.  At the end, 'index_next_extra_slot' has been advanced
        # by the final length of 'newslotnames'.
        i = 0
        while i < len(newslotnames):
            if create_slot(w_self, newslotnames[i], index_next_extra_slot):
                index_next_extra_slot += 1
                i += 1
            else:
                del newslotnames[i]
    #
    wantdict = wantdict or hasoldstylebase
    if wantdict:
        create_dict_slot(w_self)
    if wantweakref:
        create_weakref_slot(w_self)
    if '__del__' in dict_w:
        w_self.hasuserdel = True
    #
    assert index_next_extra_slot == base_layout.nslots + len(newslotnames)
    if index_next_extra_slot == base_layout.nslots and not force_new_layout:
        return base_layout
    else:
        return Layout(base_layout.typedef, index_next_extra_slot,
                      newslotnames, base_layout=base_layout)

def create_slot(w_self, slot_name, index_next_extra_slot):
    space = w_self.space
    # create member
    slot_name = mangle(slot_name, w_self.name)
    if slot_name not in w_self.dict_w:
        # Force interning of slot names.
        slot_name = space.text_w(space.new_interned_str(slot_name))
        # in cpython it is ignored less, but we probably don't care
        member = Member(index_next_extra_slot, slot_name, w_self)
        w_self.dict_w[slot_name] = member
        return True
    else:
        w_prev = w_self.dict_w[slot_name]
        if isinstance(w_prev, Member) and w_prev.w_cls is w_self:
            return False   # special case: duplicate __slots__ entry, ignored
                           # (e.g. occurs in datetime.py, fwiw)
        raise oefmt(space.w_ValueError,
                    "'%8' in __slots__ conflicts with class variable",
                    slot_name)

def create_dict_slot(w_self):
    if not w_self.hasdict:
        descr = dict_descr.copy_for_type(w_self)
        w_self.dict_w.setdefault('__dict__', descr)
        w_self.hasdict = True

def create_weakref_slot(w_self):
    if not w_self.weakrefable:
        descr = weakref_descr.copy_for_type(w_self)
        w_self.dict_w.setdefault('__weakref__', descr)
        w_self.weakrefable = True

def setup_user_defined_type(w_self, force_new_layout):
    if len(w_self.bases_w) == 0:
        w_self.bases_w = [w_self.space.w_object]
    w_bestbase = check_and_find_best_base(w_self.space, w_self.bases_w)
    for w_base in w_self.bases_w:
        if not isinstance(w_base, W_TypeObject):
            continue
        w_self.flag_cpytype |= w_base.flag_cpytype
        if w_self.flag_map_or_seq == '?':
            w_self.flag_map_or_seq = w_base.flag_map_or_seq

    hasoldstylebase = copy_flags_from_bases(w_self, w_bestbase)
    layout = create_all_slots(w_self, hasoldstylebase, w_bestbase,
                              force_new_layout)

    ensure_common_attributes(w_self)
    return layout

def setup_builtin_type(w_self, instancetypedef):
    w_self.hasdict = instancetypedef.hasdict
    w_self.weakrefable = instancetypedef.weakrefable
    if isinstance(instancetypedef.doc, W_Root):
        w_doc = instancetypedef.doc
    else:
        w_doc = w_self.space.newtext_or_none(instancetypedef.doc)
    w_self.w_doc = w_doc
    w_self.text_signature = instancetypedef.text_signature
    ensure_common_attributes(w_self)
    #
    # usually 'instancetypedef' is new, i.e. not seen in any base,
    # but not always (see Exception class)
    w_bestbase = find_best_base(w_self.bases_w)
    if w_bestbase is None:
        parent_layout = None
    else:
        parent_layout = w_bestbase.layout
        if parent_layout.typedef is instancetypedef:
            return parent_layout
    return Layout(instancetypedef, 0, base_layout=parent_layout)

def ensure_common_attributes(w_self):
    ensure_static_new(w_self)
    w_self.dict_w.setdefault('__doc__', w_self.w_doc)
    if w_self.is_heaptype():
        ensure_module_attr(w_self)
    ensure_hash(w_self)
    w_self.mro_w = []      # temporarily
    w_self.hasmro = False
    compute_mro(w_self)
    ensure_classmethods(w_self, ['__init_subclass__', '__class_getitem__'])

def ensure_static_new(w_self):
    # special-case __new__, as in CPython:
    # if it is a Function, turn it into a static method
    if '__new__' in w_self.dict_w:
        w_new = w_self.dict_w['__new__']
        if isinstance(w_new, Function):
            w_self.dict_w['__new__'] = StaticMethod(w_new)

def ensure_classmethods(w_self, method_names):
    for method_name in method_names:
        if method_name in w_self.dict_w:
            w_method = w_self.dict_w[method_name]
            if isinstance(w_method, Function):
                w_self.dict_w[method_name] = ClassMethod(w_method)

def ensure_module_attr(w_self):
    # initialize __module__ in the dict (user-defined types only)
    if '__module__' not in w_self.dict_w:
        space = w_self.space
        caller = space.getexecutioncontext().gettopframe_nohidden()
        if caller is not None:
            w_globals = caller.get_w_globals()
            w_name = space.finditem(w_globals, space.newtext('__name__'))
            if w_name is not None:
                w_self.dict_w['__module__'] = w_name

def ensure_hash(w_self):
    # if we define __eq__ but not __hash__, we force __hash__ to be None to
    # prevent inheriting it
    if '__eq__' in w_self.dict_w and '__hash__' not in w_self.dict_w:
        w_self.dict_w['__hash__'] = w_self.space.w_None

def compute_mro(w_self):
    if w_self.is_heaptype():
        space = w_self.space
        w_metaclass = space.type(w_self)
        w_where, w_mro_func = space.lookup_in_type_where(w_metaclass, 'mro')
        if w_mro_func is not None and not space.is_w(w_where, space.w_type):
            w_mro_meth = space.get(w_mro_func, w_self)
            w_mro = space.call_function(w_mro_meth)
            mro_w = space.fixedview(w_mro)
            w_self.mro_w = validate_custom_mro(space, mro_w)
            w_self.hasmro = True
            return    # done
    w_self.mro_w = w_self.compute_default_mro()[:]
    w_self.hasmro = True

def validate_custom_mro(space, mro_w):
    # do some checking here.  Note that unlike CPython, strange MROs
    # cannot really segfault PyPy.  At a minimum, we check that all
    # the elements in the mro seem to be (old- or new-style) classes.
    for w_class in mro_w:
        if not space.abstract_isclass_w(w_class):
            raise oefmt(space.w_TypeError, "mro() returned a non-class")
    return mro_w

def is_mro_purely_of_types(mro_w):
    for w_class in mro_w:
        if not isinstance(w_class, W_TypeObject):
            return False
    return True

# ____________________________________________________________

def _issubtype(w_sub, w_type):
    if w_sub.hasmro:
        return w_type in w_sub.mro_w
    else:
        return _issubtype_slow_and_wrong(w_sub, w_type)

def _issubtype_slow_and_wrong(w_sub, w_type):
    # This is only called in strange cases where w_sub is partially initialised,
    # like from a custom MetaCls.mro(). Note that it's broken wrt. multiple
    # inheritance, but that's what CPython does.
    w_cls = w_sub
    while w_cls:
        if w_cls is w_type:
            return True
        w_cls = find_best_base(w_cls.bases_w)
    return False

@elidable_promote()
def _pure_issubtype(w_sub, w_type, version_tag1, version_tag2):
    return _issubtype(w_sub, w_type)


# ____________________________________________________________


abstract_mro = gateway.applevel("""
    def abstract_mro(klass):
        # abstract/classic mro
        mro = []
        stack = [klass]
        while stack:
            klass = stack.pop()
            if klass not in mro:
                mro.append(klass)
                if not isinstance(klass.__bases__, tuple):
                    raise TypeError('__bases__ must be a tuple')
                stack += klass.__bases__[::-1]
        return mro
""", filename=__file__).interphook("abstract_mro")

def get_mro(space, klass):
    if isinstance(klass, W_TypeObject):
        return list(klass.mro_w)
    else:
        return space.unpackiterable(abstract_mro(space, klass))


def compute_C3_mro(space, cls):
    order = []
    orderlists = [get_mro(space, base) for base in cls.bases_w]
    orderlists.append([cls] + cls.bases_w)
    while orderlists:
        for candidatelist in orderlists:
            candidate = candidatelist[0]
            if mro_blockinglist(candidate, orderlists) is None:
                break    # good candidate
        else:
            return mro_error(space, orderlists)  # no candidate found
        assert candidate not in order
        order.append(candidate)
        for i in range(len(orderlists) - 1, -1, -1):
            if orderlists[i][0] is candidate:
                del orderlists[i][0]
                if len(orderlists[i]) == 0:
                    del orderlists[i]
    return order


def mro_blockinglist(candidate, orderlists):
    for lst in orderlists:
        if candidate in lst[1:]:
            return lst
    return None # good candidate

def mro_error(space, orderlists):
    cycle = []
    candidate = orderlists[-1][0]
    if candidate in orderlists[-1][1:]:
        # explicit error message for this specific case
        raise oefmt(space.w_TypeError, "duplicate base class '%N'", candidate)
    while candidate not in cycle:
        cycle.append(candidate)
        nextblockinglist = mro_blockinglist(candidate, orderlists)
        candidate = nextblockinglist[0]
    del cycle[:cycle.index(candidate)]
    cycle.append(candidate)
    cycle.reverse()
    names = [cls.getname(space) for cls in cycle]
    # Can't use oefmt() here, since names is a list of unicodes
    raise OperationError(space.w_TypeError, space.newtext(
        "cycle among base classes: " + ' < '.join(names)))


class TypeCache(SpaceCache):
    @not_rpython
    def build(self, typedef):
        "initialization-time only."
        from pypy.objspace.std.objectobject import W_ObjectObject
        from pypy.interpreter.typedef import GetSetProperty
        from rpython.rlib.objectmodel import instantiate

        space = self.space
        rawdict = typedef.rawdict
        lazyloaders = {}
        w_type = instantiate(W_TypeObject)

        # compute the bases
        if typedef is W_ObjectObject.typedef:
            bases_w = []
        else:
            bases = typedef.bases or [W_ObjectObject.typedef]
            bases_w = [space.gettypeobject(base) for base in bases]

        # wrap everything
        dict_w = {}
        for descrname, descrvalue in rawdict.items():
            # special case for GetSetProperties' __objclass__:
            if isinstance(descrvalue, GetSetProperty):
                descrvalue = descrvalue.copy_for_type(w_type)
            dict_w[descrname] = space.wrap(descrvalue)

        if typedef.applevel_subclasses_base is not None:
            overridetypedef = typedef.applevel_subclasses_base.typedef
        else:
            overridetypedef = typedef
        w_type.__init__(space, typedef.name, bases_w, dict_w,
                              overridetypedef=overridetypedef,
                              is_heaptype=overridetypedef.heaptype)
        if typedef is not overridetypedef:
            w_type.w_doc = space.newtext_or_none(typedef.doc)
        else:
            # Set the __qualname__ of member functions
            for name in rawdict:
                w_obj = dict_w[name]
                if isinstance(w_obj, ClassMethod):
                    w_obj = w_obj.w_function
                if isinstance(w_obj, StaticMethod):
                    w_obj = w_obj.w_function
                if isinstance(w_obj, FunctionWithFixedCode):
                    qualname = (w_type.getqualname(space).encode('utf-8')
                                + '.' + name)
                    w_obj.set_qualname(qualname)

        if hasattr(typedef, 'flag_sequence_bug_compat'):
            w_type.flag_sequence_bug_compat = typedef.flag_sequence_bug_compat
        w_type.lazyloaders = lazyloaders
        return w_type

    def ready(self, w_type):
        w_type.ready()

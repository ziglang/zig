import py
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import oefmt
from pypy.interpreter.gateway import interp2app, ObjSpace
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from pypy.interpreter.executioncontext import AsyncAction, report_error
from pypy.objspace.std.util import generic_alias_class_getitem
from rpython.rlib import jit, rgc
from rpython.rlib.rshrinklist import AbstractShrinkList
from rpython.rlib.objectmodel import specialize
from rpython.rlib.rweakref import dead_ref
import weakref


class WRefShrinkList(AbstractShrinkList):
    def must_keep(self, wref):
        return wref() is not None


class WeakrefLifeline(W_Root):
    typedef = None

    cached_weakref  = None
    cached_proxy    = None
    other_refs_weak = None
    has_callbacks   = False

    def __init__(self, space):
        self.space = space

    def append_wref_to(self, w_ref):
        if self.other_refs_weak is None:
            self.other_refs_weak = WRefShrinkList()
        self.other_refs_weak.append(weakref.ref(w_ref))

    @specialize.arg(1)
    def traverse(self, callback, arg=None):
        if self.cached_weakref is not None:
            arg = callback(self, self.cached_weakref, arg)
        if self.cached_proxy is not None:
            arg = callback(self, self.cached_proxy, arg)
        if self.other_refs_weak is not None:
            for ref_w_ref in self.other_refs_weak.items():
                arg = callback(self, ref_w_ref, arg)
        return arg

    def _clear_wref(self, wref, _):
        w_ref = wref()
        if w_ref is not None:
            w_ref.clear()

    def clear_all_weakrefs(self):
        """Clear all weakrefs.  This is called when an app-level object has
        a __del__, just before the app-level __del__ method is called.
        """
        self.traverse(WeakrefLifeline._clear_wref)
        # Note that for no particular reason other than convenience,
        # weakref callbacks are not invoked eagerly here.  They are
        # invoked by self.__del__() anyway.

    @jit.dont_look_inside
    def get_or_make_weakref(self, w_subtype, w_obj):
        space = self.space
        w_weakreftype = space.gettypeobject(W_Weakref.typedef)
        #
        if space.is_w(w_weakreftype, w_subtype):
            if self.cached_weakref is not None:
                w_cached = self.cached_weakref()
                if w_cached is not None:
                    return w_cached
            w_ref = W_Weakref(space, w_obj, None)
            self.cached_weakref = weakref.ref(w_ref)
        else:
            # subclass: cannot cache
            w_ref = space.allocate_instance(W_Weakref, w_subtype)
            W_Weakref.__init__(w_ref, space, w_obj, None)
            self.append_wref_to(w_ref)
        return w_ref

    @jit.dont_look_inside
    def get_or_make_proxy(self, w_obj):
        space = self.space
        if self.cached_proxy is not None:
            w_cached = self.cached_proxy()
            if w_cached is not None:
                return w_cached
        if space.is_true(space.callable(w_obj)):
            w_proxy = W_CallableProxy(space, w_obj, None)
        else:
            w_proxy = W_Proxy(space, w_obj, None)
        self.cached_proxy = weakref.ref(w_proxy)
        return w_proxy

    def get_any_weakref(self, space):
        if self.cached_weakref is not None:
            w_ref = self.cached_weakref()
            if w_ref is not None:
                return w_ref
        if self.other_refs_weak is not None:
            w_weakreftype = space.gettypeobject(W_Weakref.typedef)
            for wref in self.other_refs_weak.items():
                w_ref = wref()
                if (w_ref is not None and space.isinstance_w(w_ref, w_weakreftype)):
                    return w_ref
        return space.w_None

    def enable_callbacks(self):
        if not self.has_callbacks:
            self.space.finalizer_queue.register_finalizer(self)
            self.has_callbacks = True

    @jit.dont_look_inside
    def make_weakref_with_callback(self, w_subtype, w_obj, w_callable):
        space = self.space
        w_ref = space.allocate_instance(W_Weakref, w_subtype)
        W_Weakref.__init__(w_ref, space, w_obj, w_callable)
        self.append_wref_to(w_ref)
        self.enable_callbacks()
        return w_ref

    @jit.dont_look_inside
    def make_proxy_with_callback(self, w_obj, w_callable):
        space = self.space
        if space.is_true(space.callable(w_obj)):
            w_proxy = W_CallableProxy(space, w_obj, w_callable)
        else:
            w_proxy = W_Proxy(space, w_obj, w_callable)
        self.append_wref_to(w_proxy)
        self.enable_callbacks()
        return w_proxy

    def _finalize_(self):
        """This is called at the end, if enable_callbacks() was invoked.
        It activates the callbacks.
        """
        if self.other_refs_weak is None:
            return
        #
        # If this is set, then we're in the 'gc.disable()' mode.  In that
        # case, don't invoke the callbacks now.
        if self.space.user_del_action.gc_disabled(self):
            return
        #
        items = self.other_refs_weak.items()
        self.other_refs_weak = None
        for i in range(len(items)-1, -1, -1):
            w_ref = items[i]()
            if w_ref is not None and w_ref.w_callable is not None:
                try:
                    w_ref.activate_callback()
                except Exception as e:
                    report_error(self.space, e,
                                 "weakref callback ", w_ref.w_callable)
                w_ref.w_callable = None


# ____________________________________________________________


class W_WeakrefBase(W_Root):
    exact_class_applevel_name = 'weakref-or-proxy'

    def __init__(self, space, w_obj, w_callable):
        assert w_callable is not space.w_None    # should be really None
        self.space = space
        assert w_obj is not None
        self.w_obj_weak = weakref.ref(w_obj)
        self.w_callable = w_callable

    @jit.dont_look_inside
    def dereference(self):
        w_obj = self.w_obj_weak()
        return w_obj

    def clear(self):
        self.w_obj_weak = dead_ref

    def activate_callback(self):
        self.space.call_function(self.w_callable, self)

    def descr__repr__(self, space):
        w_obj = self.dereference()
        if w_obj is None:
            state = '; dead'
        else:
            typename = space.type(w_obj).getname(space)
            objname = w_obj.getname(space)
            if objname and objname != '?':
                state = "; to '%s' (%s)" % (typename, objname)
            else:
                state = "; to '%s'" % (typename,)
        return self.getrepr(space, self.typedef.name, state)


class W_Weakref(W_WeakrefBase):
    def __init__(self, space, w_obj, w_callable):
        W_WeakrefBase.__init__(self, space, w_obj, w_callable)
        self.w_hash = None

    def _cleanup_(self):
        # When a prebuilt weakref is frozen inside a translation, if
        # this weakref has got an already-cached w_hash, then throw it
        # away.  That's because the hash value will change after
        # translation.  It will be recomputed the first time we ask for
        # it.  Note that such a frozen weakref, if not dead, will point
        # to a frozen object, so it will never die.
        self.w_hash = None

    def descr__init__weakref(self, space, w_obj, w_callable=None):
        pass

    def descr_hash(self):
        if self.w_hash is not None:
            return self.w_hash
        w_obj = self.dereference()
        if w_obj is None:
            raise oefmt(self.space.w_TypeError, "weak object has gone away")
        self.w_hash = self.space.hash(w_obj)
        return self.w_hash

    def descr_call(self):
        w_obj = self.dereference()
        if w_obj is None:
            return self.space.w_None
        return w_obj

    def compare(self, space, w_ref2, invert):
        if not isinstance(w_ref2, W_Weakref):
            return space.w_NotImplemented
        ref1 = self
        ref2 = w_ref2
        w_obj1 = ref1.dereference()
        w_obj2 = ref2.dereference()
        if w_obj1 is None or w_obj2 is None:
            w_res = space.is_(ref1, ref2)
        else:
            w_res = space.eq(w_obj1, w_obj2)
        if invert:
            w_res = space.not_(w_res)
        return w_res

    def descr__eq__(self, space, w_ref2):
        return self.compare(space, w_ref2, invert=False)

    def descr__ne__(self, space, w_ref2):
        return self.compare(space, w_ref2, invert=True)

    def descr_callback(self, space):
        return self.w_callable

def getlifeline(space, w_obj):
    lifeline = w_obj.getweakref()
    if lifeline is None:
        lifeline = WeakrefLifeline(space)
        w_obj.setweakref(space, lifeline)
    return lifeline


def descr__new__weakref(space, w_subtype, w_obj, w_callable=None,
                        __args__=None):
    if __args__.arguments_w:
        raise oefmt(space.w_TypeError, "__new__ expected at most 2 arguments")
    lifeline = getlifeline(space, w_obj)
    if space.is_none(w_callable):
        return lifeline.get_or_make_weakref(w_subtype, w_obj)
    else:
        return lifeline.make_weakref_with_callback(w_subtype, w_obj, w_callable)

W_Weakref.typedef = TypeDef("weakref",
    __doc__ = """A weak reference to an object 'obj'.  A 'callback' can be given,
which is called with 'obj' as an argument when it is about to be finalized.""",
    __new__ = interp2app(descr__new__weakref),
    __init__ = interp2app(W_Weakref.descr__init__weakref),
    __eq__ = interp2app(W_Weakref.descr__eq__),
    __ne__ = interp2app(W_Weakref.descr__ne__),
    __hash__ = interp2app(W_Weakref.descr_hash),
    __call__ = interp2app(W_Weakref.descr_call),
    __repr__ = interp2app(W_WeakrefBase.descr__repr__),
    __callback__ = GetSetProperty(W_Weakref.descr_callback),
    __class_getitem__ = interp2app(
        generic_alias_class_getitem, as_classmethod=True),
)


def _weakref_count(lifeline, wref, count):
    if wref() is not None:
        count += 1
    return count

def getweakrefcount(space, w_obj):
    """Return the number of weak references to 'obj'."""
    lifeline = w_obj.getweakref()
    if lifeline is None:
        return space.newint(0)
    else:
        result = lifeline.traverse(_weakref_count, 0)
        return space.newint(result)

def _get_weakrefs(lifeline, wref, result):
    w_ref = wref()
    if w_ref is not None:
        result.append(w_ref)
    return result

def getweakrefs(space, w_obj):
    """Return a list of all weak reference objects that point to 'obj'."""
    result = []
    lifeline = w_obj.getweakref()
    if lifeline is not None:
        lifeline.traverse(_get_weakrefs, result)
    return space.newlist(result)

#_________________________________________________________________
# Proxy

class W_Proxy(W_WeakrefBase):
    def descr__hash__(self, space):
        raise oefmt(space.w_TypeError, "unhashable type")

class W_CallableProxy(W_Proxy):
    def descr__call__(self, space, __args__):
        w_obj = force(space, self)
        return space.call_args(w_obj, __args__)


def proxy(space, w_obj, w_callable=None):
    """Create a proxy object that weakly references 'obj'.
'callback', if given, is called with the proxy as an argument when 'obj'
is about to be finalized."""
    lifeline = getlifeline(space, w_obj)
    if space.is_none(w_callable):
        return lifeline.get_or_make_proxy(w_obj)
    else:
        return lifeline.make_proxy_with_callback(w_obj, w_callable)

def descr__new__proxy(space, w_subtype, w_obj, w_callable=None):
    raise oefmt(space.w_TypeError, "cannot create 'weakproxy' instances")

def descr__new__callableproxy(space, w_subtype, w_obj, w_callable=None):
    raise oefmt(space.w_TypeError,
                "cannot create 'weakcallableproxy' instances")


def force(space, proxy):
    if not isinstance(proxy, W_Proxy):
        return proxy
    w_obj = proxy.dereference()
    if w_obj is None:
        raise oefmt(space.w_ReferenceError,
                    "weakly referenced object no longer exists")
    return w_obj

proxy_typedef_dict = {}
callable_proxy_typedef_dict = {}
special_ops = {'repr': True, 'hash': True}

for opname, _, arity, special_methods in ObjSpace.MethodTable:
    if opname in special_ops or not special_methods:
        continue
    nonspaceargs =  ", ".join(["w_obj%s" % i for i in range(arity)])
    code = "def func(space, %s):\n    '''%s'''\n" % (nonspaceargs, opname)
    assert arity >= len(special_methods)
    forcing_count = len(special_methods)
    if opname.startswith('inplace_'):
        assert arity == 2
        forcing_count = arity
    for i in range(forcing_count):
        code += "    w_obj%s = force(space, w_obj%s)\n" % (i, i)
    code += "    return space.%s(%s)" % (opname, nonspaceargs)
    exec py.code.Source(code).compile()

    func.func_name = opname
    if len(special_methods) == 2 and special_methods[1].startswith("__r"):
        proxy_typedef_dict[special_methods[0]] = interp2app(func)
        callable_proxy_typedef_dict[special_methods[0]] = interp2app(func)

        # HACK: need to call the space method with arguments in the reverse
        # order!
        code = code.replace("(w_obj0, w_obj1)", "(w_obj1, w_obj0)")
        code = code.replace("func", "rfunc")

        exec py.code.Source(code).compile()
        rfunc.func_name = special_methods[1][2:-2]

        proxy_typedef_dict[special_methods[1]] = interp2app(rfunc)
        callable_proxy_typedef_dict[special_methods[1]] = interp2app(rfunc)
    elif opname in ["lt", "le", "gt", "ge", "eq", "ne"]:
        proxy_typedef_dict[special_methods[0]] = interp2app(func)
    else:
        for special_method in special_methods:
            proxy_typedef_dict[special_method] = interp2app(func)
            callable_proxy_typedef_dict[special_method] = interp2app(func)

# __bytes__ is not yet a space operation
def proxy_bytes(space, w_obj):
    w_obj = force(space, w_obj)
    return space.call_method(w_obj, '__bytes__')
proxy_typedef_dict['__bytes__'] = interp2app(proxy_bytes)
callable_proxy_typedef_dict['__bytes__'] = interp2app(proxy_bytes)

# neither is __reversed__
def proxy_reversed(space, w_obj):
    w_obj = force(space, w_obj)
    return space.call_method(w_obj, '__reversed__')
proxy_typedef_dict['__reversed__'] = interp2app(proxy_reversed)
callable_proxy_typedef_dict['__reversed__'] = interp2app(proxy_reversed)

W_Proxy.typedef = TypeDef("weakproxy",
    __new__ = interp2app(descr__new__proxy),
    __hash__ = interp2app(W_Proxy.descr__hash__),
    __repr__ = interp2app(W_WeakrefBase.descr__repr__),
    **proxy_typedef_dict)
W_Proxy.typedef.acceptable_as_base_class = False

W_CallableProxy.typedef = TypeDef("weakcallableproxy",
    __new__ = interp2app(descr__new__callableproxy),
    __hash__ = interp2app(W_Proxy.descr__hash__),
    __repr__ = interp2app(W_WeakrefBase.descr__repr__),
    __call__ = interp2app(W_CallableProxy.descr__call__),
    **callable_proxy_typedef_dict)
W_CallableProxy.typedef.acceptable_as_base_class = False

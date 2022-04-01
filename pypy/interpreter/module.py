"""
Module objects.
"""

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from rpython.rlib.objectmodel import we_are_translated, not_rpython


class Module(W_Root):
    """A module."""

    _immutable_fields_ = ["w_dict?", "w_userclass?"]

    _frozen = False
    w_userclass = None

    def __init__(self, space, w_name, w_dict=None):
        self.space = space
        if w_dict is None:
            w_dict = space.newdict(module=True)
        self.w_dict = w_dict
        self.w_name = w_name
        if w_name is not None:
            space.setitem(w_dict, space.new_interned_str('__name__'), w_name)
        self.startup_called = False

    def _cleanup_(self):
        """Called by the annotator on prebuilt Module instances.
        We don't have many such modules, but for the ones that
        show up, remove their __file__ rather than translate it
        statically inside the executable."""
        try:
            space = self.space
            space.delitem(self.w_dict, space.newtext('__file__'))
        except OperationError:
            pass

    @not_rpython
    def install(self):
        """installs this module into space.builtin_modules"""
        modulename = self.space.text0_w(self.w_name)
        if modulename in self.space.builtin_modules:
            raise ValueError(
                "duplicate interp-level module enabled for the "
                "app-level module %r" % (modulename,))
        self.space.builtin_modules[modulename] = self

    @not_rpython
    def setup_after_space_initialization(self):
        """to allow built-in modules to do some more setup
        after the space is fully initialized."""

    def init(self, space):
        """This is called each time the module is imported or reloaded
        """
        if not self.startup_called:
            if not we_are_translated():
                # this special case is to handle the case, during annotation,
                # of module A that gets frozen, then module B (e.g. during
                # a getdict()) runs some code that imports A
                if self._frozen:
                    return
            self.startup_called = True
            self.startup(space)

    def startup(self, space):
        """This is called at runtime on import to allow the module to
        do initialization when it is imported for the first time.
        """

    def shutdown(self, space):
        """This is called when the space is shut down, just after
        atexit functions, if the module has been imported.
        """

    def getdict(self, space):
        return self.w_dict

    def descr_module__new__(space, w_subtype, __args__):
        module = space.allocate_instance(Module, w_subtype)
        Module.__init__(module, space, None)
        return module

    def descr_module__init__(self, w_name, w_doc=None):
        space = self.space
        self.w_name = w_name
        if w_doc is None:
            w_doc = space.w_None
        w_dict = self.w_dict
        space.setitem(w_dict, space.new_interned_str('__name__'), w_name)
        space.setitem(w_dict, space.new_interned_str('__doc__'), w_doc)
        init_extra_module_attrs(space, self)

    def descr__reduce__(self, space):
        w_name = space.finditem(self.w_dict, space.newtext('__name__'))
        if (w_name is None or
            not space.isinstance_w(w_name, space.w_text)):
            # maybe raise exception here (XXX this path is untested)
            return space.w_None
        w_modules = space.sys.get('modules')
        if space.finditem(w_modules, w_name) is None:
            #not imported case
            from pypy.interpreter.mixedmodule import MixedModule
            w_mod    = space.getbuiltinmodule('_pickle_support')
            mod      = space.interp_w(MixedModule, w_mod)
            new_inst = mod.get('module_new')
            return space.newtuple([new_inst,
                                   space.newtuple([w_name,
                                                   self.getdict(space)]),
                                  ])
        #already imported case
        w_import = space.builtin.get('__import__')
        tup_return = [
            w_import,
            space.newtuple([
                w_name,
                space.w_None,
                space.w_None,
                space.newtuple([space.newtext('')])
            ])
        ]

        return space.newtuple(tup_return)

    def descr_module__repr__(self, space):
        w_importlib = space.getbuiltinmodule('_frozen_importlib')
        return space.call_method(w_importlib, "_module_repr", self)

    def descr_getattribute(self, space, w_attr):
        from pypy.objspace.descroperation import object_getattribute
        from pypy.module.imp.importing import is_spec_initializing
        try:
            return space.call_function(object_getattribute(space), self, w_attr)
        except OperationError as e:
            if not e.match(space, space.w_AttributeError):
                raise
            w_dict = self.w_dict
            w_getattr = space.finditem(w_dict, space.newtext('__getattr__'))
            if w_getattr is not None:
                return space.call_function(w_getattr, w_attr)
            w_name = space.finditem(self.w_dict, space.newtext('__name__'))
            w_spec = space.finditem(self.w_dict, space.newtext('__spec__'))
            if w_name is None:
                raise oefmt(space.w_AttributeError,
                    "module has no attribute %R", w_attr)
            elif w_spec is not None and is_spec_initializing(space, w_spec):
                raise oefmt(space.w_AttributeError,
                    "partially initialized "
                    "module %R has no attribute %R "
                    "(most likely due to a circular import)",
                    w_name, w_attr
                )
            else:
                raise oefmt(space.w_AttributeError,
                    "module %R has no attribute %R", w_name, w_attr)

    def descr_module__dir__(self, space):
        w_dict = space.getattr(self, space.newtext('__dict__'))
        if not space.isinstance_w(w_dict, space.w_dict):
            raise oefmt(space.w_TypeError, "%N.__dict__ is not a dictionary",
                        self)
        w_dir = space.finditem(w_dict, space.newtext('__dir__'))
        if w_dir is not None:
            return space.call_function(w_dir)
        return space.call_function(space.w_list, w_dict)

    # These three methods are needed to implement '__class__' assignment
    # between a module and a subclass of module.  They give every module
    # the ability to have its '__class__' set, manually.  Note that if
    # you instantiate a subclass of ModuleType in the first place, then
    # you get an RPython instance of a subclass of Module created in the
    # normal way by typedef.py.  That instance has got its own
    # getclass(), getslotvalue(), etc. but provided it has no __slots__,
    # it is compatible with ModuleType for '__class__' assignment.

    def getclass(self, space):
        if self.w_userclass is None:
            return W_Root.getclass(self, space)
        return self.w_userclass

    def setclass(self, space, w_cls):
        self.w_userclass = w_cls

    def user_setup(self, space, w_subtype):
        self.w_userclass = w_subtype


def init_extra_module_attrs(space, w_mod):
    w_dict = w_mod.getdict(space)
    if w_dict is None:
        return
    for extra in ['__package__', '__loader__', '__spec__']:
        w_attr = space.new_interned_str(extra)
        space.call_method(w_dict, 'setdefault', w_attr, space.w_None)

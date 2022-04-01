# NOT_RPYTHON
# do not load _cppyy here, see _post_import_startup()
import sys

class _C:
    def _m(self): pass
MethodType = type(_C()._m)

# Metaclasses are needed to store C++ static data members as properties and to
# provide Python language features such as a customized __dir__ for namespaces
# and __getattr__ for both. These features are used for lazy lookup/creation.
# Since the interp-level does not support metaclasses, this is all done at the
# app-level.
#
# C++ namespaces: are represented as Python classes, with CPPNamespace as the
#   base class, which is at the moment just a label, and CPPNamespaceMeta as
#   the base class of their invididualized meta class.
#
# C++ classes: are represented as Python classes, with CPPClass as the base
#   class, which is a subclass of the interp-level CPPInstance. The former
#   sets up the Python-class behavior for bound classes, the latter adds the
#   bound object behavior that lives at the class level.

class CPPScopeMeta(type):
    def __getattr__(self, name):
        try:
            return get_scoped_pycppitem(self, name)  # will cache on self
        except Exception as e:
            raise AttributeError("%s object has no attribute '%s' (details: %s)" %
                                 (self, name, str(e)))

class CPPNamespaceMeta(CPPScopeMeta):
    def __dir__(self):
        # For Py3: can actually call base class __dir__ (lives in type)
        values = set(self.__dict__.keys())
        values.update(object.__dict__.keys())
        values.update(type(self).__dict__.keys())

        # add C++ entities
        values.update(self.__cppdecl__.__dir__())
        return list(values)

class CPPClassMeta(CPPScopeMeta):
    pass

# from six.py ---
# Copyright (c) 2010-2017 Benjamin Peterson
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

def with_metaclass(meta, *bases):
    """Create a base class with a metaclass."""
    # This requires a bit of explanation: the basic idea is to make a dummy
    # metaclass for one level of class instantiation that replaces itself with
    # the actual metaclass.
    class metaclass(type):

        def __new__(cls, name, this_bases, d):
            return meta(name, bases, d)

        @classmethod
        def __prepare__(cls, name, this_bases):
            return meta.__prepare__(name, bases)
    return type.__new__(metaclass, 'temporary_class', (), {})
# --- end from six.py

# C++ namespace base class (the C++ class base class defined in _post_import_startup)
class CPPNamespace(with_metaclass(CPPNamespaceMeta, object)):
    def __init__(self):
        raise TypeError("cannot instantiate namespace '%s'", self.__cpp_name__)


# TODO: this can be moved to the interp level (and share template argument
# construction with function templates there)
class CPPTemplate(object):
    def __init__(self, name, scope=None):
        self._name = name
        if scope is None:
            self._scope = gbl
        else:
            self._scope = scope

    def _arg_to_str(self, arg):
      # arguments are strings representing types, types, or builtins
        if type(arg) == str:
            return arg                       # string describing type
        elif hasattr(arg, '__cpp_name__'):
            return arg.__cpp_name__          # C++ bound type
        elif arg == str:
            import _cppyy
            return _cppyy._std_string_name() # special case pystr -> C++ string
        elif isinstance(arg, type):          # builtin types
            return arg.__name__
        return str(arg)                      # builtin values

    def __call__(self, *args):
        fullname = ''.join(
            [self._name, '<', ','.join(map(self._arg_to_str, args))])
        fullname += '>'
        try:
            return self._scope.__dict__[fullname]
        except KeyError:
            pass
        result = get_scoped_pycppitem(self._scope, fullname, True)
        if not result:
            raise TypeError("%s does not exist" % fullname)
        return result

    def __getitem__(self, *args):
        if args and type(args[0]) == tuple:
            return self.__call__(*(args[0]))
        return self.__call__(*args)


def scope_splitter(name):
    is_open_template, scope = 0, ""
    for c in name:
        if c == ':' and not is_open_template:
            if scope:
                yield scope
                scope = ""
            continue
        elif c == '<':
            is_open_template += 1
        elif c == '>':
            is_open_template -= 1
        scope += c
    yield scope

def get_pycppitem(final_scoped_name):
    # walk scopes recursively down from global namespace ("::") to get the
    # actual (i.e. not typedef'ed) class, triggering all necessary creation
    scope = gbl
    for name in scope_splitter(final_scoped_name):
        scope = getattr(scope, name)
    return scope
get_pycppclass = get_pycppitem     # currently no distinction, but might
                                   # in future for performance


# callbacks (originating from interp_cppyy.py) to allow interp-level to
# initiate creation of app-level classes and function
def clgen_callback(final_scoped_name):
    return get_pycppclass(final_scoped_name)

def fngen_callback(func, npar): # todo, some kind of arg transform spec
    if npar == 0:
        def wrapper(a0, a1):
            la0 = [a0[0], a0[1], a0[2], a0[3]]
            return func(la0)
        return wrapper
    else:
        def wrapper(a0, a1):
            la0 = [a0[0], a0[1], a0[2], a0[3]]
            la1 = [a1[i] for i in range(npar)]
            return func(la0, la1)
        return wrapper


# construction of namespaces and classes, and their helpers
def make_module_name(scope):
    if scope:
        return scope.__module__ + '.' + scope.__name__
    return 'cppyy'

def make_cppnamespace(scope, name, decl):
    # build up a representation of a C++ namespace (namespaces are classes)

    # create a metaclass to allow properties (for static data write access)
    import _cppyy
    ns_meta = type(CPPNamespace)(name+'_meta', (CPPNamespaceMeta,), {})

    # create the python-side C++ namespace representation, cache in scope if given
    d = {"__cppdecl__"  : decl,
         "__module__"   : make_module_name(scope),
         "__cpp_name__" : decl.__cpp_name__ }
    pyns = ns_meta(name, (CPPNamespace,), d)
    if scope:
        setattr(scope, name, pyns)

    # install as modules to allow importing from (note naming: cppyy)
    sys.modules[make_module_name(pyns)] = pyns
    return pyns

def _drop_cycles(bases):
    # TODO: figure out why this is necessary?
    for b1 in bases:
        for b2 in bases:
            if not (b1 is b2) and issubclass(b2, b1):
                bases.remove(b1)   # removes lateral class
                break
    return tuple(bases)

def make_new(decl):
    def __new__(cls, *args):
        # create a place-holder only as there may be a derived class defined
        # TODO: get rid of the import and add user-land bind_object that uses
        # _bind_object (see interp_cppyy.py)
        import _cppyy
        instance = _cppyy._bind_object(0, decl, True)
        if not instance.__class__ is cls:
            instance.__class__ = cls     # happens for derived class
        return instance
    return __new__

def make_cppclass(scope, cl_name, decl):
    import _cppyy

    # get a list of base classes for class creation
    bases = [get_pycppclass(base) for base in decl.get_base_names()]
    if not bases:
        bases = [CPPClass,]
    else:
        # it's possible that the required class now has been built if one of
        # the base classes uses it in e.g. a function interface
        try:
            return scope.__dict__[cl_name]
        except KeyError:
            pass

    # prepare dictionary for metaclass
    d_meta = {}

    # prepare dictionary for python-side C++ class representation
    def dispatch(self, m_name, signature):
        cppol = decl.__dispatch__(m_name, signature)
        return MethodType(cppol, self, type(self))
    d_class = {"__cppdecl__"   : decl,
               "__new__"       : make_new(decl),
               "__module__"    : make_module_name(scope),
               "__cpp_name__"  : decl.__cpp_name__,
               "__dispatch__"  : dispatch,}

    # insert (static) methods into the class dictionary
    for m_name in decl.get_method_names():
        cppol = decl.get_overload(m_name)
        d_class[m_name] = cppol

    # add all data members to the dictionary of the class to be created, and
    # static ones also to the metaclass (needed for property setters)
    for d_name in decl.get_datamember_names():
        cppdm = decl.get_datamember(d_name)
        d_class[d_name] = cppdm
        if _cppyy._is_static_data(cppdm):
            d_meta[d_name] = cppdm

    # create a metaclass to allow properties (for static data write access)
    metabases = [type(base) for base in bases]
    cl_meta = type(CPPClassMeta)(cl_name+'_meta', _drop_cycles(metabases), d_meta)

    # create the python-side C++ class
    pycls = cl_meta(cl_name, _drop_cycles(bases), d_class)

    # store the class on its outer scope
    setattr(scope, cl_name, pycls)

    # the call to register will add back-end specific pythonizations and thus
    # needs to run first, so that the generic pythonizations can use them
    import _cppyy
    _cppyy._register_class(pycls)
    _pythonize(pycls, pycls.__cpp_name__)
    return pycls

def make_cpptemplatetype(scope, template_name):
    return CPPTemplate(template_name, scope)


def get_scoped_pycppitem(scope, name, type_only=False):
    import _cppyy

    # resolve typedefs/aliases: these may cross namespaces, in which case
    # the lookup must trigger the creation of all necessary scopes
    scoped_name = (scope == gbl) and name or (scope.__cpp_name__+'::'+name)
    final_scoped_name = _cppyy._resolve_name(scoped_name)
    if final_scoped_name != scoped_name:
        pycppitem = get_pycppitem(final_scoped_name)
        # also store on the requested scope (effectively a typedef or pointer copy)
        setattr(scope, name, pycppitem)
        return pycppitem

    pycppitem = None

    # scopes (classes and namespaces)
    cppitem = _cppyy._scope_byname(final_scoped_name)
    if cppitem:
        if cppitem.is_namespace():
            pycppitem = make_cppnamespace(scope, name, cppitem)
        else:
            pycppitem = make_cppclass(scope, name, cppitem)

    if type_only:
        return pycppitem

    # templates
    if not cppitem:
        cppitem = _cppyy._is_template(final_scoped_name)
        if cppitem:
            pycppitem = make_cpptemplatetype(scope, name)
            setattr(scope, name, pycppitem)

    # functions
    if not cppitem:
        try:
            cppitem = scope.__cppdecl__.get_overload(name)
            setattr(scope, name, cppitem)
            pycppitem = getattr(scope, name)      # binds function as needed
        except AttributeError:
            pass

    # data
    if not cppitem:
        try:
            cppdm = scope.__cppdecl__.get_datamember(name)
            setattr(scope, name, cppdm)
            if _cppyy._is_static_data(cppdm):
                setattr(scope.__class__, name, cppdm)
            pycppitem = getattr(scope, name)      # gets actual property value
        except AttributeError:
            pass

    # enum type
    if not cppitem:
        if scope.__cppdecl__.has_enum(name):
            pycppitem = int

    if pycppitem is not None:      # pycppitem could be a bound C++ NULL, so check explicitly for Py_None
        return pycppitem

    raise AttributeError("'%s' has no attribute '%s'" % (str(scope), name))


# helper for pythonization API
def extract_namespace(name):
    # find the namespace the named class lives in, take care of templates
    tpl_open = 0
    for pos in range(len(name)-1, 1, -1):
        c = name[pos]

        # count '<' and '>' to be able to skip template contents
        if c == '>':
            tpl_open += 1
        elif c == '<':
            tpl_open -= 1

        # collect name up to "::"
        elif tpl_open == 0 and c == ':' and name[pos-1] == ':':
            # found the extend of the scope ... done
            return name[:pos-1], name[pos+1:]

    # no namespace; assume outer scope
    return '', name

# pythonization by decoration (move to their own file?)
def python_style_getitem(self, _idx):
    # python-style indexing: check for size and allow indexing from the back
    sz = len(self)
    idx = _idx
    if isinstance(idx, int):
        if idx < 0: idx = sz + idx
        if 0 <= idx < sz:
            return self._getitem__unchecked(idx)
        else:
            raise IndexError(
                'index out of range: %s requested for %s of size %d' % (str(idx), str(self), sz))
    # may fail for the same reasons as above, but will now give proper error message
    return self._getitem__unchecked(_idx)

def python_style_sliceable_getitem(self, slice_or_idx):
    if type(slice_or_idx) == slice:
        nseq = self.__class__()
        nseq += [python_style_getitem(self, i) \
                    for i in range(*slice_or_idx.indices(len(self)))]
        return nseq
    return python_style_getitem(self, slice_or_idx)

def _pythonize(pyclass, name):
    # general note: use 'in pyclass.__dict__' rather than 'hasattr' to prevent
    # adding pythonizations multiple times in derived classes

    import _cppyy

    # map __eq__/__ne__ through a comparison to None
    if '__eq__' in pyclass.__dict__:
        def __eq__(self, other):
            if other is None: return not self
            if not self and not other: return True
            try:
                return self._cxx_eq(other)
            except TypeError:
                return NotImplemented
        pyclass._cxx_eq = pyclass.__dict__['__eq__']
        pyclass.__eq__ = __eq__

    if '__ne__' in pyclass.__dict__:
        def __ne__(self, other):
            if other is None: return not not self
            if type(self) is not type(other): return True
            return self._cxx_ne(other)
        pyclass._cxx_ne = pyclass.__dict__['__ne__']
        pyclass.__ne__ = __ne__

    # map size -> __len__ (generally true for STL)
    if 'size' in pyclass.__dict__ and not '__len__' in pyclass.__dict__ \
           and callable(pyclass.size):
        pyclass.__len__ = pyclass.size

    # map push_back -> __iadd__ (generally true for STL)
    if 'push_back' in pyclass.__dict__ and not '__iadd__' in pyclass.__dict__:
        if 'reserve' in pyclass.__dict__:
            def iadd(self, ll):
                self.reserve(len(ll))
                for x in ll: self.push_back(x)
                return self
        else:
            def iadd(self, ll):
                for x in ll: self.push_back(x)
                return self
        pyclass.__iadd__ = iadd

    is_vector = name.find('std::vector', 0, 11) == 0

    # map begin()/end() protocol to iter protocol on STL(-like) classes, but
    # not on vector, which is pythonized in the capi (interp-level; there is
    # also the fallback on the indexed __getitem__, but that is slower)
    add_checked_item = False
    if not is_vector:
        if 'begin' in pyclass.__dict__ and 'end' in pyclass.__dict__:
            if _cppyy._scope_byname(name+'::iterator') or \
                    _cppyy._scope_byname(name+'::const_iterator'):
                def __iter__(self):
                    i = self.begin()
                    end = self.size()
                    count = 0
                    while count != end:
                        yield i.__deref__()
                        i.__preinc__()
                        count += 1
                    i.__destruct__()
                    raise StopIteration
                pyclass.__iter__ = __iter__
            else:
                # rely on numbered iteration
                add_checked_item = True

    # add python collection based initializer
    else:
        pyclass.__real_init__ = pyclass.__init__
        def vector_init(self, *args):
            if len(args) == 1 and isinstance(args[0], (tuple, list)):
                ll = args[0]
                self.__real_init__()
                self.reserve(len(ll))
                for item in ll:
                    self.push_back(item)
                return
            return self.__real_init__(*args)
        pyclass.__init__ = vector_init

        # size-up the return of data()
        if hasattr(pyclass, 'data'):   # not the case for e.g. vector<bool>
            pyclass.__real_data = pyclass.data
            def data_with_len(self):
                arr = self.__real_data()
                arr.reshape((len(self),))
                return arr
            pyclass.data = data_with_len

    # TODO: must be a simpler way to check (or at least hook these to a namespace
    # std specific pythonizor)
    if add_checked_item or is_vector or \
            name.find('std::array', 0, 11) == 0 or name.find('std::deque', 0, 10) == 0:
        # combine __getitem__ and __len__ to make a pythonized __getitem__
        if '__getitem__' in pyclass.__dict__ and '__len__' in pyclass.__dict__:
            pyclass._getitem__unchecked = pyclass.__getitem__
            if '__setitem__' in pyclass.__dict__ and '__iadd__' in pyclass.__dict__:
                pyclass.__getitem__ = python_style_sliceable_getitem
            else:
                pyclass.__getitem__ = python_style_getitem

    # string comparisons
    if name == _cppyy._std_string_name():
        def eq(self, other):
            if type(other) == pyclass:
                return self.c_str() == other.c_str()
            else:
                return self.c_str() == other
        pyclass.__eq__  = eq
        pyclass.__str__ = pyclass.c_str

    # std::pair unpacking through iteration
    elif name.find('std::pair', 0, 9) == 0:
        def getitem(self, idx):
            if idx == 0: return self.first
            if idx == 1: return self.second
            raise IndexError("out of bounds")
        def return2(self):
            return 2
        pyclass.__getitem__ = getitem
        pyclass.__len__     = return2

    # std::complex integration with Python complex
    elif name.find('std::complex', 0, 12) == 0:
        def getreal(obj):
            return obj.__cpp_real()
        def setreal(obj, val):
            obj.__cpp_real(val)
        pyclass.__cpp_real = pyclass.real
        pyclass.real = property(getreal, setreal)

        def getimag(obj):
            return obj.__cpp_imag()
        def setimag(obj, val):
            obj.__cpp_imag(val)
        pyclass.__cpp_imag = pyclass.imag
        pyclass.imag = property(getimag, setimag)

        def cmplx(self):
            return self.real+self.imag*1.j
        pyclass.__complex__ = cmplx

        def cmplx_repr(self):
            return repr(self.__complex__())
        pyclass.__repr__ = cmplx_repr

    # user provided, custom pythonizations
    try:
        ns_name, cl_name = extract_namespace(name)
        pythonizors = _pythonizations[ns_name]
        name = cl_name
    except KeyError:
        pythonizors = _pythonizations['']   # global scope

    for p in pythonizors:
        p(pyclass, name)

cppyyIsInitialized = False
def _post_import_startup():
    # run only once (function is explicitly called in testing)
    global cppyyIsInitialized
    if cppyyIsInitialized:
        return

    # _cppyy should not be loaded at the module level, as that will trigger a
    # call to space.getbuiltinmodule(), which will cause _cppyy to be loaded
    # at pypy-c startup, rather than on the "import _cppyy" statement
    import _cppyy

    # root of all proxy classes: CPPClass in pythonify exists to combine the
    # CPPClassMeta metaclass (for Python-side class behavior) with the
    # interp-level CPPInstance (for bound object behavior)
    global CPPClass
    class CPPClass(with_metaclass(CPPClassMeta, _cppyy.CPPInstance)):
        pass

    # class generator callback
    _cppyy._set_class_generator(clgen_callback)

    # function generator callback
    _cppyy._set_function_generator(fngen_callback)

    # user interface objects
    global gbl
    gbl = make_cppnamespace(None, 'gbl', _cppyy._scope_byname(''))
    gbl.__module__  = 'cppyy'
    gbl.__doc__     = 'Global C++ namespace.'

    # pre-create std to allow direct importing
    gbl.std = make_cppnamespace(gbl, 'std', _cppyy._scope_byname('std'))

    # add move cast
    gbl.std.move = _cppyy.move

    # install a type for enums to refer to
    setattr(gbl, 'internal_enum_type_t', int)
    setattr(gbl, 'unsigned int',         int)     # if resolved

    # install for user access
    _cppyy.gbl = gbl

    # install nullptr as a unique reference
    _cppyy.nullptr = _cppyy._get_nullptr()

    # done
    cppyyIsInitialized = True


# user-defined pythonizations interface
_pythonizations = {'' : list()}
def add_pythonization(pythonizor, scope = ''):
    """<pythonizor> should be a callable taking two arguments: a class proxy,
    and its C++ name. It is called on each time a named class from <scope>
    (the global one by default, but a relevant C++ namespace is recommended)
    is bound.
    """
    if not callable(pythonizor):
        raise TypeError("given '%s' object is not callable" % str(pythonizor))
    try:
        _pythonizations[scope].append(pythonizor)
    except KeyError:
        _pythonizations[scope] = list()
        _pythonizations[scope].append(pythonizor)

def remove_pythonization(pythonizor, scope = ''):
    """Remove previously registered <pythonizor> from <scope>.
    """
    try:
        _pythonizations[scope].remove(pythonizor)
        return True
    except (KeyError, ValueError):
        return False

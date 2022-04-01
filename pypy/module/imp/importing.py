"""
Implementation of the interpreter-level default import logic.
"""

import sys, os, stat, re, platform

from pypy.interpreter.module import Module, init_extra_module_attrs
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import TypeDef, generic_new_descr
from pypy.interpreter.error import OperationError, oefmt, wrap_oserror
from pypy.interpreter.baseobjspace import W_Root, CannotHaveLock
from pypy.interpreter.eval import Code
from pypy.interpreter.pycode import PyCode
from rpython.rlib import streamio, jit
from rpython.rlib.streamio import StreamErrors
from rpython.rlib.objectmodel import we_are_translated, specialize
from rpython.rlib.signature import signature
from rpython.rlib import rposix_stat, types
from pypy.module.sys.version import PYPY_VERSION, CPYTHON_VERSION
from pypy.module.__pypy__.interp_os import _multiarch

_WIN32 = sys.platform == 'win32'

SO = '.pyd' if _WIN32 else '.so'
PYC_TAG = 'pypy%d%d' % CPYTHON_VERSION[:2]
DEFAULT_SOABI_BASE = '%s-pp%d%d' % ((PYC_TAG,) + PYPY_VERSION[:2])

# see also pypy_incremental_magic in interpreter/pycode.py for the magic
# version number stored inside pyc files.


@specialize.memo()
def get_so_extension(space):
    if space.config.objspace.soabi is not None:
        soabi = space.config.objspace.soabi
    else:
        soabi = DEFAULT_SOABI_BASE

    if not soabi:
        return SO

    if not space.config.translating:
        soabi += 'i'

    platform_name = sys.platform
    if platform_name.startswith('linux'):
        platform_name = _multiarch
    elif platform_name == 'win32' and sys.maxsize > 2**32:
        platform_name = 'win_amd64'
    else:
        # darwin?
        pass

    soabi += '-' + platform_name

    result = '.' + soabi + SO
    assert result == result.lower()   # this is an implicit requirement of importlib on Windows!
    return result

def has_so_extension(space):
    return (space.config.objspace.usemodules.cpyext or
            space.config.objspace.usemodules._cffi_backend)

def check_sys_modules(space, w_modulename):
    return space.finditem(space.sys.get('modules'), w_modulename)

def check_sys_modules_w(space, modulename):
    return space.finditem_str(space.sys.get('modules'), modulename)


lib_pypy = os.path.join(os.path.dirname(__file__),
                        '..', '..', '..', 'lib_pypy')

def _readall(space, filename):
    try:
        fd = os.open(filename, os.O_RDONLY, 0400)
        try:
            result = []
            while True:
                data = os.read(fd, 8192)
                if not data:
                    break
                result.append(data)
        finally:
            os.close(fd)
    except OSError as e:
        raise wrap_oserror(space, e, filename)
    return ''.join(result)

@unwrap_spec(modulename='fsencode', level=int)
def importhook(space, modulename, w_globals=None, w_locals=None, w_fromlist=None, level=0):
    # A minimal version, that can only import builtin and lib_pypy modules!
    # The actual __import__ is
    # pypy.module._frozenimportlib.interp_import.import_with_frames_removed
    assert w_locals is w_globals
    assert level == 0

    w_mod = check_sys_modules_w(space, modulename)
    if w_mod:
        return w_mod
    lock = getimportlock(space)
    try:
        lock.acquire_lock()

        if modulename in space.builtin_modules:
            return space.getbuiltinmodule(modulename)

        ec = space.getexecutioncontext()
        source = _readall(space, os.path.join(lib_pypy, modulename + '.py'))
        pathname = "<frozen %s>" % modulename
        # *must* pass optimize here, otherwise can get strange bootstrapping
        # problems, because compile would try to get the sys.flags, which might
        # not be there yet
        code_w = ec.compiler.compile(source, pathname, 'exec', 0, optimize=0)
        w_mod = add_module(space, space.newtext(modulename))
        assert isinstance(w_mod, Module) # XXX why is that necessary?
        space.setitem(space.sys.get('modules'), w_mod.w_name, w_mod)
        space.setitem(w_mod.w_dict, space.newtext('__name__'), w_mod.w_name)
        code_w.exec_code(space, w_mod.w_dict, w_mod.w_dict)
        assert check_sys_modules_w(space, modulename)
    finally:
        lock.release_lock(silent_after_fork=True)
    return w_mod


class _WIN32Path(object):
    def __init__(self, path):
        self.path = path

    def as_unicode(self):
        return self.path

def _prepare_module(space, w_mod, filename, pkgdir):
    space.sys.setmodule(w_mod)
    space.setattr(w_mod, space.newtext('__file__'), space.newfilename(filename))
    space.setattr(w_mod, space.newtext('__doc__'), space.w_None)
    if pkgdir is not None:
        space.setattr(w_mod, space.newtext('__path__'),
                      space.newlist([space.newtext(pkgdir)]))
    init_extra_module_attrs(space, w_mod)

def add_module(space, w_name):
    w_mod = check_sys_modules(space, w_name)
    if w_mod is None:
        w_mod = Module(space, w_name)
        init_extra_module_attrs(space, w_mod)
        space.sys.setmodule(w_mod)
    return w_mod

# __________________________________________________________________
#
# import lock, to prevent two threads from running module-level code in
# parallel.  This behavior is more or less part of the language specs,
# as an attempt to avoid failure of 'from x import y' if module x is
# still being executed in another thread.

# This logic is tested in pypy.module.thread.test.test_import_lock.

class ImportRLock:

    def __init__(self, space):
        self.space = space
        self.lock = None
        self.lockowner = None
        self.lockcounter = 0

    def lock_held_by_someone_else(self):
        me = self.space.getexecutioncontext()   # used as thread ident
        return self.lockowner is not None and self.lockowner is not me

    def lock_held_by_anyone(self):
        return self.lockowner is not None

    def acquire_lock(self):
        # this function runs with the GIL acquired so there is no race
        # condition in the creation of the lock
        if self.lock is None:
            try:
                self.lock = self.space.allocate_lock()
            except CannotHaveLock:
                return
        me = self.space.getexecutioncontext()   # used as thread ident
        if self.lockowner is me:
            pass    # already acquired by the current thread
        else:
            self.lock.acquire(True)
            assert self.lockowner is None
            assert self.lockcounter == 0
            self.lockowner = me
        self.lockcounter += 1

    def release_lock(self, silent_after_fork):
        me = self.space.getexecutioncontext()   # used as thread ident
        if self.lockowner is not me:
            if self.lockowner is None and silent_after_fork:
                # Too bad.  This situation can occur if a fork() occurred
                # with the import lock held, and we're the child.
                return
            if self.lock is None:   # CannotHaveLock occurred
                return
            space = self.space
            raise oefmt(space.w_RuntimeError, "not holding the import lock")
        assert self.lockcounter > 0
        self.lockcounter -= 1
        if self.lockcounter == 0:
            self.lockowner = None
            self.lock.release()

    def reinit_lock(self):
        # Called after fork() to ensure that newly created child
        # processes do not share locks with the parent
        # (Note that this runs after interp_imp.acquire_lock()
        # done in the "before" fork hook, so that's why we decrease
        # the lockcounter here)
        if self.lockcounter > 1:
            # Forked as a side effect of import
            self.lock = self.space.allocate_lock()
            me = self.space.getexecutioncontext()
            self.lock.acquire(True)
            # XXX: can the previous line fail?
            self.lockowner = me
            self.lockcounter -= 1
        else:
            self.lock = None
            self.lockowner = None
            self.lockcounter = 0

def getimportlock(space):
    return space.fromcache(ImportRLock)

# __________________________________________________________________
#
# .pyc file support

"""
   Magic word to reject .pyc files generated by other Python versions.
   It should change for each incompatible change to the bytecode.

   The value of CR and LF is incorporated so if you ever read or write
   a .pyc file in text mode the magic number will be wrong; also, the
   Apple MPW compiler swaps their values, botching string constants.

   CPython 2 uses values between 20121 - 62xxx
   CPython 3 uses values greater than 3000
   PyPy uses values under 3000

"""

# Depending on which opcodes are enabled, eg. CALL_METHOD we bump the version
# number by some constant
#
#     CPython + 0                  -- used by CPython without the -U option
#     CPython + 1                  -- used by CPython with the -U option
#     CPython + 7 = default_magic  -- used by PyPy (incompatible!)
#
from pypy.interpreter.pycode import default_magic
MARSHAL_VERSION_FOR_PYC = 4

def get_pyc_magic(space):
    return default_magic


def parse_source_module(space, pathname, source):
    """ Parse a source file and return the corresponding code object """
    ec = space.getexecutioncontext()
    pycode = ec.compiler.compile(source, pathname, 'exec', 0)
    return pycode

def exec_code_module(space, w_mod, code_w, pathname, cpathname,
                     write_paths=True):
    w_dict = space.getattr(w_mod, space.newtext('__dict__'))
    space.call_method(w_dict, 'setdefault',
                      space.newtext('__builtins__'),
                      space.builtin)
    if write_paths:
        if pathname is not None:
            w_pathname = get_sourcefile(space, pathname)
        else:
            w_pathname = code_w.w_filename
        if cpathname is not None:
            w_cpathname = space.newfilename(cpathname)
        else:
            w_cpathname = space.w_None
        space.setitem(w_dict, space.newtext("__file__"), w_pathname)
        space.setitem(w_dict, space.newtext("__cached__"), w_cpathname)
        #
        # like PyImport_ExecCodeModuleObject(), we invoke
        # _bootstrap_external._fix_up_module() here, which should try to
        # fix a few more attributes (also __file__ and __cached__, but
        # let's keep the logic that also sets them explicitly above, just
        # in case)
        space.appexec([w_dict, w_pathname, w_cpathname],
            """(d, pathname, cpathname):
                from importlib._bootstrap_external import _fix_up_module
                name = d.get('__name__')
                if name is not None:
                    _fix_up_module(d, name, pathname, cpathname)
            """)
        #
    code_w.exec_code(space, w_dict, w_dict)

def rightmost_sep(filename):
    "Like filename.rfind('/'), but also search for \\."
    index = filename.rfind(os.sep)
    if os.altsep is not None:
        index2 = filename.rfind(os.altsep)
        index = max(index, index2)
    return index

@signature(types.str0(), returns=types.str0())
def make_compiled_pathname(pathname):
    "Given the path to a .py file, return the path to its .pyc file."
    # foo.py -> __pycache__/foo.<tag>.pyc

    lastpos = rightmost_sep(pathname) + 1
    assert lastpos >= 0  # zero when slash, takes the full name
    fname = pathname[lastpos:]
    if lastpos > 0:
        # Windows: re-use the last separator character (/ or \\) when
        # appending the __pycache__ path.
        lastsep = pathname[lastpos-1]
    else:
        lastsep = os.sep
    ext = fname
    for i in range(len(fname)):
        if fname[i] == '.':
            ext = fname[:i + 1]

    result = (pathname[:lastpos] + "__pycache__" + lastsep +
              ext + PYC_TAG + '.pyc')
    return result

@signature(types.str0(), returns=types.any())
def make_source_pathname(pathname):
    "Given the path to a .pyc file, return the path to its .py file."
    # (...)/__pycache__/foo.<tag>.pyc -> (...)/foo.py

    right = rightmost_sep(pathname)
    if right < 0:
        return None
    left = rightmost_sep(pathname[:right]) + 1
    assert left >= 0
    if pathname[left:right] != '__pycache__':
        return None

    # Now verify that the path component to the right of the last
    # slash has two dots in it.
    rightpart = pathname[right + 1:]
    dot0 = rightpart.find('.') + 1
    if dot0 <= 0:
        return None
    dot1 = rightpart[dot0:].find('.') + 1
    if dot1 <= 0:
        return None
    # Too many dots?
    if rightpart[dot0 + dot1:].find('.') >= 0:
        return None

    result = pathname[:left] + rightpart[:dot0] + 'py'
    return result

def get_sourcefile(space, filename):
    start = len(filename) - 4
    stop = len(filename) - 1
    if not 0 <= start <= stop or filename[start:stop].lower() != ".py":
        return space.newfilename(filename)
    py = make_source_pathname(filename)
    if py is None:
        py = filename[:-1]
    try:
        st = os.stat(py)
    except OSError:
        pass
    else:
        if stat.S_ISREG(st.st_mode):
            return space.newfilename(py)
    return space.newfilename(filename)

def update_code_filenames(space, code_w, pathname, oldname=None):
    assert isinstance(code_w, PyCode)
    if oldname is None:
        oldname = code_w.co_filename
    elif code_w.co_filename != oldname:
        return

    code_w.co_filename = pathname
    code_w.w_filename = space.newfilename(pathname)
    constants = code_w.co_consts_w
    for const in constants:
        if const is not None and isinstance(const, PyCode):
            update_code_filenames(space, const, pathname, oldname)

def _get_long(s):
    a = ord(s[0])
    b = ord(s[1])
    c = ord(s[2])
    d = ord(s[3])
    if d >= 0x80:
        d -= 0x100
    return a | (b<<8) | (c<<16) | (d<<24)

def read_compiled_module(space, cpathname, strbuf):
    """ Read a code object from a file and check it for validity """

    w_marshal = space.getbuiltinmodule('marshal')
    w_code = space.call_method(w_marshal, 'loads', space.newbytes(strbuf))
    if not isinstance(w_code, Code):
        raise oefmt(space.w_ImportError, "Non-code object in %s", cpathname)
    return w_code

@jit.dont_look_inside
def load_compiled_module(space, w_modulename, w_mod, cpathname, magic,
                         source, write_paths=True):
    """
    Load a module from a compiled file, execute it, and return its
    module object.
    """
    if magic != get_pyc_magic(space):
        raise oefmt(space.w_ImportError, "Bad magic number in %s", cpathname)
    #print "loading pyc file:", cpathname
    code_w = read_compiled_module(space, cpathname, source)
    optimize = space.sys.get_optimize()
    if optimize >= 2:
        code_w.remove_docstrings(space)

    exec_code_module(space, w_mod, code_w, cpathname, cpathname, write_paths)

    return w_mod

class FastPathGiveUp(Exception):
    pass

def _gcd_import(space, name):
    # check sys.modules, if the module is already there and initialized, we can
    # use it, otherwise fall back to importlib.__import__

    # NB: we don't get the importing lock here, but CPython has the same fast
    # path
    w_modules = space.sys.get('modules')
    w_module = space.finditem_str(w_modules, name)
    if w_module is None:
        raise FastPathGiveUp

    # to check whether a module is initialized, we can ask for
    # module.__spec__._initializing, which should be False
    try:
        w_spec = space.getattr(w_module, space.newtext("__spec__"))
    except OperationError as e:
        if not e.match(space, space.w_AttributeError):
            raise
        raise FastPathGiveUp
    try:
        w_initializing = space.getattr(w_spec, space.newtext("_initializing"))
    except OperationError as e:
        if not e.match(space, space.w_AttributeError):
            raise
        # we have no mod.__spec__._initializing, so it's probably a builtin
        # module which we can assume is initialized
    else:
        if space.is_true(w_initializing):
            raise FastPathGiveUp
    return w_module

def import_name_fast_path(space, w_modulename, w_globals, w_locals, w_fromlist,
        w_level):
    level = space.int_w(w_level)
    if level == 0:
        # fast path only for absolute imports without a "from" list, for now
        # fromlist can be supported if we are importing from a module, not a
        # package. to check that, look for the existence of __path__ attribute
        # in w_mod
        try:
            name = space.text_w(w_modulename)
            w_mod = _gcd_import(space, name)
            have_fromlist = space.is_true(w_fromlist)
            if not have_fromlist:
                dotindex = name.find(".")
                if dotindex < 0:
                    return w_mod
                return _gcd_import(space, name[:dotindex])
        except FastPathGiveUp:
            pass
        else:
            assert have_fromlist
            w_path = space.findattr(w_mod, space.newtext("__path__"))
            if w_path is not None:
                # hard case, a package! Call back into importlib
                w_importlib = space.getbuiltinmodule('_frozen_importlib')
                return space.call_method(w_importlib, "_handle_fromlist",
                        w_mod, w_fromlist,
                        space.w_default_importlib_import)
            else:
                return w_mod
    return space.call_function(space.w_default_importlib_import, w_modulename, w_globals,
                                w_locals, w_fromlist, w_level)

def get_spec(space, w_module):
    try:
        return space.getattr(w_module, space.newtext('__spec__'))
    except OperationError as e:
        if not e.match(space, space.w_AttributeError):
            raise
        return space.w_None

def is_spec_initializing(space, w_spec):
    if space.is_none(w_spec):
        return False

    try:
        w_initializing = space.getattr(w_spec, space.newtext("_initializing"))
    except OperationError as e:
        if not e.match(space, space.w_AttributeError):
            raise

        return False
    else:
        return space.is_true(w_initializing)

def get_path(space, w_module):
    default = space.newtext("unknown location")
    try:
        w_ret = space.getattr(w_module, space.newtext('__file__'))
    except OperationError as e:
        if not e.match(space, space.w_AttributeError):
            raise
        return default
    if w_ret is space.w_None:
        return default
    return w_ret


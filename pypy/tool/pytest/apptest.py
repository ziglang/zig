# Collects and executes application-level tests.
#
# Classes which names start with "AppTest"
# are not executed by the host Python, but
# by an interpreted pypy object space.
#
# ...unless the -A option ('runappdirect') is passed.

import py
import os
import sys, textwrap, types, gc
from pypy.interpreter.gateway import app2interp_temp
from pypy.interpreter.error import OperationError
from pypy.interpreter.function import Method
from rpython.tool.runsubprocess import run_subprocess
from pypy.tool.pytest import appsupport
from pypy.tool.pytest.objspace import gettestobjspace
from rpython.tool.udir import udir
from pypy import pypydir
from inspect import getmro

pypyroot = os.path.dirname(pypydir)


RENAMED_USEMODULES = {
    '_winreg': 'winreg',
    'exceptions': 'builtins',
    'struct': '_struct',
    'thread': '_thread',
    'operator': '_operator',
    'signal': '_signal',
    'imp': '_imp'}
if sys.platform == 'win32':
    RENAMED_USEMODULES['posix'] = 'nt'

if sys.platform == 'win32':
    RENAMED_USEMODULES['posix'] = 'nt'

class AppError(Exception):
    def __init__(self, excinfo):
        self.excinfo = excinfo

class PythonInterpreter(object):
    def __init__(self, path):
        self.path = path
        self._is_pypy = None

    @property
    def is_pypy(self):
        if self._is_pypy is not None:
            return self._is_pypy
        CODE = "import sys; print('__pypy__' in sys.builtin_module_names)"
        res, stdout, stderr = run_subprocess( self.path, ["-c", CODE])
        if res != 0:
            raise ValueError("Invalid Python interpreter")
        print stdout
        is_pypy = stdout.strip() == 'True'
        self._is_pypy = is_pypy
        return is_pypy


def py3k_repr(value):
    "return the repr() that py3k would give for an object."""
    if isinstance(value, str):
        # python2 string -> Bytes string
        return "b" + repr(value)
    elif isinstance(value, unicode):
        # python2 unicode -> python3 string
        return repr(value)[1:]
    elif isinstance(value, list):
        return '[' + ', '.join(py3k_repr(item) for item in value) + ']'
    elif isinstance(value, tuple):
        return '(' + ', '.join(py3k_repr(item) for item in value) + ',)'
    elif isinstance(value, dict):
        return '{' + ', '.join('%s: %s' % (py3k_repr(key), py3k_repr(value))
                               for key, value in value.items()) + '}'
    elif isinstance(value, long):
        return repr(value)[:-1]
    elif isinstance(value, float):
        r = repr(value)
        if r in ('nan', 'inf', '-inf'):
            return "float(%r)" % r
        else:
            return r
    elif isinstance(value, type):
        return type.__name__
    else:
        return repr(value)


def _rename_module(name):
    return str(RENAMED_USEMODULES.get(name, name))

# we assume that the source of target_ is in utf-8. Unfortunately, we don't
# have any easy/standard way to determine from here the original encoding
# of the source file
helpers = r"""# -*- encoding: utf-8 -*-
if 1:
    import sys
    sys.path.append(%r)
%s
    def skip(message):
        print(message)
        raise SystemExit(0)
    __builtins__.skip = skip
    __builtins__.py3k_skip = skip
    class ExceptionWrapper:
        pass
    def raises(exc, *args, **kwargs):
        if not args:
            return RaisesContext(exc)
        func = args[0]
        args = args[1:]
        import os
        try:
            if isinstance(func, str):
                if func.startswith((' ', os.linesep, '\n')):
                    # it's probably an indented block, so we prefix if True:
                    # to avoid SyntaxError
                    func = "if True:\n" + func
                frame = sys._getframe(1)
                exec(func, frame.f_globals, frame.f_locals)
            else:
                func(*args, **kwargs)
        except exc as e:
            res = ExceptionWrapper()
            res.value = e
            return res
        else:
            raise AssertionError("DID NOT RAISE")

    class RaisesContext(object):
        def __init__(self, expected_exception):
            self.expected_exception = expected_exception
            self.excinfo = None

        def __enter__(self):
            return self

        def __exit__(self, *tp):
            __tracebackhide__ = True
            if tp[0] is None:
                raise AssertionError("DID NOT RAISE")
            self.value = tp[1]
            return issubclass(tp[0], self.expected_exception)

    __builtins__.raises = raises
    class Test:
        pass
    self = Test()
"""

def run_with_python(python_, target_, usemodules, **definitions):
    if python_ is None:
        py.test.skip("Cannot find the default python3 interpreter to run with -A")
    defs = []
    for symbol, value in sorted(definitions.items()):
        if isinstance(value, tuple) and isinstance(value[0], py.code.Source):
            code, args = value
            defs.append(str(code))
            arg_repr = []
            for arg in args:
                if isinstance(arg, types.FunctionType):
                    arg_repr.append(arg.__name__)
                elif isinstance(arg, types.MethodType):
                    arg_repr.append(arg.__name__)
                else:
                    arg_repr.append(py3k_repr(arg))
            args = ', '.join(arg_repr)
            defs.append("self.%s = anonymous(%s)\n" % (symbol, args))
        elif isinstance(value, types.MethodType):
            # "def w_method(self)"
            code = py.code.Code(value)
            defs.append(str(code.source()))
            defs.append("type(self).%s = %s\n" % (symbol, value.__name__))
        elif isinstance(value, types.ModuleType):
            name = value.__name__
            defs.append("import %s; self.%s = %s\n" % (name, symbol, name))
        elif isinstance(value, (str, unicode, int, long, float, list, tuple,
                                dict)) or value is None:
            defs.append("self.%s = %s\n" % (symbol, py3k_repr(value)))

    check_usemodules = ''
    if usemodules:
        usemodules = [_rename_module(name) for name in usemodules]
        check_usemodules = """\
    missing = set(%r).difference(sys.builtin_module_names)
    if missing:
        if not hasattr(sys, 'pypy_version_info'):
            # They may be extension modules on CPython
            name = None
            for name in missing.copy():
                if name in ['cpyext', '_cffi_backend', '_rawffi']:
                    missing.remove(name)
                    continue
                try:
                    __import__(name)
                except ImportError:
                    pass
                else:
                    missing.remove(name)
            del name
        if missing:
            sys.exit(81)
    del missing""" % usemodules

    source = list(py.code.Source(target_))
    while source[0].startswith(('@py.test.mark.', '@pytest.mark.')):
        source.pop(0)
    source = source[1:]

    pyfile = udir.join('src.py')
    if isinstance(target_, str):
        # Special case of a docstring; the function name is the first word.
        target_name = target_.split('(', 1)[0]
    else:
        target_name = target_.__name__
    with pyfile.open('w') as f:
        f.write(helpers % (pypyroot, check_usemodules))
        f.write('\n'.join(defs))
        f.write('def %s():\n' % target_name)
        f.write('\n'.join(source))
        f.write("\ntry:\n    %s()\n" % target_name)
        f.write('finally:\n    print("===aefwuiheawiu===")')
    helper_dir = os.path.join(pypydir, 'tool', 'cpyext')
    env = os.environ.copy()
    env['PYTHONPATH'] = helper_dir
    res, stdout, stderr = run_subprocess(
        python_, [str(pyfile)], env=env)
    print pyfile.read()
    print >> sys.stdout, stdout
    print >> sys.stderr, stderr
    if res == 81:
        py.test.skip('%r was not compiled w/ required usemodules: %r' %
                     (python_, usemodules))
    elif res != 0:
        raise AssertionError(
            "Subprocess failed with exit code %s:\n%s" % (res, stderr))
    elif "===aefwuiheawiu===" not in stdout:
        raise AssertionError("%r crashed:\n%s" % (python_, stderr))


def extract_docstring_if_empty_function(fn):
    def empty_func():
        ""
        pass
    empty_func_code = empty_func.func_code
    fn_code = fn.func_code
    if fn_code.co_code == empty_func_code.co_code and fn.__doc__ is not None:
        fnargs = py.std.inspect.getargs(fn_code).args
        head = '%s(%s):' % (fn.func_name, ', '.join(fnargs))
        body = py.code.Source(fn.__doc__)
        return head + str(body.indent())
    else:
        return fn


class AppTestMethod(py.test.collect.Function):
    def _prunetraceback(self, traceback):
        return traceback

    def execute_appex(self, space, target, *args):
        self.space = space
        space.getexecutioncontext().set_sys_exc_info(None)
        try:
            target(*args)
        except OperationError as e:
            if self.config.option.raise_operr:
                raise
            tb = sys.exc_info()[2]
            if e.match(space, space.w_KeyboardInterrupt):
                raise KeyboardInterrupt, KeyboardInterrupt(), tb
            appexcinfo = appsupport.AppExceptionInfo(space, e)
            if appexcinfo.traceback:
                raise AppError, AppError(appexcinfo), tb
            raise

    def repr_failure(self, excinfo):
        if excinfo.errisinstance(AppError):
            excinfo = excinfo.value.excinfo
        return super(AppTestMethod, self).repr_failure(excinfo)

    def _getdynfilename(self, func):
        code = getattr(func, 'im_func', func).func_code
        return "[%s:%s]" % (code.co_filename, code.co_firstlineno)

    def track_allocations_collect(self):
        gc.collect()
        # must also invoke finalizers now; UserDelAction
        # would not run at all unless invoked explicitly
        if hasattr(self, 'space'):
            self.space.getexecutioncontext()._run_finalizers_now()

    def setup(self):
        super(AppTestMethod, self).setup()
        instance = self.parent.obj
        w_instance = self.parent.w_instance
        space = instance.space
        for name in dir(instance):
            if name.startswith('w_'):
                if self.config.option.runappdirect:
                    setattr(instance, name[2:], getattr(instance, name))
                else:
                    obj = getattr(instance, name)
                    if isinstance(obj, types.MethodType):
                        source = py.code.Source(obj).indent()
                        w_func = space.appexec([], textwrap.dedent("""
                        ():
                        %s
                            return %s
                        """) % (source, obj.__name__))
                        w_obj = Method(space, w_func, w_instance)
                    else:
                        w_obj = obj
                    space.setattr(w_instance, space.wrap(name[2:]), w_obj)

    def runtest(self):
        target = self.obj
        src = extract_docstring_if_empty_function(target.im_func)
        space = target.im_self.space
        if self.config.option.runappdirect:
            appexec_definitions = self.parent.obj.__dict__
            spaceconfig = getattr(self.parent.obj, 'spaceconfig', None)
            usemodules = spaceconfig.get('usemodules') if spaceconfig else None
            return run_with_python(self.config.option.python, src, usemodules,
                                   **appexec_definitions)
        filename = self._getdynfilename(target)
        func = app2interp_temp(src, filename=filename)
        w_instance = self.parent.w_instance
        self.execute_appex(space, func, space, w_instance)


class AppClassInstance(py.test.collect.Instance):
    Function = AppTestMethod

    def setup(self):
        super(AppClassInstance, self).setup()
        instance = self.obj
        space = instance.space
        w_class = self.parent.w_class
        if self.config.option.runappdirect:
            self.w_instance = instance
        else:
            self.w_instance = space.call_function(w_class)


class AppClassCollector(py.test.Class):
    Instance = AppClassInstance

    def setup(self):
        super(AppClassCollector, self).setup()
        cls = self.obj
        #
        # <hack>
        for name in dir(cls):
            if name.startswith('test_'):
                func = getattr(cls, name, None)
                code = getattr(func, 'func_code', None)
                if code and code.co_flags & 32:
                    raise AssertionError("unsupported: %r is a generator "
                                         "app-level test method" % (name,))
        # </hack>
        #
        space = cls.space
        clsname = cls.__name__
        if self.config.option.runappdirect:
            w_class = cls
        else:
            w_class = space.call_function(space.w_type,
                                          space.wrap(clsname),
                                          space.newtuple([]),
                                          space.newdict())
        self.w_class = w_class

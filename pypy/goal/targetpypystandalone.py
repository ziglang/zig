import py

import os, sys, subprocess
from os.path import join, dirname

import pypy
from pypy.interpreter import gateway
from pypy.interpreter.error import OperationError
from pypy.tool.ann_override import PyPyAnnotatorPolicy
from rpython.config.config import to_optparse, make_dict, SUPPRESS_USAGE
from rpython.config.config import ConflictConfigError
from rpython.rlib import rlocale
from pypy.tool.option import make_objspace
from pypy import pypydir
from rpython.rlib import rthread
from pypy.module.thread import os_thread
from pypy.module.sys.version import CPYTHON_VERSION

thisdir = py.path.local(__file__).dirpath()

try:
    this_dir = dirname(__file__)
except NameError:
    this_dir = dirname(sys.argv[0])

def debug(msg):
    try:
        os.write(2, "debug: " + msg + '\n')
    except OSError:
        pass     # bah, no working stderr :-(

# __________  Entry point  __________


def create_entry_point(space, w_dict):
    if w_dict is not None: # for tests
        w_entry_point = space.getitem(w_dict, space.newtext('entry_point'))
        w_run_toplevel = space.getitem(w_dict, space.newtext('run_toplevel'))
        w_initstdio = space.getitem(w_dict, space.newtext('initstdio'))
        withjit = space.config.objspace.usemodules.pypyjit
        hashfunc = space.config.objspace.hash
    else:
        w_initstdio = space.appexec([], """():
            return lambda unbuffered: None
        """)

    def entry_point(argv):
        if withjit:
            from rpython.jit.backend.hlinfo import highleveljitinfo
            highleveljitinfo.sys_executable = argv[0]

        if hashfunc == "siphash24":
            from rpython.rlib import rsiphash
            rsiphash.enable_siphash24()

        #debug("entry point starting")
        #for arg in argv:
        #    debug(" argv -> " + arg)
        if len(argv) > 2 and argv[1] == '--heapsize':
            # Undocumented option, handled at interp-level.
            # It has silently no effect with some GCs.
            # It works in Boehm and in the semispace or generational GCs
            # (but see comments in semispace.py:set_max_heap_size()).
            # At the moment this option exists mainly to support sandboxing.
            from rpython.rlib import rgc
            rgc.set_max_heap_size(int(argv[2]))
            argv = argv[:1] + argv[3:]
        try:
            try:
                space.startup()
                if rlocale.HAVE_LANGINFO:
                    try:
                        rlocale.setlocale(rlocale.LC_CTYPE, '')
                    except rlocale.LocaleError:
                        pass
                w_executable = space.newfilename(argv[0])
                w_argv = space.newlist([space.newfilename(s)
                                        for s in argv[1:]])
                w_bargv = space.newlist([space.newbytes(s)
                                        for s in argv[1:]])
                w_exitcode = space.call_function(w_entry_point, w_executable, w_bargv, w_argv)
                exitcode = space.int_w(w_exitcode)
            except OperationError as e:
                debug("OperationError:")
                debug(" operror-type: " + e.w_type.getname(space))
                debug(" operror-value: " + space.text_w(space.str(e.get_w_value(space))))
                return 1
        finally:
            try:
                # the equivalent of Py_FinalizeEx
                if space.finish() < 0:
                    # Value unlikely to be confused with a non-error exit status
                    # or other special meaning (from cpython/Modules/main.c)
                    exitcode = 120
            except OperationError as e:
                debug("OperationError:")
                debug(" operror-type: " + e.w_type.getname(space))
                debug(" operror-value: " + space.text_w(space.str(e.get_w_value(space))))
                return 1
        return exitcode

    return entry_point, get_additional_entrypoints(space, w_initstdio)


def get_additional_entrypoints(space, w_initstdio):
    # register the minimal equivalent of running a small piece of code. This
    # should be used as sparsely as possible, just to register callbacks
    from rpython.rlib.entrypoint import entrypoint_highlevel
    from rpython.rtyper.lltypesystem import rffi, lltype

    if space.config.objspace.disable_entrypoints:
        return {}

    @entrypoint_highlevel('main', [rffi.CCHARP, rffi.INT],
                          c_name='pypy_setup_home')
    def pypy_setup_home(ll_home, verbose):
        from pypy.module.sys.initpath import pypy_find_stdlib
        verbose = rffi.cast(lltype.Signed, verbose)
        if ll_home and ord(ll_home[0]):
            home1 = rffi.charp2str(ll_home)
            home = join(home1, 'x') # <- so that 'll_home' can be
                                            # directly the root directory
        else:
            home1 = "pypy's shared library location"
            home = '*'
        w_path = pypy_find_stdlib(space, home)
        if space.is_none(w_path):
            if verbose:
                debug("pypy_setup_home: directories 'lib-python' and 'lib_pypy'"
                      " not found in %s or in any parent directory" % home1)
            return rffi.cast(rffi.INT, 1)
        space.startup()
        must_leave = space.threadlocals.try_enter_thread(space)
        try:
            # initialize sys.{path,executable,stdin,stdout,stderr}
            # (in unbuffered mode, to avoid troubles) and import site
            space.appexec([w_path, space.newfilename(home), w_initstdio],
            r"""(path, home, initstdio):
                import sys 
                # don't import anything more above this: sys.path is not set
                sys.path[:] = path
                sys.executable = home
                initstdio(unbuffered=True)
                import os   # don't move it to the first line of this function!
                _MACOSX = sys.platform == 'darwin'
                if _MACOSX:
                    # __PYVENV_LAUNCHER__, used by CPython on macOS, should be ignored
                    # since it (possibly) results in a wrong sys.prefix and
                    # sys.exec_prefix (and consequently sys.path).
                    old_pyvenv_launcher = os.environ.pop('__PYVENV_LAUNCHER__', None)
                try:
                    import site
                except Exception as e:
                    sys.stderr.write("'import site' failed:\n")
                    import traceback
                    traceback.print_exc()
                if _MACOSX and old_pyvenv_launcher:
                    os.environ['__PYVENV_LAUNCHER__'] = old_pyvenv_launcher
            """)
            return rffi.cast(rffi.INT, 0)
        except OperationError as e:
            if verbose:
                debug("OperationError:")
                debug(" operror-type: " + e.w_type.getname(space))
                debug(" operror-value: " + space.text_w(space.str(e.get_w_value(space))))
            return rffi.cast(rffi.INT, -1)
        finally:
            if must_leave:
                space.threadlocals.leave_thread(space)

    @entrypoint_highlevel('main', [rffi.CCHARP], c_name='pypy_execute_source')
    def pypy_execute_source(ll_source):
        return pypy_execute_source_ptr(ll_source, 0)

    @entrypoint_highlevel('main', [rffi.CCHARP, lltype.Signed],
                          c_name='pypy_execute_source_ptr')
    def pypy_execute_source_ptr(ll_source, ll_ptr):
        source = rffi.charp2str(ll_source)
        res = _pypy_execute_source(source, ll_ptr)
        return rffi.cast(rffi.INT, res)

    @entrypoint_highlevel('main', [], c_name='pypy_init_threads')
    def pypy_init_threads():
        if not space.config.objspace.usemodules.thread:
            return
        os_thread.setup_threads(space)

    @entrypoint_highlevel('main', [], c_name='pypy_thread_attach')
    def pypy_thread_attach():
        if not space.config.objspace.usemodules.thread:
            return
        os_thread.setup_threads(space)
        os_thread.bootstrapper.acquire(space, None, None)
        # XXX this doesn't really work.  Don't use os.fork(), and
        # if your embedder program uses fork(), don't use any PyPy
        # code in the fork
        rthread.gc_thread_start()
        os_thread.bootstrapper.nbthreads += 1
        os_thread.bootstrapper.release()

    def _pypy_execute_source(source, c_argument):
        try:
            w_globals = space.newdict(module=True)
            space.setitem(w_globals, space.newtext('__builtins__'),
                          space.builtin_modules['builtins'])
            space.setitem(w_globals, space.newtext('c_argument'),
                          space.newint(c_argument))
            space.appexec([space.newtext(source), w_globals], """(src, glob):
                import sys
                stmt = compile(src, 'c callback', 'exec')
                if not hasattr(sys, '_pypy_execute_source'):
                    sys._pypy_execute_source = []
                sys._pypy_execute_source.append(glob)
                exec(stmt, glob)
            """)
        except OperationError as e:
            debug("OperationError:")
            debug(" operror-type: " + e.w_type.getname(space))
            debug(" operror-value: " + space.text_w(space.str(e.get_w_value(space))))
            return -1
        return 0

    return {'pypy_execute_source': pypy_execute_source,
            'pypy_execute_source_ptr': pypy_execute_source_ptr,
            'pypy_init_threads': pypy_init_threads,
            'pypy_thread_attach': pypy_thread_attach,
            'pypy_setup_home': pypy_setup_home}


# _____ Define and setup target ___

# for now this will do for option handling

class PyPyTarget(object):

    usage = SUPPRESS_USAGE

    take_options = True
    space = None

    def opt_parser(self, config):
        parser = to_optparse(config, useoptions=["objspace.*"],
                             parserkwargs={'usage': self.usage})
        return parser

    def handle_config(self, config, translateconfig):
        if (not translateconfig.help and
            translateconfig._cfgimpl_value_owners['opt'] == 'default'):
            raise Exception("You have to specify the --opt level.\n"
                    "Try --opt=2 or --opt=jit, or equivalently -O2 or -Ojit .")
        self.translateconfig = translateconfig

        # change the default for this option
        # XXX disabled until we fix the real problem: a per-translation
        # seed for siphash is bad
        #config.translation.suggest(hash="siphash24")

        # set up the objspace optimizations based on the --opt argument
        from pypy.config.pypyoption import set_pypy_opt_level
        set_pypy_opt_level(config, translateconfig.opt)

    def print_help(self, config):
        self.opt_parser(config).print_help()

    def get_additional_config_options(self):
        from pypy.config.pypyoption import pypy_optiondescription
        return pypy_optiondescription

    def target(self, driver, args):
        driver.exe_name = 'pypy%d.%d-%%(backend)s' % CPYTHON_VERSION[:2]

        config = driver.config
        parser = self.opt_parser(config)

        parser.parse_args(args)

        # expose the following variables to ease debugging
        global space, entry_point

        if config.objspace.allworkingmodules:
            from pypy.config.pypyoption import enable_allworkingmodules
            enable_allworkingmodules(config)
        if config.objspace.translationmodules:
            from pypy.config.pypyoption import enable_translationmodules
            enable_translationmodules(config)

        config.translation.suggest(check_str_without_nul=True)
        config.translation.suggest(shared=True)
        config.translation.suggest(icon=join(this_dir, 'pypy.ico'))
        config.translation.suggest(manifest=join(this_dir, 'python.manifest'))
        if config.translation.shared:
            if config.translation.output is not None:
                raise Exception("Cannot use the --output option with PyPy "
                                "when --shared is on (it is by default). "
                                "See issue #1971.")

        # if both profopt and profoptpath are specified then we keep them as they are with no other changes
        if config.translation.profopt:
            if config.translation.profoptargs is None:
                config.translation.profoptargs = "$(RPYDIR)/../lib-python/2.7/test/regrtest.py --pgo -x test_asyncore test_gdb test_multiprocessing test_subprocess || true"
        elif config.translation.profoptargs is not None:
            raise Exception("Cannot use --profoptargs without specifying --profopt as well")

        if sys.platform == 'win32':
            libdir = thisdir.join('..', '..', 'libs')
            libdir.ensure(dir=1)
            pythonlib = "python{0[0]}{0[1]}.lib".format(CPYTHON_VERSION)
            config.translation.libname = str(libdir.join(pythonlib))

        if config.translation.thread:
            config.objspace.usemodules.thread = True
        elif config.objspace.usemodules.thread:
            try:
                config.translation.thread = True
            except ConflictConfigError:
                # If --allworkingmodules is given, we reach this point
                # if threads cannot be enabled (e.g. they conflict with
                # something else).  In this case, we can try setting the
                # usemodules.thread option to False again.  It will
                # cleanly fail if that option was set to True by the
                # command-line directly instead of via --allworkingmodules.
                config.objspace.usemodules.thread = False

        if config.translation.continuation:
            config.objspace.usemodules._continuation = True
        elif config.objspace.usemodules._continuation:
            try:
                config.translation.continuation = True
            except ConflictConfigError:
                # Same as above: try to auto-disable the _continuation
                # module if translation.continuation cannot be enabled
                config.objspace.usemodules._continuation = False

        if not config.translation.rweakref:
            config.objspace.usemodules._weakref = False

        if config.translation.jit:
            config.objspace.usemodules.pypyjit = True
        elif config.objspace.usemodules.pypyjit:
            config.translation.jit = True

        if config.translation.sandbox:
            assert 0, ("--sandbox is not tested nor maintained.  If you "
                       "really want to try it anyway, remove this line in "
                       "pypy/goal/targetpypystandalone.py.")

        if config.objspace.usemodules.cpyext:
            if config.translation.gc not in ('incminimark', 'boehm'):
                raise Exception("The 'cpyext' module requires the 'incminimark'"
                    " or 'boehm' GC.  You need either 'targetpypystandalone.py"
                    " --withoutmod-cpyext', or use one of these two GCs.")

        config.translating = True

        import translate
        translate.log_config(config.objspace, "PyPy config object")

        # obscure hack to stuff the translation options into the translated PyPy
        from pypy.module.sys.moduledef import Module as SysModule
        options = make_dict(config)
        wrapstr = 'space.wrap(%r)' % (options)  # import time
        SysModule.interpleveldefs['pypy_translation_info'] = wrapstr
        
        if 'compile' in driver._disabled:
            driver.default_goal = 'source'
        elif config.objspace.usemodules._cffi_backend:
            self.hack_for_cffi_modules(driver)
        else:
            driver.default_goal = 'compile' 
        return self.get_entry_point(config)

    def hack_for_cffi_modules(self, driver):
        # HACKHACKHACK
        # ugly hack to modify target goal from compile_* to build_cffi_imports,
        # as done in package.py
        # this is needed by the benchmark buildbot run, maybe do it as a seperate step there?
        from rpython.tool.runsubprocess import run_subprocess
        from rpython.translator.driver import taskdef
        import types

        compile_goal, = driver.backend_select_goals(['compile'])
        @taskdef([compile_goal], "Create cffi bindings for modules")
        def task_build_cffi_imports(self):
            ''' Use cffi to compile cffi interfaces to modules'''
            filename = join(pypydir, '..', 'lib_pypy', 'pypy_tools',
                                   'build_cffi_imports.py')
            if sys.platform in ('darwin', 'linux', 'linux2'):
                argv = [filename, '--embed-dependencies']
            else:
                argv = [filename,]
            exe_name = py.path.local(driver.c_entryp)
            status, out, err = run_subprocess(str(exe_name), argv)
            sys.stdout.write(out)
            sys.stderr.write(err)
        driver.task_build_cffi_imports = types.MethodType(task_build_cffi_imports, driver)
        driver.tasks['build_cffi_imports'] = driver.task_build_cffi_imports, [compile_goal]
        driver.default_goal = 'build_cffi_imports'
        # HACKHACKHACK end

    def jitpolicy(self, driver):
        from pypy.module.pypyjit.policy import PyPyJitPolicy
        from pypy.module.pypyjit.hooks import pypy_hooks
        return PyPyJitPolicy(pypy_hooks)

    def get_gchooks(self):
        from pypy.module.gc.hook import LowLevelGcHooks
        if self.space is None:
            raise Exception("get_gchooks must be called after get_entry_point")
        return self.space.fromcache(LowLevelGcHooks)

    def get_entry_point(self, config):
        self.space = make_objspace(config)

        # manually imports app_main.py
        filename = join(pypydir, 'interpreter', 'app_main.py')
        app = gateway.applevel(open(filename).read(), 'app_main.py', 'app_main')
        app.hidden_applevel = False
        w_dict = app.getwdict(self.space)
        entry_point, _ = create_entry_point(self.space, w_dict)

        return entry_point, None, PyPyAnnotatorPolicy()

    def interface(self, ns):
        for name in ['take_options', 'handle_config', 'print_help', 'target',
                     'jitpolicy', 'get_entry_point',
                     'get_additional_config_options']:
            ns[name] = getattr(self, name)
        ns['get_gchooks'] = self.get_gchooks

PyPyTarget().interface(globals())


from pypy.interpreter.mixedmodule import MixedModule
from pypy.interpreter.error import OperationError
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib import rdynload
import sys

_WIN = sys.platform == 'win32'

class Module(MixedModule):
    """Sys Builtin Module. """
    _immutable_fields_ = ["defaultencoding", "debug?"]

    def __init__(self, space, w_name):
        """NOT_RPYTHON""" # because parent __init__ isn't
        if space.config.translating:
            del self.__class__.interpleveldefs['pypy_getudir']
            del self.__class__.appleveldefs['stdin']
            del self.__class__.appleveldefs['__stdin__']
            del self.__class__.appleveldefs['stdout']
            del self.__class__.appleveldefs['__stdout__']
            del self.__class__.appleveldefs['stderr']
            del self.__class__.appleveldefs['__stderr__']

        super(Module, self).__init__(space, w_name)
        self.recursionlimit = 1000
        self.defaultencoding = "utf-8"
        self.filesystemencoding = None
        self.track_resources = False
        self.finalizing = False
        self.dlopenflags = rdynload._dlopen_default_mode()

    interpleveldefs = {
        '__name__'              : '(space.newtext("sys"))',
        '__doc__'               : '(space.newtext("PyPy sys module"))',

        'platform'              : 'space.newtext(system.PLATFORM)',
        'maxsize'               : 'space.newint(sys.maxint)',
        'byteorder'             : 'space.newtext(sys.byteorder)',
        'maxunicode'            : 'space.newint(vm.MAXUNICODE)',
        'pypy_objspaceclass'    : 'space.newtext(repr(space))',
        'prefix'                : 'state.get(space).w_initial_prefix',
        'exec_prefix'           : 'state.get(space).w_initial_prefix',
        'path'                  : 'state.get(space).w_path',
        'modules'               : 'state.get(space).w_modules',
        'argv'                  : 'state.get(space).w_argv',
        'warnoptions'           : 'state.get(space).w_warnoptions',
        'abiflags'              : 'space.wrap("")',
        '_framework': "space.newtext('')",
        'builtin_module_names'  : 'space.w_None',
        'pypy_getudir'          : 'state.pypy_getudir',    # not translated
        'pypy_find_stdlib'      : 'initpath.pypy_find_stdlib',
        'pypy_find_executable'  : 'initpath.pypy_find_executable',
        'pypy_resolvedirof'     : 'initpath.pypy_resolvedirof',
        'pypy_initfsencoding'   : 'initpath.pypy_initfsencoding',

        '_getframe'             : 'vm._getframe',
        '_current_frames'       : 'currentframes._current_frames',
        'setrecursionlimit'     : 'vm.setrecursionlimit',
        'getrecursionlimit'     : 'vm.getrecursionlimit',
        'setcheckinterval'      : 'vm.setcheckinterval',
        'getcheckinterval'      : 'vm.getcheckinterval',
        'setswitchinterval'     : 'vm.setswitchinterval',
        'getswitchinterval'     : 'vm.getswitchinterval',
        'exc_info'              : 'vm.exc_info',
        'settrace'              : 'vm.settrace',
        'gettrace'              : 'vm.gettrace',
        'setprofile'            : 'vm.setprofile',
        'getprofile'            : 'vm.getprofile',
        'call_tracing'          : 'vm.call_tracing',
        'getsizeof'             : 'vm.getsizeof',
        'intern'                : 'vm.intern',

        'api_version'           : 'version.get_api_version(space)',
        'version_info'          : 'version.get_version_info(space)',
        #'version'              : set in startup()
        'pypy_version_info'     : 'version.get_pypy_version_info(space)',
        'subversion'            : 'version.get_subversion_info(space)',
        '_mercurial'            : 'version.get_repo_info(space)',
        'hexversion'            : 'version.get_hexversion(space)',

        'displayhook'           : 'hook.displayhook',
        '__displayhook__'       : 'hook.__displayhook__',
        'meta_path'             : 'space.newlist([])',
        'path_hooks'            : 'space.newlist([])',
        'path_importer_cache'   : 'space.newdict()',
        'dont_write_bytecode'   : 'space.newbool(space.config.translation.sandbox)',

        'getdefaultencoding'    : 'interp_encoding.getdefaultencoding',
        'getfilesystemencoding' : 'interp_encoding.getfilesystemencoding',
        'getfilesystemencodeerrors': 'interp_encoding.getfilesystemencodeerrors',

        'float_info'            : 'system.get_float_info(space)',
        'int_info'              : 'system.get_int_info(space)',
        'hash_info'             : 'system.get_hash_info(space)',
        'float_repr_style'      : 'system.get_float_repr_style(space)',

        'get_asyncgen_hooks'    : 'vm.get_asyncgen_hooks',
        'set_asyncgen_hooks'    : 'vm.set_asyncgen_hooks',

        'is_finalizing'         : 'vm.is_finalizing',

        'audit'                 : 'vm.audit',
        'addaudithook'          : 'vm.addaudithook',

        'pycache_prefix'        : 'space.w_None',

        'get_coroutine_origin_tracking_depth': 'vm.get_coroutine_origin_tracking_depth',
        'set_coroutine_origin_tracking_depth': 'vm.set_coroutine_origin_tracking_depth',

        'unraisablehook'        : 'vm.unraisablehook',
        '__unraisablehook__'    : 'vm.unraisablehook',
        }

    if sys.platform == 'win32':
        interpleveldefs['winver'] = 'version.get_winver(space)'
        interpleveldefs['getwindowsversion'] = 'vm.getwindowsversion'
    else:
        interpleveldefs['getdlopenflags'] = 'system.getdlopenflags'
        interpleveldefs['setdlopenflags'] = 'system.setdlopenflags'

    appleveldefs = {
        'excepthook'            : 'app.excepthook',
        '__excepthook__'        : 'app.excepthook',
        'breakpointhook'        : 'app.breakpointhook',
        '__breakpointhook__'    : 'app.breakpointhook',
        'exit'                  : 'app.exit',
        'callstats'             : 'app.callstats',
        'copyright'             : 'app.copyright_str',
        'flags'                 : 'app.null_sysflags',
        '_xoptions'             : 'app.null__xoptions',
        'implementation'        : 'app.implementation',

        # these six attributes are here only during tests;
        # they are removed before translation
        'stdin'                 : 'std_test.stdin',
        '__stdin__'             : 'std_test.stdin',
        'stdout'                : 'std_test.stdout',
        '__stdout__'            : 'std_test.stdout',
        'stderr'                : 'std_test.stderr',
        '__stderr__'            : 'std_test.stderr',
    }

    def startup(self, space):
        if space.config.translating:
            assert self.filesystemencoding is None

        if not space.config.translating or we_are_translated():
            from pypy.module.sys import version
            space.setitem(self.w_dict, space.newtext("version"),
                          version.get_version(space))
            if _WIN:
                from pypy.module.sys import vm
                w_handle = vm.get_dllhandle(space)
                space.setitem(self.w_dict, space.newtext("dllhandle"), w_handle)

        from pypy.module.sys import system
        thread_info = system.get_thread_info(space)
        if thread_info is not None:
            space.setitem(self.w_dict, space.newtext('thread_info'), thread_info)

    def setup_after_space_initialization(self):
        "NOT_RPYTHON"
        space = self.space

        if not space.config.translating:
            ## from pypy.module.sys.interp_encoding import _getfilesystemencoding
            ## self.filesystemencoding = _getfilesystemencoding(space)
            # XXX the two lines above take a few seconds to run whenever
            # we initialize the space; for tests, use a simpler version.
            # Check what exactly breaks, if anything, in py3.6.  This is
            # not strictly necessary but is an extremely nice-to-have
            # feature: running just one test for example take 3
            # seconds instead of 11.
            from pypy.module.sys.interp_encoding import base_encoding
            self.filesystemencoding = base_encoding

            # Set up sys.prefix and friends, like app_main.py would do
            # We somewhat arbitrarily use the repo's root dir as sys.prefix
            from pypy import pypydir
            import os
            rootdir = os.path.dirname(pypydir)
            for attr in ['prefix', 'exec_prefix', 'base_prefix', 'base_exec_prefix']:
                space.setitem(self.w_dict, space.wrap(attr), space.wrap(rootdir))
        space.setitem(self.w_dict, space.wrap("platlibdir"), space.wrap(space.config.objspace.platlibdir))


    def flush_std_files(self, space):
        w_stdout = space.sys.getdictvalue(space, 'stdout')
        w_stderr = space.sys.getdictvalue(space, 'stderr')
        ret = 0
        for w_file in [w_stdout, w_stderr]:
            if not (space.is_none(w_file) or
                    self._file_is_closed(space, w_file)):
                try:
                    space.call_method(w_file, 'flush')
                except OperationError as e:
                    if w_file is w_stdout:
                        e.write_unraisable(space, '', w_file)
                    ret = -1
        return ret

    def _file_is_closed(self, space, w_file):
        try:
            w_closed = space.getattr(w_file, space.newtext('closed'))
        except OperationError:
            return False
        return space.bool_w(w_closed)

    def getmodule(self, name):
        space = self.space
        w_modules = self.get('modules')
        try:
            return space.getitem(w_modules, space.newtext(name))
        except OperationError as e:
            if not e.match(space, space.w_KeyError):
                raise
            return None

    def setmodule(self, w_module):
        space = self.space
        w_name = self.space.getattr(w_module, space.newtext('__name__'))
        w_modules = self.get('modules')
        self.space.setitem(w_modules, w_name, w_module)

    def get_flag(self, name):
        space = self.space
        return space.int_w(space.getattr(self.get('flags'), space.newtext(name)))

    def get_state(self, space):
        from pypy.module.sys import state
        return state.get(space)

    def get_optimize(self):
        try:
            return self.get_flag('optimize')
        except RuntimeError:  # bootstrapping
            return 0

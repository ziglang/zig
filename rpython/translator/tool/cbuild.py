import py
import sys, os, subprocess

from rpython.translator.platform import host
from rpython.translator import cdir
from rpython.tool.udir import udir


class ExternalCompilationInfo(object):

    _ATTRIBUTES = ['pre_include_bits', 'includes', 'include_dirs',
                   'post_include_bits', 'libraries', 'library_dirs',
                   'separate_module_sources', 'separate_module_files',
                   'compile_extra', 'link_extra',
                   'frameworks', 'link_files', 'testonly_libraries']
    _DUPLICATES_OK = ['compile_extra', 'link_extra']
    _EXTRA_ATTRIBUTES = ['use_cpp_linker', 'platform']

    def __init__(self,
                 pre_include_bits        = [],
                 includes                = [],
                 include_dirs            = [],
                 post_include_bits       = [],
                 libraries               = [],
                 library_dirs            = [],
                 separate_module_sources = [],
                 separate_module_files   = [],
                 compile_extra           = [],
                 link_extra              = [],
                 frameworks              = [],
                 link_files              = [],
                 testonly_libraries      = [],
                 use_cpp_linker          = False,
                 platform                = None):
        """
        pre_include_bits: list of pieces of text that should be put at the top
        of the generated .c files, before any #include.  They shouldn't
        contain an #include themselves.  (Duplicate pieces are removed.)

        includes: list of .h file names to be #include'd from the
        generated .c files.

        include_dirs: list of dir names that is passed to the C compiler

        post_include_bits: list of pieces of text that should be put at the top
        of the generated .c files, after the #includes.  (Duplicate pieces are
        removed.)

        libraries: list of library names that is passed to the linker

        library_dirs: list of dir names that is passed to the linker

        separate_module_sources: list of multiline strings that are
        each written to a .c file and compiled separately and linked
        later on.  (If function prototypes are needed for other .c files
        to access this, they can be put in post_include_bits.)

        separate_module_files: list of .c file names that are compiled
        separately and linked later on.  (If an .h file is needed for
        other .c files to access this, it can be put in includes.)

        (export_symbols: killed; you need, depending on the case, to
        add the RPY_EXTERN or RPY_EXPORTED macro just before the
        declaration of each function in the C header file, as explained
        in translator/c/src/precommondefs.h; or you need the decorator
        @rlib.entrypoint.export_symbol)

        compile_extra: list of parameters which will be directly passed to
        the compiler

        link_extra: list of parameters which will be directly passed to
        the linker

        frameworks: list of Mac OS X frameworks which should passed to the
        linker. Use this instead of the 'libraries' parameter if you want to
        link to a framework bundle. Not suitable for unix-like .dylib
        installations.

        link_files: list of file names which will be directly passed to the
        linker

        testonly_libraries: list of libraries that are searched for during
        testing only, by ll2ctypes.  Useful to search for a name in a dynamic
        library during testing but use the static library for compilation.

        use_cpp_linker: a flag to tell if g++ should be used instead of gcc
        when linking (a bit custom so far)

        platform: an object that can identify the platform
        """
        for name in self._ATTRIBUTES:
            value = locals()[name]
            assert isinstance(value, (list, tuple))
            setattr(self, name, tuple(value))
        self.use_cpp_linker = use_cpp_linker
        self._platform = platform

    @property
    def platform(self):
        if self._platform is None:
            from rpython.translator.platform import platform
            return platform
        return self._platform

    @classmethod
    def from_compiler_flags(cls, flags):
        """Returns a new ExternalCompilationInfo instance by parsing
        the string 'flags', which is in the typical Unix compiler flags
        format."""
        pre_include_bits = []
        include_dirs = []
        compile_extra = []
        for arg in flags.split():
            if arg.startswith('-I'):
                include_dirs.append(arg[2:])
            elif arg.startswith('-D'):
                macro = arg[2:]
                if '=' in macro:
                    macro, value = macro.split('=')
                else:
                    value = '1'
                if macro == '_XOPEN_SOURCE':
                    # use default _XOPEN_SOURCE since we always define
                    # _GNU_SOURCE, which then defines a _XOPEN_SOURCE itself
                    continue
                pre_include_bits.append('#define %s %s' % (macro, value))
            elif arg.startswith('-L') or arg.startswith('-l'):
                raise ValueError('linker flag found in compiler options: %r'
                                 % (arg,))
            else:
                compile_extra.append(arg)
        return cls(pre_include_bits=pre_include_bits,
                   include_dirs=include_dirs,
                   compile_extra=compile_extra)

    @classmethod
    def from_linker_flags(cls, flags):
        """Returns a new ExternalCompilationInfo instance by parsing
        the string 'flags', which is in the typical Unix linker flags
        format."""
        libraries = []
        library_dirs = []
        link_extra = []
        for arg in flags.split():
            if arg.startswith('-L'):
                library_dirs.append(arg[2:])
            elif arg.startswith('-l'):
                libraries.append(arg[2:])
            elif arg.startswith('-I') or arg.startswith('-D'):
                raise ValueError('compiler flag found in linker options: %r'
                                 % (arg,))
            else:
                link_extra.append(arg)
        return cls(libraries=libraries,
                   library_dirs=library_dirs,
                   link_extra=link_extra)

    @classmethod
    def from_config_tool(cls, execonfigtool):
        """Returns a new ExternalCompilationInfo instance by executing
        the 'execonfigtool' with --cflags and --libs arguments."""
        path = py.path.local.sysfind(execonfigtool)
        if not path:
            raise ImportError("cannot find %r" % (execonfigtool,))
            # we raise ImportError to be nice to the pypy.config.pypyoption
            # logic of skipping modules depending on non-installed libs
        return cls._run_config_tool('"%s"' % (str(path),))

    @classmethod
    def from_pkg_config(cls, pkgname):
        """Returns a new ExternalCompilationInfo instance by executing
        'pkg-config <pkgname>' with --cflags and --libs arguments."""
        assert isinstance(pkgname, str)
        try:
            popen = subprocess.Popen(['pkg-config', pkgname, '--exists'])
            result = popen.wait()
        except OSError:
            result = -1
        if result != 0:
            raise ImportError("failed: 'pkg-config %s --exists'" % pkgname)
        return cls._run_config_tool('pkg-config "%s"' % pkgname)

    @classmethod
    def _run_config_tool(cls, command):
        cflags = py.process.cmdexec('%s --cflags' % command)
        eci1 = cls.from_compiler_flags(cflags)
        libs = py.process.cmdexec('%s --libs' % command)
        eci2 = cls.from_linker_flags(libs)
        return eci1.merge(eci2)

    def _value(self):
        return tuple([getattr(self, x)
                          for x in self._ATTRIBUTES + self._EXTRA_ATTRIBUTES])

    def __hash__(self):
        return hash(self._value())

    def __eq__(self, other):
        return self.__class__ is other.__class__ and \
               self._value() == other._value()

    def __ne__(self, other):
        return not self == other

    def __repr__(self):
        info = []
        for attr in self._ATTRIBUTES + self._EXTRA_ATTRIBUTES:
            val = getattr(self, attr)
            info.append("%s=%s" % (attr, repr(val)))
        return "<ExternalCompilationInfo (%s)>" % ", ".join(info)

    def merge(self, *others):
        def unique_elements(l):
            seen = set()
            new_objs = []
            for obj in l:
                if obj not in seen:
                    new_objs.append(obj)
                    seen.add(obj)
            return new_objs
        others = unique_elements(list(others))

        attrs = {}
        for name in self._ATTRIBUTES:
            if name in self._DUPLICATES_OK:
                s = []
                for i in [self] + others:
                    s += getattr(i, name)
                attrs[name] = s
            else:
                s = set()
                attr = []
                for one in [self] + others:
                    for elem in getattr(one, name):
                        if elem not in s:
                            s.add(elem)
                            attr.append(elem)
                attrs[name] = attr
        use_cpp_linker = self.use_cpp_linker
        for other in others:
            use_cpp_linker = use_cpp_linker or other.use_cpp_linker
        attrs['use_cpp_linker'] = use_cpp_linker
        for other in others:
            if other.platform != self.platform:
                raise Exception("Mixing ECI for different platforms %s and %s"%
                                (other.platform, self.platform))
        attrs['platform'] = self.platform
        return ExternalCompilationInfo(**attrs)

    def write_c_header(self, fileobj):
        f = open(os.path.join(cdir, 'src', 'precommondefs.h'))
        fileobj.write(f.read())
        f.close()
        print >> fileobj
        for piece in self.pre_include_bits:
            print >> fileobj, piece
        for path in self.includes:
            print >> fileobj, '#include <%s>' % (path,)
        for piece in self.post_include_bits:
            print >> fileobj, piece

    def _copy_attributes(self):
        d = {}
        for attr in self._ATTRIBUTES + self._EXTRA_ATTRIBUTES:
            d[attr] = getattr(self, attr)
        return d

    def convert_sources_to_files(self, cache_dir=None):
        if not self.separate_module_sources:
            return self
        if cache_dir is None:
            cache_dir = udir.join('module_cache').ensure(dir=1)
        num = 0
        files = []
        for source in self.separate_module_sources:
            while 1:
                filename = cache_dir.join('module_%d.c' % num)
                num += 1
                if not filename.check():
                    break
            f = filename.open("w")
            self.write_c_header(f)
            source = str(source)
            f.write(source)
            if not source.endswith('\n'):
                f.write('\n')
            f.close()
            files.append(str(filename))
        d = self._copy_attributes()
        d['separate_module_sources'] = ()
        d['separate_module_files'] += tuple(files)
        return ExternalCompilationInfo(**d)

    def get_module_files(self):
        d = self._copy_attributes()
        files = d['separate_module_files']
        d['separate_module_files'] = ()
        return files, ExternalCompilationInfo(**d)

    def compile_shared_lib(self, outputfilename=None, ignore_a_files=False,
                           debug_mode=True, defines=[]):
        self = self.convert_sources_to_files()
        if ignore_a_files:
            if not [fn for fn in self.link_files if fn.endswith('.a')]:
                ignore_a_files = False    # there are none
        if not self.separate_module_files and not ignore_a_files:
            return self    # xxx there was some condition about win32 here
        else:
            #basepath = py.path.local(self.separate_module_files[0]).dirpath()
            basepath = udir.join('shared_cache')
        if outputfilename is None:
            # find more or less unique name there
            pth = basepath.join('externmod').new(ext=host.so_ext)
            num = 0
            while pth.check():
                pth = basepath.join(
                    'externmod_%d' % (num,)).new(ext=host.so_ext)
                num += 1
            basepath.ensure(dir=1)
            outputfilename = str(pth.dirpath().join(pth.purebasename))

        d = self._copy_attributes()
        if ignore_a_files:
            d['link_files'] = [fn for fn in d['link_files']
                                  if not fn.endswith('.a')]
        if debug_mode and sys.platform != 'win32':
            d['compile_extra'] = d['compile_extra'] + ('-g', '-O0')
        d['compile_extra'] = d['compile_extra'] + (
            '-DRPY_EXTERN=RPY_EXPORTED',)
        for define in defines:
            d['compile_extra'] += ('-D%s' % define,)
        self = ExternalCompilationInfo(**d)

        lib = str(host.compile([], self, outputfilename=outputfilename,
                               standalone=False))
        d = self._copy_attributes()
        d['libraries'] += (lib,)
        d['separate_module_files'] = ()
        d['separate_module_sources'] = ()
        return ExternalCompilationInfo(**d)

    def copy_without(self, *names):
        d = self._copy_attributes()
        for name in names:
            del d[name]
        return ExternalCompilationInfo(**d)

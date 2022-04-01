import contextlib
import py
import sys, os
from rpython.rlib import exports
from rpython.rtyper.lltypesystem.lltype import getfunctionptr
from rpython.rtyper.lltypesystem import lltype
from rpython.tool import runsubprocess
from rpython.tool.nullpath import NullPyPathLocal
from rpython.tool.udir import udir
from rpython.translator.c import gc
from rpython.translator.c.database import LowLevelDatabase
from rpython.translator.c.extfunc import pre_include_code_lines
from rpython.translator.c.support import log
from rpython.translator.gensupp import uniquemodulename, NameManager
from rpython.translator.tool.cbuild import ExternalCompilationInfo


_CYGWIN = sys.platform == 'cygwin'

_CPYTHON_RE = py.std.re.compile('^Python 2.[567]')

def get_recent_cpython_executable():

    if sys.platform == 'win32':
        python = sys.executable.replace('\\', '/')
    else:
        python = sys.executable
    # Is there a command 'python' that runs python 2.5-2.7?
    # If there is, then we can use it instead of sys.executable
    returncode, stdout, stderr = runsubprocess.run_subprocess(
        "python", "-V")
    if _CPYTHON_RE.match(stdout) or _CPYTHON_RE.match(stderr):
        python = 'python'
    return python


class CCompilerDriver(object):
    def __init__(self, platform, cfiles, eci, outputfilename=None,
                 profbased=False):
        # XXX config might contain additional link and compile options.
        #     We need to fish for it somehow.
        self.platform = platform
        self.cfiles = cfiles
        self.eci = eci
        self.outputfilename = outputfilename
        # self.profbased = profbased

    def _build(self, eci=ExternalCompilationInfo(), shared=False):
        outputfilename = self.outputfilename
        if shared:
            if outputfilename:
                basename = outputfilename
            else:
                basename = self.cfiles[0].purebasename
            outputfilename = 'lib' + basename
        return self.platform.compile(self.cfiles, self.eci.merge(eci),
                                     outputfilename=outputfilename,
                                     standalone=not shared)

class CBuilder(object):
    c_source_filename = None
    _compiled = False
    modulename = None
    split = False

    def __init__(self, translator, entrypoint, config, gcpolicy=None,
                 gchooks=None, secondary_entrypoints=()):
        self.translator = translator
        self.entrypoint = entrypoint
        self.entrypoint_name = getattr(self.entrypoint, 'func_name', None)
        self.originalentrypoint = entrypoint
        self.config = config
        self.gcpolicy = gcpolicy    # for tests only, e.g. rpython/memory/
        self.gchooks = gchooks
        self.eci = self.get_eci()
        self.secondary_entrypoints = secondary_entrypoints

    def get_eci(self):
        pypy_include_dir = py.path.local(__file__).join('..')
        include_dirs = [pypy_include_dir]
        if self.config.translation.reverse_debugger:
            include_dirs.append(pypy_include_dir.join('..', 'revdb'))
        return ExternalCompilationInfo(include_dirs=include_dirs)

    def build_database(self):
        translator = self.translator

        gcpolicyclass = self.get_gcpolicyclass()

        exctransformer = translator.getexceptiontransformer()
        db = LowLevelDatabase(translator, standalone=self.standalone,
                              gcpolicyclass=gcpolicyclass,
                              gchooks=self.gchooks,
                              exctransformer=exctransformer,
                              thread_enabled=self.config.translation.thread,
                              sandbox=self.config.translation.sandbox,
                              split_gc_address_space=
                                 self.config.translation.split_gc_address_space,
                              reverse_debugger=
                                 self.config.translation.reverse_debugger)
        self.db = db

        # give the gc a chance to register interest in the start-up functions it
        # need (we call this for its side-effects of db.get())
        list(db.gcpolicy.gc_startup_code())

        # build entrypoint and eventually other things to expose
        pf = self.getentrypointptr()
        if isinstance(pf, list):
            for one_pf in pf:
                db.get(one_pf)
            self.c_entrypoint_name = None
        else:
            pfname = db.get(pf)

            for func, _ in self.secondary_entrypoints:
                bk = translator.annotator.bookkeeper
                db.get(getfunctionptr(bk.getdesc(func).getuniquegraph()))

            self.c_entrypoint_name = pfname

        if self.config.translation.reverse_debugger:
            from rpython.translator.revdb import gencsupp
            gencsupp.prepare_database(db)

        for obj in exports.EXPORTS_obj2name.keys():
            db.getcontainernode(obj)
        exports.clear()

        for ll_func in db.translator._call_at_startup:
            db.get(ll_func)

        db.complete()

        self.collect_compilation_info(db)
        return db

    have___thread = None

    def merge_eci(self, *ecis):
        self.eci = self.eci.merge(*ecis)

    def collect_compilation_info(self, db):
        # we need a concrete gcpolicy to do this
        self.merge_eci(db.gcpolicy.compilation_info())

        all = []
        for node in self.db.globalcontainers():
            eci = node.compilation_info()
            if eci:
                all.append(eci)
        for node in self.db.getstructdeflist():
            try:
                all.append(node.STRUCT._hints['eci'])
            except (AttributeError, KeyError):
                pass
        self.merge_eci(*all)

    def get_gcpolicyclass(self):
        if self.gcpolicy is None:
            name = self.config.translation.gctransformer
            if name == "framework":
                name = "%s+%s" % (name, self.config.translation.gcrootfinder)
            return gc.name_to_gcpolicy[name]
        return self.gcpolicy

    # use generate_source(defines=DEBUG_DEFINES) to force the #definition
    # of the macros that enable debugging assertions
    DEBUG_DEFINES = {'RPY_ASSERT': 1,
                     'RPY_LL_ASSERT': 1,
                     'RPY_REVDB_PRINT_ALL': 1}

    def generate_source(self, db=None, defines={}, exe_name=None):
        assert self.c_source_filename is None
        if db is None:
            db = self.build_database()
        pf = self.getentrypointptr()
        if self.modulename is None:
            self.modulename = uniquemodulename('testing')
        modulename = self.modulename
        targetdir = udir.ensure(modulename, dir=1)
        if self.config.translation.dont_write_c_files:
            targetdir = NullPyPathLocal(targetdir)

        self.targetdir = targetdir
        defines = defines.copy()
        if self.config.translation.countmallocs:
            defines['COUNT_OP_MALLOCS'] = 1
        if self.config.translation.sandbox:
            defines['RPY_SANDBOXED'] = 1
        if self.config.translation.reverse_debugger:
            defines['RPY_REVERSE_DEBUGGER'] = 1
        if self.config.translation.rpython_translate:
            defines['RPY_TRANSLATE'] = 1
        if CBuilder.have___thread is None:
            CBuilder.have___thread = self.translator.platform.check___thread()
        if not self.standalone:
            assert not self.config.translation.instrument
        else:
            defines['PYPY_STANDALONE'] = db.get(pf)
            if self.config.translation.instrument:
                defines['PYPY_INSTRUMENT'] = 1
            if CBuilder.have___thread:
                if not self.config.translation.no__thread:
                    defines['USE___THREAD'] = 1
            if self.config.translation.shared:
                defines['PYPY_MAIN_FUNCTION'] = "pypy_main_startup"
        self.eci, cfile, extra, headers_to_precompile = \
                gen_source(db, modulename, targetdir,
                           self.eci, defines=defines, split=self.split)
        self.c_source_filename = py.path.local(cfile)
        self.extrafiles = self.eventually_copy(extra)
        self.gen_makefile(targetdir, exe_name=exe_name,
                          headers_to_precompile=headers_to_precompile)
        return cfile

    def eventually_copy(self, cfiles):
        extrafiles = []
        for fn in cfiles:
            fn = py.path.local(fn)
            if not fn.relto(udir):
                newname = self.targetdir.join(fn.basename)
                if newname.check(exists=True):
                    raise ValueError(
                        "Cannot have two different separate_module_sources "
                        "with the same basename, please rename one: %s" % fn.basename)
                fn.copy(newname)
                fn = newname
            extrafiles.append(fn)
        return extrafiles


class CStandaloneBuilder(CBuilder):
    standalone = True
    split = True
    executable_name = None
    shared_library_name = None
    _entrypoint_wrapper = None
    make_entrypoint_wrapper = True    # for tests


    def getentrypointptr(self):
        # XXX check that the entrypoint has the correct
        # signature:  list-of-strings -> int
        if not self.make_entrypoint_wrapper:
            bk = self.translator.annotator.bookkeeper
            return getfunctionptr(bk.getdesc(self.entrypoint).getuniquegraph())
        if self._entrypoint_wrapper is not None:
            return self._entrypoint_wrapper
        #
        from rpython.annotator import model as annmodel
        from rpython.rtyper.lltypesystem import rffi
        from rpython.rtyper.annlowlevel import MixLevelHelperAnnotator
        from rpython.rtyper.llannotation import lltype_to_annotation
        entrypoint = self.entrypoint
        #
        def entrypoint_wrapper(argc, argv):
            """This is a wrapper that takes "Signed argc" and "char **argv"
            like the C main function, and puts them inside an RPython list
            of strings before invoking the real entrypoint() function.
            """
            list = [""] * argc
            i = 0
            while i < argc:
                list[i] = rffi.charp2str(argv[i])
                i += 1
            return entrypoint(list)
        #
        mix = MixLevelHelperAnnotator(self.translator.rtyper)
        args_s = [annmodel.SomeInteger(),
                  lltype_to_annotation(rffi.CCHARPP)]
        s_result = annmodel.SomeInteger()
        graph = mix.getgraph(entrypoint_wrapper, args_s, s_result)
        mix.finish()
        res = getfunctionptr(graph)
        self._entrypoint_wrapper = res
        return res

    def cmdexec(self, args='', env=None, err=False, expect_crash=False, exe=None):
        assert self._compiled
        if sys.platform == 'win32':
            #Prevent opening a dialog box
            import ctypes
            winapi = ctypes.windll.kernel32
            SetErrorMode = winapi.SetErrorMode
            SetErrorMode.argtypes=[ctypes.c_int]

            SEM_FAILCRITICALERRORS = 1
            SEM_NOGPFAULTERRORBOX  = 2
            SEM_NOOPENFILEERRORBOX = 0x8000
            flags = SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX \
                    | SEM_NOOPENFILEERRORBOX
            #Since there is no GetErrorMode, do a double Set
            old_mode = SetErrorMode(flags)
            SetErrorMode(old_mode | flags)
        if env is None:
            envrepr = ''
        else:
            envrepr = ' [env=%r]' % (env,)
        if exe is None:
            exe = self.executable_name
        log.cmdexec('%s %s%s' % (exe, args, envrepr))
        res = self.translator.platform.execute(exe, args, env=env)
        if sys.platform == 'win32':
            SetErrorMode(old_mode)
        if res.returncode != 0:
            if expect_crash:
                if type(expect_crash) is int and expect_crash != res.returncode:
                    raise Exception("Returned %d, but expected %d" % (
                        res.returncode, expect_crash))
                return res.out, res.err
            print >> sys.stderr, res.err
            raise Exception("Returned %d" % (res.returncode,))
        if expect_crash:
            raise Exception("Program did not crash!")
        if err:
            return res.out, res.err
        return res.out

    def compile(self, exe_name=None):
        assert self.c_source_filename
        assert not self._compiled

        shared = self.config.translation.shared

        extra_opts = []
        if self.config.translation.profopt:
            extra_opts += ["profopt"]
        if self.config.translation.make_jobs != 1:
            extra_opts += ['-j', str(self.config.translation.make_jobs)]
        if self.config.translation.lldebug:
            extra_opts += ["lldebug"]
        elif self.config.translation.lldebug0:
            extra_opts += ["lldebug0"]
        self.translator.platform.execute_makefile(self.targetdir,
                                                  extra_opts)
        self._compiled = True
        return self.executable_name

    def gen_makefile(self, targetdir, exe_name=None, headers_to_precompile=[]):
        module_files = self.eventually_copy(self.eci.separate_module_files)
        self.eci.separate_module_files = []
        self.eci.compile_extra += ('-DPYPY_MAKEFILE',)
        cfiles = [self.c_source_filename] + self.extrafiles + list(module_files)
        if exe_name is not None:
            exe_name = targetdir.join(exe_name)
        mk = self.translator.platform.gen_makefile(
            cfiles, self.eci,
            path=targetdir, exe_name=exe_name,
            headers_to_precompile=headers_to_precompile,
            no_precompile_cfiles = module_files,
            shared=self.config.translation.shared,
            profopt = self.config.translation.profopt,
            config=self.config)

        if exe_name is None:
            short =  targetdir.basename
            exe_name = targetdir.join(short)

        rules = [
            ('debug', '', '$(MAKE) CFLAGS="$(DEBUGFLAGS) -DRPY_ASSERT" debug_target'),
            ('debug_exc', '', '$(MAKE) CFLAGS="$(DEBUGFLAGS) -DRPY_ASSERT -DDO_LOG_EXC" debug_target'),
            ('debug_mem', '', '$(MAKE) CFLAGS="$(DEBUGFLAGS) -DRPY_ASSERT -DPYPY_USE_TRIVIAL_MALLOC" debug_target'),
            ('llsafer', '', '$(MAKE) CFLAGS="-O2 -DRPY_LL_ASSERT" $(DEFAULT_TARGET)'),
            ('lldebug', '', '$(MAKE) CFLAGS="$(DEBUGFLAGS) -DRPY_ASSERT -DRPY_LL_ASSERT" debug_target'),
            ('profile', '', '$(MAKE) CFLAGS="-g -O1 -pg $(CFLAGS) -fno-omit-frame-pointer" LDFLAGS="-pg $(LDFLAGS)" $(DEFAULT_TARGET)'),
        ]

        # added a new target for profopt, because it requires -lgcov to compile successfully when -shared is used as an argument
        # Also made a difference between translating with shared or not, because this affects profopt's target

        if self.config.translation.profopt:
            if self.config.translation.profoptargs is None:
                raise Exception("No profoptargs specified, neither in the command line, nor in the target. If the target is not PyPy, please specify profoptargs")

            # Set the correct PGO params based on OS and CC
            profopt_gen_flag = ""
            profopt_use_flag = ""
            profopt_merger = ""
            profopt_file = ""
            llvm_profdata = ""

            cc = self.translator.platform.cc

            # Locate llvm-profdata
            if "clang" in cc:
                clang_bin = cc
                path = os.environ.get("PATH").split(":")
                profdata_found = False

                # Try to find it in $PATH (Darwin and Linux)
                for dir in path:
                    bin = "%s/llvm-profdata" % dir
                    if os.path.isfile(bin):
                        llvm_profdata = bin
                        profdata_found = True
                        break

                # If not found, try to find it where clang is actually installed (Darwin and Linux)
                if not profdata_found:
                    # If the full path is not given, find where clang is located
                    if not os.path.isfile(clang_bin):
                        for dir in path:
                            bin = "%s/%s" % (dir, cc)
                            if os.path.isfile(bin):
                                clang_bin = bin
                                break
                    # Some systems install clang elsewhere as a symlink to the real path,
                    # which is where the related llvm tools are located.
                    if os.path.islink(clang_bin):
                        clang_bin = os.path.realpath(clang_bin)  # the real clang binary
                    # llvm-profdata must be in the same directory as clang
                    llvm_profdata = "%s/llvm-profdata" % os.path.dirname(clang_bin)
                    profdata_found = os.path.isfile(llvm_profdata)

                # If not found, and Darwin is used, try to find it in the development environment
                # More: https://apple.stackexchange.com/questions/197053/
                if not profdata_found and sys.platform == 'darwin':
                    code = os.system("/usr/bin/xcrun -find llvm-profdata 2>/dev/null")
                    if code == 0:
                        llvm_profdata = "/usr/bin/xcrun llvm-profdata"
                        profdata_found = True

                # If everything failed, throw Exception, sorry
                if not profdata_found:
                    raise Exception(
                        "Error: Cannot perform profopt build because llvm-profdata was not found in PATH. "
                        "Please add it to PATH and run the translation again.")

            # Set the PGO flags
            if "clang" in cc:
                # Any changes made here should be reflected in the GCC+Darwin case below
                profopt_gen_flag = "-fprofile-instr-generate"
                profopt_use_flag = "-fprofile-instr-use=code.profclangd"
                profopt_merger = "%s merge -output=code.profclangd *.profclangr" % llvm_profdata
                profopt_file = 'LLVM_PROFILE_FILE="code-%p.profclangr"'
            elif "gcc" in cc:
                if sys.platform == 'darwin':
                    profopt_gen_flag = "-fprofile-instr-generate"
                    profopt_use_flag = "-fprofile-instr-use=code.profclangd"
                    profopt_merger = "%s merge -output=code.profclangd *.profclangr" % llvm_profdata
                    profopt_file = 'LLVM_PROFILE_FILE="code-%p.profclangr"'
                else:
                    profopt_gen_flag = "-fprofile-generate"
                    profopt_use_flag = "-fprofile-use -fprofile-correction"
                    profopt_merger = "true"
                    profopt_file = ""

            if self.config.translation.shared:
                mk.rule('$(PROFOPT_TARGET)', '$(TARGET) main.o',
                         ['$(CC_LINK) $(LDFLAGS_LINK) main.o -L. -l$(SHARED_IMPORT_LIB) -o $@ $(RPATH_FLAGS) -lgcov', '$(MAKE) postcompile BIN=$(PROFOPT_TARGET)'])
            else:
                mk.definition('PROFOPT_TARGET', '$(TARGET)')

            rules.append(
                ('profopt', '', [
                    '$(MAKE) CFLAGS="%s -fPIC $(CFLAGS)"  LDFLAGS="%s $(LDFLAGS)" $(PROFOPT_TARGET)' % (profopt_gen_flag, profopt_gen_flag),
                    '%s %s %s ' % (profopt_file, exe_name, self.config.translation.profoptargs),
                    '%s' % (profopt_merger),
                    '$(MAKE) clean_noprof',
                    '$(MAKE) CFLAGS="%s -fPIC $(CFLAGS)"  LDFLAGS="%s $(LDFLAGS)" $(PROFOPT_TARGET)' % (profopt_use_flag, profopt_use_flag),
                ]))

        for rule in rules:
            mk.rule(*rule)

        if self.translator.platform.name == 'msvc':
            mk.rule('lldebug0','', '$(MAKE) CFLAGS="$(DEBUGFLAGS) -Od -DMAX_STACK_SIZE=8192000 -DRPY_ASSERT -DRPY_LL_ASSERT" debug_target'),
            wildcards = '..\*.obj ..\*.pdb ..\*.lib ..\*.dll ..\*.manifest ..\*.exp *.pch'
            cmd =  r'del /s %s $(DEFAULT_TARGET) $(TARGET) $(ASMFILES)' % wildcards
            mk.rule('clean', '',  cmd + ' *.gc?? ..\module_cache\*.gc??')
            mk.rule('clean_noprof', '', cmd)
        else:
            mk.rule('lldebug0','', '$(MAKE) CFLAGS="$(DEBUGFLAGS) -O0 -DMAX_STACK_SIZE=8192000 -DRPY_ASSERT -DRPY_LL_ASSERT" debug_target'),
            mk.rule('clean', '', 'rm -f $(OBJECTS) $(DEFAULT_TARGET) $(TARGET) $(ASMFILES) $(PRECOMPILEDHEADERS) *.gc?? ../module_cache/*.gc??')
            mk.rule('clean_noprof', '', 'rm -f $(OBJECTS) $(DEFAULT_TARGET) $(TARGET) $(ASMFILES)')

        if self.config.translation.gcrootfinder == 'asmgcc':
            raise AssertionError("asmgcc not supported any more")
        else:
            if self.translator.platform.name == 'msvc':
                mk.definition('DEBUGFLAGS', '-MD -Zi')
            else:
                if self.config.translation.shared:
                    mk.definition('DEBUGFLAGS', '-O1 -g -fPIC')
                else:
                    mk.definition('DEBUGFLAGS', '-O1 -g')
        if self.translator.platform.name == 'msvc':
            mk.rule('debug_target', '$(DEFAULT_TARGET) $(WTARGET)', 'rem')
        else:
            mk.rule('debug_target', '$(DEFAULT_TARGET)', '#')
        mk.write()
        #self.translator.platform,
        #                           ,
        #                           self.eci, profbased=self.getprofbased()
        self.executable_name = mk.exe_name
        if self.config.translation.shared:
            self.shared_library_name = mk.so_name
        if sys.platform == 'win32':
            self.executable_name_w = mk.wtarget_name

# ____________________________________________________________

SPLIT_CRITERIA = 65535 # support VC++ 7.2
#SPLIT_CRITERIA = 32767 # enable to support VC++ 6.0

MARKER = '/*/*/' # provide an easy way to split after generating

class SourceGenerator:
    one_source_file = True

    def __init__(self, database):
        self.database = database
        self.extrafiles = []
        self.headers_to_precompile = []
        self.path = None
        self.namespace = NameManager()

    def set_strategy(self, path, split=True):
        all_nodes = list(self.database.globalcontainers())
        # split off non-function nodes. We don't try to optimize these, yet.
        funcnodes = []
        othernodes = []
        for node in all_nodes:
            if node.nodekind == 'func':
                funcnodes.append(node)
            else:
                othernodes.append(node)
        if split:
            self.one_source_file = False
        self.funcnodes = funcnodes
        self.othernodes = othernodes
        self.path = path

    def uniquecname(self, name):
        assert name.endswith('.c')
        return self.namespace.uniquename(name[:-2]) + '.c'

    def makefile(self, name):
        log.writing(name)
        filepath = self.path.join(name)
        if name.endswith('.c'):
            self.extrafiles.append(filepath)
        if name.endswith('.h'):
            self.headers_to_precompile.append(filepath)
        return filepath.open('w')

    def getextrafiles(self):
        return self.extrafiles

    def getothernodes(self):
        return self.othernodes[:]

    def getbasecfilefornode(self, node, basecname):
        # For FuncNode instances, use the python source filename (relative to
        # the top directory):
        def invent_nice_name(g):
            # Lookup the filename from the function.
            # However, not all FunctionGraph objs actually have a "func":
            if hasattr(g, 'func'):
                if g.filename.endswith('.py'):
                    localpath = py.path.local(g.filename)
                    pypkgpath = localpath.pypkgpath()
                    if pypkgpath:
                        relpypath = localpath.relto(pypkgpath.dirname)
                        assert relpypath, ("%r should be relative to %r" %
                            (localpath, pypkgpath.dirname))
                        if len(relpypath.split(os.path.sep)) > 2:
                            # pypy detail to agregate the c files by directory,
                            # since the enormous number of files was causing
                            # memory issues linking on win32
                            return os.path.split(relpypath)[0] + '.c'
                        return relpypath.replace('.py', '.c')
            return None
        if hasattr(node.obj, 'graph'):
            # Regular RPython functions
            name = invent_nice_name(node.obj.graph)
            if name is not None:
                return name
        elif node._funccodegen_owner is not None:
            # Data nodes that belong to a known function
            graph = getattr(node._funccodegen_owner, 'graph', None)
            name = invent_nice_name(graph)
            if name is not None:
                return "data_" + name
        return basecname

    def splitnodesimpl(self, basecname, nodes, nextra, nbetween,
                       split_criteria=SPLIT_CRITERIA):
        # Gather nodes by some criteria:
        nodes_by_base_cfile = {}
        for node in nodes:
            c_filename = self.getbasecfilefornode(node, basecname)
            if c_filename in nodes_by_base_cfile:
                nodes_by_base_cfile[c_filename].append(node)
            else:
                nodes_by_base_cfile[c_filename] = [node]

        # produce a sequence of nodes, grouped into files
        # which have no more than SPLIT_CRITERIA lines
        for basecname in sorted(nodes_by_base_cfile):
            iternodes = iter(nodes_by_base_cfile[basecname])
            done = [False]
            def subiter():
                used = nextra
                for node in iternodes:
                    impl = '\n'.join(list(node.implementation())).split('\n')
                    if not impl:
                        continue
                    cost = len(impl) + nbetween
                    yield node, impl
                    del impl
                    if used + cost > split_criteria:
                        # split if criteria met, unless we would produce nothing.
                        raise StopIteration
                    used += cost
                done[0] = True
            while not done[0]:
                yield self.uniquecname(basecname), subiter()

    @contextlib.contextmanager
    def write_on_included_file(self, f, name):
        fi = self.makefile(name)
        print >> f, '#include "%s"' % name
        yield fi
        fi.close()

    @contextlib.contextmanager
    def write_on_maybe_separate_source(self, f, name):
        print >> f, '/* %s */' % name
        if self.one_source_file:
            yield f
        else:
            fi = self.makefile(name)
            yield fi
            fi.close()

    def gen_readable_parts_of_source(self, f):
        split_criteria_big = SPLIT_CRITERIA
        if py.std.sys.platform != "win32":
            if self.database.gcpolicy.need_no_typeptr():
                pass    # XXX gcc uses toooooons of memory???
            else:
                split_criteria_big = SPLIT_CRITERIA * 4

        #
        # All declarations
        #
        with self.write_on_included_file(f, 'structdef.h') as fi:
            gen_structdef(fi, self.database)
        with self.write_on_included_file(f, 'forwarddecl.h') as fi:
            gen_forwarddecl(fi, self.database)
        with self.write_on_included_file(f, 'preimpl.h') as fi:
            gen_preimpl(fi, self.database)

        #
        # Implementation of functions and global structures and arrays
        #
        print >> f
        print >> f, '/***********************************************************/'
        print >> f, '/***  Implementations                                    ***/'
        print >> f

        print >> f, '#define PYPY_FILE_NAME "%s"' % os.path.basename(f.name)
        print >> f, '#include "src/g_include.h"'
        if self.database.reverse_debugger:
            print >> f, '#include "revdb_def.h"'
        print >> f

        nextralines = 11 + 1
        for name, nodeiter in self.splitnodesimpl('nonfuncnodes.c',
                                                   self.othernodes,
                                                   nextralines, 1):
            with self.write_on_maybe_separate_source(f, name) as fc:
                if fc is not f:
                    print >> fc, '/***********************************************************/'
                    print >> fc, '/***  Non-function Implementations                       ***/'
                    print >> fc
                    print >> fc, '#include "singleheader.h"'
                    print >> fc, '#include "src/g_include.h"'
                    print >> fc
                print >> fc, MARKER
                for node, impl in nodeiter:
                    print >> fc, '\n'.join(impl)
                    print >> fc, MARKER
                print >> fc, '/***********************************************************/'

        nextralines = 12
        for name, nodeiter in self.splitnodesimpl('implement.c',
                                                   self.funcnodes,
                                                   nextralines, 1,
                                                   split_criteria_big):
            with self.write_on_maybe_separate_source(f, name) as fc:
                if fc is not f:
                    print >> fc, '/***********************************************************/'
                    print >> fc, '/***  Implementations                                    ***/'
                    print >> fc
                    print >> fc, '#include "singleheader.h"'
                    print >> fc, '#define PYPY_FILE_NAME "%s"' % name
                    print >> fc, '#include "src/g_include.h"'
                    if self.database.reverse_debugger:
                        print >> fc, '#include "revdb_def.h"'
                    print >> fc
                print >> fc, MARKER
                for node, impl in nodeiter:
                    print >> fc, '\n'.join(impl)
                    print >> fc, MARKER
                print >> fc, '/***********************************************************/'
        print >> f


def gen_structdef(f, database):
    structdeflist = database.getstructdeflist()
    print >> f, '/***********************************************************/'
    print >> f, '/***  Structure definitions                              ***/'
    print >> f
    print >> f, "#ifndef _PYPY_STRUCTDEF_H"
    print >> f, "#define _PYPY_STRUCTDEF_H"
    for node in structdeflist:
        if hasattr(node, 'forward_decl'):
            if node.forward_decl:
                print >> f, node.forward_decl
        elif node.name is not None:
            print >> f, '%s %s;' % (node.typetag, node.name)
    print >> f
    for node in structdeflist:
        for line in node.definition():
            print >> f, line
    gen_threadlocal_structdef(f, database)
    print >> f, "#endif"

def gen_threadlocal_structdef(f, database):
    from rpython.translator.c.support import cdecl
    print >> f
    bk = database.translator.annotator.bookkeeper
    fields = list(bk.thread_local_fields)
    fields.sort(key=lambda field: field.fieldname)
    for field in fields:
        print >> f, ('#define RPY_TLOFS_%s  offsetof(' % field.fieldname +
                     'struct pypy_threadlocal_s, %s)' % field.fieldname)
    if fields:
        print >> f, '#define RPY_TLOFSFIRST  RPY_TLOFS_%s' % fields[0].fieldname
    else:
        print >> f, '#define RPY_TLOFSFIRST  sizeof(struct pypy_threadlocal_s)'
    print >> f, 'struct pypy_threadlocal_s {'
    print >> f, '\tint ready;'
    print >> f, '\tchar *stack_end;'
    print >> f, '\tstruct pypy_threadlocal_s *prev, *next;'
    # note: if the four fixed fields above are changed, you need
    # to adapt threadlocal.c's linkedlist_head declaration too
    for field in fields:
        typename = database.gettype(field.FIELDTYPE)
        print >> f, '\t%s;' % cdecl(typename, field.fieldname)
    print >> f, '};'
    print >> f

def gen_forwarddecl(f, database):
    print >> f, '/***********************************************************/'
    print >> f, '/***  Forward declarations                               ***/'
    print >> f
    print >> f, "#ifndef _PYPY_FORWARDDECL_H"
    print >> f, "#define _PYPY_FORWARDDECL_H"
    for node in database.globalcontainers():
        for line in node.forward_declaration():
            print >> f, line
    print >> f, "#endif"

def gen_preimpl(f, database):
    f.write('#ifndef _PY_PREIMPL_H\n#define _PY_PREIMPL_H\n')
    if database.translator is None or database.translator.rtyper is None:
        return
    preimplementationlines = pre_include_code_lines(
        database, database.translator.rtyper)
    for line in preimplementationlines:
        print >> f, line
    f.write('#endif /* _PY_PREIMPL_H */\n')

def gen_startupcode(f, database):
    # generate the start-up code and put it into a function
    print >> f, 'void RPython_StartupCode(void) {'

    for line in database.gcpolicy.gc_startup_code():
        print >> f,"\t" + line

    # put float infinities in global constants, we should not have so many of them for now to make
    # a table+loop preferable
    for dest, value in database.late_initializations:
        print >> f, "\t%s = %s;" % (dest, value)

    for node in database.containerlist:
        lines = list(node.startupcode())
        if lines:
            for line in lines:
                print >> f, '\t'+line

    for ll_init in database.translator._call_at_startup:
        print >> f, '\t%s();\t/* call_at_startup */' % (database.get(ll_init),)

    print >> f, '}'

def commondefs(defines):
    from rpython.rlib.rarithmetic import LONG_BIT, LONGLONG_BIT
    defines['PYPY_LONG_BIT'] = LONG_BIT
    defines['PYPY_LONGLONG_BIT'] = LONGLONG_BIT

def add_extra_files(database, eci):
    srcdir = py.path.local(__file__).join('..', 'src')
    files = [
        srcdir / 'entrypoint.c',       # ifdef PYPY_STANDALONE
        srcdir / 'mem.c',
        srcdir / 'exception.c',
        srcdir / 'rtyper.c',           # ifdef HAVE_RTYPER
        srcdir / 'support.c',
        srcdir / 'profiling.c',
        srcdir / 'debug_print.c',
        srcdir / 'debug_traceback.c',  # ifdef HAVE_RTYPER
        srcdir / 'asm.c',
        srcdir / 'instrument.c',
        srcdir / 'int.c',
        srcdir / 'stack.c',
        srcdir / 'threadlocal.c',
    ]
    if _CYGWIN:
        files.append(srcdir / 'cygwin_wait.c')
    if database.reverse_debugger:
        from rpython.translator.revdb import gencsupp
        files += gencsupp.extra_files()
    return eci.merge(ExternalCompilationInfo(separate_module_files=files))


def gen_source(database, modulename, targetdir,
               eci, defines={}, split=False):
    if isinstance(targetdir, str):
        targetdir = py.path.local(targetdir)

    filename = targetdir.join(modulename + '.c')
    f = filename.open('w')
    incfilename = targetdir.join('common_header.h')
    fi = incfilename.open('w')
    fi.write('#ifndef _PY_COMMON_HEADER_H\n#define _PY_COMMON_HEADER_H\n')

    #
    # Header
    #
    print >> f, '#include "common_header.h"'
    print >> f
    commondefs(defines)
    for key, value in defines.items():
        print >> fi, '#define %s %s' % (key, value)

    eci.write_c_header(fi)
    print >> fi, '#include "src/g_prerequisite.h"'
    fi.write('#endif /* _PY_COMMON_HEADER_H*/\n')

    fi.close()

    #
    # 1) All declarations
    # 2) Implementation of functions and global structures and arrays
    #
    sg = SourceGenerator(database)
    sg.set_strategy(targetdir, split)
    sg.gen_readable_parts_of_source(f)
    headers_to_precompile = sg.headers_to_precompile[:]
    headers_to_precompile.insert(0, incfilename)

    gen_startupcode(f, database)
    f.close()

    if 'PYPY_INSTRUMENT' in defines:
        fi = incfilename.open('a')
        n = database.instrument_ncounter
        print >>fi, "#define PYPY_INSTRUMENT_NCOUNTER %d" % n
        fi.close()
    if database.reverse_debugger:
        from rpython.translator.revdb import gencsupp
        gencsupp.write_revdb_def_file(database, targetdir.join('revdb_def.h'))

    eci = add_extra_files(database, eci)
    eci = eci.convert_sources_to_files()

    # create singleheader.h, which combines common_header.h, structdef.h,
    # forwarddecl.h and preimpl.h
    singleheader = targetdir.join('singleheader.h')
    with singleheader.open("w") as fs:
        for fn in "common_header structdef forwarddecl preimpl".split():
            fs.write("/*************** content of %s.h ***************/\n\n" % fn)
            with targetdir.join(fn + ".h").open("r") as f:
                fs.write(f.read())
            fs.write("\n\n")
    headers_to_precompile.insert(0, singleheader)

    return eci, filename, sg.getextrafiles(), headers_to_precompile

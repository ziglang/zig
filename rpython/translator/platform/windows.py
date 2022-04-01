"""Support for Windows."""

import py, os, sys, re, shutil

from rpython.translator.platform import CompilationError
from rpython.translator.platform import log, _run_subprocess
from rpython.translator.platform import Platform, posix

import rpython
rpydir = str(py.path.local(rpython.__file__).join('..'))

def _get_compiler_type(cc, x64_flag):
    if not cc:
        cc = os.environ.get('CC','')
    if not cc:
        return MsvcPlatform(x64=x64_flag)
    elif cc.startswith('mingw') or cc == 'gcc':
        return MingwPlatform(cc)
    return MsvcPlatform(cc=cc, x64=x64_flag)

def _get_vcver0():
    # try to get the compiler which served to compile python
    msc_pos = sys.version.find('MSC v.')
    if msc_pos != -1:
        msc_ver = int(sys.version[msc_pos+6:msc_pos+10])
        # 1500 -> 90, 1900 -> 140
        vsver = (msc_ver / 10) - 60
        return vsver
    return None

def Windows(cc=None):
    return _get_compiler_type(cc, False)

def Windows_x64(cc=None, ver0=None):
    #raise Exception("Win64 is not supported.  You must either build for Win32"
    #                " or contribute the missing support in PyPy.")
    return _get_compiler_type(cc, True)

def _find_vcvarsall(version, x64flag):
    import rpython.tool.setuptools_msvc as msvc
    if x64flag:
        arch = 'x64'
    else:
        arch = 'x86'
    if version >= 140:
        return msvc.msvc14_get_vc_env(arch)
    else:
        return msvc.msvc9_query_vcvarsall(version / 10.0, arch)

def _get_msvc_env(vsver, x64flag):
    vcdict = None
    toolsdir = None
    try:
        toolsdir = os.environ['VS%sCOMNTOOLS' % vsver]
    except KeyError:
        # use setuptools from python3 to find tools
        try:
            vcdict = _find_vcvarsall(vsver, x64flag)
        except ImportError as e:
            if 'setuptools' in str(e):
                log.error('is setuptools installed (perhaps try %s -mensurepip)?' % sys.executable)
            log.error('looking for compiler %s raised exception "%s' % (vsver, str(e)))
        except Exception as e:
            log.error('looking for compiler %s raised exception "%s' % (vsver, str(e)))
            return None
    else:
        if x64flag:
            vsinstalldir = os.path.abspath(os.path.join(toolsdir, '..', '..'))
            vcinstalldir = os.path.join(vsinstalldir, 'VC')
            vcbindir = os.path.join(vcinstalldir, 'BIN')
            vcvars = os.path.join(vcbindir, 'amd64', 'vcvarsamd64.bat')
        else:
            vcvars = os.path.join(toolsdir, 'vsvars32.bat')
            if not os.path.exists(vcvars):
                # even msdn does not know which to run
                # see https://msdn.microsoft.com/en-us/library/1700bbwd(v=vs.90).aspx
                # which names both
                vcvars = os.path.join(toolsdir, 'vcvars32.bat')

        import subprocess
        try:
            popen = subprocess.Popen('"%s" & set' % (vcvars,),
                                 stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE)

            stdout, stderr = popen.communicate()
            if popen.wait() != 0 or stdout[:5].lower() == 'error':
                log.msg('Running "%s" errored: \n\nstdout:\n%s\n\nstderr:\n%s' % (
                    vcvars, stdout.split()[0], stderr))
                return None
            else:
                log.msg('Running "%s" succeeded' %(vcvars,))
        except Exception as e:
            log.msg('Running "%s" failed: "%s"' % (vcvars, str(e)))
            return None

        stdout = stdout.replace("\r\n", "\n")
        vcdict = {}
        for line in stdout.split("\n"):
            if '=' not in line:
                continue
            key, value = line.split('=', 1)
            vcdict[key] = value
    env = {}
    for key, value in vcdict.items():
        if key.upper() in ['PATH', 'INCLUDE', 'LIB']:
            if sys.version_info[0] < 3:
                env[key.upper()] = value.encode('utf-8')
            else:
                env[key.upper()] = value
    if 'PATH' not in env:
        log.msg('Did not find "PATH" in stdout\n%s' %(stdout))
    if not _find_executable('mt.exe', env['PATH']):
        # For some reason the sdk bin path is missing?
        # put it together from some other env variables that happened to exist
        # on the buildbot where this occurred
        if 'WindowsSDKVersion' in vcdict and 'WindowsSdkDir' in vcdict:
            binpath = vcdict['WindowsSdkDir'] + '\\bin\\' + vcdict['WindowsSDKVersion'] + 'x86'
            env['PATH'] += ';' + binpath
        if not _find_executable('mt.exe', env['PATH']):
            log.msg('Could not find mt.exe on path=%s' % env['PATH'])
            log.msg('Running vsver %s set this env' % vsver)
            for key, value in vcdict.items():
                log.msg('%s=%s' %(key, value))
    log.msg("Updated environment with vsver %d, using x64 %s" % (vsver, x64flag,))
    return env

def find_msvc_env(x64flag=False, ver0=None):
    vcvers = [160, 150, 141, 140, 100, 90]
    if ver0 in vcvers:
        vcvers.insert(0, ver0)
    errs = []
    for vsver in vcvers:
        env = _get_msvc_env(vsver, x64flag)
        if env is not None:
            return env, vsver
    log.error("Could not find a Microsoft Compiler")
    # Assume that the compiler is already part of the environment

# copied from distutils.spawn
def _find_executable(executable, path=None):
    """Tries to find 'executable' in the directories listed in 'path'.

    A string listing directories separated by 'os.pathsep'; defaults to
    os.environ['PATH'].  Returns the complete filename or None if not found.
    """
    if path is None:
        path = os.environ['PATH']
    paths = path.split(os.pathsep)

    for ext in '.exe', '':
        newexe = executable + ext

        if os.path.isfile(newexe):
            return newexe
        else:
            for p in paths:
                f = os.path.join(p, newexe)
                if os.path.isfile(f):
                    # the file exists, we have a shot at spawn working
                    return f
    return None

class MsvcPlatform(Platform):
    name = "msvc"
    so_ext = 'dll'
    exe_ext = 'exe'

    relevant_environ = ('PATH', 'INCLUDE', 'LIB')

    cc = 'cl.exe'
    link = 'link.exe'
    make = 'nmake'
    if _find_executable('jom.exe'):
        make = 'jom.exe'

    cflags = ('/MD', '/O2', '/FS', '/Zi')
    # allow >2GB address space, set stack to 3MB (1MB is too small)
    link_flags = ('/nologo', '/debug','/LARGEADDRESSAWARE',
                  '/STACK:3145728', '/MANIFEST:EMBED')
    standalone_only = ()
    shared_only = ()
    environ = None

    def __init__(self, cc=None, x64=False, ver0=None):
        self.x64 = x64
        patch_os_env(self.externals)
        self.c_environ = os.environ.copy()
        if cc is None:
            msvc_compiler_environ, self.vsver = find_msvc_env(x64, ver0=ver0)
            Platform.__init__(self, 'cl.exe')
            if msvc_compiler_environ:
                self.c_environ.update(msvc_compiler_environ)
                self.version = "MSVC %s" % str(self.vsver)
                if self.vsver > 90:
                    tag = '14x'
                else:
                    tag = '%d' % self.vsver
                if x64:
                    self.externals_branch = 'win64_%s' % tag
                else:
                    self.externals_branch = 'win32_%s' % tag
        else:
            self.cc = cc

        # Try to find a masm assembler
        # Dilemma: raise now or later if masm is not found. Postponing the
        # exception means we can use a fake compiler for testing on linux
        # but may mean cryptic error messages and wasted build time.
        try:
            returncode, stdout, stderr = _run_subprocess(
                'ml.exe' if not x64 else 'ml64.exe', [], env=self.c_environ)
            r = re.search('Macro Assembler', stderr)
        except (EnvironmentError, OSError):
            r = None
            masm32 = "'Could not find ml.exe'"
            masm64 = "'Could not find ml.exe'"
        if r is None and os.path.exists('c:/masm32/bin/ml.exe'):
            masm32 = 'c:/masm32/bin/ml.exe'
            masm64 = 'c:/masm64/bin/ml64.exe'
        elif r:
            masm32 = 'ml.exe'
            masm64 = 'ml64.exe'

        if x64:
            self.masm = masm64
        else:
            self.masm = masm32

        # Install debug options only when interpreter is in debug mode
        if sys.executable.lower().endswith('_d.exe'):
            self.cflags = ['/MDd', '/Z7', '/Od']

            # Increase stack size, for the linker and the stack check code.
            stack_size = 8 << 20  # 8 Mb
            self.link_flags = self.link_flags + ('/STACK:%d' % stack_size,)
            # The following symbol is used in c/src/stack.h
            self.cflags.append('/DMAX_STACK_SIZE=%d' % (stack_size - 1024))

    def _includedirs(self, include_dirs):
        return ['/I%s' % (idir,) for idir in include_dirs]

    def _libs(self, libraries):
        libs = []
        for lib in libraries:
            lib = str(lib)
            if lib.endswith('.dll'):
                lib = lib[:-4]
            libs.append('%s.lib' % (lib,))
        return libs

    def _libdirs(self, library_dirs):
        return ['/LIBPATH:%s' % (ldir,) for ldir in library_dirs]

    def _linkfiles(self, link_files):
        return list(link_files)

    def _args_for_shared(self, args, **kwds):
        return ['/dll'] + args

    def check___thread(self):
        # __declspec(thread) does not seem to work when using assembler.
        # Returning False will cause the program to use TlsAlloc functions.
        # see src/thread_nt.h
        return False

    def _link_args_from_eci(self, eci, standalone):
        # Windows needs to resolve all symbols even for DLLs
        return super(MsvcPlatform, self)._link_args_from_eci(eci, standalone=True)

    def _compile_c_file(self, cc, cfile, compile_args):
        oname = self._make_o_file(cfile, ext='obj')
        # notabene: (tismer)
        # This function may be called for .c but also .asm files.
        # The c compiler accepts any order of arguments, while
        # the assembler still has the old behavior that all options
        # must come first, and after the file name all options are ignored.
        # So please be careful with the order of parameters! ;-)
        pdb_dir = oname.dirname
        if pdb_dir:
                compile_args = compile_args + ['/Fd%s\\' % (pdb_dir,)]
        args = ['/nologo', '/c'] + compile_args + ['/Fo%s' % (oname,), str(cfile)]
        self._execute_c_compiler(cc, args, oname)
        return oname

    def _link(self, cc, ofiles, link_args, standalone, exe_name):
        args = ['/nologo'] + [str(ofile) for ofile in ofiles] + link_args
        args += ['/out:%s' % (exe_name,), '/incremental:no']
        if not standalone:
            args = self._args_for_shared(args)

        # Tell the linker to embed a manifest with the default
        # UAC level asInvoker (Visual Studio 2008 +)
        args += ["/MANIFEST:EMBED"]

        self._execute_c_compiler(self.link, args, exe_name)

        return exe_name

    def _handle_error(self, returncode, stdout, stderr, outname):
        if returncode != 0:
            # Microsoft compilers write compilation errors to stdout
            stderr = stdout + stderr
            errorfile = outname.new(ext='errors')
            errorfile.write(stderr, mode='wb')
            if self.log_errors:
                stderrlines = stderr.splitlines()
                for line in stderrlines:
                    log.Error(line)
                # ^^^ don't use ERROR, because it might actually be fine.
                # Also, ERROR confuses lib-python/conftest.py.
            raise CompilationError(stdout, stderr)


    def gen_makefile(self, cfiles, eci, exe_name=None, path=None,
                     shared=False, headers_to_precompile=[],
                     no_precompile_cfiles = [], profopt=False, config=None):
        cfiles = self._all_cfiles(cfiles, eci)

        if path is None:
            path = cfiles[0].dirpath()

        rpypath = py.path.local(rpydir)
        m = NMakefile(path)

        if exe_name is None:
            exe_name = cfiles[0].new(ext='')
        if shared:
            so_name = exe_name.new(purebasename='lib' + exe_name.basename,
                                   ext=self.so_ext)
            wtarget_name = exe_name.new(purebasename=exe_name.basename + 'w',
                                   ext=self.exe_ext)
            target_name = so_name.basename
            m.so_name = path.join(target_name)
            m.wtarget_name = path.join(wtarget_name.basename)
            m.exe_name = path.join(exe_name.basename + '.' + self.exe_ext)
        else:
            target_name = exe_name.basename + '.' + self.exe_ext
            wtarget_name = exe_name.basename + 'w.' + self.exe_ext
            m.exe_name = path.join(target_name)
            m.wtarget_name = path.join(wtarget_name)

        m.eci = eci

        linkflags = list(self.link_flags)
        if shared:
            linkflags = self._args_for_shared(linkflags)
        linkflags += self._exportsymbols_link_flags()
        # Make sure different functions end up at different addresses!
        # This is required for the JIT.
        linkflags.append('/opt:noicf')

        def rpyrel(fpath):
            rel = py.path.local(fpath).relto(rpypath)
            if rel:
                return os.path.join('$(RPYDIR)', rel)
            else:
                return fpath

        rel_cfiles = [m.pathrel(cfile) for cfile in cfiles]
        rel_ofiles = [rel_cfile[:rel_cfile.rfind('.')]+'.obj' for rel_cfile in rel_cfiles]
        m.cfiles = rel_cfiles

        rel_includedirs = [rpyrel(incldir) for incldir in
                           self.preprocess_include_dirs(eci.include_dirs)]
        rel_libdirs = [rpyrel(libdir) for libdir in
                       self.preprocess_library_dirs(eci.library_dirs)]

        m.comment('automatically generated makefile')
        definitions = [
            ('RPYDIR', '"%s"' % rpydir),
            ('TARGET', target_name),
            ('DEFAULT_TARGET', m.exe_name.basename),
            ('SOURCES', rel_cfiles),
            ('OBJECTS', rel_ofiles),
            ('LIBS', self._libs(eci.libraries)),
            ('LIBDIRS', self._libdirs(rel_libdirs)),
            ('INCLUDEDIRS', self._includedirs(rel_includedirs)),
            ('CFLAGS', self.cflags),
            ('CFLAGSEXTRA', list(eci.compile_extra)),
            ('LDFLAGS', linkflags),
            ('LDFLAGSEXTRA', list(eci.link_extra)),
            ('CC', self.cc),
            ('CC_LINK', self.link),
            ('LINKFILES', eci.link_files),
            ('MASM', self.masm),
            ('MAKE', 'nmake.exe'),
            ('_WIN32', '1'),
            ]
        if shared:
            definitions.insert(0, ('WTARGET', wtarget_name.basename))
        if self.x64:
            definitions.append(('_WIN64', '1'))

        if shared and self.make == 'jom.exe':
            # Add `.SYNC` for jom.exe and get it to create
            # main.c, wmain.c in a separate step before trying to compile them
            rules = [('all',
                      'main.c wmain.c .SYNC $(DEFAULT_TARGET) .SYNC $(WTARGET)',
                      []),
                    ]
        else:
            rules = [('all', '$(DEFAULT_TARGET) $(WTARGET)', []),]
        rules += [
            ('.asm.obj', '', '$(MASM) /nologo /Fo$@ /c $< $(INCLUDEDIRS)'),
            ]

        if len(headers_to_precompile)>0:
            if shared:
                no_precompile_cfiles += [m.makefile_dir / 'main.c',
                                         m.makefile_dir / 'wmain.c']
            stdafx_h = path.join('stdafx.h')
            txt  = '#ifndef PYPY_STDAFX_H\n'
            txt += '#define PYPY_STDAFX_H\n'
            txt += '\n'.join(['#include "' + m.pathrel(c) + '"' for c in headers_to_precompile])
            txt += '\n#endif\n'
            stdafx_h.write(txt)
            stdafx_c = path.join('stdafx.c')
            stdafx_c.write('#include "stdafx.h"\n')
            definitions.append(('CREATE_PCH', '/Ycstdafx.h /Fpstdafx.pch /FIstdafx.h'))
            definitions.append(('USE_PCH', '/Yustdafx.h /Fpstdafx.pch /FIstdafx.h'))
            rules.append(('$(OBJECTS)', 'stdafx.pch', []))
            rules.append(('stdafx.pch', 'stdafx.h',
               '$(CC) stdafx.c /c /nologo $(CFLAGS) $(CFLAGSEXTRA) '
               '$(CREATE_PCH) $(INCLUDEDIRS)'))
            rules.append(('.c.obj', '',
                    '$(CC) /nologo $(CFLAGS) $(CFLAGSEXTRA) $(USE_PCH) '
                    '/Fo$@ /c $< $(INCLUDEDIRS)'))
            #Do not use precompiled headers for some files
            #rules.append((r'{..\module_cache}.c{..\module_cache}.obj', '',
            #        '$(CC) /nologo $(CFLAGS) $(CFLAGSEXTRA) /Fo$@ /c $< $(INCLUDEDIRS)'))
            # nmake cannot handle wildcard target specifications, so we must
            # create a rule for compiling each file from eci since they cannot use
            # precompiled headers :(
            no_precompile = []
            for f in list(no_precompile_cfiles):
                f = m.pathrel(py.path.local(f))
                if f not in no_precompile and (f.endswith('.c') or f.endswith('.cpp')):
                    no_precompile.append(f)
                    target = f[:f.rfind('.')] + '.obj'
                    rules.append((target, f,
                        '$(CC) /nologo $(CFLAGS) $(CFLAGSEXTRA) '
                        '/Fo%s /c %s $(INCLUDEDIRS)' %(target, f)))

        else:
            rules.append(('.c.obj', '',
                          '$(CC) /nologo $(CFLAGS) $(CFLAGSEXTRA) '
                          '/Fo$@ /c $< $(INCLUDEDIRS)'))
            if shared:
                rules.append(('main.obj', 'main.c',
                              '$(CC) /nologo $(CFLAGS) $(CFLAGSEXTRA) '
                              '/Fo$@ /c main.c $(INCLUDEDIRS)'))
                rules.append(('wmain.obj', 'wmain.c',
                              '$(CC) /nologo $(CFLAGS) $(CFLAGSEXTRA) '
                              '/Fo$@ /c wmain.c $(INCLUDEDIRS)'))

        icon = config.translation.icon if config else None
        manifest = config.translation.manifest if config else None
        if icon:
            shutil.copyfile(icon, str(path.join('icon.ico')))
            rc_file = path.join('icon.rc')
            rc_file.write('IDI_ICON1 ICON DISCARDABLE "icon.ico"')
            rules.append(('icon.res', 'icon.rc', 'rc icon.rc'))
        if manifest:
            shutil.copyfile(manifest, str(path.join('pypy.manifest')))


        for args in definitions:
            m.definition(*args)

        for rule in rules:
            m.rule(*rule)

        if len(headers_to_precompile) > 0:
            # at least from VS2013 onwards we need to include PCH
            # objects in the final link command
            linkobjs = 'stdafx.obj '
        else:
            linkobjs = ''
        if len(' '.join(rel_ofiles)) > 2048:
            # command line is limited in length, use a response file
            linkobjs += '@<<\n$(OBJECTS)\n<<'
        else:
            linkobjs += '$(OBJECTS)'
        extra_deps = []
        if icon and not shared:
            extra_deps.append('icon.res')
            linkobjs = 'icon.res ' + linkobjs
        if manifest and not shared:
            linkflags.append('/MANIFESTINPUT:pypy.manifest')
        m.rule('$(TARGET)', ['$(OBJECTS)'] + extra_deps,
                [ '$(CC_LINK) $(LDFLAGS) $(LDFLAGSEXTRA)' +
                  ' $(LINKFILES) /out:$@ $(LIBDIRS) $(LIBS) ' +
                  linkobjs,
                ])
        m.rule('debugmode_$(TARGET)', ['$(OBJECTS)'] + extra_deps,
                [ '$(CC_LINK) /DEBUG $(LDFLAGS) $(LDFLAGSEXTRA)' +
                  ' $(LINKFILES) /out:$@ $(LIBDIRS) $(LIBS) ' +
                  linkobjs,
                ])

        if shared:
            m.definition('SHARED_IMPORT_LIB', so_name.new(ext='lib').basename)
            m.definition('PYPY_MAIN_FUNCTION', "pypy_main_startup")
            m.rule('main.c', '',
                   'echo '
                   'int $(PYPY_MAIN_FUNCTION)(int, char*[]); '
                   'int main(int argc, char* argv[]) '
                   '{ return $(PYPY_MAIN_FUNCTION)(argc, argv); } > $@')
            deps = ['main.obj']
            m.rule('wmain.c', '',
                   ['echo #define WIN32_LEAN_AND_MEAN > $@.tmp',
                   'echo #include "stdlib.h" >> $@.tmp',
                   'echo #include "windows.h" >> $@.tmp',
                   'echo int $(PYPY_MAIN_FUNCTION)(int, char*[]); >> $@.tmp',
                   'echo int WINAPI WinMain( >> $@.tmp',
                   'echo     HINSTANCE hInstance,      /* handle to current instance */ >> $@.tmp',
                   'echo     HINSTANCE hPrevInstance,  /* handle to previous instance */ >> $@.tmp',
                   'echo     LPSTR lpCmdLine,          /* pointer to command line */ >> $@.tmp',
                   'echo     int nCmdShow              /* show state of window */ >> $@.tmp',
                   'echo ) >> $@.tmp',
                   'echo    { return $(PYPY_MAIN_FUNCTION)(__argc, __argv); } >> $@.tmp',
                   'move $@.tmp $@',
                   ])
            wdeps = ['wmain.obj']
            if icon:
                deps.append('icon.res')
                wdeps.append('icon.res')
            manifest_args = '/MANIFEST:EMBED'
            if manifest:
                manifest_args += ' /MANIFESTINPUT:pypy.manifest'
            m.rule('$(DEFAULT_TARGET)', ['$(TARGET)'] + deps,
                   ['$(CC_LINK) /DEBUG /LARGEADDRESSAWARE /STACK:3145728 ' +
                    ' '.join(deps) + ' $(SHARED_IMPORT_LIB) ' +
                    manifest_args + ' /out:$@ '
                    ])
            m.rule('$(WTARGET)', ['$(TARGET)'] + wdeps,
                   ['$(CC_LINK) /DEBUG /LARGEADDRESSAWARE /STACK:3145728 ' +
                    '/SUBSYSTEM:WINDOWS '  +
                    ' '.join(wdeps) + ' $(SHARED_IMPORT_LIB) ' +
                    manifest_args + ' /out:$@ '
                    ])
            m.rule('debugmode_$(DEFAULT_TARGET)', ['debugmode_$(TARGET)']+deps,
                   ['$(CC_LINK) /DEBUG /LARGEADDRESSAWARE /STACK:3145728 ' +
                    ' '.join(deps) + ' debugmode_$(SHARED_IMPORT_LIB) ' +
                    manifest_args + ' /out:$@ '
                    ])

        return m

    def execute_makefile(self, path_to_makefile, extra_opts=[]):
        if isinstance(path_to_makefile, NMakefile):
            path = path_to_makefile.makefile_dir
        else:
            path = path_to_makefile
        log.execute('%s %s in %s' % (self.make, " ".join(extra_opts), path))
        oldcwd = path.chdir()
        try:
            returncode, stdout, stderr = _run_subprocess(
                self.make,
                ['/nologo', '/f', str(path.join('Makefile'))] + extra_opts,
                env = self.c_environ)
        finally:
            oldcwd.chdir()

        self._handle_error(returncode, stdout, stderr, path.join('make'))

# These are the external libraries, created and maintained by get_externals.py
# The buildbot runs get_externals before building
def patch_os_env(externals = Platform.externals):
    #print 'adding %s to PATH, INCLUDE, LIB' % basepath
    binpath = externals + r'\bin'
    path = os.environ['PATH']
    if binpath not in path:
        path = binpath + ';' + path
        # make sure externals is in current path for tests and translating
        os.environ['PATH'] = path
    if externals not in os.environ.get('INCLUDE', ''):
        os.environ['INCLUDE'] = externals + r'\include;' + os.environ.get('INCLUDE', '')
    if externals not in os.environ.get('LIB', ''):
        os.environ['LIB'] = externals + r'\lib;' + os.environ.get('LIB', '')
    return None

class WinDefinition(posix.Definition):
    def write(self, f):
        def write_list(prefix, lst):
            lst = lst or ['']
            for i, fn in enumerate(lst):
                print >> f, prefix, fn,
                if i < len(lst)-1:
                    print >> f, '\\'
                else:
                    print >> f
                prefix = ' ' * len(prefix)
        name, value = self.name, self.value
        if isinstance(value, str):
            f.write('%s = %s\n' % (name, value))
        else:
            write_list('%s =' % (name,), value)
        f.write('\n')


class NMakefile(posix.GnuMakefile):
    def write(self, out=None):
        # nmake expands macros when it parses rules.
        # Write all macros before the rules.
        if out is None:
            f = self.makefile_dir.join('Makefile').open('w')
        else:
            f = out
        for line in self.lines:
            if not isinstance(line, posix.Rule):
                line.write(f)
        for line in self.lines:
            if isinstance(line, posix.Rule):
                line.write(f)
        f.flush()
        if out is None:
            f.close()

    def definition(self, name, value):
        defs = self.defs
        defn = WinDefinition(name, value)
        if name in defs:
            self.lines[defs[name]] = defn
        else:
            defs[name] = len(self.lines)
            self.lines.append(defn)

class MingwPlatform(posix.BasePosix):
    name = 'mingw32'
    standalone_only = ()
    shared_only = ()
    cflags = ('-O3',)
    link_flags = ()
    exe_ext = 'exe'
    so_ext = 'dll'

    def __init__(self, cc=None):
        if not cc:
            cc = 'gcc'
        Platform.__init__(self, cc)

    def _args_for_shared(self, args, **kwds):
        return ['-shared'] + args

    def _include_dirs_for_libffi(self):
        return []

    def _library_dirs_for_libffi(self):
        return []

    def _handle_error(self, returncode, stdout, stderr, outname):
        # Mingw tools write compilation errors to stdout
        super(MingwPlatform, self)._handle_error(
            returncode, '', stderr + stdout, outname)

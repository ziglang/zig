#!/usr/bin/env python
from __future__ import print_function
""" packages PyPy, provided that it's already built.
It uses 'pypy/goal/pypy%d.%d-c' and parts of the rest of the working
copy.  Usage:

    package.py [--options] --archive-name=pypy-VER-PLATFORM

The output is found in the directory from --builddir,
by default /tmp/usession-YOURNAME/build/.

For a list of all options, see 'package.py --help'.
"""

import shutil
import sys
import os
#Add toplevel repository dir to sys.path
basedir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0,basedir)
import py
import fnmatch
import subprocess
import platform
from pypy.tool.release.smartstrip import smartstrip
from pypy.tool.release.make_portable import make_portable


def get_arch():
    if sys.platform in ('win32', 'darwin'):
        return sys.platform
    else:
        return platform.uname()[-1]

ARCH = get_arch()


USE_ZIPFILE_MODULE = ARCH == 'win32'

STDLIB_VER = "3"
POSIX_EXE = 'pypy3.9'


from lib_pypy.pypy_tools.build_cffi_imports import (create_cffi_import_libraries,
        MissingDependenciesError, cffi_build_scripts)

def ignore_patterns(*patterns):
    """Function that can be used as copytree() ignore parameter.

    Patterns is a sequence of glob-style patterns
    that are used to exclude files"""
    def _ignore_patterns(path, names):
        ignored_names = []
        for pattern in patterns:
            ignored_names.extend(fnmatch.filter(names, pattern))
        return set(ignored_names)
    return _ignore_patterns

def copytree(src, dst, ignore=None):
    """Recursively copy a directory tree using shtuil.copy2().

    If exception(s) occur, an Error is raised with a list of reasons.

    The optional ignore argument is a callable. If given, it
    is called with the `src` parameter, which is the directory
    being visited by copytree(), and `names` which is the list of
    `src` contents, as returned by os.listdir():

        callable(src, names) -> ignored_names

    Since copytree() is called recursively, the callable will be
    called once for each directory that is copied. It returns a
    list of names relative to the `src` directory that should
    not be copied.

    XXX Derived from shutil.copytree, but allow dst dir to exist

    """
    names = os.listdir(src)
    if ignore is not None:
        ignored_names = ignore(src, names)
    else:
        ignored_names = set()

    if not os.path.isdir(dst):
        os.makedirs(dst)
    errors = []
    for name in names:
        if name in ignored_names:
            continue
        srcname = os.path.join(src, name)
        dstname = os.path.join(dst, name)
        try:
            if os.path.isdir(srcname):
                copytree(srcname, dstname, ignore)
            else:
                # Will raise a SpecialFileError for unsupported file types
                shutil.copy2(srcname, dstname)
        # catch the Error from the recursive copytree so that we can
        # continue with other files
        except Error as err:
            errors.extend(err.args[0])
        except EnvironmentError as why:
            errors.append((srcname, dstname, str(why)))
    try:
        shutil.copystat(src, dst)
    except OSError as why:
        if WindowsError is not None and isinstance(why, WindowsError):
            # Copying file access times may fail on Windows
            pass
        else:
            errors.append((src, dst, str(why)))
    if errors:
        raise Error(errors)



class PyPyCNotFound(Exception):
    pass

def fix_permissions(dirname):
    if ARCH != 'win32':
        os.system("chmod -R a+rX %s" % dirname)
        os.system("chmod -R g-w %s" % dirname)


def get_python_ver(pypy_c, quiet=False):
    kwds = {'universal_newlines': True}
    if quiet:
        kwds['stderr'] = subprocess.NULL
    ver = subprocess.check_output([str(pypy_c), '-c',
             'import sysconfig as s; print(s.get_python_version())'], **kwds)
    return ver.strip()

def get_platlibdir(pypy_c, quiet=False):
    kwds = {'universal_newlines': True}
    if quiet:
        kwds['stderr'] = subprocess.NULL
    ver = subprocess.check_output([str(pypy_c), '-c',
             'import sysconfig as s; print(s.get_config_var("platlibdir"))'], **kwds)
    return ver.strip()

    
def generate_sysconfigdata(pypy_c, stdlib):
    """Create a _sysconfigdata_*.py file that is platform specific and can be
    parsed by non-python tools. Used in cross-platform package building and
    when calling sysconfig.get_config_var
    """
    if ARCH == 'win32':
        return
    # run ./config.guess to add the HOST_GNU_TYPE (copied from CPython, 
    # apparently useful for the crossenv package)
    config_guess = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                'config.guess')
    try:
        host_gnu_type = subprocess.check_output([config_guess]).strip()
    except Exception:
        host_gnu_type = "unkown"

     # this creates a _sysconfigdata_*.py file in some directory, the name
    # of the directory is written into pybuilddir.txt
    subprocess.check_call([str(pypy_c), '-m' 'sysconfig',
                           '--generate-posix-vars',
                           # Use PyPy-specific extension to get HOST_GNU_TYPE
                           'HOST_GNU_TYPE', host_gnu_type])
    with open('pybuilddir.txt') as fid:
        dirname = fid.read().strip()
    assert os.path.exists(dirname)
    sysconfigdata_names = os.listdir(dirname)
    # what happens if there is more than one file?
    assert len(sysconfigdata_names) == 1
    shutil.copy(os.path.join(dirname, sysconfigdata_names[0]), stdlib)
    shutil.rmtree(dirname)
       
        
    
                

def create_package(basedir, options, _fake=False):
    retval = 0
    name = options.name
    if not name:
        name = 'pypy-nightly'
    assert '/' not in name
    rename_pypy_c = options.pypy_c
    override_pypy_c = options.override_pypy_c

    basedir = py.path.local(basedir)
    if not override_pypy_c:
        basename = POSIX_EXE + '-c'
        if ARCH == 'win32':
            basename += '.exe'
        pypy_c = basedir.join('pypy', 'goal', basename)
    else:
        pypy_c = py.path.local(override_pypy_c)
    if not _fake and not pypy_c.check():
        raise PyPyCNotFound(
            'Expected but did not find %s.'
            ' Please compile pypy first, using translate.py,'
            ' or check that you gave the correct path'
            ' with --override_pypy_c' % pypy_c)
    builddir = py.path.local(options.builddir)
    pypydir = builddir.ensure(name, dir=True)
    if _fake:
        python_ver = '3.9'
    else:
        python_ver = get_python_ver(pypy_c)
    IMPLEMENTATION = 'pypy{}'.format(python_ver)
    if ARCH == 'win32':
        target = pypydir.join('Lib')
    elif _fake:
        target = pypydir.join('lib', IMPLEMENTATION)
    else:
        target = pypydir.join(get_platlibdir(pypy_c), IMPLEMENTATION)
    os.makedirs(str(target))
    if not _fake:
        generate_sysconfigdata(pypy_c, str(target))
    if ARCH == 'win32':
        os.environ['PATH'] = str(basedir.join('externals').join('bin')) + ';' + \
                            os.environ.get('PATH', '')
    if not options.no_cffi:
        failures = create_cffi_import_libraries(
            str(pypy_c), options, str(basedir),
            embed_dependencies=options.embed_dependencies,
        )

        for key, module in failures:
            print("""!!!!!!!!!!\nBuilding {0} bindings failed.
                You can either install development headers package,
                add the --without-{0} option to skip packaging this
                binary CFFI extension, or say --without-cffi.""".format(key),
                file=sys.stderr)
        if len(failures) > 0:
            return 1, None

    if ARCH == 'win32' and not rename_pypy_c.lower().endswith('.exe'):
        rename_pypy_c += '.exe'
    binaries = [(pypy_c, rename_pypy_c, None)]

    if (ARCH != 'win32' and    # handled below
        not _fake and os.path.getsize(str(pypy_c)) < 500000):
        # This 'pypy_c' is very small, so it means it relies on a so/dll
        # If it would be bigger, it wouldn't.  That's a hack.
        if ARCH.startswith('darwin'):
            ext = 'dylib'
        else:
            ext = 'so'
        libpypy_name = 'lib' + POSIX_EXE + '-c.' + ext
        libpypy_c = pypy_c.new(basename=libpypy_name)
        if not libpypy_c.check():
            raise PyPyCNotFound('Expected pypy to be mostly in %r, but did '
                                'not find it' % (str(libpypy_c),))
        binaries.append((libpypy_c, libpypy_name, None))
    #

    includedir = basedir.join('include')
    copytree(str(includedir), str(pypydir.join('include')))
    pypydir.ensure('include', dir=True)

    if ARCH == 'win32':
        src, tgt, _ = binaries[0]
        pypyw = src.new(purebasename=src.purebasename + 'w')
        if pypyw.exists():
            tgt = py.path.local(tgt)
            binaries.append((pypyw, tgt.new(purebasename=tgt.purebasename + 'w').basename, None))
            print("Picking %s" % str(pypyw))
            binaries.append((pypyw, 'pythonw.exe', None))
            print('Picking {} as pythonw.exe'.format(pypyw))
            binaries.append((pypyw, 'pypyw.exe', None))
            print('Picking {} as pypyw.exe'.format(pypyw))
        binaries.append((src, 'python.exe', None))
        print('Picking {} as python.exe'.format(src))
        binaries.append((src, 'pypy.exe', None))
        print('Picking {} as pypy.exe'.format(src))
        binaries.append((src, 'pypy{}.exe'.format(python_ver), None))
        print('Picking {} as pypy{}.exe'.format(src, python_ver))
        binaries.append((src, 'python{}.exe'.format(python_ver), None))
        print('Picking {} as python{}.exe'.format(src, python_ver))
        binaries.append((src, 'pypy{}.exe'.format(python_ver[0]), None))
        print('Picking {} as pypy{}.exe'.format(src, python_ver[0]))
        binaries.append((src, 'python{}.exe'.format(python_ver[0]), None))
        print('Picking {} as python{}.exe'.format(src, python_ver[0]))
        # Can't rename a DLL
        win_extras = [('lib' + POSIX_EXE + '-c.dll', None),
                      ('sqlite3.dll', target),
                      ('libffi-8.dll', None),
                     ]
        if not options.no__tkinter:
            tkinter_dir = target.join('_tkinter')
            win_extras += [('tcl86t.dll', tkinter_dir), ('tk86t.dll', tkinter_dir)]
            # for testing, copy the dlls to the `base_dir` as well
            tkinter_dir = basedir.join('lib_pypy', '_tkinter')
            win_extras += [('tcl86t.dll', tkinter_dir), ('tk86t.dll', tkinter_dir)]
        for extra, target_dir in win_extras:
            p = pypy_c.dirpath().join(extra)
            if not p.check():
                p = py.path.local.sysfind(extra)
                if not p:
                    print("%s not found, expect trouble if this "
                          "is a shared build" % (extra,))
                    continue
            print("Picking %s" % p)
            binaries.append((p, p.basename, target_dir))
        libsdir = basedir.join('libs')
        if libsdir.exists():
            print('Picking %s (and contents)' % libsdir)
            copytree(str(libsdir), str(pypydir.join('libs')))
        else:
            if not _fake:
                raise RuntimeError('"libs" dir with import library not found.')
            # XXX users will complain that they cannot compile capi (cpyext)
            # modules for windows, also embedding pypy (i.e. in cffi)
            # will fail.
            # Has the lib moved, was translation not 'shared', or are
            # there no exported functions in the dll so no import
            # library was created?
        if not options.no__tkinter:
            try:
                p = pypy_c.dirpath().join('tcl86t.dll')
                if not p.check():
                    p = py.path.local.sysfind('tcl86t.dll')
                    if p is None:
                        raise WindowsError("tcl86t.dll not found")
                tktcldir = p.dirpath().join('..').join('lib')
                copytree(str(tktcldir), str(pypydir.join('tcl')))
            except WindowsError:
                print("Packaging Tk runtime failed. tk86t.dll and tcl86t.dll "
                      "found in %s, expecting to find runtime in %s directory "
                      "next to the dlls, as per build "
                      "instructions." %(p, tktcldir), file=sys.stderr)
                import traceback;traceback.print_exc()
                raise MissingDependenciesError('Tk runtime')

    print('* Binaries:', [source.relto(str(basedir))
                          for source, dst, target_dir in binaries])

    copytree(str(basedir.join('lib-python').join(STDLIB_VER)),
                    str(target),
                    ignore=ignore_patterns('.svn', 'py', '*.pyc', '*~','__pycache__'))
    # Careful: to copy lib_pypy, copying just the hg-tracked files
    # would not be enough: there are also build artifacts like cffi-generated
    # dynamic libs
    copytree(str(basedir.join('lib_pypy')), str(target),
                    ignore=ignore_patterns('.svn', 'py', '*.pyc', '*~',
                                           '*_cffi.c', '*.o', '*.pyd-*', '*.obj',
                                           '*.lib', '*.exp', '*.manifest', '__pycache__'))
    for file in ['README.rst',]:
        shutil.copy(str(basedir.join(file)), str(pypydir))
    # Use original LICENCE file
    base_file = str(basedir.join('LICENSE'))
    with open(base_file) as fid:
        license = fid.read()
    with open(str(pypydir.join('LICENSE')), 'w') as LICENSE:
        LICENSE.write(license)
    #
    spdir = target.ensure('site-packages', dir=True)
    shutil.copy(str(basedir.join('lib', IMPLEMENTATION, 'site-packages', 'README')),
                str(spdir))
    #
    if ARCH == 'win32':
        bindir = pypydir
    else:
        bindir = pypydir.join('bin')
        bindir.ensure(dir=True)
    for source, dst, target_dir in binaries:
        if target_dir:
            archive = target_dir.join(dst)
        else:
            archive = bindir.join(dst)
        if not _fake:
            shutil.copy(str(source), str(archive))
        else:
            open(str(archive), 'wb').close()
        os.chmod(str(archive), 0o755)
    if not _fake and not ARCH == 'win32':
        # create a link to pypy, python
        old_dir = os.getcwd()
        os.chdir(str(bindir))
        try:
            os.symlink(POSIX_EXE, 'pypy')
            # os.symlink(POSIX_EXE, 'pypy{}'.format(python_ver))
            os.symlink(POSIX_EXE, 'pypy{}'.format(python_ver[0]))
            os.symlink(POSIX_EXE, 'python')
            os.symlink(POSIX_EXE, 'python{}'.format(python_ver))
            os.symlink(POSIX_EXE, 'python{}'.format(python_ver[0]))
        finally:
            os.chdir(old_dir)
    fix_permissions(pypydir)

    old_dir = os.getcwd()
    try:
        os.chdir(str(builddir))
        if not _fake:
            for source, dst, target_dir in binaries:
                if target_dir:
                    archive = target_dir.join(dst)
                else:
                    archive = bindir.join(dst)
                smartstrip(archive, keep_debug=options.keep_debug)

            # make the package portable by adding rpath=$ORIGIN/..lib,
            # bundling dependencies
            if options.make_portable:
                os.chdir(str(name))
                if not os.path.exists('lib'):
                    os.mkdir('lib')
                make_portable(copytree, python_ver)
                os.chdir(str(builddir))
        if USE_ZIPFILE_MODULE:
            import zipfile
            archive = str(builddir.join(name + '.zip'))
            zf = zipfile.ZipFile(archive, 'w',
                                 compression=zipfile.ZIP_DEFLATED)
            for (dirpath, dirnames, filenames) in os.walk(name):
                for fnname in filenames:
                    filename = os.path.join(dirpath, fnname)
                    zf.write(filename)
            zf.close()
        else:
            archive = str(builddir.join(name + '.tar.bz2'))
            if ARCH == 'darwin':
                print("Warning: tar on current platform does not suport "
                      "overriding the uid and gid for its contents. The tarball "
                      "will contain your uid and gid. If you are building the "
                      "actual release for the PyPy website, you may want to be "
                      "using another platform...", file=sys.stderr)
                e = os.system('tar --numeric-owner -cjf ' + archive + " " + name)
            elif sys.platform.startswith('freebsd'):
                e = os.system('tar --uname=root --gname=wheel -cjf ' + archive + " " + name)
            elif sys.platform == 'cygwin':
                e = os.system('tar --owner=Administrator --group=Administrators --numeric-owner -cjf ' + archive + " " + name)
            else:
                e = os.system('tar --owner=root --group=root --numeric-owner -cjf ' + archive + " " + name)
            if e:
                raise OSError('"tar" returned exit status %r' % e)
    finally:
        os.chdir(old_dir)
    if options.targetdir:
        tdir = os.path.normpath(options.targetdir)
        adir = os.path.dirname(archive)
        if tdir != adir:
            print("Copying %s to %s" % (archive, options.targetdir))
            shutil.copy(archive, options.targetdir)
    print("Ready in %s" % (builddir,))
    return retval, builddir # for tests

def package(*args, **kwds):
    import argparse

    class NegateAction(argparse.Action):
        def __init__(self, option_strings, dest, nargs=0, **kwargs):
            super(NegateAction, self).__init__(option_strings, dest, nargs,
                                               **kwargs)

        def __call__(self, parser, ns, values, option):
            setattr(ns, self.dest, option[2:4] != 'no')

    if ARCH == 'win32':
        pypy_exe = POSIX_EXE + '.exe'
    else:
        pypy_exe = POSIX_EXE
    parser = argparse.ArgumentParser()
    args = list(args)
    if args:
        args[0] = str(args[0])
    for key, module in sorted(cffi_build_scripts.items()):
        if module is not None:
            parser.add_argument('--without-' + key,
                    dest='no_' + key,
                    action='store_true',
                    help='do not build and package the %r cffi module' % (key,))
    parser.add_argument('--without-cffi', dest='no_cffi', action='store_true',
        help='skip building *all* the cffi modules listed above')
    parser.add_argument('--no-keep-debug', dest='keep_debug',
                        action='store_false', help='do not keep debug symbols')
    parser.add_argument('--rename_pypy_c', dest='pypy_c', type=str, default=pypy_exe,
        help='target executable name, defaults to "%s"' % pypy_exe)
    parser.add_argument('--archive-name', dest='name', type=str, default='',
        help='pypy-VER-PLATFORM')
    parser.add_argument('--builddir', type=str, default='',
        help='tmp dir for packaging')
    parser.add_argument('--targetdir', type=str, default='',
        help='destination dir for archive')
    parser.add_argument('--override_pypy_c', type=str, default='',
        help='use as pypy3 exe, default is %s' % POSIX_EXE)
    parser.add_argument('--embedded-dependencies', '--no-embedded-dependencies',
                        dest='embed_dependencies',
                        action=NegateAction,
                        default=(ARCH in ('darwin', 'aarch64', 'x86_64')),
                        help='whether to embed dependencies in CFFI modules '
                        '(default on OS X)')
    parser.add_argument('--make-portable', '--no-make-portable',
                        dest='make_portable',
                        action=NegateAction,
                        default=(ARCH in ('darwin',)),
                        help='make the package portable by shipping '
                            'dependent shared objects and mangling RPATH')
    options = parser.parse_args(args)

    if "PYPY_PACKAGE_NOKEEPDEBUG" in os.environ:
        options.keep_debug = False
    if "PYPY_PACKAGE_WITHOUTTK" in os.environ:
        options.no__tkinter = True
    if "PYPY_EMBED_DEPENDENCIES" in os.environ:
        options.embed_dependencies = True
    elif "PYPY_NO_EMBED_DEPENDENCIES" in os.environ:
        options.embed_dependencies = False
    if "PYPY_MAKE_PORTABLE" in os.environ:
        options.make_portable = True
    if not options.builddir:
        # The import actually creates the udir directory
        from rpython.tool.udir import udir
        options.builddir = udir.ensure("build", dir=True)
    else:
        # if a user provides a path it must be converted to a local file system path
        # otherwise ensure in create_package will fail
        options.builddir = py.path.local(options.builddir)
    assert '/' not in options.pypy_c
    return create_package(basedir, options, **kwds)


if __name__ == '__main__':
    import sys
    if ARCH == 'win32':
        # Try to avoid opeing a dialog box if one of the
        # subprocesses causes a system error
        import ctypes
        winapi = ctypes.windll.kernel32
        SetErrorMode = winapi.SetErrorMode
        SetErrorMode.argtypes=[ctypes.c_int]

        SEM_FAILCRITICALERRORS = 1
        SEM_NOGPFAULTERRORBOX  = 2
        SEM_NOOPENFILEERRORBOX = 0x8000
        flags = SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX
        #Since there is no GetErrorMode, do a double Set
        old_mode = SetErrorMode(flags)
        SetErrorMode(old_mode | flags)

    retval, _ = package(*sys.argv[1:])
    sys.exit(retval)

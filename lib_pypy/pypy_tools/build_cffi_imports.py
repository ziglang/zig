from __future__ import print_function
import collections
import hashlib
import os
import platform
import shutil
import sys
import sysconfig
import tempfile
from os.path import join

try:
    import _multiprocessing
except ImportError:
    # The only function we need from multiprocessing is cpu_count(), which is
    # written in the pure Python part of multiprocessing. We can make it work
    # in environments that don't have _multiprocessing by adding an empty
    # module in place of _multiprocessing.
    import types
    sys.modules['_multiprocessing'] = types.ModuleType('fake _multiprocessing')
import multiprocessing

# do not use the long-running runsubprocess._run here, since building some of
# the extensions enable importing them later
os.environ['PYPY_DONT_RUN_SUBPROCESS'] = '1'

class MissingDependenciesError(Exception):
    pass


cffi_build_scripts = collections.OrderedDict([
    ("_ctypes._ctypes_cffi",
     "_ctypes/_ctypes_build.py" if sys.platform == 'darwin' else None),
    ("_pypy_util_cffi_inner", "_pypy_util_build.py"), # this needs to come before ssl
    ("_blake2", "_blake2/_blake2_build.py"),
    ("_ssl", "_ssl_build.py"),
    ("sqlite3", "_sqlite3_build.py"),
    ("audioop", "_audioop_build.py"),
    ("_tkinter", "_tkinter/tklib_build.py"),
    ("curses", "_curses_build.py" if sys.platform != "win32" else None),
    ("syslog", "_syslog_build.py" if sys.platform != "win32" else None),
    ("_gdbm", "_gdbm_build.py"  if sys.platform != "win32" else None),
    ("grp", "_pwdgrp_build.py" if sys.platform != "win32" else None),
    ("resource", "_resource_build.py" if sys.platform != "win32" else None),
    ("lzma", "_lzma_build.py"),
    # ("_decimal", "_decimal_build.py"),  # issue 3024
    ("_sha3", "_sha3/_sha3_build.py"),
    ("xx", None),    # for testing: 'None' should be completely ignored
    ("_posixshmem", "_posixshmem_build.py" if sys.platform != "win32" else None),
    ])

# for distribution, we may want to fetch dependencies not provided by
# the OS, such as a recent openssl/libressl.
curdir = os.path.abspath(os.path.dirname(__file__))
deps_destdir = os.path.join(curdir, 'dest')
configure_args = ['./configure',
            '--prefix=/usr',
            '--disable-shared',
            '--enable-silent-rules',
            '--disable-dependency-tracking',
        ]
# please note the deliberate use of a mirror site: we can't use HTTPS
# without an _ssl module, but the OpenSSL download site redirect HTTP
# to HTTPS
cffi_dependencies = {
    '_ssl1': ('http://artfiles.org/openssl.org/source/openssl-1.1.1n.tar.gz',
             '40dceb51a4f6a5275bde0e6bf20ef4b91bfc32ed57c0552e2e8e15463372b17a',
             [
              ['./config', '--prefix=/usr', 'no-shared'],
              ['make', '-s', '-j', str(multiprocessing.cpu_count())],
              ['make', 'install', 'DESTDIR={}/'.format(deps_destdir)],
             ]),
    '_ssl3': ('http://artfiles.org/openssl.org/source/openssl-3.0.1.tar.gz',
              'c311ad853353bce796edad01a862c50a8a587f62e7e2100ef465ab53ec9b06d1',
              [
               ['./config', '--prefix=/usr', 'no-shared', 'enable-fips'],
               ['make', '-s', '-j', str(multiprocessing.cpu_count())],
               ['make', 'install', 'DESTDIR={}/'.format(deps_destdir)],
              ]),
}
cffi_dependencies['_ssl'] = cffi_dependencies['_ssl1']

if sys.platform == 'darwin' or platform.machine() == 'aarch64':
    # TODO: use these on x86 after upgrading Docker images to manylinux2014
    cffi_dependencies['_gdbm'] = (
              # this does not compile on the x86 buildbot, linker is missing '_history_list'
              'http://distfiles.macports.org/gdbm/gdbm-1.19.tar.gz',
              '37ed12214122b972e18a0d94995039e57748191939ef74115b1d41d8811364bc',
              [configure_args + ['--without-readline'],
              ['make', '-s', '-j', str(multiprocessing.cpu_count())],
              ['make', 'install', 'DESTDIR={}/'.format(deps_destdir)],
             ])
    cffi_dependencies['lzma'] = (
              # this does not compile on the linux64 buildbot, needs -fPIC
             'http://distfiles.macports.org/xz/xz-5.2.5.tar.bz2',
             '5117f930900b341493827d63aa910ff5e011e0b994197c3b71c08a20228a42df',
             [configure_args,
              ['make', '-s', '-j', str(multiprocessing.cpu_count())],
              ['make', 'install', 'DESTDIR={}/'.format(deps_destdir)],
             ])

def _unpack_tarfile(filename, extract_dir):
    """Unpack tar/tar.gz/tar.bz2/tar.xz `filename` to `extract_dir`
    """
    import tarfile  # late import for breaking circular dependency
    try:
        tarobj = tarfile.open(filename)
    except tarfile.TarError:
        raise ReadError(
            "%s is not a compressed or uncompressed tar file" % filename)
    try:
        tarobj.extractall(extract_dir)
    finally:
        tarobj.close()

def _sha256(filename):
    dgst = hashlib.sha256()

    with open(filename, 'rb') as fp:
        dgst.update(fp.read())
    return dgst.hexdigest()


def _build_dependency(name, patches=[]):
    import shutil
    from rpython.tool.runsubprocess import run_subprocess

    try:
        from urllib.request import urlretrieve
    except ImportError:
        from urllib import urlretrieve

    try:
        url, dgst, build_cmds = cffi_dependencies[name]
    except KeyError:
        return 0, None, None

    archive_dir = os.path.join(tempfile.gettempdir(), 'pypy-archives')

    if not os.path.isdir(archive_dir):
        os.makedirs(archive_dir)

    archive = os.path.join(archive_dir, url.rsplit('/', 1)[-1])

    # next, fetch the archive to disk, if needed
    if not os.path.exists(archive) or _sha256(archive) != dgst:
        print('fetching archive', url, file=sys.stderr)
        urlretrieve(url, archive)

    # make sure the hash matches
    if _sha256(archive) != dgst:
        return 1, '{} archive {} hash mismatch'.format(name, archive), ''

    shutil.rmtree(deps_destdir, ignore_errors=True)
    os.makedirs(deps_destdir)

    # extract the into our destination directory
    print('unpacking archive', archive, file=sys.stderr)
    _unpack_tarfile(archive, deps_destdir)

    sources = os.path.join(
        deps_destdir,
        os.path.basename(archive).rsplit('.', 2)[0],
    )

    # apply any patches
    if patches:
        for patch in patches:
            print('applying patch', patch, file=sys.stderr)
            status, stdout, stderr = run_subprocess(
                '/usr/bin/patch', ['-p1', '-i', patch], cwd=sources,
            )

            if status != 0:
                return status, stdout, stderr
    env = os.environ
    if sys.platform == 'darwin':
        target = sysconfig.get_config_var('MACOSX_DEPLOYMENT_TARGET')
        if target:
            # override the value for building support libraries
            env = os.environ.copy()
            env['MACOSX_DEPLOYMENT_TARGET'] = target
            print('setting MACOSX_DEPLOYMENT_TARGET to "{}"'.format(target))
        
    for args in build_cmds:
        print('running', ' '.join(args), 'in', sources, file=sys.stderr)
        status, stdout, stderr = run_subprocess(args[0], args[1:],
                                                cwd=sources, env=env)
        if status != 0:
            break
    return status, stdout, stderr

def create_cffi_import_libraries(pypy_c, options, basedir, only=None,
                                 embed_dependencies=False, rebuild=False):
    """
    Entry point for building the cffi c-extension modules. 
    pypy_c is a pypy3 interpreter
    options is the parsed options
    basedir is the pypy-source base directory
    embed_dependencies will download and build the external libraries in
        cffi_dependencies and link to them statically
    rebuild will force rebuilding a module
    only will only build the modules in that list rather than all in cffi_build_scripts
    """
    from rpython.tool.runsubprocess import run_subprocess
    print('calling create_cffi_import_libraries with "embed_dependencies"', embed_dependencies)

    shutil.rmtree(str(join(basedir,'lib_pypy','__pycache__')),
                  ignore_errors=True)
    pypy3 = str(pypy_c)
    env = os.environ
    if sys.platform == 'win32':
        externals_path = os.path.abspath(os.path.join(basedir, 'externals'))
        # Needed for buildbot builds. On conda this is not needed. 
        if os.path.exists(externals_path):
            env = os.environ.copy()
            env['INCLUDE'] = externals_path + r'\include;' + env.get('INCLUDE', '')
            env['LIB'] = externals_path + r'\lib;' + env.get('LIB', '')
            env['PATH'] = externals_path + r'\bin;' + env.get('PATH', '')
    else:
        # normally, this would be correctly added by setuptools/distutils, but
        # we moved this for python3.8, and the ensurepip setuptools has not
        # caught up yet. It needs at least setuptools-58.2 in ensurepip
        status, stdout, stderr = run_subprocess(str(pypy_c), ['-c', 'from sysconfig import get_config_var as gcv; print(gcv("INCLUDEPY"))'])
        stdout = stdout.decode('utf-8')
        if status != 0:
            print("stdout:")
            print(stdout)
            print("stderr:")
            print(stderr.decode('utf-8'))
            return list(cffi_build_scripts.items())
        include_path = stdout.strip()
        env['CFLAGS'] = ' '.join(('-fPIC', '-I' + include_path, env.get('CFLAGS', '')))
    status, stdout, stderr = run_subprocess(pypy3, ['-c', 'import setuptools'])
    if status  != 0:
        status, stdout, stderr = run_subprocess(pypy3, ['-m', 'ensurepip'])
    failures = []

    for key, module in cffi_build_scripts.items():
        if only and key not in only:
            print("* SKIPPING", key, '(not specified in --only)')
            continue
        if module is None or getattr(options, 'no_' + key, False):
            continue
        if not rebuild:
            # the key is the module name, has it already been built?
            status, stdout, stderr = run_subprocess(pypy3,
                                         ['-c', 'import %s' % key], env=env)
            if status  == 0:
                print('*', ' %s already built' % key, file=sys.stderr)
                continue

        if module.endswith('.py'):
            args = [module]
            cwd = str(join(basedir,'lib_pypy'))
        else:
            args = ['-c', 'import ' + module]
            cwd = None

        print('*', ' '.join(args), file=sys.stderr)
        if embed_dependencies and key in cffi_dependencies:
            status, stdout, stderr = _build_dependency(key)
            if status != 0:
                failures.append((key, module))
                print("stdout:")
                print(stdout.decode('utf-8'))
                print("stderr:")
                print(stderr.decode('utf-8'))
                continue

            env['CPPFLAGS'] = '-I{}/usr/include {}'.format(
                            deps_destdir, env.get('CPPFLAGS', ''))
            env['LDFLAGS'] = '-L{}/usr/lib64 -L{}/usr/lib {}'.format(
                            deps_destdir, deps_destdir, env.get('LDFLAGS', ''))

        try:
            status, bld_stdout, bld_stderr = run_subprocess(str(pypy_c), args,
                                                    cwd=cwd, env=env)
            if status != 0:
                print("stdout:")
                print(stdout.decode('utf-8'), file=sys.stderr)
                print("stderr:")
                print(bld_stderr.decode('utf-8'), file=sys.stderr)
                raise RuntimeError('building {} failed'.format(key))
        except:
            import traceback;traceback.print_exc()
            failures.append((key, module))
        else:
            # Make sure it worked
            test_script = "print('testing {0}'); import {0}".format(key)
            if sys.platform == 'win32': 
                externals_path = os.path.abspath(os.path.join(basedir, 'externals'))
                test_script = ("import os; os.add_dll_directory(r'" +
                               externals_path + r'\bin'  + "');" + test_script)
            status, stdout, stderr = run_subprocess(pypy3, ['-c', test_script],
                                                    env=env)
            if status != 0:
                failures.append((key, module))
                print("build stdout:")
                print(bld_stdout.decode('utf-8'), file=sys.stderr)
                print("build stderr:")
                print(bld_stderr.decode('utf-8'), file=sys.stderr)
                print("test stdout:")
                print(stdout.decode('utf-8'), file=sys.stderr)
                print("test stderr:")
                print(stderr.decode('utf-8'), file=sys.stderr)
        if os.path.exists(deps_destdir):
            shutil.rmtree(deps_destdir, ignore_errors=True)
    return failures

if __name__ == '__main__':
    import argparse
    if '__pypy__' not in sys.builtin_module_names:
        print('Call with a pypy interpreter', file=sys.stderr)
        sys.exit(1)

    tool_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
    lib_pypy_dir = os.path.dirname(os.path.dirname(tool_dir))
    sys.path.insert(0, lib_pypy_dir)

    class Options(object):
        pass

    parser = argparse.ArgumentParser(description='Build all cffi backends in lib_pypy')
    parser.add_argument('--exefile', dest='exefile', default=sys.executable,
                        help='instead of executing sys.executable' \
                             ' you can specify an alternative pypy vm here')
    parser.add_argument('--rebuild', dest='rebuild', action='store_true',
        help='Rebuild the module even if it already appears to have been built.')
    parser.add_argument('--only', dest='only', default=None,
                        help='Only build the modules delimited by a comma e.g. _ssl,sqlite')
    parser.add_argument('--embed-dependencies', dest='embed_dependencies', action='store_true',
        help='embed dependencies for distribution')
    args = parser.parse_args()

    exename = join(os.getcwd(), args.exefile)
    basedir = exename

    while not os.path.exists(join(basedir,'lib_pypy')):
        _basedir = os.path.dirname(basedir)
        if _basedir == basedir:
            raise ValueError('interpreter %s not inside pypy repo', 
                                 str(exename))
        basedir = _basedir
    options = Options()
    if args.only is None:
        only = None
    else:
        only = set(args.only.split(','))
    olddir = os.getcwd()
    os.chdir(lib_pypy_dir)
    try:
        failures = create_cffi_import_libraries(exename, options, basedir,
                        only=only, embed_dependencies=args.embed_dependencies,
                        rebuild=args.rebuild)
    finally:
        os.chdir(olddir)
    if len(failures) > 0:
        print('*** failed to build the CFFI modules %r' % (
            [f[1] for f in failures],), file=sys.stderr)
        print('''
PyPy can still be used as long as you don't need the corresponding
modules.  If you do need them, please install the missing headers and
libraries (see error messages just above) and then re-run the command:

    %s %s
''' % (sys.executable, ' '.join(sys.argv)), file=sys.stderr)
        sys.exit(1)

    if len(sys.argv) > 1 and sys.argv[1] == '--test':
        # monkey patch a failure, just to test
        print('This line should be followed by a traceback', file=sys.stderr)
        for k in cffi_build_scripts:
            setattr(options, 'no_' + k, True)
        must_fail = '_missing_build_script.py'
        assert not os.path.exists(str(join(join(basedir,'lib_pypy'),must_fail)))
        cffi_build_scripts['should_fail'] = must_fail
        failures = create_cffi_import_libraries(exename, options, basedir, only=only)
        assert len(failures) == 1

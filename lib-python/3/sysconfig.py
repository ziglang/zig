"""Access to Python's configuration information."""

import os
import sys
from os.path import pardir, realpath

__all__ = [
    'get_config_h_filename',
    'get_config_var',
    'get_config_vars',
    'get_makefile_filename',
    'get_path',
    'get_path_names',
    'get_paths',
    'get_platform',
    'get_python_version',
    'get_scheme_names',
    'parse_config_h',
]

# Keys for get_config_var() that are never converted to Python integers.
_ALWAYS_STR = {
    'MACOSX_DEPLOYMENT_TARGET',
}

_INSTALL_SCHEMES = {
    'posix_prefix': {
        'stdlib': '{installed_base}/{platlibdir}/{implementation_lower}{py_version_short}',
        'platstdlib': '{platbase}/{platlibdir}/{implementation_lower}{py_version_short}',
        'purelib': '{base}/lib/{implementation_lower}{py_version_short}/site-packages',
        'platlib': '{platbase}/{platlibdir}/{implementation_lower}{py_version_short}/site-packages',
        'include':
            '{installed_base}/include/{implementation_lower}{py_version_short}{abiflags}',
        'platinclude':
            '{installed_platbase}/include/{implementation_lower}{py_version_short}{abiflags}',
        'scripts': '{base}/bin',
        'data': '{base}',
        },
    'posix_home': {
        'stdlib': '{installed_base}/lib/{implementation_lower}',
        'platstdlib': '{base}/lib/{implementation_lower}',
        'purelib': '{base}/lib/{implementation_lower}',
        'platlib': '{base}/lib/{implementation_lower}',
        'include': '{installed_base}/include/{implementation_lower}',
        'platinclude': '{installed_base}/include/{implementation_lower}',
        'scripts': '{base}/bin',
        'data': '{base}',
        },
    'nt': {
        'stdlib': '{installed_base}/Lib',
        'platstdlib': '{base}/Lib',
        'purelib': '{base}/Lib/site-packages',
        'platlib': '{base}/Lib/site-packages',
        'include': '{installed_base}/Include',
        'platinclude': '{installed_base}/Include',
        'scripts': '{base}/Scripts',
        'data': '{base}',
        },
    'nt_user': {
        'stdlib': '{userbase}/{implementation}{py_version_nodot}',
        'platstdlib': '{userbase}/{implementation}{py_version_nodot}',
        'purelib': '{userbase}/{implementation}{py_version_nodot}/site-packages',
        'platlib': '{userbase}/{implementation}{py_version_nodot}/site-packages',
        'include': '{userbase}/{implementation}{py_version_nodot}/Include',
        'scripts': '{userbase}/{implementation}{py_version_nodot}/Scripts',
        'data': '{userbase}',
        },
    'posix_user': {
        'stdlib': '{userbase}/{platlibdir}/{implementation_lower}{py_version_short}',
        'platstdlib': '{userbase}/{platlibdir}/{implementation_lower}{py_version_short}',
        'purelib': '{userbase}/lib/{implementation_lower}{py_version_short}/site-packages',
        'platlib': '{userbase}/{platlibdir}/{implementation_lower}{py_version_short}/site-packages',
        'include': '{userbase}/include/{implementation_lower}{py_version_short}',
        'scripts': '{userbase}/bin',
        'data': '{userbase}',
        },
    'osx_framework_user': {
        'stdlib': '{userbase}/lib/{implementation_lower}',
        'platstdlib': '{userbase}/lib/{implementation_lower}',
        'purelib': '{userbase}/lib/{implementation_lower}/site-packages',
        'platlib': '{userbase}/lib/{implementation_lower}/site-packages',
        'include': '{userbase}/include',
        'scripts': '{userbase}/bin',
        'data': '{userbase}',
        },
    }

_SCHEME_KEYS = ('stdlib', 'platstdlib', 'purelib', 'platlib', 'include',
                'scripts', 'data')

_PY_VERSION = sys.version.split()[0]
_PY_VERSION_SHORT = '%d.%d' % sys.version_info[:2]
_PY_VERSION_SHORT_NO_DOT = '%d%d' % sys.version_info[:2]
_PREFIX = os.path.normpath(sys.prefix)
_BASE_PREFIX = os.path.normpath(sys.base_prefix)
_EXEC_PREFIX = os.path.normpath(sys.exec_prefix)
_BASE_EXEC_PREFIX = os.path.normpath(sys.base_exec_prefix)
_CONFIG_VARS = None
_USER_BASE = None


# NOTE: site.py has copy of this function.
# Sync it when modify this function.
def _get_implementation():
    if sys.implementation.name == 'pypy':
        return 'PyPy'
    return 'Python'

def _safe_realpath(path):
    try:
        return realpath(path)
    except OSError:
        return path

if sys.executable:
    _PROJECT_BASE = os.path.dirname(_safe_realpath(sys.executable))
else:
    # sys.executable can be empty if argv[0] has been changed and Python is
    # unable to retrieve the real program name
    _PROJECT_BASE = _safe_realpath(os.getcwd())

if (os.name == 'nt' and
    _PROJECT_BASE.lower().endswith(('\\pcbuild\\win32', '\\pcbuild\\amd64'))):
    _PROJECT_BASE = _safe_realpath(os.path.join(_PROJECT_BASE, pardir, pardir))

# set for cross builds
if "_PYTHON_PROJECT_BASE" in os.environ:
    _PROJECT_BASE = _safe_realpath(os.environ["_PYTHON_PROJECT_BASE"])

def _is_python_source_dir(d):
    for fn in ("Setup", "Setup.local"):
        if os.path.isfile(os.path.join(d, "Modules", fn)):
            return True
    return False

_sys_home = getattr(sys, '_home', None)

if os.name == 'nt':
    def _fix_pcbuild(d):
        if d and os.path.normcase(d).startswith(
                os.path.normcase(os.path.join(_PREFIX, "PCbuild"))):
            return _PREFIX
        return d
    _PROJECT_BASE = _fix_pcbuild(_PROJECT_BASE)
    _sys_home = _fix_pcbuild(_sys_home)

def is_python_build(check_home=False):
    if check_home and _sys_home:
        return _is_python_source_dir(_sys_home)
    return _is_python_source_dir(_PROJECT_BASE)

_PYTHON_BUILD = is_python_build(True)

if _PYTHON_BUILD:
    for scheme in ('posix_prefix', 'posix_home'):
        _INSTALL_SCHEMES[scheme]['include'] = '{srcdir}/Include'
        _INSTALL_SCHEMES[scheme]['platinclude'] = '{projectbase}/.'


def _subst_vars(s, local_vars):
    try:
        return s.format(**local_vars)
    except KeyError as var:
        try:
            return s.format(**os.environ)
        except KeyError:
            raise AttributeError('{%s}' % var) from None

def _extend_dict(target_dict, other_dict):
    target_keys = target_dict.keys()
    for key, value in other_dict.items():
        if key in target_keys:
            continue
        target_dict[key] = value


def _expand_vars(scheme, vars):
    res = {}
    if vars is None:
        vars = {}
    _extend_dict(vars, get_config_vars())

    for key, value in _INSTALL_SCHEMES[scheme].items():
        if os.name in ('posix', 'nt'):
            value = os.path.expanduser(value)
        res[key] = os.path.normpath(_subst_vars(value, vars))
    return res


def _get_default_scheme():
    if os.name == 'posix':
        # the default scheme for posix is posix_prefix
        return 'posix_prefix'
    return os.name


# NOTE: site.py has copy of this function.
# Sync it when modify this function.
def _getuserbase():
    env_base = os.environ.get("PYTHONUSERBASE", None)
    if env_base:
        return env_base

    def joinuser(*args):
        return os.path.expanduser(os.path.join(*args))

    if os.name == "nt":
        base = os.environ.get("APPDATA") or "~"
        return joinuser(base, _get_implementation())

    if sys.platform == "darwin" and sys._framework:
        return joinuser("~", "Library", sys._framework,
                        "%d.%d" % sys.version_info[:2])

    return joinuser("~", ".local")


def _parse_makefile(filename, vars=None):
    """Parse a Makefile-style file.

    A dictionary containing name/value pairs is returned.  If an
    optional dictionary is passed in as the second argument, it is
    used instead of a new dictionary.
    """
    # Regexes needed for parsing Makefile (and similar syntaxes,
    # like old-style Setup files).
    import re
    _variable_rx = re.compile(r"([a-zA-Z][a-zA-Z0-9_]+)\s*=\s*(.*)")
    _findvar1_rx = re.compile(r"\$\(([A-Za-z][A-Za-z0-9_]*)\)")
    _findvar2_rx = re.compile(r"\${([A-Za-z][A-Za-z0-9_]*)}")

    if vars is None:
        vars = {}
    done = {}
    notdone = {}

    with open(filename, errors="surrogateescape") as f:
        lines = f.readlines()

    for line in lines:
        if line.startswith('#') or line.strip() == '':
            continue
        m = _variable_rx.match(line)
        if m:
            n, v = m.group(1, 2)
            v = v.strip()
            # `$$' is a literal `$' in make
            tmpv = v.replace('$$', '')

            if "$" in tmpv:
                notdone[n] = v
            else:
                try:
                    if n in _ALWAYS_STR:
                        raise ValueError

                    v = int(v)
                except ValueError:
                    # insert literal `$'
                    done[n] = v.replace('$$', '$')
                else:
                    done[n] = v

    # do variable interpolation here
    variables = list(notdone.keys())

    # Variables with a 'PY_' prefix in the makefile. These need to
    # be made available without that prefix through sysconfig.
    # Special care is needed to ensure that variable expansion works, even
    # if the expansion uses the name without a prefix.
    renamed_variables = ('CFLAGS', 'LDFLAGS', 'CPPFLAGS')

    while len(variables) > 0:
        for name in tuple(variables):
            value = notdone[name]
            m1 = _findvar1_rx.search(value)
            m2 = _findvar2_rx.search(value)
            if m1 and m2:
                m = m1 if m1.start() < m2.start() else m2
            else:
                m = m1 if m1 else m2
            if m is not None:
                n = m.group(1)
                found = True
                if n in done:
                    item = str(done[n])
                elif n in notdone:
                    # get it on a subsequent round
                    found = False
                elif n in os.environ:
                    # do it like make: fall back to environment
                    item = os.environ[n]

                elif n in renamed_variables:
                    if (name.startswith('PY_') and
                        name[3:] in renamed_variables):
                        item = ""

                    elif 'PY_' + n in notdone:
                        found = False

                    else:
                        item = str(done['PY_' + n])

                else:
                    done[n] = item = ""

                if found:
                    after = value[m.end():]
                    value = value[:m.start()] + item + after
                    if "$" in after:
                        notdone[name] = value
                    else:
                        try:
                            if name in _ALWAYS_STR:
                                raise ValueError
                            value = int(value)
                        except ValueError:
                            done[name] = value.strip()
                        else:
                            done[name] = value
                        variables.remove(name)

                        if name.startswith('PY_') \
                        and name[3:] in renamed_variables:

                            name = name[3:]
                            if name not in done:
                                done[name] = value

            else:
                # bogus variable reference (e.g. "prefix=$/opt/python");
                # just drop it since we can't deal
                done[name] = value
                variables.remove(name)

    # strip spurious spaces
    for k, v in done.items():
        if isinstance(v, str):
            done[k] = v.strip()

    # save the results in the global dictionary
    vars.update(done)
    return vars


def get_makefile_filename():
    """Return the path of the Makefile."""
    if _PYTHON_BUILD:
        return os.path.join(_sys_home or _PROJECT_BASE, "Makefile")
    if hasattr(sys, 'abiflags'):
        config_dir_name = 'config-%s%s' % (_PY_VERSION_SHORT, sys.abiflags)
    else:
        config_dir_name = 'config'
    if hasattr(sys.implementation, '_multiarch'):
        config_dir_name += '-%s' % sys.implementation._multiarch
    return os.path.join(get_path('stdlib'), config_dir_name, 'Makefile')


def _get_sysconfigdata_name():
    return os.environ.get('_PYTHON_SYSCONFIGDATA_NAME',
        '_sysconfigdata_{abi}_{platform}_{multiarch}'.format(
        abi=sys.abiflags,
        platform=sys.platform,
        multiarch=getattr(sys.implementation, '_multiarch', ''),
    ))


def _generate_posix_vars(args):
    """Generate the Python module containing build-time variables."""
    import pprint
    vars = {}
    if sys.implementation.name == 'pypy':
        import _sysconfigdata
        vars = _sysconfigdata.build_time_vars
    else:
        # load the installed Makefile:
        makefile = get_makefile_filename()
        try:
            _parse_makefile(makefile, vars)
        except OSError as e:
            msg = "invalid Python installation: unable to open %s" % makefile
            if hasattr(e, "strerror"):
                msg = msg + " (%s)" % e.strerror
            raise OSError(msg)
        # load the installed pyconfig.h:
        config_h = get_config_h_filename()
        try:
            with open(config_h) as f:
                parse_config_h(f, vars)
        except OSError as e:
            msg = "invalid Python installation: unable to open %s" % config_h
            if hasattr(e, "strerror"):
                msg = msg + " (%s)" % e.strerror
            raise OSError(msg)
        # On AIX, there are wrong paths to the linker scripts in the Makefile
        # -- these paths are relative to the Python source, but when installed
        # the scripts are in another directory.
        if _PYTHON_BUILD:
            vars['BLDSHARED'] = vars['LDSHARED']

    if args:
        # PyPy extension: they should be key, value pairs
        for k, v in zip(args[::2], args[1::2]):
            vars[k] = v
    # There's a chicken-and-egg situation on OS X with regards to the
    # _sysconfigdata module after the changes introduced by #15298:
    # get_config_vars() is called by get_platform() as part of the
    # `make pybuilddir.txt` target -- which is a precursor to the
    # _sysconfigdata.py module being constructed.  Unfortunately,
    # get_config_vars() eventually calls _init_posix(), which attempts
    # to import _sysconfigdata, which we won't have built yet.  In order
    # for _init_posix() to work, if we're on Darwin, just mock up the
    # _sysconfigdata module manually and populate it with the build vars.
    # This is more than sufficient for ensuring the subsequent call to
    # get_platform() succeeds.
    name = _get_sysconfigdata_name()
    if 'darwin' in sys.platform:
        import types
        module = types.ModuleType(name)
        module.build_time_vars = vars
        sys.modules[name] = module

    pybuilddir = 'build/lib.%s-%s' % (get_platform(), _PY_VERSION_SHORT)
    if hasattr(sys, "gettotalrefcount"):
        pybuilddir += '-pydebug'
    os.makedirs(pybuilddir, exist_ok=True)
    destfile = os.path.join(pybuilddir, name + '.py')

    with open(destfile, 'w', encoding='utf8') as f:
        f.write('# system configuration generated and used by'
                ' the sysconfig module\n')
        f.write('build_time_vars = ')
        pprint.pprint(vars, stream=f)

    # Create file used for sys.path fixup -- see Modules/getpath.c
    with open('pybuilddir.txt', 'w', encoding='utf8') as f:
        f.write(pybuilddir)

def _init_posix(vars):
    """Initialize the module as appropriate for POSIX systems."""
    # CPython: _sysconfigdata_* is generated at build time, see _generate_posix_vars()
    # name = _get_sysconfigdata_name()
    # PyPy: _sysconfigdata is a dynamic module (uses sys to determine values),
    #       while _sysconfigdata_* is a static version of the same values
    #       generated by calling _generate_posix_vars as part of packaging.py.
    #       To prevent chicken-and-egg problems of needing the values before
    #       generating them, use the dynamic version here.
    name = os.environ.get('_PYTHON_SYSCONFIGDATA_NAME', '_sysconfigdata')
    _temp = __import__(name, globals(), locals(), ['build_time_vars'], 0)
    build_time_vars = _temp.build_time_vars
    vars.update(build_time_vars)

def _init_non_posix(vars):
    """Initialize the module as appropriate for NT"""
    # set basic install directories
    import _imp
    vars['LIBDEST'] = get_path('stdlib')
    vars['BINLIBDEST'] = get_path('platstdlib')
    vars['INCLUDEPY'] = get_path('include')
    vars['EXT_SUFFIX'] = _imp.extension_suffixes()[0]
    vars['EXE'] = '.exe'
    vars['VERSION'] = _PY_VERSION_SHORT_NO_DOT
    vars['BINDIR'] = os.path.dirname(_safe_realpath(sys.executable))
    # pypy: give us control over the ABI tag in a wheel name
    so_ext = _imp.extension_suffixes()[0]
    vars['SOABI']= '-'.join(so_ext.split('.')[1].split('-')[:2])

#
# public APIs
#


def parse_config_h(fp, vars=None):
    """Parse a config.h-style file.

    A dictionary containing name/value pairs is returned.  If an
    optional dictionary is passed in as the second argument, it is
    used instead of a new dictionary.
    """
    if vars is None:
        vars = {}
    import re
    define_rx = re.compile("#define ([A-Z][A-Za-z0-9_]+) (.*)\n")
    undef_rx = re.compile("/[*] #undef ([A-Z][A-Za-z0-9_]+) [*]/\n")

    while True:
        line = fp.readline()
        if not line:
            break
        m = define_rx.match(line)
        if m:
            n, v = m.group(1, 2)
            try:
                if n in _ALWAYS_STR:
                    raise ValueError
                v = int(v)
            except ValueError:
                pass
            vars[n] = v
        else:
            m = undef_rx.match(line)
            if m:
                vars[m.group(1)] = 0
    return vars


def get_config_h_filename():
    """Return the path of pyconfig.h."""
    if _PYTHON_BUILD:
        if os.name == "nt":
            inc_dir = os.path.join(_sys_home or _PROJECT_BASE, "PC")
        else:
            inc_dir = _sys_home or _PROJECT_BASE
    else:
        inc_dir = get_path('platinclude')
    return os.path.join(inc_dir, 'pyconfig.h')


def get_scheme_names():
    """Return a tuple containing the schemes names."""
    return tuple(sorted(_INSTALL_SCHEMES))


def get_path_names():
    """Return a tuple containing the paths names."""
    return _SCHEME_KEYS


def get_paths(scheme=_get_default_scheme(), vars=None, expand=True):
    """Return a mapping containing an install scheme.

    ``scheme`` is the install scheme name. If not provided, it will
    return the default scheme for the current platform.
    """
    if expand:
        return _expand_vars(scheme, vars)
    else:
        return _INSTALL_SCHEMES[scheme]


def get_path(name, scheme=_get_default_scheme(), vars=None, expand=True):
    """Return a path corresponding to the scheme.

    ``scheme`` is the install scheme name.
    """
    return get_paths(scheme, vars, expand)[name]


def get_config_vars(*args):
    """With no arguments, return a dictionary of all configuration
    variables relevant for the current platform.

    On Unix, this means every variable defined in Python's installed Makefile;
    On Windows it's a much smaller set.

    With arguments, return a list of values that result from looking up
    each argument in the configuration variable dictionary.
    """
    global _CONFIG_VARS
    if _CONFIG_VARS is None:
        _CONFIG_VARS = {}
        # Normalized versions of prefix and exec_prefix are handy to have;
        # in fact, these are the standard versions used most places in the
        # Distutils.
        _CONFIG_VARS['prefix'] = _PREFIX
        _CONFIG_VARS['exec_prefix'] = _EXEC_PREFIX
        _CONFIG_VARS['py_version'] = _PY_VERSION
        _CONFIG_VARS['py_version_short'] = _PY_VERSION_SHORT
        _CONFIG_VARS['py_version_nodot'] = _PY_VERSION_SHORT_NO_DOT
        _CONFIG_VARS['installed_base'] = _BASE_PREFIX
        _CONFIG_VARS['base'] = _PREFIX
        _CONFIG_VARS['installed_platbase'] = _BASE_EXEC_PREFIX
        _CONFIG_VARS['platbase'] = _EXEC_PREFIX
        _CONFIG_VARS['projectbase'] = _PROJECT_BASE
        _CONFIG_VARS['platlibdir'] = sys.platlibdir
        try:
            _CONFIG_VARS['abiflags'] = sys.abiflags
        except AttributeError:
            # sys.abiflags may not be defined on all platforms.
            _CONFIG_VARS['abiflags'] = ''
        _CONFIG_VARS['implementation'] = _get_implementation()
        _CONFIG_VARS['implementation_lower'] = _get_implementation().lower()
        _CONFIG_VARS['LIBRARY'] = ''

        if os.name == 'nt':
            _init_non_posix(_CONFIG_VARS)
            _CONFIG_VARS['TZPATH'] = ''
        if os.name == 'posix':
            _init_posix(_CONFIG_VARS)
        # For backward compatibility, see issue19555
        SO = _CONFIG_VARS.get('EXT_SUFFIX')
        if SO is not None:
            _CONFIG_VARS['SO'] = SO
        # Setting 'userbase' is done below the call to the
        # init function to enable using 'get_config_var' in
        # the init-function.
        _CONFIG_VARS['userbase'] = _getuserbase()

        # Always convert srcdir to an absolute path
        srcdir = _CONFIG_VARS.get('srcdir', _PROJECT_BASE)
        if os.name == 'posix':
            if sys.implementation.name == 'pypy':
                pass
            elif _PYTHON_BUILD:
                # If srcdir is a relative path (typically '.' or '..')
                # then it should be interpreted relative to the directory
                # containing Makefile.
                base = os.path.dirname(get_makefile_filename())
                srcdir = os.path.join(base, srcdir)
            else:
                # srcdir is not meaningful since the installation is
                # spread about the filesystem.  We choose the
                # directory containing the Makefile since we know it
                # exists.
                srcdir = os.path.dirname(get_makefile_filename())
        _CONFIG_VARS['srcdir'] = _safe_realpath(srcdir)

        # OS X platforms require special customization to handle
        # multi-architecture, multi-os-version installers
        if sys.platform == 'darwin':
            import _osx_support
            _osx_support.customize_config_vars(_CONFIG_VARS)

    if args:
        vals = []
        for name in args:
            vals.append(_CONFIG_VARS.get(name))
        return vals
    else:
        return _CONFIG_VARS


def get_config_var(name):
    """Return the value of a single variable using the dictionary returned by
    'get_config_vars()'.

    Equivalent to get_config_vars().get(name)
    """
    if name == 'SO':
        import warnings
        warnings.warn('SO is deprecated, use EXT_SUFFIX', DeprecationWarning, 2)
    return get_config_vars().get(name)


def get_platform():
    """Return a string that identifies the current platform.

    This is used mainly to distinguish platform-specific build directories and
    platform-specific built distributions.  Typically includes the OS name and
    version and the architecture (as supplied by 'os.uname()'), although the
    exact information included depends on the OS; on Linux, the kernel version
    isn't particularly important.

    Examples of returned values:
       linux-i586
       linux-alpha (?)
       solaris-2.6-sun4u

    Windows will return one of:
       win-amd64 (64bit Windows on AMD64 (aka x86_64, Intel64, EM64T, etc)
       win32 (all others - specifically, sys.platform is returned)

    For other non-POSIX platforms, currently just returns 'sys.platform'.

    """
    if os.name == 'nt':
        if 'amd64' in sys.version.lower():
            return 'win-amd64'
        if '(arm)' in sys.version.lower():
            return 'win-arm32'
        if '(arm64)' in sys.version.lower():
            return 'win-arm64'
        return sys.platform

    if os.name != "posix" or not hasattr(os, 'uname'):
        # XXX what about the architecture? NT is Intel or Alpha
        return sys.platform

    # Set for cross builds explicitly
    if "_PYTHON_HOST_PLATFORM" in os.environ:
        return os.environ["_PYTHON_HOST_PLATFORM"]

    # Try to distinguish various flavours of Unix
    osname, host, release, version, machine = os.uname()

    # Convert the OS name to lowercase, remove '/' characters, and translate
    # spaces (for "Power Macintosh")
    osname = osname.lower().replace('/', '')
    machine = machine.replace(' ', '_')
    machine = machine.replace('/', '-')

    if osname[:5] == "linux":
        # At least on Linux/Intel, 'machine' is the processor --
        # i386, etc.
        # XXX what about Alpha, SPARC, etc?
        return  "%s-%s" % (osname, machine)
    elif osname[:5] == "sunos":
        if release[0] >= "5":           # SunOS 5 == Solaris 2
            osname = "solaris"
            release = "%d.%s" % (int(release[0]) - 3, release[2:])
            # We can't use "platform.architecture()[0]" because a
            # bootstrap problem. We use a dict to get an error
            # if some suspicious happens.
            bitness = {2147483647:"32bit", 9223372036854775807:"64bit"}
            machine += ".%s" % bitness[sys.maxsize]
        # fall through to standard osname-release-machine representation
    elif osname[:3] == "aix":
        from _aix_support import aix_platform
        return aix_platform()
    elif osname[:6] == "cygwin":
        osname = "cygwin"
        import re
        rel_re = re.compile(r'[\d.]+')
        m = rel_re.match(release)
        if m:
            release = m.group()
    elif osname[:6] == "darwin":
        import _osx_support
        osname, release, machine = _osx_support.get_platform_osx(
                                            get_config_vars(),
                                            osname, release, machine)

    return "%s-%s-%s" % (osname, release, machine)


def get_python_version():
    return _PY_VERSION_SHORT


def _print_dict(title, data):
    for index, (key, value) in enumerate(sorted(data.items())):
        if index == 0:
            print('%s: ' % (title))
        print('\t%s = "%s"' % (key, value))


def _main():
    """Display all information sysconfig detains."""
    if '--generate-posix-vars' in sys.argv:
        _generate_posix_vars(sys.argv[2:])
        return
    print('Platform: "%s"' % get_platform())
    print('Python version: "%s"' % get_python_version())
    print('Current installation scheme: "%s"' % _get_default_scheme())
    print()
    _print_dict('Paths', get_paths())
    print()
    _print_dict('Variables', get_config_vars())
    print
    _print_dict('User', get_paths('%s_user' % os.name))


if __name__ == '__main__':
    _main()

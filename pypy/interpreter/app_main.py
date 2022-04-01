#! /usr/bin/env python3
# This is pure Python code that handles the main entry point into "pypy3".
# See test/test_app_main.

# Missing vs CPython: -x
USAGE1 = __doc__ = """\
Options and arguments (and corresponding environment variables):
-b     : issue warnings about str(bytes_instance), str(bytearray_instance)
         and comparing bytes/bytearray with str. (-bb: issue errors)
-B     : don't write .py[co] files on import; also PYTHONDONTWRITEBYTECODE=x
-c cmd : program passed in as string (terminates option list)
-d     : debug output from parser; also PYTHONDEBUG=x\n\
-E     : ignore PYTHON* environment variables (such as PYTHONPATH)
-h     : print this help message and exit (also --help)
-i     : inspect interactively after running script; forces a prompt even
         if stdin does not appear to be a terminal; also PYTHONINSPECT=x
-I     : isolate Python from the user's environment (implies -E and -s)
-m mod : run library module as a script (terminates option list)
-O     : remove assert and __debug__-dependent statements; add .opt-1 before
         .pyc extension; also PYTHONOPTIMIZE=x
-OO    : do -O changes and also discard docstrings; add .opt-2 before
         .pyc extension
-q     : don't print version and copyright messages on interactive startup
-s     : don't add user site directory to sys.path; also PYTHONNOUSERSITE
-S     : don't imply 'import site' on initialization
-u     : force the binary I/O layers of stdout and stderr to be unbuffered.
         stdin is always buffered. the text I/O layer will still be
         line-buffered. see also PYTHONUNBUFFERED=x
-v     : verbose (trace import statements); also PYTHONVERBOSE=x
         can be supplied multiple times to increase verbosity
-V     : print the Python version number and exit (also --version)
-W arg : warning control; arg is action:message:category:module:lineno
         also PYTHONWARNINGS=arg
-X opt : set implementation-specific option
--check-hash-based-pycs always|default|never:
    control how Python invalidates hash-based .pyc files
file   : program read from script file
-      : program read from stdin (default; interactive mode if a tty)
arg ...: arguments passed to program in sys.argv[1:]
PyPy options and arguments:
--info : print translation information about this PyPy executable
-X faulthandler: attempt to display tracebacks when PyPy crashes
-X dev: enable PyPy's "development mode"
-X jit-off: turn the JIT off, equivalent to --jit off
"""
# Missing vs CPython: PYTHONHOME
USAGE2 = """
Other environment variables:
PYTHONSTARTUP: file executed on interactive startup (no default)
PYTHONPATH   : %r-separated list of directories prefixed to the
               default module search path.  The result is sys.path.
PYTHONCASEOK : ignore case in 'import' statements (Windows).
PYTHONIOENCODING: Encoding[:errors] used for stdin/stdout/stderr.
PYTHONFAULTHANDLER: dump the Python traceback on fatal errors.
PYTHONDEVMODE: enable the development mode.
PYPY_IRC_TOPIC: if set to a non-empty value, print a random #pypy IRC
               topic at startup of interactive mode.
PYPYLOG: If set to a non-empty value, enable logging.
"""

try:
    from __pypy__ import hidden_applevel, StdErrPrinter
except ImportError:
    hidden_applevel = lambda f: f
    StdErrPrinter = None
try:
    from _ast import PyCF_ACCEPT_NULL_BYTES
except ImportError:
    PyCF_ACCEPT_NULL_BYTES = 0
import errno
import sys

_MACOSX = sys.platform == 'darwin'

DEBUG = False       # dump exceptions before calling the except hook

originalexcepthook = sys.__excepthook__

def handle_sys_exit(e):
    # exit if we catch a w_SystemExit
    exitcode = e.code
    if exitcode is None:
        exitcode = 0
    else:
        try:
            exitcode = int(exitcode)
        except:
            # not an integer: print it to stderr
            try:
                print(exitcode, file=sys.stderr)
            except:
                pass   # too bad
            exitcode = 1
    raise SystemExit(exitcode)

WE_ARE_TRANSLATED = True   # patch to False if we're not really translated
IS_WINDOWS = 'nt' in sys.builtin_module_names
def get_getenv():
    try:
        # we need a version of getenv before we import os
        from __pypy__.os import real_getenv
    except ImportError:
        # dont fail on CPython tests here
        import os
        real_getenv = os.getenv
    return real_getenv


@hidden_applevel
def run_toplevel(f, *fargs, **fkwds):
    """Calls f() and handles all OperationErrors.
    Intended use is to run the main program or one interactive statement.
    run_protected() handles details like forwarding exceptions to
    sys.excepthook(), catching SystemExit, etc.
    """
    # don't use try:except: here, otherwise the exception remains
    # visible in user code.  Make sure revdb_stop is a callable, so
    # that we can call it immediately after finally: below.  Doing
    # so minimizes the number of "blind" lines that we need to go
    # back from, with "bstep", after we do "continue" in revdb.
    if '__pypy__' in sys.builtin_module_names:
        from __pypy__ import revdb_stop
    else:
        revdb_stop = None
    if revdb_stop is None:
        revdb_stop = lambda: None

    try:
        # run it
        try:
            f(*fargs, **fkwds)
        finally:
            revdb_stop()
            sys.settrace(None)
            sys.setprofile(None)
    except SystemExit as e:
        handle_sys_exit(e)
    except KeyboardInterrupt as e:
        # handled a level up
        raise
    except BaseException as e:
        display_exception(e)
        return False
    return True   # success

def display_exception(e):
    etype, evalue, etraceback = type(e), e, e.__traceback__
    try:
        # extra debugging info in case the code below goes very wrong
        if DEBUG and hasattr(sys, 'stderr'):
            s = getattr(etype, '__name__', repr(etype))
            print("debug: exception-type: ", s, file=sys.stderr)
            print("debug: exception-value:", str(evalue), file=sys.stderr)
            tbentry = etraceback
            if tbentry:
                while tbentry.tb_next:
                    tbentry = tbentry.tb_next
                lineno = tbentry.tb_lineno
                filename = tbentry.tb_frame.f_code.co_filename
                print("debug: exception-tb:    %s:%d" % (filename, lineno),
                      file=sys.stderr)

        # set the sys.last_xxx attributes
        sys.last_type = etype
        sys.last_value = evalue
        sys.last_traceback = etraceback

        # call sys.excepthook
        hook = getattr(sys, 'excepthook', originalexcepthook)
        try:
            sys.audit("sys.excepthook", hook, etype, evalue, etraceback)
        except RuntimeError:
            return
        except Exception as e:
            # CPython uses _PyErr_WriteUnraisableMsg("in audit hook", NULL)
            try:
                initstdio()
                import __pypy__
                __pypy__.writeunraisable("in audit hook", e, None)
            except Exception as e:
                # Too bad
                pass
        hook(etype, evalue, etraceback)
        return # done

    except BaseException as e:
        try:
            initstdio()
            stderr = sys.stderr
            print('Error calling sys.excepthook:', file=stderr)
            originalexcepthook(type(e), e, e.__traceback__)
            print(file=stderr)
            print('Original exception was:', file=stderr)
        except:
            pass   # too bad

    # we only get here if sys.excepthook didn't do its job
    originalexcepthook(etype, evalue, etraceback)


# ____________________________________________________________
# Option parsing

def print_info(*args):
    initstdio()
    try:
        options = sys.pypy_translation_info
    except AttributeError:
        print('no translation information found', file=sys.stderr)
    else:
        optitems = sorted(options.items())
        current = []
        for key, value in optitems:
            group = key.split('.')
            name = group.pop()
            n = 0
            while n < min(len(current), len(group)) and current[n] == group[n]:
                n += 1
            while n < len(group):
                print('%s[%s]' % ('    ' * n, group[n]))
                n += 1
            print('%s%s = %r' % ('    ' * n, name, value))
            current = group
    raise SystemExit

def get_sys_executable():
    return getattr(sys, 'executable', 'pypy3')

def print_help(*args):
    if IS_WINDOWS:
        pathsep = ';'
    else:
        pathsep = ':'
    initstdio()
    print('usage: %s [option] ... [-c cmd | -m mod | file | -] [arg] ...' % (
        get_sys_executable(),))
    print(USAGE1, end='')
    if 'pypyjit' in sys.builtin_module_names:
        print("--jit options: advanced JIT options: try 'off' or 'help'")
    print(USAGE2 % (pathsep,), end='')
    raise SystemExit

def _print_jit_help():
    initstdio()
    try:
        import pypyjit
    except ImportError:
        print("No jit support in %s" % (get_sys_executable(),), file=sys.stderr)
        return
    items = sorted(pypyjit.defaults.items())
    print('Advanced JIT options: a comma-separated list of OPTION=VALUE:')
    for key, value in items:
        print()
        print(' %s=N' % (key,))
        doc = '%s (default %s)' % (pypyjit.PARAMETER_DOCS[key], value)
        while len(doc) > 72:
            i = doc[:74].rfind(' ')
            if i < 0:
                i = doc.find(' ')
                if i < 0:
                    i = len(doc)
            print('    ' + doc[:i])
            doc = doc[i+1:]
        print('    ' + doc)
    print()
    print(' off')
    print('    turn off the JIT')
    print(' help')
    print('    print this page')
    print()
    print('The "pypyjit" module can be used to control the JIT from inside python')

def print_version(*args):
    initstdio()
    print("Python", sys.version)
    raise SystemExit


def funroll_loops(*args):
    print("Vroom vroom, I'm a racecar!")


def set_jit_option(options, jitparam, *args):
    if jitparam == 'help':
        _print_jit_help()
        raise SystemExit
    if 'pypyjit' not in sys.builtin_module_names:
        initstdio()
        print("Warning: No jit support in %s" % (get_sys_executable(),),
              file=sys.stderr)
    else:
        import pypyjit
        pypyjit.set_param(jitparam)

class CommandLineError(Exception):
    pass

def print_error(msg):
    print(msg, file=sys.stderr)
    print('usage: %s [options]' % (get_sys_executable(),), file=sys.stderr)
    print('Try `%s -h` for more information.' % (get_sys_executable(),), file=sys.stderr)

def fdopen(fd, mode, bufsize=-1):
    try:
        fdopen = file.fdopen
    except AttributeError:     # only on top of CPython, running tests
        from os import fdopen
    return fdopen(fd, mode, bufsize)

# ____________________________________________________________
# Main entry point

def setup_and_fix_paths(ignore_environment=False, **extra):
    if IS_WINDOWS:
        pathsep = ';'
    else:
        pathsep = ':'
    getenv = get_getenv()
    newpath = sys.path[:]
    del sys.path[:]
    # first prepend PYTHONPATH
    readenv = not ignore_environment
    path = readenv and getenv('PYTHONPATH')
    if path:
        sys.path.extend(path.split(pathsep))
    # then add again the original entries, ignoring duplicates
    _seen = set()
    for dir in newpath:
        if dir not in _seen:
            sys.path.append(dir)
            _seen.add(dir)

def initstdio(encoding=None, unbuffered=False):
    if hasattr(sys, 'stdin'):
        return # already initialized
    if IS_WINDOWS:
        pathsep = ';'
    else:
        pathsep = ':'
    getenv = get_getenv()

    if StdErrPrinter is not None:
        sys.stderr = sys.__stderr__ = StdErrPrinter(2)

    # Hack to avoid recursion issues during bootstrapping: pre-import
    # the utf-8 and latin-1 codecs
    encerr = None
    try:
        import encodings.utf_8
        import encodings.latin_1
    except ImportError as e:
        encerr = e

    try:
        if encoding and ':' in encoding:
            encoding, errors = encoding.split(':', 1)
            if encoding == '':
                encoding = 'utf-8'
            if errors == '':
                errors = 'strict'
            errors = errors or None
        else:
            errors = None
        encoding = encoding or None
        if not (encoding or errors):
            # stdin/out default to surrogateescape in C locale
            import _locale
            if _locale.setlocale(_locale.LC_CTYPE, None) == 'C':
                errors = 'surrogateescape'

        sys.stderr = sys.__stderr__ = create_stdio(
            2, True, "<stderr>", encoding, 'backslashreplace', unbuffered)
        sys.stdout = sys.__stdout__ = create_stdio(
            1, True, "<stdout>", encoding, errors, unbuffered)

        try:
            sys.stdin = sys.__stdin__ = create_stdio(
                0, False, "<stdin>", encoding, errors, unbuffered)
        except IsADirectoryError:
            import os
            print("Python error: <stdin> is a directory, cannot continue",
                  file=sys.stderr)
            os._exit(1)
    finally:
        if encerr:
            display_exception(encerr)
            del encerr

def create_stdio(fd, writing, name, encoding, errors, unbuffered):
    import _io
    # stdin is always opened in buffered mode, first because it
    # shouldn't make a difference in common use cases, second because
    # TextIOWrapper depends on the presence of a read1() method which
    # only exists on buffered streams.
    buffering = 0 if unbuffered and writing else -1
    mode = 'w' if writing else 'r'
    try:
        buf = _io.open(fd, mode + 'b', buffering, closefd=False)
    except OSError as e:
        if e.errno != errno.EBADF:
            raise
        return None

    raw = buf.raw if buffering else buf
    raw.name = name
    # We normally use newline='\n' below, which turns off any translation.
    # However, on Windows (independently of -u), then we must enable
    # the Universal Newline mode (set by newline = None): on input, \r\n
    # is translated into \n; on output, \n is translated into \r\n.
    # We must never enable the Universal Newline mode on POSIX: CPython
    # never interprets '\r\n' in stdin as meaning just '\n', unlike what
    # it does if you explicitly open a file in text mode.
    newline = None if sys.platform == 'win32' else '\n'
    stream = _io.TextIOWrapper(buf, encoding, errors, newline=newline,
                              line_buffering=unbuffered or raw.isatty(),
                              write_through=unbuffered)
    stream.mode = mode
    return stream


# Keep synchronized with pypy.module.sys.app.sysflags and
# pypy.module.cpyext._flags
sys_flags = (
    "debug",
    "inspect",
    "interactive",
    "optimize",
    "dont_write_bytecode",
    "no_user_site",
    "no_site",
    "ignore_environment",
    "verbose",
    "bytes_warning",
    "quiet",
    "hash_randomization",
    "isolated",
    "dev_mode",
    "utf8_mode",
)
# ^^^ Order is significant!  Keep in sync with module.sys.app.sysflags

default_options = dict.fromkeys(
    sys_flags +
    ("run_command",
    "run_module",
    "run_stdin",
    "warnoptions",
    "unbuffered"), 0)
default_options["check_hash_based_pycs"] = "default"
default_options["dev_mode"] = False # needs to be bool
default_options["utf8_mode"] = -1

def simple_option(options, name, iterargv):
    options[name] += 1

def isolated_option(options, name, iterargv):
    options[name] += 1
    options["no_user_site"] += 1
    options["ignore_environment"] += 1

def c_option(options, runcmd, iterargv):
    options["run_command"] = runcmd
    return ['-c'] + list(iterargv)

def m_option(options, runmodule, iterargv):
    options["run_module"] = runmodule
    return ['-m'] + list(iterargv)

def X_option(options, xoption, iterargv):
    options["_xoptions"].append(xoption)
    if xoption == "dev":
        options["dev_mode"] = True
    elif xoption.startswith("utf8"):
        if xoption == "utf8" or xoption == "utf8=1":
            options["utf8_mode"] = 1
        elif xoption == "utf8=0":
            options["utf8_mode"] = 0

def W_option(options, warnoption, iterargv):
    options["warnoptions"].append(warnoption)

def end_options(options, _, iterargv):
    return list(iterargv)

def ignore_option(*args):
    pass

def check_hash_based_pycs(options, value, iterargv):
    if value not in ("default", "always", "never"):
        initstdio()
        print_error("--check-hash-based-pycs must be one of 'default', 'always', or 'never'")
        raise SystemExit
    import _imp
    _imp.check_hash_based_pycs = value
    options["check_hash_based_pycs"] = value


cmdline_options = {
    # simple options just increment the counter of the options listed above
    'b': (simple_option, 'bytes_warning'),
    'B': (simple_option, 'dont_write_bytecode'),
    'd': (simple_option, 'debug'),
    'E': (simple_option, 'ignore_environment'),
    'I': (isolated_option, 'isolated'),
    'i': (simple_option, 'interactive'),
    'O': (simple_option, 'optimize'),
    's': (simple_option, 'no_user_site'),
    'S': (simple_option, 'no_site'),
    'u': (simple_option, 'unbuffered'),
    'v': (simple_option, 'verbose'),
    'q': (simple_option, 'quiet'),
    # more complex options
    'c':         (c_option,        Ellipsis),
    '?':         (print_help,      None),
    'h':         (print_help,      None),
    '--help':    (print_help,      None),
    'm':         (m_option,        Ellipsis),
    'W':         (W_option,        Ellipsis),
    'X':         (X_option,        Ellipsis),
    'V':         (print_version,   None),
    '--version': (print_version,   None),
    '--info':    (print_info,      None),
    '--jit':     (set_jit_option,  Ellipsis),
    '-funroll-loops': (funroll_loops, None),
    '--check-hash-based-pycs': (check_hash_based_pycs, Ellipsis),
    '--':        (end_options,     None),
    'R':         (ignore_option,   None),      # previously hash_randomization
    }

def handle_argument(c, options, iterargv, iterarg=iter(())):
    function, funcarg = cmdline_options[c]

    # If needed, fill in the real argument by taking it from the command line
    if funcarg is Ellipsis:
        remaining = list(iterarg)
        if remaining:
            funcarg = ''.join(remaining)
        else:
            try:
                funcarg = next(iterargv)
            except StopIteration:
                if len(c) == 1:
                    c = '-' + c
                raise CommandLineError('Argument expected for the %r option' % c)

    return function(options, funcarg, iterargv)

def parse_env(name, key, options):
    ''' Modify options inplace if name exists in os.environ
    '''
    getenv = get_getenv()
    v = getenv(name)
    if v:
        options[key] = max(1, options[key])
        try:
            newval = int(v)
        except ValueError:
            pass
        else:
            newval = max(1, newval)
            options[key] = max(options[key], newval)

def parse_command_line(bargv, argv):
    # bargv is the bytes version, argv is decoded via the default locale
    # logic: parse arguments argv. if utf8-mode is enabled, re-decode bargv
    # with utf-8, then parse arguments again
    options = _parse_command_line(argv)
    if options["utf8_mode"]:
        argv = [b.decode("utf-8", "surrogateescape") for b in bargv]
        return _parse_command_line(argv)
    return options

def _parse_command_line(argv):
    getenv = get_getenv()
    options = default_options.copy()
    options['warnoptions'] = []
    options['_xoptions'] = []

    iterargv = iter(argv)
    argv = None
    for arg in iterargv:
        #
        # If the next argument isn't at least two characters long or
        # doesn't start with '-', stop processing
        if len(arg) < 2 or arg[0] != '-':
            if IS_WINDOWS and arg == '/?':      # special case
                print_help()
            argv = [arg] + list(iterargv)    # finishes processing
        #
        # If the next argument is directly in cmdline_options, handle
        # it as a single argument
        elif arg in cmdline_options:
            argv = handle_argument(arg, options, iterargv)
        elif arg.startswith("--"):
            raise CommandLineError('Unknown option %s' % (arg,))
        #
        # Else interpret the rest of the argument character by character
        else:
            iterarg = iter(arg)
            next(iterarg)      # skip the '-'
            for c in iterarg:
                if c not in cmdline_options:
                    raise CommandLineError('Unknown option: -%s' % (c,))
                argv = handle_argument(c, options, iterargv, iterarg)

    if not argv:
        argv = ['']
        options["run_stdin"] = True
    elif argv[0] == '-':
        options["run_stdin"] = True

    # don't change the list that sys.argv is bound to
    # (relevant in case of "reload(sys)")
    sys.argv[:] = argv

    if not options["ignore_environment"]:
        parse_env('PYTHONDEBUG', "debug", options)
        parse_env('PYTHONDONTWRITEBYTECODE', "dont_write_bytecode", options)
        if getenv('PYTHONNOUSERSITE'):
            options["no_user_site"] = 1
        if getenv('PYTHONUNBUFFERED'):
            options["unbuffered"] = 1
        parse_env('PYTHONVERBOSE', "verbose", options)
        parse_env('PYTHONOPTIMIZE', "optimize", options)
        if getenv('PYTHONDEVMODE'):
            options["dev_mode"] = True
        val = getenv('PYTHONUTF8')
        if not val:
            pass
        elif val == "0":
            if options["utf8_mode"] == -1: # don't overwrite -X value
                options["utf8_mode"] = 0
        elif val == "1":
            if options["utf8_mode"] == -1: # don't overwrite -X value
                options["utf8_mode"] = 1
        else:
            initstdio()
            sys.stderr.write(
                "Fatal Python error: invalid PYTHONUTF8 environment variable value %r\n" % val)
            raise SystemExit(1)
    if options["utf8_mode"] == -1: # neither env var nor -X utf8
        import _locale
        lc = _locale.setlocale(_locale.LC_CTYPE, None)
        if lc == 'C' or lc == 'POSIX':
            options["utf8_mode"] = 1
        else:
            options["utf8_mode"] = 0

    if (options["interactive"] or
        (not options["ignore_environment"] and getenv('PYTHONINSPECT'))):
        options["inspect"] = 1

    if WE_ARE_TRANSLATED:
        flags = [options[flag] for flag in sys_flags]
        sys.flags = type(sys.flags)(flags)
        sys.dont_write_bytecode = bool(sys.flags.dont_write_bytecode)

    sys._xoptions = dict(x.split('=', 1) if '=' in x else (x, True)
                         for x in options['_xoptions'])

##    if not WE_ARE_TRANSLATED:
##        for key in sorted(options):
##            print '%40s: %s' % (key, options[key])
##        print '%40s: %s' % ("sys.argv", sys.argv)

    return options

@hidden_applevel
def run_command_line(interactive,
                     inspect,
                     run_command,
                     no_site,
                     run_module,
                     run_stdin,
                     warnoptions,
                     unbuffered,
                     ignore_environment,
                     verbose,
                     bytes_warning,
                     quiet,
                     isolated,
                     dev_mode,
                     utf8_mode,
                     **ignored):
    # with PyPy in top of CPython we can only have around 100
    # but we need more in the PyPy level for the compiler package
    if not WE_ARE_TRANSLATED:
        sys.setrecursionlimit(5000)
    getenv = get_getenv()


    readenv = not ignore_environment
    io_encoding = getenv("PYTHONIOENCODING") if readenv else None
    if (not io_encoding or io_encoding == ":") and utf8_mode:
        io_encoding = "utf-8:surrogateescape"
    initstdio(io_encoding, unbuffered)

    if 'faulthandler' in sys.builtin_module_names:
        if dev_mode or 'faulthandler' in sys._xoptions or (readenv and getenv('PYTHONFAULTHANDLER')):
            import faulthandler
            try:
                faulthandler.enable(2)   # manually set to stderr
            except ValueError:
                pass      # ignore "2 is not a valid file descriptor"
    if 'pypyjit' in sys.builtin_module_names:
        if 'jit-off' in sys._xoptions:
            set_jit_option(None, "off")

    pycache_prefix = sys._xoptions.get('pycache_prefix', None)
    if pycache_prefix is True:
        # "-Xpycache_prefix"
        pass
    elif pycache_prefix is not None:
        # "-Xpycache_prefix=" or "-Xpycache_prefix=something"
        if pycache_prefix:
            sys.pycache_prefix = pycache_prefix
    elif readenv:
        # only if no "-Xpycache_prefix at all"
        pycache_prefix = getenv('PYTHONPYCACHEPREFIX')
        if pycache_prefix:    
            sys.pycache_prefix = pycache_prefix

    mainmodule = type(sys)('__main__')
    mainmodule.__loader__ = sys.__loader__
    mainmodule.__builtins__ = __builtins__
    mainmodule.__annotations__ = {}
    sys.modules['__main__'] = mainmodule

    if not no_site:
        # __PYVENV_LAUNCHER__, used here by CPython on macOS, is be ignored
        # since it (possibly) results in a wrong sys.prefix and
        # sys.exec_prefix (and consequently sys.path) set by site.py.
        try:
            import site
        except:
            print("'import site' failed", file=sys.stderr)

    # The priority order for warnings configuration is (highest precedence
    # first):
    #
    # - the BytesWarning filter, if needed ('-b', '-bb')
    # - any '-W' command line options; then
    # - the 'PYTHONWARNINGS' environment variable; then
    # - the dev mode filter ('-X dev', 'PYTHONDEVMODE'); then
    # - any implicit filters added by _warnings.c/warnings.py
    #
    # All settings except the last are passed to the warnings module via
    # the `sys.warnoptions` list. Since the warnings module works on the basis
    # of "the most recently added filter will be checked first", we add
    # the lowest precedence entries first so that later entries override them.
    sys_warnoptions = []
    if dev_mode:
        sys_warnoptions.append("default")
    pythonwarnings = readenv and getenv('PYTHONWARNINGS')
    if pythonwarnings:
        sys_warnoptions.extend(pythonwarnings.split(','))
    if warnoptions:
        sys_warnoptions.extend(warnoptions)
    if bytes_warning:
        sys_warnoptions.append("error::BytesWarning" if bytes_warning > 1 else "default::BytesWarning")

    if sys_warnoptions:
        sys.warnoptions[:] = sys_warnoptions
        try:
            if 'warnings' in sys.modules:
                from warnings import _processoptions
                _processoptions(sys.warnoptions)
            else:
                import warnings
        except ImportError as e:
            pass   # CPython just eats any exception here

    # set up the Ctrl-C => KeyboardInterrupt signal handler, if the
    # signal module is available
    try:
        import _signal as signal
    except ImportError:
        pass
    else:
        signal.signal(signal.SIGINT, signal.default_int_handler)
        if hasattr(signal, "SIGPIPE"):
            signal.signal(signal.SIGPIPE, signal.SIG_IGN)
        if hasattr(signal, 'SIGXFZ'):
            signal.signal(signal.SIGXFZ, signal.SIG_IGN)
        if hasattr(signal, 'SIGXFSZ'):
            signal.signal(signal.SIGXFSZ, signal.SIG_IGN)

    def inspect_requested():
        # We get an interactive prompt in one of the following three cases:
        #
        #     * interactive=True, from the "-i" option
        # or
        #     * inspect=True and stdin is a tty
        # or
        #     * PYTHONINSPECT is set and stdin is a tty.
        #
        return (interactive or
                ((inspect or (readenv and getenv('PYTHONINSPECT')))
                 and sys.stdin.isatty()))

    success = True

    try:
        from os.path import abspath
        if run_command != 0:
            # handle the "-c" command
            # Put '' on sys.path
            try:
                bytes = run_command.encode()
            except BaseException as e:
                print("Unable to decode the command from the command line:",
                      file=sys.stderr)
                display_exception(e)
                success = False
            else:
                if not isolated:
                    sys.path.insert(0, '')
                success = run_toplevel(exec, bytes, mainmodule.__dict__)
        elif run_module != 0:
            # handle the "-m" command
            # Put abspath('') on sys.path
            if not isolated:
                fullpath = abspath('.')
                sys.path.insert(0, fullpath)
            import runpy
            success = run_toplevel(runpy._run_module_as_main, run_module)
        elif run_stdin:
            # handle the case where no command/filename/module is specified
            # on the command-line.

            # update sys.path *after* loading site.py, in case there is a
            # "site.py" file in the script's directory. Only run this if we're
            # executing the interactive prompt, if we're running a script we
            # put it's directory on sys.path
            if not isolated:
                sys.path.insert(0, '')

            if interactive or sys.stdin.isatty():
                # If stdin is a tty or if "-i" is specified, we print a
                # banner (unless "-q" was specified) and run
                # $PYTHONSTARTUP.
                if not quiet:
                    print_banner(not no_site)
                python_startup = readenv and getenv('PYTHONSTARTUP')
                if python_startup:
                    try:
                        with open(python_startup, 'rb') as f:
                            startup = f.read()
                    except IOError as e:
                        print("Could not open PYTHONSTARTUP", file=sys.stderr)
                        print("IOError:", e, file=sys.stderr)
                    else:
                        @hidden_applevel
                        def run_it():
                            co_python_startup = compile(startup,
                                                        python_startup,
                                                        'exec',
                                                        PyCF_ACCEPT_NULL_BYTES)
                            exec(co_python_startup, mainmodule.__dict__)
                        mainmodule.__file__ = python_startup
                        mainmodule.__cached__ = None
                        run_toplevel(run_it)
                        try:
                            del mainmodule.__file__
                        except (AttributeError, TypeError):
                            pass
                # Then we need a prompt.
                inspect = True
            else:
                # If not interactive, just read and execute stdin normally.
                if verbose:
                    print_banner(not no_site)
                @hidden_applevel
                def run_it():
                    co_stdin = compile(sys.stdin.read(), '<stdin>', 'exec',
                                       PyCF_ACCEPT_NULL_BYTES)
                    exec(co_stdin, mainmodule.__dict__)
                mainmodule.__file__ = '<stdin>'
                mainmodule.__cached__ = None
                success = run_toplevel(run_it)
        else:
            # handle the common case where a filename is specified
            # on the command-line.
            filename = sys.argv[0]
            mainmodule.__file__ = filename
            mainmodule.__cached__ = None
            for hook in sys.path_hooks:
                try:
                    importer = hook(filename)
                    break
                except ImportError:
                    continue
            else:
                importer = None
            if importer is None and not isolated:
                sys.path.insert(0, sys.pypy_resolvedirof(filename))
            # assume it's a pyc file only if its name says so.
            # CPython goes to great lengths to detect other cases
            # of pyc file format, but I think it's ok not to care.
            try:
                from _frozen_importlib import (
                    SourceFileLoader, SourcelessFileLoader)
            except ImportError:
                from _frozen_importlib_external import (
                    SourceFileLoader, SourcelessFileLoader)
            if IS_WINDOWS:
                filename = filename.lower()
            if filename.endswith('.pyc'):
                # We don't actually load via SourcelessFileLoader
                # because '__main__' must not be listed inside
                # 'importlib._bootstrap._module_locks' (it deadlocks
                # test_multiprocessing_main_handling.test_script_compiled)
                from importlib._bootstrap_external import MAGIC_NUMBER
                import marshal
                loader = SourcelessFileLoader('__main__', filename)
                mainmodule.__loader__ = loader
                @hidden_applevel
                def execfile(filename, namespace):
                    with open(filename, 'rb') as f:
                        if f.read(4) != MAGIC_NUMBER:
                            raise RuntimeError("Bad magic number in .pyc file")
                        if len(f.read(12)) != 12:
                            raise RuntimeError("Truncated .pyc file")
                        co = marshal.load(f)
                    if type(co) is not type((lambda:0).__code__):
                        raise RuntimeError("Bad code object in .pyc file")
                    exec(co, namespace)
                args = (execfile, filename, mainmodule.__dict__)
            else:
                filename = sys.argv[0]
                if importer is not None:
                    # It's the name of a directory or a zip file.
                    # put the filename in sys.path[0] and import
                    # the module __main__
                    import runpy
                    sys.path.insert(0, filename)
                    args = (runpy._run_module_as_main, '__main__', False)
                else:
                    # That's the normal path, "pypy3 stuff.py".
                    # We don't actually load via SourceFileLoader
                    # because we require PyCF_ACCEPT_NULL_BYTES
                    loader = SourceFileLoader('__main__', filename)
                    mainmodule.__loader__ = loader
                    @hidden_applevel
                    def execfile(filename, namespace):
                        try:
                            with open(filename, 'rb') as f:
                                code = f.read()
                        except IOError as e:
                            sys.stderr.write(
                                "%s: can't open file %s: [Errno %d] %s\n" %
                                (sys.executable, filename, e.errno, e.strerror))
                            raise SystemExit(e.errno)
                        co = compile(code, filename, 'exec',
                                     PyCF_ACCEPT_NULL_BYTES)
                        exec(co, namespace)
                    args = (execfile, filename, mainmodule.__dict__)
            success = run_toplevel(*args)

    except SystemExit as e:
        status = e.code
        if inspect_requested():
            display_exception(e)
    except KeyboardInterrupt as e:
        display_exception(e)
        status = True
        if not inspect_requested():
            try:
                import _signal
                import os
            except ImportError:
                pass
            else:
                try:
                    sys.stdout.flush()
                except Exception:
                    pass
                try:
                    sys.stderr.flush()
                except Exception:
                    pass
                _signal.signal(_signal.SIGINT, _signal.SIG_DFL)
                os.kill(os.getpid(), _signal.SIGINT);
                assert 0, "should be unreachable"
    else:
        status = not success

    # start a prompt if requested
    if inspect_requested():
        try:
            from _pypy_interact import interactive_console
            if hasattr(sys, '__interactivehook__'):
                run_toplevel(sys.__interactivehook__)
            pypy_version_info = getattr(sys, 'pypy_version_info', sys.version_info)
            irc_topic = pypy_version_info[3] != 'final' or (
                            readenv and getenv('PYPY_IRC_TOPIC'))
            success = run_toplevel(interactive_console, mainmodule,
                                   quiet=quiet or not irc_topic)
        except SystemExit as e:
            status = e.code
        else:
            status = not success
    try:
        sys.stdout.flush()
    except Exception:
        pass
    try:
        sys.stderr.flush()
    except Exception:
        pass
    return status

def print_banner(copyright):
    print('Python %s on %s' % (sys.version, sys.platform), file=sys.stderr)
    if copyright:
        print('Type "help", "copyright", "credits" or '
              '"license" for more information.', file=sys.stderr)

STDLIB_WARNING = """\
debug: WARNING: Library path not found, using compiled-in sys.path, with
debug: WARNING: sys.prefix = %r
debug: WARNING: Make sure the pypy3 binary is kept inside its tree of files.
debug: WARNING: It is ok to create a symlink to it from somewhere else."""

def setup_bootstrap_path(executable):
    """
    Try to do as little as possible and to have the stdlib in sys.path. In
    particular, we cannot use any unicode at this point, because lots of
    unicode operations require to be able to import encodings.
    """
    # at this point, sys.path is set to the compiled-in one, based on the
    # location where pypy was compiled. This is set during the objspace
    # initialization by module.sys.state.State.setinitialpath.
    #
    # Now, we try to find the absolute path of the executable and the stdlib
    # path
    executable = sys.pypy_find_executable(executable)
    stdlib_path = sys.pypy_find_stdlib(executable)
    if stdlib_path is None:
        initstdio()
        print(STDLIB_WARNING % (getattr(sys, 'prefix', '<missing>'),),
            file=sys.stderr)
    else:
        sys.path[:] = stdlib_path
    # from this point on, we are free to use all the unicode stuff we want,
    # This is important for py3k
    sys.executable = executable
    if sys.platform == 'win32':
        # someday PyPy will grow a PEP 397 launcher. Until then ...
        exe = executable.replace('\\', '/').rsplit('/', 1)[-1]
        sys._base_executable = sys.base_prefix + '\\' + exe
    else:
        sys._base_executable = executable


@hidden_applevel
def entry_point(executable, bargv, argv):
    # note that before calling 'import site', we are limited because we
    # cannot import stdlib modules. In particular, we cannot use unicode
    # stuffs (because we need to be able to import encodings). The full stdlib
    # can only be used in a virtualenv after 'import site' in run_command_line
    setup_bootstrap_path(executable)
    sys.pypy_initfsencoding()
    try:
        cmdline = parse_command_line(bargv, argv)
    except CommandLineError as e:
        initstdio()
        print_error(str(e))
        return 2
    except SystemExit as e:
        return e.code or 0
    setup_and_fix_paths(**cmdline)
    return run_command_line(**cmdline)


def main():
    import os
    # obscure! try removing the following line, see how it crashes, and
    # guess why...
    ImStillAroundDontForgetMe = sys.modules['__main__']
    global WE_ARE_TRANSLATED
    WE_ARE_TRANSLATED = False

    # emulate passing bytes by using fsencode
    bargv = [os.fsencode(a) for a in sys.argv]


    if len(sys.argv) > 1 and sys.argv[1] == '--argparse-only':
        import io
        del sys.argv[:2]
        del bargv[:2]
        sys.stdout = sys.stderr = io.StringIO()
        try:
            options = parse_command_line(bargv, sys.argv)
        except SystemExit:
            print('SystemExit', file=sys.__stdout__)
            print(sys.stdout.getvalue(), file=sys.__stdout__)
            raise
        except BaseException as e:
            print('Error', file=sys.__stdout__)
            print(repr(e), file=sys.__stdout__)
            raise
        else:
            print('Return', file=sys.__stdout__)
        print(options, file=sys.__stdout__)
        print(sys.argv, file=sys.__stdout__)
        return

    # Testing python on python is hard:
    # Some code above (run_command_line) will create a new module
    # named __main__ and store it into sys.modules.  There it will
    # replace the __main__ module that CPython created to execute the
    # lines you are currently reading. This will free the module, and
    # all globals (os, sys...) will be set to None.
    # To avoid this we make a copy of our __main__ module.
    sys.modules['__cpython_main__'] = sys.modules['__main__']

    # debugging only
    def pypy_find_executable(s):
        return os.path.abspath(s)

    def pypy_find_stdlib(s):
        from os.path import abspath, join, exists, dirname as dn
        thisfile = abspath(__file__)
        root = dn(dn(dn(thisfile)))
        pre_build = join(root, 'lib-python', '3')
        if sys.platform == 'win32':
            post_build = join(root, 'Lib')
        else:
            post_build = join(root, 'lib', 'pypy3.8')
        if exists(pre_build):
            return [pre_build, join(root, 'lib_pypy')]
        elif exists(post_build):
            return [post_build, join(root, 'lib_pypy')]
        raise RuntimeError(
                "could not find stdlib in '{}' and '{}'".format(pre_build, post_build))

    def pypy_resolvedirof(s):
        # we ignore the issue of symlinks; for tests, the executable is always
        # interpreter/app_main.py anyway
        return os.path.abspath(os.path.join(s, '..'))

    reset = []
    if 'PYTHONINSPECT_' in os.environ:
        reset.append(('PYTHONINSPECT', os.environ.get('PYTHONINSPECT', '')))
        os.environ['PYTHONINSPECT'] = os.environ['PYTHONINSPECT_']
    if 'PYTHONWARNINGS_' in os.environ:
        reset.append(('PYTHONWARNINGS', os.environ.get('PYTHONWARNINGS', '')))
        os.environ['PYTHONWARNINGS'] = os.environ['PYTHONWARNINGS_']

    # when run as __main__, this module is often executed by a Python
    # interpreter that have a different list of builtin modules.
    # Make some tests happy by loading them before we clobber sys.path
    import runpy
    if 'time' not in sys.builtin_module_names:
        import time; del time
    if '_operator' not in sys.builtin_module_names:
        import _operator; del _operator

    # no one should change to which lists sys.argv and sys.path are bound
    old_argv = sys.argv
    old_path = sys.path

    old_streams = sys.stdin, sys.stdout, sys.stderr
    del sys.stdin, sys.stdout, sys.stderr

    sys.pypy_find_executable = pypy_find_executable
    sys.pypy_find_stdlib = pypy_find_stdlib
    sys.pypy_resolvedirof = pypy_resolvedirof
    sys.pypy_initfsencoding = lambda: None
    sys.cpython_path = sys.path[:]

    try:
        sys.exit(int(entry_point(sys.argv[0], bargv[1:], sys.argv[1:])))
    finally:
        # restore the normal prompt (which was changed by _pypy_interact), in
        # case we are dropping to CPython's prompt
        sys.stdin, sys.stdout, sys.stderr = old_streams
        sys.ps1 = '>>> '
        sys.ps2 = '... '
        import os; os.environ.update(reset)
        assert old_argv is sys.argv
        assert old_path is sys.path

if __name__ == '__main__':
    main()

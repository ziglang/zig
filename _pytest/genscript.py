""" (deprecated) generate a single-file self-contained version of pytest """
import os
import sys
import pkgutil

import py
import _pytest



def find_toplevel(name):
    for syspath in sys.path:
        base = py.path.local(syspath)
        lib = base/name
        if lib.check(dir=1):
            return lib
        mod = base.join("%s.py" % name)
        if mod.check(file=1):
            return mod
    raise LookupError(name)

def pkgname(toplevel, rootpath, path):
    parts = path.parts()[len(rootpath.parts()):]
    return '.'.join([toplevel] + [x.purebasename for x in parts])

def pkg_to_mapping(name):
    toplevel = find_toplevel(name)
    name2src = {}
    if toplevel.check(file=1): # module
        name2src[toplevel.purebasename] = toplevel.read()
    else: # package
        for pyfile in toplevel.visit('*.py'):
            pkg = pkgname(name, toplevel, pyfile)
            name2src[pkg] = pyfile.read()
        # with wheels py source code might be not be installed
        # and the resulting genscript is useless, just bail out.
        assert name2src, "no source code found for %r at %r" %(name, toplevel)
    return name2src

def compress_mapping(mapping):
    import base64, pickle, zlib
    data = pickle.dumps(mapping, 2)
    data = zlib.compress(data, 9)
    data = base64.encodestring(data)
    data = data.decode('ascii')
    return data


def compress_packages(names):
    mapping = {}
    for name in names:
        mapping.update(pkg_to_mapping(name))
    return compress_mapping(mapping)

def generate_script(entry, packages):
    data = compress_packages(packages)
    tmpl = py.path.local(__file__).dirpath().join('standalonetemplate.py')
    exe = tmpl.read()
    exe = exe.replace('@SOURCES@', data)
    exe = exe.replace('@ENTRY@', entry)
    return exe


def pytest_addoption(parser):
    group = parser.getgroup("debugconfig")
    group.addoption("--genscript", action="store", default=None,
        dest="genscript", metavar="path",
        help="create standalone pytest script at given target path.")

def pytest_cmdline_main(config):
    import _pytest.config
    genscript = config.getvalue("genscript")
    if genscript:
        tw = _pytest.config.create_terminal_writer(config)
        tw.line("WARNING: usage of genscript is deprecated.",
                red=True)
        deps =  ['py', '_pytest', 'pytest']  # pluggy is vendored
        if sys.version_info < (2,7):
            deps.append("argparse")
            tw.line("generated script will run on python2.6-python3.3++")
        else:
            tw.line("WARNING: generated script will not run on python2.6 "
                    "due to 'argparse' dependency. Use python2.6 "
                    "to generate a python2.6 compatible script", red=True)
        script = generate_script(
            'import pytest; raise SystemExit(pytest.cmdline.main())',
            deps,
        )
        genscript = py.path.local(genscript)
        genscript.write(script)
        tw.line("generated pytest standalone script: %s" % genscript,
                bold=True)
        return 0


def pytest_namespace():
    return {'freeze_includes': freeze_includes}


def freeze_includes():
    """
    Returns a list of module names used by py.test that should be
    included by cx_freeze.
    """
    result = list(_iter_all_modules(py))
    result += list(_iter_all_modules(_pytest))
    return result


def _iter_all_modules(package, prefix=''):
    """
    Iterates over the names of all modules that can be found in the given
    package, recursively.

    Example:
        _iter_all_modules(_pytest) ->
            ['_pytest.assertion.newinterpret',
             '_pytest.capture',
             '_pytest.core',
             ...
            ]
    """
    if type(package) is not str:
        path, prefix = package.__path__[0], package.__name__ + '.'
    else:
        path = package
    for _, name, is_package in pkgutil.iter_modules([path]):
        if is_package:
            for m in _iter_all_modules(os.path.join(path, name), prefix=name + '.'):
                yield prefix + m
        else:
            yield prefix + name

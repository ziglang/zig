# This is where the options for py.py are defined.

from pypy.config.pypyoption import get_pypy_config
from rpython.config.config import to_optparse
import optparse

extra_useage = """For detailed descriptions of all the options see
http://doc.pypy.org/en/latest/config/commandline.html"""

def get_standard_options():
    config = get_pypy_config()
    parser = to_optparse(config, useoptions=["objspace.*"],
                         extra_useage=extra_useage)
    return config, parser

def process_options(parser, argv=None):
    parser.disable_interspersed_args()
    options, args = parser.parse_args(argv)
    return args

def make_config(cmdlineopt, **kwds):
    """ make a config from cmdline options (which overrides everything)
    and kwds """

    config = get_pypy_config(translating=False)
    for modname in kwds.pop("usemodules", []):
        setattr(config.objspace.usemodules, modname, True)
    config.set(**kwds)
    return config

def make_objspace(config):
    from pypy.objspace.std.objspace import StdObjSpace
    return StdObjSpace(config)

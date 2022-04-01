from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    """
    This module provides access to the Unix password database.
    It is available on all Unix versions.

    Password database entries are reported as 7-tuples containing the following
    items from the password database (see `<pwd.h>'), in order:
    pw_name, pw_passwd, pw_uid, pw_gid, pw_gecos, pw_dir, pw_shell.
    The uid and gid items are integers, all others are strings. An
    exception is raised if the entry asked for cannot be found.
    """

    interpleveldefs = {
        'getpwuid': 'interp_pwd.getpwuid',
        'getpwnam': 'interp_pwd.getpwnam',
        'getpwall': 'interp_pwd.getpwall',
    }

    appleveldefs = {
        'struct_passwd': 'app_pwd.struct_passwd',
        'struct_pwent': 'app_pwd.struct_passwd',
    }


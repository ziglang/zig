"""Provide access to Python's configuration information.  The specific
configuration variables available depend heavily on the platform and
configuration.  The values may be retrieved using
get_config_var(name), and the list of variables is available via
get_config_vars().keys().  Additional convenience functions are also
available.

Written by:   Fred L. Drake, Jr.
Email:        <fdrake@acm.org>
"""

import sys


# The content of this file is redirected from
# sysconfig_cpython or sysconfig_pypy.

if '__pypy__' in sys.builtin_module_names:
    from distutils.sysconfig_pypy import *
    from distutils.sysconfig_pypy import _config_vars # needed by setuptools
    from distutils.sysconfig_pypy import _variable_rx # read_setup_file()
else:
    from distutils.sysconfig_cpython import *
    from distutils.sysconfig_cpython import _config_vars # needed by setuptools
    from distutils.sysconfig_cpython import _variable_rx # read_setup_file()

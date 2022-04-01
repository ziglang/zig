"""
imports symbols from vendored "pluggy" if available, otherwise
falls back to importing "pluggy" from the default namespace.
"""

try:
    from _pytest.vendored_packages.pluggy import *  # noqa
    from _pytest.vendored_packages.pluggy import __version__  # noqa
except ImportError:
    from pluggy import *  # noqa
    from pluggy import __version__  # noqa

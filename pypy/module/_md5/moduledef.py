
"""
Mixed-module definition for the md5 module.
Note that there is also a pure Python implementation in pypy/lib/md5.py;
the present mixed-module version of md5 takes precedence if it is enabled.
"""

from pypy.interpreter.mixedmodule import MixedModule


class Module(MixedModule):
    """\
This module implements the interface to RSA's MD5 message digest
algorithm (see also Internet RFC 1321). Its use is quite
straightforward: use new() to create an md5 object. You can now feed
this object with arbitrary strings using the update() method, and at any
point you can ask it for the digest (a strong kind of 128-bit checksum,
a.k.a. ``fingerprint'') of the concatenation of the strings fed to it so
far using the digest() method."""

    interpleveldefs = {
        'md5': 'interp_md5.W_MD5',
        }

    appleveldefs = {
        }

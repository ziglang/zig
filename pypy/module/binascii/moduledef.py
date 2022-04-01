
"""
Mixed-module definition for the binascii module.
Note that there is also a pure Python implementation in lib_pypy/binascii.py;
the pypy/module/binascii/ version takes precedence if it is enabled.
"""

from pypy.interpreter.mixedmodule import MixedModule


class Module(MixedModule):
    """binascii - Conversion between binary data and ASCII"""

    appleveldefs = {
        }

    interpleveldefs = {
        'a2b_uu': 'interp_uu.a2b_uu',
        'b2a_uu': 'interp_uu.b2a_uu',
        'a2b_base64': 'interp_base64.a2b_base64',
        'b2a_base64': 'interp_base64.b2a_base64',
        'a2b_qp': 'interp_qp.a2b_qp',
        'b2a_qp': 'interp_qp.b2a_qp',
        'a2b_hqx': 'interp_hqx.a2b_hqx',
        'b2a_hqx': 'interp_hqx.b2a_hqx',
        'rledecode_hqx': 'interp_hqx.rledecode_hqx',
        'rlecode_hqx': 'interp_hqx.rlecode_hqx',
        'crc_hqx': 'interp_hqx.crc_hqx',
        'crc32': 'interp_crc32.crc32',
        'b2a_hex': 'interp_hexlify.hexlify',
        'hexlify': 'interp_hexlify.hexlify',
        'a2b_hex': 'interp_hexlify.unhexlify',
        'unhexlify': 'interp_hexlify.unhexlify',
        'Error'     : 'space.fromcache(interp_binascii.Cache).w_error',
        'Incomplete': 'space.fromcache(interp_binascii.Cache).w_incomplete',
        }

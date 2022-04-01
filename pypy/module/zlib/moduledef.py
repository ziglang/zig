
"""
Mixed-module definition for the zlib module.
"""

from pypy.interpreter.mixedmodule import MixedModule
from rpython.rlib import rzlib


class Module(MixedModule):
    """\
The functions in this module allow compression and decompression using the
zlib library, which is based on GNU zip.

adler32(string[, start]) -- Compute an Adler-32 checksum.
compress(string[, level]) -- Compress string, with compression level in 1-9.
compressobj([level]) -- Return a compressor object.
crc32(string[, start]) -- Compute a CRC-32 checksum.
decompress(string,[wbits],[bufsize]) -- Decompresses a compressed string.
decompressobj([wbits]) -- Return a decompressor object.

'wbits' is window buffer size.
Compressor objects support compress() and flush() methods; decompressor
objects support decompress() and flush()."""

    interpleveldefs = {
        'crc32': 'interp_zlib.crc32',
        'adler32': 'interp_zlib.adler32',
        'compressobj': 'interp_zlib.Compress',
        'decompressobj': 'interp_zlib.Decompress',
        'compress': 'interp_zlib.compress',
        'decompress': 'interp_zlib.decompress',
        'DEF_BUF_SIZE': 'interp_zlib.default_buffer_size(space)',
        '__version__': 'space.newtext("1.0")',
        'error': 'space.fromcache(interp_zlib.Cache).w_error',
        }

    appleveldefs = {
        }

    def setup_after_space_initialization(self):
        space = self.space
        space.setattr(self, space.wrap('ZLIB_RUNTIME_VERSION'),
                      space.wrap(rzlib.zlibVersion()))



for _name in """
    MAX_WBITS  DEFLATED  DEF_MEM_LEVEL
    Z_BEST_SPEED  Z_BEST_COMPRESSION  Z_DEFAULT_COMPRESSION
    Z_FILTERED  Z_HUFFMAN_ONLY  Z_DEFAULT_STRATEGY
    Z_FINISH  Z_NO_FLUSH  Z_SYNC_FLUSH  Z_FULL_FLUSH
    ZLIB_VERSION
    """.split():
    Module.interpleveldefs[_name] = 'space.wrap(%r)' % (getattr(rzlib, _name),)

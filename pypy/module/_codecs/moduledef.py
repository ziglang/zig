from pypy.interpreter.mixedmodule import MixedModule
from rpython.rlib.objectmodel import not_rpython
from rpython.rlib import rwin32
from pypy.module._codecs import interp_codecs

class Module(MixedModule):
    """
   _codecs -- Provides access to the codec registry and the builtin
              codecs.

   This module should never be imported directly. The standard library
   module "codecs" wraps this builtin module for use within Python.

   The codec registry is accessible via:

     register(search_function) -> None

     lookup(encoding) -> (encoder, decoder, stream_reader, stream_writer)

   The builtin Unicode codecs use the following interface:

     <encoding>_encode(Unicode_object[,errors='strict']) ->
         (string object, bytes consumed)

     <encoding>_decode(char_buffer_obj[,errors='strict']) ->
        (Unicode object, bytes consumed)

   <encoding>_encode() interfaces also accept non-Unicode object as
   input. The objects are then converted to Unicode using
   PyUnicode_FromObject() prior to applying the conversion.

   These <encoding>s are available: utf_8, unicode_escape,
   raw_unicode_escape, latin_1, ascii (7-bit),
   mbcs (on win32).


Written by Marc-Andre Lemburg (mal@lemburg.com).

Copyright (c) Corporation for National Research Initiatives.
"""

    appleveldefs = {}

    interpleveldefs = {
         'encode':         'interp_codecs.encode',
         'decode':         'interp_codecs.decode',
         'lookup':         'interp_codecs.lookup_codec',
         'lookup_error':   'interp_codecs.lookup_error',
         'register':       'interp_codecs.register_codec',
         'register_error': 'interp_codecs.register_error',
         'charmap_build' : 'interp_codecs.charmap_build',

         # encoders and decoders
         'ascii_decode'     : 'interp_codecs.ascii_decode',
         'ascii_encode'     : 'interp_codecs.ascii_encode',
         'latin_1_decode'   : 'interp_codecs.latin_1_decode',
         'latin_1_encode'   : 'interp_codecs.latin_1_encode',
         'utf_7_decode'     : 'interp_codecs.utf_7_decode',
         'utf_7_encode'     : 'interp_codecs.utf_7_encode',
         'utf_8_decode'     : 'interp_codecs.utf_8_decode',
         'utf_8_encode'     : 'interp_codecs.utf_8_encode',
         'utf_16_be_decode' : 'interp_codecs.utf_16_be_decode',
         'utf_16_be_encode' : 'interp_codecs.utf_16_be_encode',
         'utf_16_decode'    : 'interp_codecs.utf_16_decode',
         'utf_16_encode'    : 'interp_codecs.utf_16_encode',
         'utf_16_le_decode' : 'interp_codecs.utf_16_le_decode',
         'utf_16_le_encode' : 'interp_codecs.utf_16_le_encode',
         'utf_16_ex_decode' : 'interp_codecs.utf_16_ex_decode',
         'utf_32_decode'    : 'interp_codecs.utf_32_decode',
         'utf_32_encode'    : 'interp_codecs.utf_32_encode',
         'utf_32_be_decode' : 'interp_codecs.utf_32_be_decode',
         'utf_32_be_encode' : 'interp_codecs.utf_32_be_encode',
         'utf_32_le_decode' : 'interp_codecs.utf_32_le_decode',
         'utf_32_le_encode' : 'interp_codecs.utf_32_le_encode',
         'utf_32_ex_decode' : 'interp_codecs.utf_32_ex_decode',
         'readbuffer_encode': 'interp_codecs.readbuffer_encode',
         'charmap_decode'   : 'interp_codecs.charmap_decode',
         'charmap_encode'   : 'interp_codecs.charmap_encode',
         'escape_encode'    : 'interp_codecs.escape_encode',
         'escape_decode'    : 'interp_codecs.escape_decode',
         'unicode_escape_decode'     :  'interp_codecs.unicode_escape_decode',
         'unicode_escape_encode'     :  'interp_codecs.unicode_escape_encode',
         'raw_unicode_escape_decode' :  'interp_codecs.raw_unicode_escape_decode',
         'raw_unicode_escape_encode' :  'interp_codecs.raw_unicode_escape_encode',
    }

    @not_rpython
    def __init__(self, space, *args):
        # mbcs codec is Windows specific, and based on rffi system calls.
        if rwin32.WIN32:
            self.interpleveldefs['mbcs_encode'] = 'interp_codecs.mbcs_encode'
            self.interpleveldefs['oem_encode'] = 'interp_codecs.oem_encode'
            self.interpleveldefs['code_page_encode'] = 'interp_codecs.code_page_encode'
            self.interpleveldefs['mbcs_decode'] = 'interp_codecs.mbcs_decode'
            self.interpleveldefs['oem_decode'] = 'interp_codecs.oem_decode'
            self.interpleveldefs['code_page_decode'] = 'interp_codecs.code_page_decode'

        MixedModule.__init__(self, space, *args)

        interp_codecs.register_builtin_error_handlers(space)

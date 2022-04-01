import sys
from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):

    appleveldefs = {
    }

    interpleveldefs = {
        'DEFAULT_BUFFER_SIZE': 'space.wrap(interp_iobase.DEFAULT_BUFFER_SIZE)',
        'BlockingIOError': 'space.w_BlockingIOError',
        'UnsupportedOperation':
            'space.fromcache(interp_io.Cache).w_unsupportedoperation',
        '_IOBase': 'interp_iobase.W_IOBase',
        '_RawIOBase': 'interp_iobase.W_RawIOBase',
        '_BufferedIOBase': 'interp_bufferedio.W_BufferedIOBase',
        '_TextIOBase': 'interp_textio.W_TextIOBase',

        'FileIO': 'interp_fileio.W_FileIO',
        'BytesIO': 'interp_bytesio.W_BytesIO',
        'StringIO': 'interp_stringio.W_StringIO',
        'BufferedReader': 'interp_bufferedio.W_BufferedReader',
        'BufferedWriter': 'interp_bufferedio.W_BufferedWriter',
        'BufferedRWPair': 'interp_bufferedio.W_BufferedRWPair',
        'BufferedRandom': 'interp_bufferedio.W_BufferedRandom',
        'TextIOWrapper': 'interp_textio.W_TextIOWrapper',

        'open': 'interp_io.open',
        'open_code': 'interp_io.open_code',
        'IncrementalNewlineDecoder': 'interp_textio.W_IncrementalNewlineDecoder',
    }
    if sys.platform == 'win32':
        interpleveldefs['_WindowsConsoleIO'] = 'interp_win32consoleio.W_WinConsoleIO'

    def shutdown(self, space):
        # at shutdown, flush all open streams.  Ignore I/O errors.
        from pypy.module._io.interp_iobase import get_autoflusher
        get_autoflusher(space).flush_all(space)

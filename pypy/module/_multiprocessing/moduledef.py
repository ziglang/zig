import sys
from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):

    interpleveldefs = {
        'SemLock'         : 'interp_semaphore.W_SemLock',
    }

    appleveldefs = {
    }

    if sys.platform == 'win32':
        interpleveldefs['closesocket'] = 'interp_win32_py3.multiprocessing_closesocket'
        interpleveldefs['recv'] = 'interp_win32_py3.multiprocessing_recv'
        interpleveldefs['send'] = 'interp_win32_py3.multiprocessing_send'
    
    interpleveldefs['sem_unlink'] = 'interp_semaphore.semaphore_unlink'

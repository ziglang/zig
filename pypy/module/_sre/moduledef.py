from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):

    appleveldefs = {
    }

    interpleveldefs = {
        'CODESIZE':       'space.newint(interp_sre.CODESIZE)',
        'MAGIC':          'space.newint(20171005)',
        'MAXREPEAT':      'space.newint(interp_sre.MAXREPEAT)',
        'MAXGROUPS':      'space.newint(interp_sre.MAXGROUPS)',
        'compile':        'interp_sre.W_SRE_Pattern',
        'getcodesize':    'interp_sre.w_getcodesize',
        'ascii_iscased':  'interp_sre.w_ascii_iscased',
        'unicode_iscased':'interp_sre.w_unicode_iscased',
        'ascii_tolower':  'interp_sre.w_ascii_tolower',
        'unicode_tolower':'interp_sre.w_unicode_tolower',
    }

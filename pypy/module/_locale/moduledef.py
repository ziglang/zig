from pypy.interpreter.mixedmodule import MixedModule
from rpython.rlib import rlocale
import sys

class Module(MixedModule):
    """Support for POSIX locales."""

    interpleveldefs  = {
        'setlocale':  'interp_locale.setlocale',
        'localeconv': 'interp_locale.localeconv',
        'strcoll':    'interp_locale.strcoll',
        'strxfrm':    'interp_locale.strxfrm',
        'Error':      'interp_locale.W_Error',
    }

    if sys.platform == 'win32':
        interpleveldefs.update({
            '_getdefaultlocale':        'interp_locale.getdefaultlocale',
            })

    if rlocale.HAVE_LANGINFO:
        interpleveldefs.update({
            'nl_langinfo':              'interp_locale.nl_langinfo',
            })
    if rlocale.HAVE_LIBINTL and not sys.platform == 'darwin':
        interpleveldefs.update({
            'gettext':                  'interp_locale.gettext',
            'dgettext':                 'interp_locale.dgettext',
            'dcgettext':                'interp_locale.dcgettext',
            'textdomain':               'interp_locale.textdomain',
            'bindtextdomain':           'interp_locale.bindtextdomain',
            })
        if rlocale.HAVE_BIND_TEXTDOMAIN_CODESET:
            interpleveldefs.update({
            'bind_textdomain_codeset':'interp_locale.bind_textdomain_codeset',
            })

    appleveldefs  = {
            }

    def buildloaders(cls):
        for constant, value in rlocale.constants.iteritems():
            Module.interpleveldefs[constant] = "space.wrap(%r)" % value
        super(Module, cls).buildloaders()
    buildloaders = classmethod(buildloaders)

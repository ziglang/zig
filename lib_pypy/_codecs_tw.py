# this getcodec() function supports any multibyte codec, although
# for compatibility with CPython it should only be used for the
# codecs from this module, i.e.:
#
#    'big5', 'cp950'

from _multibytecodec import __getcodec as getcodec

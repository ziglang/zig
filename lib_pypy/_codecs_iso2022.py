# this getcodec() function supports any multibyte codec, although
# for compatibility with CPython it should only be used for the
# codecs from this module, i.e.:
#
#    'iso2022_kr', 'iso2022_jp', 'iso2022_jp_1', 'iso2022_jp_2',
#    'iso2022_jp_2004', 'iso2022_jp_3', 'iso2022_jp_ext'

from _multibytecodec import __getcodec as getcodec

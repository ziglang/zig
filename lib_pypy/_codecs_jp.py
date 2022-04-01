# this getcodec() function supports any multibyte codec, although
# for compatibility with CPython it should only be used for the
# codecs from this module, i.e.:
#
#    'shift_jis', 'cp932', 'euc_jp', 'shift_jis_2004',
#    'euc_jis_2004', 'euc_jisx0213', 'shift_jisx0213'

from _multibytecodec import __getcodec as getcodec

import py
import StringIO

from rpython.rlib.unicodedata import triegenerator

def setup_module(mod):
    mod.tmpdir = py.test.ensuretemp(mod.__name__)
    mod.lines = lines = map(hex,map(hash, map(str, range(100))))
    # some extra handcrafted tests
    lines.extend([ 'AAA', 'AAAA', 'AAAB', 'AAB', 'AABB' ]) 
    out = mod.tmpdir.join('btree.py')
    o = out.open('w')
    mod.trie = triegenerator.build_compression_tree(
        o, dict(map(lambda (x,y):(y,x), enumerate(lines))))
    o.close()
    mod.bt = out.pyimport()


def test_roundtrip():
    for i, line in enumerate(lines):
        assert bt.lookup_charcode(i) == line
        assert bt.trie_lookup(line) == i

# The following file was auto-generated, but has been edited to remove tests that 
# do not pass; we have verified that they should NOT pass, due to our interpretation
# of regex formats. The tests were removed for the following reasons (which were not
# easily recognizable during the parsing and creation of this file):
#   1)  In PCRE, '.' matches any character except \n. We define '.' as matching any
#       character at all.
#   2)  In PCRE, '\n' at the end of a line is ignored for matches on regex like 'a$'.
#       Our implementation does not actually implement $ or ^, but we fake it by
#       restricting the substrings that we test. Therefore, we cannot properly fake
#       these cases.
#   3)  The expression "^a|b" contains two tests "^a" or "b". The ^ only binds to
#       the first group; we fake $ and ^ as it is, so we will not pass this test.

# Auto-generated file of regular expressions from PCRE library

# The PCRE library is distributed under the BSD license. We have borrowed some
# of the regression tests (the ones that fit under the DFA scope) in order to
# exercise our regex implementation. Those tests are distributed under PCRE's
# BSD license. Here is the text:

#        PCRE LICENCE
#        ------------
#        
#        PCRE is a library of functions to support regular expressions whose syntax
#        and semantics are as close as possible to those of the Perl 5 language.
#
#        Release 7 of PCRE is distributed under the terms of the "BSD" licence, as
#        specified below. The documentation for PCRE, supplied in the "doc"
#        directory, is distributed under the same terms as the software itself.
#        
#        The basic library functions are written in C and are freestanding. Also
#        included in the distribution is a set of C++ wrapper functions.
#        
#        THE BASIC LIBRARY FUNCTIONS
#        ---------------------------
#        
#        Written by:       Philip Hazel
#        Email local part: ph10
#        Email domain:     cam.ac.uk
#        
#        University of Cambridge Computing Service,
#        Cambridge, England.
#        
#        Copyright (c) 1997-2008 University of Cambridge
#        All rights reserved.
#        
#        THE C++ WRAPPER FUNCTIONS
#        -------------------------
#        
#        Contributed by:   Google Inc.
#        
#        Copyright (c) 2007-2008, Google Inc.
#        All rights reserved.
#        
#        THE "BSD" LICENCE
#        -----------------
#        
#        Redistribution and use in source and binary forms, with or without
#        modification, are permitted provided that the following conditions are met:
#        
#            * Redistributions of source code must retain the above copyright notice,
#              this list of conditions and the following disclaimer.
#        
#            * Redistributions in binary form must reproduce the above copyright
#              notice, this list of conditions and the following disclaimer in the
#              documentation and/or other materials provided with the distribution.
#        
#            * Neither the name of the University of Cambridge nor the name of Google
#              Inc. nor the names of their contributors may be used to endorse or
#              promote products derived from this software without specific prior
#              written permission.
#        
#        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#        AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#        IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#        ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
#        LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#        CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#        SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#        INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#        CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#        ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#        POSSIBILITY OF SUCH DAMAGE.
#        
#        End

suite = []
suite.append(['abc', '', [('abc', 'abc')]])
suite.append(['ab*c', '', [('abc', 'abc'), ('abbbbc', 'abbbbc'), ('ac', 'ac')]])
suite.append(['ab+c', '', [('abc', 'abc'), ('abbbbbbc', 'abbbbbbc'), ('*** Failers', None), ('ac', None), ('ab', None)]])
suite.append(['a*', '', [('a', 'a'), ('aaaaaaaaaaaaaaaaa', 'aaaaaaaaaaaaaaaaa'), ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')]])
suite.append(['(a|abcd|african)', '', [('a', 'a'), ('abcd', 'abcd'), ('african', 'african')]])
suite.append(['^abc', '', [('abcdef', 'abc'), ('*** Failers', None), ('xyzabc', None), ('xyz\nabc', None)]])
suite.append(['x\\dy\\Dz', '', [('x9yzz', 'x9yzz'), ('x0y+z', 'x0y+z'), ('*** Failers', None), ('xyz', None), ('xxy0z', None)]])
suite.append(['x\\sy\\Sz', '', [('x yzz', 'x yzz'), ('x y+z', 'x y+z'), ('*** Failers', None), ('xyz', None), ('xxyyz', None)]])
suite.append(['x\\wy\\Wz', '', [('xxy+z', 'xxy+z'), ('*** Failers', None), ('xxy0z', None), ('x+y+z', None)]])
suite.append(['x.y', '', [('x+y', 'x+y'), ('x-y', 'x-y')]])  #  MANUALLY REMOVED TESTS: , ('*** Failers', None), ('x\ny', None)]])
suite.append(['a\\d$', '', [('ba0', 'a0')]])  #  MANUALLY REMOVED TESTS: , ('ba0\n', 'a0'), ('*** Failers', None), ('ba0\ncd', None)]])
suite.append(['[^a]', '', [('abcd', 'b')]])
suite.append(['ab?\\w', '', [('abz', 'abz'), ('abbz', 'abb'), ('azz', 'az')]])
suite.append(['x{0,3}yz', '', [('ayzq', 'yz'), ('axyzq', 'xyz'), ('axxyz', 'xxyz'), ('axxxyzq', 'xxxyz'), ('axxxxyzq', 'xxxyz'), ('*** Failers', None), ('ax', None), ('axx', None)]])
suite.append(['x{3}yz', '', [('axxxyzq', 'xxxyz'), ('axxxxyzq', 'xxxyz'), ('*** Failers', None), ('ax', None), ('axx', None), ('ayzq', None), ('axyzq', None), ('axxyz', None)]])
suite.append(['x{2,3}yz', '', [('axxyz', 'xxyz'), ('axxxyzq', 'xxxyz'), ('axxxxyzq', 'xxxyz'), ('*** Failers', None), ('ax', None), ('axx', None), ('ayzq', None), ('axyzq', None)]])
suite.append(['[^a]+', '', [('bac', 'b'), ('bcdefax', 'bcdef'), ('*** Failers', '*** F'), ('aaaaa', None)]])
suite.append(['[^a]*', '', [('bac', 'b'), ('bcdefax', 'bcdef'), ('*** Failers', '*** F'), ('aaaaa', '')]])
suite.append(['[^a]{3,5}', '', [('xyz', 'xyz'), ('awxyza', 'wxyz'), ('abcdefa', 'bcdef'), ('abcdefghijk', 'bcdef'), ('*** Failers', '*** F'), ('axya', None), ('axa', None), ('aaaaa', None)]])
suite.append(['\\d*', '', [('1234b567', '1234'), ('xyz', '')]])
suite.append(['\\D*', '', [('a1234b567', 'a'), ('xyz', 'xyz')]])
suite.append(['\\d+', '', [('ab1234c56', '1234'), ('*** Failers', None), ('xyz', None)]])
suite.append(['\\D+', '', [('ab123c56', 'ab'), ('*** Failers', '*** Failers'), ('789', None)]])
suite.append(['\\d?A', '', [('045ABC', '5A'), ('ABC', 'A'), ('*** Failers', None), ('XYZ', None)]])
suite.append(['\\D?A', '', [('ABC', 'A'), ('BAC', 'BA'), ('9ABC', 'A'), ('*** Failers', None)]])
suite.append(['a+', '', [('aaaa', 'aaaa')]])
suite.append(['^.*xyz', '', [('xyz', 'xyz'), ('ggggggggxyz', 'ggggggggxyz')]])
suite.append(['^.+xyz', '', [('abcdxyz', 'abcdxyz'), ('axyz', 'axyz'), ('*** Failers', None), ('xyz', None)]])
suite.append(['^.?xyz', '', [('xyz', 'xyz'), ('cxyz', 'cxyz')]])
suite.append(['^\\d{2,3}X', '', [('12X', '12X'), ('123X', '123X'), ('*** Failers', None), ('X', None), ('1X', None), ('1234X', None)]])
suite.append(['^[abcd]\\d', '', [('a45', 'a4'), ('b93', 'b9'), ('c99z', 'c9'), ('d04', 'd0'), ('*** Failers', None), ('e45', None), ('abcd', None), ('abcd1234', None), ('1234', None)]])
suite.append(['^[abcd]*\\d', '', [('a45', 'a4'), ('b93', 'b9'), ('c99z', 'c9'), ('d04', 'd0'), ('abcd1234', 'abcd1'), ('1234', '1'), ('*** Failers', None), ('e45', None), ('abcd', None)]])
suite.append(['^[abcd]+\\d', '', [('a45', 'a4'), ('b93', 'b9'), ('c99z', 'c9'), ('d04', 'd0'), ('abcd1234', 'abcd1'), ('*** Failers', None), ('1234', None), ('e45', None), ('abcd', None)]])
suite.append(['^a+X', '', [('aX', 'aX'), ('aaX', 'aaX')]])
suite.append(['^[abcd]?\\d', '', [('a45', 'a4'), ('b93', 'b9'), ('c99z', 'c9'), ('d04', 'd0'), ('1234', '1'), ('*** Failers', None), ('abcd1234', None), ('e45', None)]])
suite.append(['^[abcd]{2,3}\\d', '', [('ab45', 'ab4'), ('bcd93', 'bcd9'), ('*** Failers', None), ('1234', None), ('a36', None), ('abcd1234', None), ('ee45', None)]])
suite.append(['^(abc)*\\d', '', [('abc45', 'abc4'), ('abcabcabc45', 'abcabcabc4'), ('42xyz', '4'), ('*** Failers', None)]])
suite.append(['^(abc)+\\d', '', [('abc45', 'abc4'), ('abcabcabc45', 'abcabcabc4'), ('*** Failers', None), ('42xyz', None)]])
suite.append(['^(abc)?\\d', '', [('abc45', 'abc4'), ('42xyz', '4'), ('*** Failers', None), ('abcabcabc45', None)]])
suite.append(['^(abc){2,3}\\d', '', [('abcabc45', 'abcabc4'), ('abcabcabc45', 'abcabcabc4'), ('*** Failers', None), ('abcabcabcabc45', None), ('abc45', None), ('42xyz', None)]])
suite.append(['^(a*\\w|ab)=(a*\\w|ab)', '', [('ab=ab', 'ab=ab')]])
suite.append(['^abc', '', [('abcdef', 'abc'), ('*** Failers', None)]])
suite.append(['^(a*|xyz)', '', [('bcd', ''), ('aaabcd', 'aaa'), ('xyz', 'xyz'), ('*** Failers', '')]])
suite.append(['xyz$', '', [('xyz', 'xyz')]]) #  MANUALLY REMOVED TESTS:  , ('xyz\n', 'xyz'), ('*** Failers', None)]])
suite.append(['^abcdef', '', [('*** Failers', None)]])
suite.append(['^a{2,4}\\d+z', '', [('*** Failers', None)]])
suite.append(['the quick brown fox', '', [('the quick brown fox', 'the quick brown fox'), ('The quick brown FOX', None), ('What do you know about the quick brown fox?', 'the quick brown fox'), ('What do you know about THE QUICK BROWN FOX?', None)]])
suite.append(['abcd\\t\\n\\r\\f\\a\\e\\071\\x3b\\$\\\\\\?caxyz', '', [('abcd\t\n\r\x0c\x07\x1b9;$\\?caxyz', 'abcd\t\n\r\x0c\x07\x1b9;$\\?caxyz')]])
suite.append(['a*abc?xyz+pqr{3}ab{2,}xy{4,5}pq{0,6}AB{0,}zz', '', [('abxyzpqrrrabbxyyyypqAzz', 'abxyzpqrrrabbxyyyypqAzz'), ('abxyzpqrrrabbxyyyypqAzz', 'abxyzpqrrrabbxyyyypqAzz'), ('aabxyzpqrrrabbxyyyypqAzz', 'aabxyzpqrrrabbxyyyypqAzz'), ('aaabxyzpqrrrabbxyyyypqAzz', 'aaabxyzpqrrrabbxyyyypqAzz'), ('aaaabxyzpqrrrabbxyyyypqAzz', 'aaaabxyzpqrrrabbxyyyypqAzz'), ('abcxyzpqrrrabbxyyyypqAzz', 'abcxyzpqrrrabbxyyyypqAzz'), ('aabcxyzpqrrrabbxyyyypqAzz', 'aabcxyzpqrrrabbxyyyypqAzz'), ('aaabcxyzpqrrrabbxyyyypAzz', 'aaabcxyzpqrrrabbxyyyypAzz'), ('aaabcxyzpqrrrabbxyyyypqAzz', 'aaabcxyzpqrrrabbxyyyypqAzz'), ('aaabcxyzpqrrrabbxyyyypqqAzz', 'aaabcxyzpqrrrabbxyyyypqqAzz'), ('aaabcxyzpqrrrabbxyyyypqqqAzz', 'aaabcxyzpqrrrabbxyyyypqqqAzz'), ('aaabcxyzpqrrrabbxyyyypqqqqAzz', 'aaabcxyzpqrrrabbxyyyypqqqqAzz'), ('aaabcxyzpqrrrabbxyyyypqqqqqAzz', 'aaabcxyzpqrrrabbxyyyypqqqqqAzz'), ('aaabcxyzpqrrrabbxyyyypqqqqqqAzz', 'aaabcxyzpqrrrabbxyyyypqqqqqqAzz'), ('aaaabcxyzpqrrrabbxyyyypqAzz', 'aaaabcxyzpqrrrabbxyyyypqAzz'), ('abxyzzpqrrrabbxyyyypqAzz', 'abxyzzpqrrrabbxyyyypqAzz'), ('aabxyzzzpqrrrabbxyyyypqAzz', 'aabxyzzzpqrrrabbxyyyypqAzz'), ('aaabxyzzzzpqrrrabbxyyyypqAzz', 'aaabxyzzzzpqrrrabbxyyyypqAzz'), ('aaaabxyzzzzpqrrrabbxyyyypqAzz', 'aaaabxyzzzzpqrrrabbxyyyypqAzz'), ('abcxyzzpqrrrabbxyyyypqAzz', 'abcxyzzpqrrrabbxyyyypqAzz'), ('aabcxyzzzpqrrrabbxyyyypqAzz', 'aabcxyzzzpqrrrabbxyyyypqAzz'), ('aaabcxyzzzzpqrrrabbxyyyypqAzz', 'aaabcxyzzzzpqrrrabbxyyyypqAzz'), ('aaaabcxyzzzzpqrrrabbxyyyypqAzz', 'aaaabcxyzzzzpqrrrabbxyyyypqAzz'), ('aaaabcxyzzzzpqrrrabbbxyyyypqAzz', 'aaaabcxyzzzzpqrrrabbbxyyyypqAzz'), ('aaaabcxyzzzzpqrrrabbbxyyyyypqAzz', 'aaaabcxyzzzzpqrrrabbbxyyyyypqAzz'), ('aaabcxyzpqrrrabbxyyyypABzz', 'aaabcxyzpqrrrabbxyyyypABzz'), ('aaabcxyzpqrrrabbxyyyypABBzz', 'aaabcxyzpqrrrabbxyyyypABBzz'), ('>>>aaabxyzpqrrrabbxyyyypqAzz', 'aaabxyzpqrrrabbxyyyypqAzz'), ('>aaaabxyzpqrrrabbxyyyypqAzz', 'aaaabxyzpqrrrabbxyyyypqAzz'), ('>>>>abcxyzpqrrrabbxyyyypqAzz', 'abcxyzpqrrrabbxyyyypqAzz'), ('*** Failers', None), ('abxyzpqrrabbxyyyypqAzz', None), ('abxyzpqrrrrabbxyyyypqAzz', None), ('abxyzpqrrrabxyyyypqAzz', None), ('aaaabcxyzzzzpqrrrabbbxyyyyyypqAzz', None), ('aaaabcxyzzzzpqrrrabbbxyyypqAzz', None), ('aaabcxyzpqrrrabbxyyyypqqqqqqqAzz', None)]])
suite.append(['^(abc){1,2}zz', '', [('abczz', 'abczz'), ('abcabczz', 'abcabczz'), ('*** Failers', None), ('zz', None), ('abcabcabczz', None), ('>>abczz', None)]])
suite.append(['^(b+|a){1,2}c', '', [('bc', 'bc'), ('bbc', 'bbc'), ('bbbc', 'bbbc'), ('bac', 'bac'), ('bbac', 'bbac'), ('aac', 'aac'), ('abbbbbbbbbbbc', 'abbbbbbbbbbbc'), ('bbbbbbbbbbbac', 'bbbbbbbbbbbac'), ('*** Failers', None), ('aaac', None), ('abbbbbbbbbbbac', None)]])
suite.append(['^\\ca\\cA\\c[\\c{\\c:', '', [('\x01\x01\x1b;z', '\x01\x01\x1b;z')]])
suite.append(['^[ab\\]cde]', '', [('athing', 'a'), ('bthing', 'b'), (']thing', ']'), ('cthing', 'c'), ('dthing', 'd'), ('ething', 'e'), ('*** Failers', None), ('fthing', None), ('[thing', None), ('\\thing', None)]])
suite.append(['^[]cde]', '', [(']thing', ']'), ('cthing', 'c'), ('dthing', 'd'), ('ething', 'e'), ('*** Failers', None), ('athing', None), ('fthing', None)]])
suite.append(['^[^ab\\]cde]', '', [('fthing', 'f'), ('[thing', '['), ('\\thing', '\\'), ('*** Failers', '*'), ('athing', None), ('bthing', None), (']thing', None), ('cthing', None), ('dthing', None), ('ething', None)]])
suite.append(['^[^]cde]', '', [('athing', 'a'), ('fthing', 'f'), ('*** Failers', '*'), (']thing', None), ('cthing', None), ('dthing', None), ('ething', None)]])
suite.append(['^\\\x81', '', [('\x81', '\x81')]])
suite.append(['^\xff', '', [('\xff', '\xff')]])
suite.append(['^[0-9]+$', '', [('0', '0'), ('1', '1'), ('2', '2'), ('3', '3'), ('4', '4'), ('5', '5'), ('6', '6'), ('7', '7'), ('8', '8'), ('9', '9'), ('10', '10'), ('100', '100'), ('*** Failers', None), ('abc', None)]])
suite.append(['^.*nter', '', [('enter', 'enter'), ('inter', 'inter'), ('uponter', 'uponter')]])
suite.append(['^xxx[0-9]+$', '', [('xxx0', 'xxx0'), ('xxx1234', 'xxx1234'), ('*** Failers', None), ('xxx', None)]])
suite.append(['^.+[0-9][0-9][0-9]$', '', [('x123', 'x123'), ('xx123', 'xx123'), ('123456', '123456'), ('*** Failers', None), ('123', None), ('x1234', 'x1234')]])
suite.append(['^([^!]+)!(.+)=apquxz\\.ixr\\.zzz\\.ac\\.uk$', '', [('abc!pqr=apquxz.ixr.zzz.ac.uk', 'abc!pqr=apquxz.ixr.zzz.ac.uk'), ('*** Failers', None), ('!pqr=apquxz.ixr.zzz.ac.uk', None), ('abc!=apquxz.ixr.zzz.ac.uk', None), ('abc!pqr=apquxz:ixr.zzz.ac.uk', None), ('abc!pqr=apquxz.ixr.zzz.ac.ukk', None)]])
suite.append([':', '', [('Well, we need a colon: somewhere', ':'), ("*** Fail if we don't", None)]])
suite.append(['^.*\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})$', '', [('.1.2.3', '.1.2.3'), ('A.12.123.0', 'A.12.123.0'), ('*** Failers', None), ('.1.2.3333', None), ('1.2.3', None), ('1234.2.3', None)]])
suite.append(['^(\\d+)\\s+IN\\s+SOA\\s+(\\S+)\\s+(\\S+)\\s*\\(\\s*$', '', [('1 IN SOA non-sp1 non-sp2(', '1 IN SOA non-sp1 non-sp2('), ('1    IN    SOA    non-sp1    non-sp2   (', '1    IN    SOA    non-sp1    non-sp2   ('), ('*** Failers', None), ('1IN SOA non-sp1 non-sp2(', None)]])
suite.append(['^[a-zA-Z\\d][a-zA-Z\\d\\-]*(\\.[a-zA-Z\\d][a-zA-z\\d\\-]*)*\\.$', '', [('a.', 'a.'), ('Z.', 'Z.'), ('2.', '2.'), ('ab-c.pq-r.', 'ab-c.pq-r.'), ('sxk.zzz.ac.uk.', 'sxk.zzz.ac.uk.'), ('x-.y-.', 'x-.y-.'), ('*** Failers', None), ('-abc.peq.', None)]])
suite.append(['^\\*\\.[a-z]([a-z\\-\\d]*[a-z\\d]+)?(\\.[a-z]([a-z\\-\\d]*[a-z\\d]+)?)*$', '', [('*.a', '*.a'), ('*.b0-a', '*.b0-a'), ('*.c3-b.c', '*.c3-b.c'), ('*.c-a.b-c', '*.c-a.b-c'), ('*** Failers', None), ('*.0', None), ('*.a-', None), ('*.a-b.c-', None), ('*.c-a.0-c', None)]])
suite.append(['^\\".*\\"\\s*(;.*)?$', '', [('"1234"', '"1234"'), ('"abcd" ;', '"abcd" ;'), ('"" ; rhubarb', '"" ; rhubarb'), ('*** Failers', None), ('"1234" : things', None)]])
suite.append(['^$', '', [('', ''), ('*** Failers', None)]])
suite.append(['^(a(b(c)))(d(e(f)))(h(i(j)))(k(l(m)))$', '', [('abcdefhijklm', 'abcdefhijklm')]])
suite.append(['^a*\\w', '', [('z', 'z'), ('az', 'az'), ('aaaz', 'aaaz'), ('a', 'a'), ('aa', 'aa'), ('aaaa', 'aaaa'), ('a+', 'a'), ('aa+', 'aa')]])
suite.append(['^a+\\w', '', [('az', 'az'), ('aaaz', 'aaaz'), ('aa', 'aa'), ('aaaa', 'aaaa'), ('aa+', 'aa')]])
suite.append(['^\\d{8}\\w{2,}', '', [('1234567890', '1234567890'), ('12345678ab', '12345678ab'), ('12345678__', '12345678__'), ('*** Failers', None), ('1234567', None)]])
suite.append(['^[aeiou\\d]{4,5}$', '', [('uoie', 'uoie'), ('1234', '1234'), ('12345', '12345'), ('aaaaa', 'aaaaa'), ('*** Failers', None), ('123456', None)]])
suite.append(['^From +([^ ]+) +[a-zA-Z][a-zA-Z][a-zA-Z] +[a-zA-Z][a-zA-Z][a-zA-Z] +[0-9]?[0-9] +[0-9][0-9]:[0-9][0-9]', '', [('From abcd  Mon Sep 01 12:33:02 1997', 'From abcd  Mon Sep 01 12:33')]])
suite.append(['^From\\s+\\S+\\s+([a-zA-Z]{3}\\s+){2}\\d{1,2}\\s+\\d\\d:\\d\\d', '', [('From abcd  Mon Sep 01 12:33:02 1997', 'From abcd  Mon Sep 01 12:33'), ('From abcd  Mon Sep  1 12:33:02 1997', 'From abcd  Mon Sep  1 12:33'), ('*** Failers', None), ('From abcd  Sep 01 12:33:02 1997', None)]])
suite.append(['^[ab]{1,3}(ab*|b)', '', [('aabbbbb', 'aabbbbb')]])
suite.append(['abc\\0def\\00pqr\\000xyz\\0000AB', '', [('abc\x00def\x00pqr\x00xyz\x000AB', 'abc\x00def\x00pqr\x00xyz\x000AB'), ('abc456 abc\x00def\x00pqr\x00xyz\x000ABCDE', 'abc\x00def\x00pqr\x00xyz\x000AB')]])
suite.append(['abc\\x0def\\x00pqr\\x000xyz\\x0000AB', '', [('abc\ref\x00pqr\x000xyz\x0000AB', 'abc\ref\x00pqr\x000xyz\x0000AB'), ('abc456 abc\ref\x00pqr\x000xyz\x0000ABCDE', 'abc\ref\x00pqr\x000xyz\x0000AB')]])
suite.append(['^[\\000-\\037]', '', [('\x00A', '\x00'), ('\x01B', '\x01'), ('\x1fC', '\x1f')]])
suite.append(['\\0*', '', [('\x00\x00\x00\x00', '\x00\x00\x00\x00')]])
suite.append(['A\\x00{2,3}Z', '', [('The A\x00\x00Z', 'A\x00\x00Z'), ('An A\x00\x00\x00Z', 'A\x00\x00\x00Z'), ('*** Failers', None), ('A\x00Z', None), ('A\x00\x00\x00\x00Z', None)]])
suite.append(['^\\s', '', [(' abc', ' '), ('\x0cabc', '\x0c'), ('\nabc', '\n'), ('\rabc', '\r'), ('\tabc', '\t'), ('*** Failers', None), ('abc', None)]])
suite.append(['ab{1,3}bc', '', [('abbbbc', 'abbbbc'), ('abbbc', 'abbbc'), ('abbc', 'abbc'), ('*** Failers', None), ('abc', None), ('abbbbbc', None)]])
suite.append(['([^.]*)\\.([^:]*):[T ]+(.*)', '', [('track1.title:TBlah blah blah', 'track1.title:TBlah blah blah')]])
suite.append(['^[W-c]+$', '', [('WXY_^abc', 'WXY_^abc'), ('*** Failers', None), ('wxy', None)]])
suite.append(['^abc$', '', [('abc', 'abc'), ('*** Failers', None), ('qqq\nabc', None), ('abc\nzzz', None), ('qqq\nabc\nzzz', None)]])
suite.append(['[-az]+', '', [('az-', 'az-'), ('*** Failers', 'a'), ('b', None)]])
suite.append(['[az-]+', '', [('za-', 'za-'), ('*** Failers', 'a'), ('b', None)]])
suite.append(['[a\\-z]+', '', [('a-z', 'a-z'), ('*** Failers', 'a'), ('b', None)]])
suite.append(['[a-z]+', '', [('abcdxyz', 'abcdxyz')]])
suite.append(['[\\d-]+', '', [('12-34', '12-34'), ('*** Failers', None), ('aaa', None)]])
suite.append(['[\\d-z]+', '', [('12-34z', '12-34z'), ('*** Failers', None), ('aaa', None)]])
suite.append(['\\x5c', '', [('\\', '\\')]])
suite.append(['\\x20Z', '', [('the Zoo', ' Z'), ('*** Failers', None), ('Zulu', None)]])
suite.append(['ab{3cd', '', [('ab{3cd', 'ab{3cd')]])
suite.append(['ab{3,cd', '', [('ab{3,cd', 'ab{3,cd')]])
suite.append(['ab{3,4a}cd', '', [('ab{3,4a}cd', 'ab{3,4a}cd')]])
suite.append(['{4,5a}bc', '', [('{4,5a}bc', '{4,5a}bc')]])
suite.append(['abc$', '', [('abc', 'abc')]])  #  MANUALLY REMOVED TESTS: ('abc\n', 'abc'), ('*** Failers', None), ('abc\ndef', None)]])
suite.append(['(abc)\\223', '', [('abc\x93', 'abc\x93')]])
suite.append(['(abc)\\323', '', [('abc\xd3', 'abc\xd3')]])
suite.append(['ab\\idef', '', [('abidef', 'abidef')]])
suite.append(['a{0}bc', '', [('bc', 'bc')]])
suite.append(['abc[\\10]de', '', [('abc\x08de', 'abc\x08de')]])
suite.append(['abc[\\1]de', '', [('abc\x01de', 'abc\x01de')]])
suite.append(['[^a]', '', [('Abc', 'A')]])
suite.append(['[^a]+', '', [('AAAaAbc', 'AAA')]])
suite.append(['[^a]+', '', [('bbb\nccc', 'bbb\nccc')]])
suite.append(['[^k]$', '', [('abc', 'c'), ('*** Failers', 's'), ('abk', None)]])
suite.append(['[^k]{2,3}$', '', [('abc', 'abc'), ('kbc', 'bc'), ('kabc', 'abc'), ('*** Failers', 'ers'), ('abk', None), ('akb', None), ('akk', None)]])
suite.append(['^\\d{8,}\\@.+[^k]$', '', [('12345678@a.b.c.d', '12345678@a.b.c.d'), ('123456789@x.y.z', '123456789@x.y.z'), ('*** Failers', None), ('12345678@x.y.uk', None), ('1234567@a.b.c.d', None)]])
suite.append(['[^a]', '', [('aaaabcd', 'b'), ('aaAabcd', 'A')]])
suite.append(['[^az]', '', [('aaaabcd', 'b'), ('aaAabcd', 'A')]])
suite.append(['\\000\\001\\002\\003\\004\\005\\006\\007\\010\\011\\012\\013\\014\\015\\016\\017\\020\\021\\022\\023\\024\\025\\026\\027\\030\\031\\032\\033\\034\\035\\036\\037\\040\\041\\042\\043\\044\\045\\046\\047\\050\\051\\052\\053\\054\\055\\056\\057\\060\\061\\062\\063\\064\\065\\066\\067\\070\\071\\072\\073\\074\\075\\076\\077\\100\\101\\102\\103\\104\\105\\106\\107\\110\\111\\112\\113\\114\\115\\116\\117\\120\\121\\122\\123\\124\\125\\126\\127\\130\\131\\132\\133\\134\\135\\136\\137\\140\\141\\142\\143\\144\\145\\146\\147\\150\\151\\152\\153\\154\\155\\156\\157\\160\\161\\162\\163\\164\\165\\166\\167\\170\\171\\172\\173\\174\\175\\176\\177\\200\\201\\202\\203\\204\\205\\206\\207\\210\\211\\212\\213\\214\\215\\216\\217\\220\\221\\222\\223\\224\\225\\226\\227\\230\\231\\232\\233\\234\\235\\236\\237\\240\\241\\242\\243\\244\\245\\246\\247\\250\\251\\252\\253\\254\\255\\256\\257\\260\\261\\262\\263\\264\\265\\266\\267\\270\\271\\272\\273\\274\\275\\276\\277\\300\\301\\302\\303\\304\\305\\306\\307\\310\\311\\312\\313\\314\\315\\316\\317\\320\\321\\322\\323\\324\\325\\326\\327\\330\\331\\332\\333\\334\\335\\336\\337\\340\\341\\342\\343\\344\\345\\346\\347\\350\\351\\352\\353\\354\\355\\356\\357\\360\\361\\362\\363\\364\\365\\366\\367\\370\\371\\372\\373\\374\\375\\376\\377', '', [('\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7f\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff', '\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7f\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff')]])
suite.append(['(\\.\\d\\d[1-9]?)\\d+', '', [('1.230003938', '.230003938'), ('1.875000282', '.875000282'), ('1.235', '.235')]])
suite.append(['foo(.*)bar', '', [('The food is under the bar in the barn.', 'food is under the bar in the bar')]])
suite.append(['(.*)(\\d*)', '', [('I have 2 numbers: 53147', 'I have 2 numbers: 53147')]])
suite.append(['(.*)(\\d+)', '', [('I have 2 numbers: 53147', 'I have 2 numbers: 53147')]])
suite.append(['(.*)(\\d+)$', '', [('I have 2 numbers: 53147', 'I have 2 numbers: 53147')]])
suite.append(['(.*\\D)(\\d+)$', '', [('I have 2 numbers: 53147', 'I have 2 numbers: 53147')]])
suite.append(['^[W-]46]', '', [('W46]789', 'W46]'), ('-46]789', '-46]'), ('*** Failers', None), ('Wall', None), ('Zebra', None), ('42', None), ('[abcd]', None), (']abcd[', None)]])
suite.append(['^[W-\\]46]', '', [('W46]789', 'W'), ('Wall', 'W'), ('Zebra', 'Z'), ('Xylophone', 'X'), ('42', '4'), ('[abcd]', '['), (']abcd[', ']'), ('\\backslash', '\\'), ('*** Failers', None), ('-46]789', None), ('well', None)]])
suite.append(['\\d\\d\\/\\d\\d\\/\\d\\d\\d\\d', '', [('01/01/2000', '01/01/2000')]])
suite.append(['^(a){0,0}', '', [('bcd', ''), ('abc', ''), ('aab', '')]])
suite.append(['^(a){0,1}', '', [('bcd', ''), ('abc', 'a'), ('aab', 'a')]])
suite.append(['^(a){0,2}', '', [('bcd', ''), ('abc', 'a'), ('aab', 'aa')]])
suite.append(['^(a){0,3}', '', [('bcd', ''), ('abc', 'a'), ('aab', 'aa'), ('aaa', 'aaa')]])
suite.append(['^(a){0,}', '', [('bcd', ''), ('abc', 'a'), ('aab', 'aa'), ('aaa', 'aaa'), ('aaaaaaaa', 'aaaaaaaa')]])
suite.append(['^(a){1,1}', '', [('bcd', None), ('abc', 'a'), ('aab', 'a')]])
suite.append(['^(a){1,2}', '', [('bcd', None), ('abc', 'a'), ('aab', 'aa')]])
suite.append(['^(a){1,3}', '', [('bcd', None), ('abc', 'a'), ('aab', 'aa'), ('aaa', 'aaa')]])
suite.append(['^(a){1,}', '', [('bcd', None), ('abc', 'a'), ('aab', 'aa'), ('aaa', 'aaa'), ('aaaaaaaa', 'aaaaaaaa')]])
#  MANUALLY REMOVED TESTS:  suite.append(['.*\\.gif', '', [('borfle\nbib.gif\nno', 'bib.gif')]])
#  MANUALLY REMOVED TESTS:  suite.append(['.{0,}\\.gif', '', [('borfle\nbib.gif\nno', 'bib.gif')]])
#  MANUALLY REMOVED TESTS:  suite.append(['.*$', '', [('borfle\nbib.gif\nno', 'no')]])
#  MANUALLY REMOVED TESTS:  suite.append(['.*$', '', [('borfle\nbib.gif\nno\n', 'no')]])
#  MANUALLY REMOVED TESTS:  suite.append(['^.*B', '', [('**** Failers', None), ('abc\nB', None)]])
suite.append(['^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]', '', [('123456654321', '123456654321')]])
suite.append(['^\\d\\d\\d\\d\\d\\d\\d\\d\\d\\d\\d\\d', '', [('123456654321', '123456654321')]])
suite.append(['^[\\d][\\d][\\d][\\d][\\d][\\d][\\d][\\d][\\d][\\d][\\d][\\d]', '', [('123456654321', '123456654321')]])
suite.append(['^[abc]{12}', '', [('abcabcabcabc', 'abcabcabcabc')]])
suite.append(['^[a-c]{12}', '', [('abcabcabcabc', 'abcabcabcabc')]])
suite.append(['^(a|b|c){12}', '', [('abcabcabcabc', 'abcabcabcabc')]])
suite.append(['^[abcdefghijklmnopqrstuvwxy0123456789]', '', [('n', 'n'), ('*** Failers', None), ('z', None)]])
suite.append(['abcde{0,0}', '', [('abcd', 'abcd'), ('*** Failers', None), ('abce', None)]])
suite.append(['ab[cd]{0,0}e', '', [('abe', 'abe'), ('*** Failers', None), ('abcde', None)]])
suite.append(['ab(c){0,0}d', '', [('abd', 'abd'), ('*** Failers', None), ('abcd', None)]])
suite.append(['a(b*)', '', [('a', 'a'), ('ab', 'ab'), ('abbbb', 'abbbb'), ('*** Failers', 'a'), ('bbbbb', None)]])
suite.append(['ab\\d{0}e', '', [('abe', 'abe'), ('*** Failers', None), ('ab1e', None)]])
suite.append(['"([^\\\\"]+|\\\\.)*"', '', [('the "quick" brown fox', '"quick"'), ('"the \\"quick\\" brown fox"', '"the \\"quick\\" brown fox"')]])
suite.append(['a[^a]b', '', [('acb', 'acb'), ('a\nb', 'a\nb')]])
suite.append(['a.b', '', [('acb', 'acb')]])  #  MANUALLY REMOVED TESTS: , ('*** Failers', None), ('a\nb', None)]])
suite.append(['\\x00{ab}', '', [('\x00{ab}', '\x00{ab}')]])
suite.append(['(A|B)*CD', '', [('CD', 'CD')]])
suite.append(['(\\d+)(\\w)', '', [('12345a', '12345a'), ('12345+', '12345')]])
suite.append(['(a+|b+|c+)*c', '', [('aaabbbbccccd', 'aaabbbbcccc')]])
suite.append(['(abc|)+', '', [('abc', 'abc'), ('abcabc', 'abcabc'), ('abcabcabc', 'abcabcabc'), ('xyz', '')]])
suite.append(['([a]*)*', '', [('a', 'a'), ('aaaaa', 'aaaaa')]])
suite.append(['([ab]*)*', '', [('a', 'a'), ('b', 'b'), ('ababab', 'ababab'), ('aaaabcde', 'aaaab'), ('bbbb', 'bbbb')]])
suite.append(['([^a]*)*', '', [('b', 'b'), ('bbbb', 'bbbb'), ('aaa', '')]])
suite.append(['([^ab]*)*', '', [('cccc', 'cccc'), ('abab', '')]])
suite.append(['The following tests are taken from the Perl 5.005 test suite; some of them', '', [("/are compatible with 5.004, but I'd rather not have to sort them out./", None)]])
suite.append(['abc', '', [('abc', 'abc'), ('xabcy', 'abc'), ('ababc', 'abc'), ('*** Failers', None), ('xbc', None), ('axc', None), ('abx', None)]])
suite.append(['ab*c', '', [('abc', 'abc')]])
suite.append(['ab*bc', '', [('abc', 'abc'), ('abbc', 'abbc'), ('abbbbc', 'abbbbc')]])
suite.append(['.{1}', '', [('abbbbc', 'a')]])
suite.append(['.{3,4}', '', [('abbbbc', 'abbb')]])
suite.append(['ab{0,}bc', '', [('abbbbc', 'abbbbc')]])
suite.append(['ab+bc', '', [('abbc', 'abbc'), ('*** Failers', None), ('abc', None), ('abq', None)]])
suite.append(['ab+bc', '', [('abbbbc', 'abbbbc')]])
suite.append(['ab{1,}bc', '', [('abbbbc', 'abbbbc')]])
suite.append(['ab{1,3}bc', '', [('abbbbc', 'abbbbc')]])
suite.append(['ab{3,4}bc', '', [('abbbbc', 'abbbbc')]])
suite.append(['ab{4,5}bc', '', [('*** Failers', None), ('abq', None), ('abbbbc', None)]])
suite.append(['ab?bc', '', [('abbc', 'abbc'), ('abc', 'abc')]])
suite.append(['ab{0,1}bc', '', [('abc', 'abc')]])
suite.append(['ab?c', '', [('abc', 'abc')]])
suite.append(['ab{0,1}c', '', [('abc', 'abc')]])
suite.append(['^abc$', '', [('abc', 'abc'), ('*** Failers', None), ('abbbbc', None), ('abcc', None)]])
suite.append(['^abc', '', [('abcc', 'abc')]])
suite.append(['abc$', '', [('aabc', 'abc'), ('*** Failers', None), ('aabc', 'abc'), ('aabcd', None)]])
suite.append(['^', '', [('abc', '')]])
suite.append(['$', '', [('abc', '')]])
suite.append(['a.c', '', [('abc', 'abc'), ('axc', 'axc')]])
suite.append(['a.*c', '', [('axyzc', 'axyzc')]])
suite.append(['a[bc]d', '', [('abd', 'abd'), ('*** Failers', None), ('axyzd', None), ('abc', None)]])
suite.append(['a[b-d]e', '', [('ace', 'ace')]])
suite.append(['a[b-d]', '', [('aac', 'ac')]])
suite.append(['a[-b]', '', [('a-', 'a-')]])
suite.append(['a[b-]', '', [('a-', 'a-')]])
suite.append(['a]', '', [('a]', 'a]')]])
suite.append(['a[]]b', '', [('a]b', 'a]b')]])
suite.append(['a[^bc]d', '', [('aed', 'aed'), ('*** Failers', None), ('abd', None), ('abd', None)]])
suite.append(['a[^-b]c', '', [('adc', 'adc')]])
suite.append(['a[^]b]c', '', [('adc', 'adc'), ('*** Failers', None), ('a-c', 'a-c'), ('a]c', None)]])
suite.append(['\\w', '', [('a', 'a')]])
suite.append(['\\W', '', [('-', '-'), ('*** Failers', '*'), ('-', '-'), ('a', None)]])
suite.append(['a\\sb', '', [('a b', 'a b')]])
suite.append(['a\\Sb', '', [('a-b', 'a-b'), ('*** Failers', None), ('a-b', 'a-b'), ('a b', None)]])
suite.append(['\\d', '', [('1', '1')]])
suite.append(['\\D', '', [('-', '-'), ('*** Failers', '*'), ('-', '-'), ('1', None)]])
suite.append(['[\\w]', '', [('a', 'a')]])
suite.append(['[\\W]', '', [('-', '-'), ('*** Failers', '*'), ('-', '-'), ('a', None)]])
suite.append(['a[\\s]b', '', [('a b', 'a b')]])
suite.append(['a[\\S]b', '', [('a-b', 'a-b'), ('*** Failers', None), ('a-b', 'a-b'), ('a b', None)]])
suite.append(['[\\d]', '', [('1', '1')]])
suite.append(['[\\D]', '', [('-', '-'), ('*** Failers', '*'), ('-', '-'), ('1', None)]])
suite.append(['ab|cd', '', [('abc', 'ab'), ('abcd', 'ab')]])
suite.append(['()ef', '', [('def', 'ef')]])
suite.append(['a\\(b', '', [('a(b', 'a(b')]])
suite.append(['a\\(*b', '', [('ab', 'ab'), ('a((b', 'a((b')]])
suite.append(['((a))', '', [('abc', 'a')]])
suite.append(['(a)b(c)', '', [('abc', 'abc')]])
suite.append(['a+b+c', '', [('aabbabc', 'abc')]])
suite.append(['a{1,}b{1,}c', '', [('aabbabc', 'abc')]])
suite.append(['(a+|b)*', '', [('ab', 'ab')]])
suite.append(['(a+|b){0,}', '', [('ab', 'ab')]])
suite.append(['(a+|b)+', '', [('ab', 'ab')]])
suite.append(['(a+|b){1,}', '', [('ab', 'ab')]])
suite.append(['(a+|b)?', '', [('ab', 'a')]])
suite.append(['(a+|b){0,1}', '', [('ab', 'a')]])
suite.append(['[^ab]*', '', [('cde', 'cde')]])
suite.append(['abc', '', [('*** Failers', None), ('b', None)]])
suite.append(['([abc])*d', '', [('abbbcd', 'abbbcd')]])
suite.append(['([abc])*bcd', '', [('abcd', 'abcd')]])
suite.append(['a|b|c|d|e', '', [('e', 'e')]])
suite.append(['(a|b|c|d|e)f', '', [('ef', 'ef')]])
suite.append(['abcd*efg', '', [('abcdefg', 'abcdefg')]])
suite.append(['ab*', '', [('xabyabbbz', 'ab'), ('xayabbbz', 'a')]])
suite.append(['(ab|cd)e', '', [('abcde', 'cde')]])
suite.append(['[abhgefdc]ij', '', [('hij', 'hij')]])
suite.append(['(abc|)ef', '', [('abcdef', 'ef')]])
suite.append(['(a|b)c*d', '', [('abcd', 'bcd')]])
suite.append(['(ab|ab*)bc', '', [('abc', 'abc')]])
suite.append(['a([bc]*)c*', '', [('abc', 'abc')]])
suite.append(['a([bc]*)(c*d)', '', [('abcd', 'abcd')]])
suite.append(['a([bc]+)(c*d)', '', [('abcd', 'abcd')]])
suite.append(['a([bc]*)(c+d)', '', [('abcd', 'abcd')]])
suite.append(['a[bcd]*dcdcde', '', [('adcdcde', 'adcdcde')]])
suite.append(['a[bcd]+dcdcde', '', [('*** Failers', None), ('abcde', None), ('adcdcde', None)]])
suite.append(['(ab|a)b*c', '', [('abc', 'abc')]])
suite.append(['((a)(b)c)(d)', '', [('abcd', 'abcd')]])
suite.append(['[a-zA-Z_][a-zA-Z0-9_]*', '', [('alpha', 'alpha')]])
#  MANUALLY REMOVED TESTS:  suite.append(['^a(bc+|b[eh])g|.h$', '', [('abh', 'bh')]])
suite.append(['(bc+d$|ef*g.|h?i(j|k))', '', [('effgz', 'effgz'), ('ij', 'ij'), ('reffgz', 'effgz'), ('*** Failers', None), ('effg', None), ('bcdd', None)]])
suite.append(['((((((((((a))))))))))', '', [('a', 'a')]])
suite.append(['(((((((((a)))))))))', '', [('a', 'a')]])
suite.append(['multiple words of text', '', [('*** Failers', None), ('aa', None), ('uh-uh', None)]])
suite.append(['multiple words', '', [('multiple words, yeah', 'multiple words')]])
suite.append(['(.*)c(.*)', '', [('abcde', 'abcde')]])
suite.append(['\\((.*), (.*)\\)', '', [('(a, b)', '(a, b)')]])
suite.append(['abcd', '', [('abcd', 'abcd')]])
suite.append(['a(bc)d', '', [('abcd', 'abcd')]])
suite.append(['a[-]?c', '', [('ac', 'ac')]])
suite.append(['((foo)|(bar))*', '', [('foobar', 'foobar')]])
suite.append(['^(.+)?B', '', [('AB', 'AB')]])
suite.append(['^([^a-z])|(\\^)$', '', [('.', '.')]])
suite.append(['^[<>]&', '', [('<&OUT', '<&')]])
suite.append(['^(){3,5}', '', [('abc', '')]])
suite.append(['^(a+)*ax', '', [('aax', 'aax')]])
suite.append(['^((a|b)+)*ax', '', [('aax', 'aax')]])
suite.append(['^((a|bc)+)*ax', '', [('aax', 'aax')]])
suite.append(['(a|x)*ab', '', [('cab', 'ab')]])
suite.append(['(a)*ab', '', [('cab', 'ab')]])
suite.append(['foo\\w*\\d{4}baz', '', [('foobar1234baz', 'foobar1234baz')]])
suite.append(['(\\w+:)+', '', [('one:', 'one:')]])
suite.append(['([\\w:]+::)?(\\w+)$', '', [('abcd', 'abcd'), ('xy:z:::abcd', 'xy:z:::abcd')]])
suite.append(['^[^bcd]*(c+)', '', [('aexycd', 'aexyc')]])
suite.append(['(a*)b+', '', [('caab', 'aab')]])
suite.append(['([\\w:]+::)?(\\w+)$', '', [('abcd', 'abcd'), ('xy:z:::abcd', 'xy:z:::abcd'), ('*** Failers', 'Failers'), ('abcd:', None), ('abcd:', None)]])
suite.append(['^[^bcd]*(c+)', '', [('aexycd', 'aexyc')]])
suite.append(['([[:]+)', '', [('a:[b]:', ':[')]])
suite.append(['([[=]+)', '', [('a=[b]=', '=[')]])
suite.append(['([[.]+)', '', [('a.[b].', '.[')]])
suite.append(['((Z)+|A)*', '', [('ZABCDEFG', 'ZA')]])
suite.append(['(Z()|A)*', '', [('ZABCDEFG', 'ZA')]])
suite.append(['(Z(())|A)*', '', [('ZABCDEFG', 'ZA')]])
suite.append(['^[a-\\d]', '', [('abcde', 'a'), ('-things', '-'), ('0digit', '0'), ('*** Failers', None), ('bcdef', None)]])
suite.append(['^[\\d-a]', '', [('abcde', 'a'), ('-things', '-'), ('0digit', '0'), ('*** Failers', None), ('bcdef', None)]])
suite.append(['[\\s]+', '', [('> \t\n\x0c\r\x0b<', ' \t\n\x0c\r')]])
suite.append(['\\s+', '', [('> \t\n\x0c\r\x0b<', ' \t\n\x0c\r')]])
suite.append(['\\M', '', [('M', 'M')]])
suite.append(['(a+)*b', '', [('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', None)]])
suite.append(['\xc5\xe6\xe5\xe4[\xe0-\xff\xc0-\xdf]+', '', [('\xc5\xe6\xe5\xe4\xe0', '\xc5\xe6\xe5\xe4\xe0'), ('\xc5\xe6\xe5\xe4\xff', '\xc5\xe6\xe5\xe4\xff'), ('\xc5\xe6\xe5\xe4\xc0', '\xc5\xe6\xe5\xe4\xc0'), ('\xc5\xe6\xe5\xe4\xdf', '\xc5\xe6\xe5\xe4\xdf')]])
suite.append(['line\\nbreak', '', [('this is a line\nbreak', 'line\nbreak'), ('line one\nthis is a line\nbreak in the second line', 'line\nbreak')]])
suite.append(['Content-Type\\x3A[^\\r\\n]{6,}', '', [('Content-Type:xxxxxyyy', 'Content-Type:xxxxxyyy')]])
suite.append(['Content-Type\\x3A[^\\r\\n]{6,}z', '', [('Content-Type:xxxxxyyyz', 'Content-Type:xxxxxyyyz')]])
suite.append(['Content-Type\\x3A[^a]{6,}', '', [('Content-Type:xxxyyy', 'Content-Type:xxxyyy')]])
suite.append(['Content-Type\\x3A[^a]{6,}z', '', [('Content-Type:xxxyyyz', 'Content-Type:xxxyyyz')]])
suite.append(['^\\w+=.*(\\\\\\n.*)*', '', [('abc=xyz\\\npqr', 'abc=xyz\\\npqr')]])
suite.append(['^(a()*)*', '', [('aaaa', 'aaaa')]])
suite.append(['^(a()+)+', '', [('aaaa', 'aaaa')]])
suite.append(['(a|)*\\d', '', [('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', None), ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4')]])
suite.append(['.+foo', '', [('afoo', 'afoo')]])    #  MANUALLY REMOVED TESTS:, ('** Failers', None), ('\r\nfoo', None), ('\nfoo', None)]])

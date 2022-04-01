
### a trivial program to test strings, lists, functions and methods ###
## tiny change wrt goal so far needed: explicit parameter to str.split

def addstr(s1,s2):
    return s1 + s2

str = "an interesting string"
str2 = 'another::string::xxx::y:aa'
str3 = addstr(str,str2)
arr = []
for word in str.split(' '):
    if word in str2.split('::'):
        arr.append(word)
print ''.join(arr)
print "str + str2 = ", str3



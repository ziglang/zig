print '--- beginning of PyPy run of app_example.py ---'
print 6*7
print "OK, we managed to print a good number, now let's try 'import code'" 
print "(this will last a while, because compiling happens at app-level)" 
import code 
print "fine, we managed to import 'code', now let's run code.interact()" 
code.interact()

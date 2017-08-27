// Build with cl:
//    cl.exe /Z7 pdb-diff.cpp /link /debug /pdb:pdb-diff-cl.pdb
//           /nodefaultlib /entry:main
// Build with lld (after running the above cl command):
//    lld-link.exe /debug /pdb:pdb-diff-lld.pdb /nodefaultlib
//                 /entry:main pdb-diff.obj

void *__purecall = 0;

int main() { return 42; }

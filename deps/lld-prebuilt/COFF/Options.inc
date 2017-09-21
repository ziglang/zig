/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* Option Parsing Definitions                                                 *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

/////////
// Prefixes

#ifdef PREFIX
#define COMMA ,
PREFIX(prefix_0, {nullptr})
PREFIX(prefix_2, {"/" COMMA "-" COMMA nullptr})
PREFIX(prefix_1, {"/" COMMA "-" COMMA "-?" COMMA nullptr})
PREFIX(prefix_3, {"/?" COMMA "-?" COMMA nullptr})
#undef COMMA
#endif // PREFIX

/////////
// Groups

#ifdef OPTION

//////////
// Options

OPTION(prefix_0, "<input>", INPUT, Input, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_0, "<unknown>", UNKNOWN, Unknown, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "align:", align, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Section alignment", nullptr, nullptr)
OPTION(prefix_1, "allowbind:no", allowbind_no, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Disable DLL binding", nullptr, nullptr)
OPTION(prefix_1, "allowbind", allowbind, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "allowisolation:no", allowisolation_no, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Set NO_ISOLATION bit", nullptr, nullptr)
OPTION(prefix_1, "allowisolation", allowisolation, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "alternatename:", alternatename, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Define weak alias", nullptr, nullptr)
OPTION(prefix_1, "appcontainer:no", appcontainer_no, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Image can only be run in an app container", nullptr, nullptr)
OPTION(prefix_1, "appcontainer", appcontainer, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "base:", base, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Base address of the program", nullptr, nullptr)
OPTION(prefix_1, "debugtype:", debugtype, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Debug Info Options", nullptr, nullptr)
OPTION(prefix_1, "debug", debug, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Embed a symbol table in the image", nullptr, nullptr)
OPTION(prefix_2, "def:", deffile, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Use module-definition file", nullptr, nullptr)
OPTION(prefix_1, "defaultlib:", defaultlib, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Add the library to the list of input files", nullptr, nullptr)
OPTION(prefix_1, "delay:", delay, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "delayload:", delayload, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Delay loaded DLL name", nullptr, nullptr)
OPTION(prefix_1, "disallowlib:", disallowlib, Joined, INVALID, nodefaultlib, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "dll", dll, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Create a DLL", nullptr, nullptr)
OPTION(prefix_1, "driver:", driver, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Generate a Windows NT Kernel Mode Driver", nullptr, nullptr)
OPTION(prefix_1, "dynamicbase:no", dynamicbase_no, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Disable address space layout randomization", nullptr, nullptr)
OPTION(prefix_1, "dynamicbase", dynamicbase, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "editandcontinue", editandcontinue, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "entry:", entry, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Name of entry point symbol", nullptr, nullptr)
OPTION(prefix_1, "errorlimit:", errorlimit, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Maximum number of errors to emit before stopping (0 = no limit)", nullptr, nullptr)
OPTION(prefix_1, "errorreport:", errorreport, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "export:", export, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Export a function", nullptr, nullptr)
OPTION(prefix_1, "failifmismatch:", failifmismatch, Joined, INVALID, INVALID, nullptr, 0, 0,
       "", nullptr, nullptr)
OPTION(prefix_1, "fastfail", fastfail, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "fixed:no", fixed_no, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Enable base relocations", nullptr, nullptr)
OPTION(prefix_1, "fixed", fixed, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "force:unresolved", force_unresolved, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "force", force, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Allow undefined symbols when creating executables", nullptr, nullptr)
OPTION(prefix_1, "functionpadmin", functionpadmin, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "guardsym:", guardsym, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "heap:", heap, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Size of the heap", nullptr, nullptr)
OPTION(prefix_1, "help", help, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "highentropyva:no", highentropyva_no, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Set HIGH_ENTROPY_VA bit", nullptr, nullptr)
OPTION(prefix_1, "highentropyva", highentropyva, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "idlout:", idlout, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "ignore:", ignore, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "ignoreidl", ignoreidl, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "implib:", implib, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Import library name", nullptr, nullptr)
OPTION(prefix_2, "include:", incl, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Force symbol to be added to symbol table as undefined one", nullptr, nullptr)
OPTION(prefix_1, "incremental:no", no_incremental, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "incremental", incremental, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "largeaddressaware:no", largeaddressaware_no, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Disable large addresses", nullptr, nullptr)
OPTION(prefix_1, "largeaddressaware", largeaddressaware, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "libpath:", libpath, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Additional library search path", nullptr, nullptr)
OPTION(prefix_1, "linkrepro:", linkrepro, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Dump linker invocation and input files for debugging", nullptr, nullptr)
OPTION(prefix_2, "lldmap:", lldmap_file, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "lldmap", lldmap, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "lldsavetemps", lldsavetemps, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Save temporary files instead of deleting them", nullptr, nullptr)
OPTION(prefix_1, "machine:", machine, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Specify target platform", nullptr, nullptr)
OPTION(prefix_1, "manifest:", manifest_colon, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Create manifest file", nullptr, nullptr)
OPTION(prefix_1, "manifestdependency:", manifestdependency, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Attributes for <dependency> in manifest file", nullptr, nullptr)
OPTION(prefix_1, "manifestfile:", manifestfile, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Manifest file path", nullptr, nullptr)
OPTION(prefix_1, "manifestinput:", manifestinput, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Specify manifest file", nullptr, nullptr)
OPTION(prefix_1, "manifestuac:", manifestuac, Joined, INVALID, INVALID, nullptr, 0, 0,
       "User access control", nullptr, nullptr)
OPTION(prefix_1, "manifest", manifest, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "maxilksize:", maxilksize, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "merge:", merge, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Combine sections", nullptr, nullptr)
OPTION(prefix_1, "mllvm:", mllvm, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Options to pass to LLVM", nullptr, nullptr)
OPTION(prefix_1, "msvclto", msvclto, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "nodefaultlib:", nodefaultlib, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Remove a default library", nullptr, nullptr)
OPTION(prefix_1, "nodefaultlib", nodefaultlib_all, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "noentry", noentry, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "nologo", nologo, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "nopdb", nopdb, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Disable PDB generation for DWARF users", nullptr, nullptr)
OPTION(prefix_1, "nosymtab", nosymtab, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "nxcompat:no", nxcompat_no, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Disable data execution provention", nullptr, nullptr)
OPTION(prefix_1, "nxcompat", nxcompat, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "opt:", opt, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Control optimizations", nullptr, nullptr)
OPTION(prefix_1, "out:", out, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Path to file to write output", nullptr, nullptr)
OPTION(prefix_1, "pdb:", pdb, Joined, INVALID, INVALID, nullptr, 0, 0,
       "PDB file path", nullptr, nullptr)
OPTION(prefix_1, "pdbaltpath:", pdbaltpath, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "profile", profile, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "safeseh:no", safeseh_no, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Produce an image with Safe Exception Handler", nullptr, nullptr)
OPTION(prefix_1, "safeseh", safeseh, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "section:", section, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Specify section attributes", nullptr, nullptr)
OPTION(prefix_1, "stack:", stack, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Size of the stack", nullptr, nullptr)
OPTION(prefix_1, "stub:", stub, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Specify DOS stub file", nullptr, nullptr)
OPTION(prefix_1, "subsystem:", subsystem, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Specify subsystem", nullptr, nullptr)
OPTION(prefix_1, "swaprun:cd", swaprun_cd, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "swaprun:net", swaprun_net, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "throwingnew", throwingnew, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "tlbid:", tlbid, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "tlbout:", tlbout, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "tsaware:no", tsaware_no, Flag, INVALID, INVALID, nullptr, 0, 0,
       "Create non-Terminal Server aware executable", nullptr, nullptr)
OPTION(prefix_1, "tsaware", tsaware, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "verbose:", verbose_all, Joined, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "verbose", verbose, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "version:", version, Joined, INVALID, INVALID, nullptr, 0, 0,
       "Specify a version number in the PE header", nullptr, nullptr)
OPTION(prefix_1, "wx:no", wx_no, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_1, "wx", wx, Flag, INVALID, INVALID, nullptr, 0, 0, nullptr, nullptr, nullptr)
OPTION(prefix_3, "", help_q, Flag, INVALID, help, nullptr, 0, 0, nullptr, nullptr, nullptr)
#endif // OPTION

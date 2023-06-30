#!/bin/sh -e

if [ $# != 2 ]; then
    echo "usage: $0 <zig-lib-dir> <mingw-w64-dir>"
    exit 1
fi

: ${MAKE:=make -j$(nproc)}
ZIG="$(realpath $1)"
set -x
cd $2

cd mingw-w64-headers
./configure --prefix= --includedir=/ --with-widl --with-default-win32-winnt=0x0A00 --with-default-msvcrt=ucrt
$MAKE
rm -r "$ZIG/libc/include/any-windows-any"
$MAKE install DESTDIR="$ZIG/libc/include/any-windows-any"
cd ..

cd mingw-w64-crt
rm -r build-aux libce math/DFP math/softmath profile testcases
rm .gitignore ChangeLog* Makefile.* aclocal.m4 config.h.in configure*
rm gdtoa/README* lib*/Makefile.am lib*/ChangeLog*
rm cfguard/mingw_cfguard_loadcfg.S
rm crt/binmode.c crt/crtbegin.c crt/crtend.c crt/CRT_fp8.c crt/CRT_glob.c crt/CRT_noglob.c crt/txtmode.c crt/ucrtexe.c
rm lib32/res.rc lib32/test.c
rm mingw/mingwthrd.def mingw/mthr_stub.c
for f in agtctl_i agtsvr_i cdoex_i cdoexm_i cdosys_i emostore_i iisext_i mtsadmin_i mtxadmin_i scardssp_i scardssp_p tsuserex_i; do
    mv libsrc/$f.c "$ZIG/libc/include/any-windows-any"
done
for f in COPYING include/config.h; do
    cp "$ZIG/libc/mingw/$f" $f;
done
rm -r "$ZIG/libc/mingw"
cp -r . "$ZIG/libc/mingw"

set +x

echo
echo 'Processing MRI files...'
cd "$ZIG/libc/mingw"

first_arg() {
    echo $1
}

for f in lib*/*.mri; do
    out=${f%.mri}.zri
    while read line; do
        case $line in
            ADDLIB\ lib*.a)
                lib=${line#ADDLIB lib}
                lib=${lib%.a}
                case $lib in
                    *_extra|*_def|msvcrt_common) ;;
                    *)
                        case $(first_arg lib*/$lib.def*) in
                            lib\**) echo "warning: $out: def file for $lib not found"
                        esac
                        echo $lib >>$out
                esac
                ;;
            \;*|CREATE*|SAVE|END) ;;
            *)
                echo "error: unsupported line in $f: $line"
                exit 1
        esac
    done <$f
    rm $f
done

echo
echo 'Done.'
echo
echo 'If there were changes to mingw-w64-crt/Makefile.am since the last release,'
echo 'edit src/mingw.zig to reflect them.'

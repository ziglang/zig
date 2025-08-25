/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <stdlib.h>
#include <libgen.h>
#include <windows.h>

/* A 'directory separator' is a byte that equals 0x2F ('solidus' or more
 * commonly 'forward slash') or 0x5C ('reverse solidus' or more commonly
 * 'backward slash'). The byte 0x5C may look different from a backward slash
 * in some locales; for example, it looks the same as a Yen sign in Japanese
 * locales and a Won sign in Korean locales. Despite its appearance, it still
 * functions as a directory separator.
 *
 * A 'path' comprises an optional DOS drive letter with a colon, and then an
 * arbitrary number of possibily empty components, separated by non-empty
 * sequences of directory separators (in other words, consecutive directory
 * separators are treated as a single one). A path that comprises an empty
 * component denotes the current working directory.
 *
 * An 'absolute path' comprises at least two components, the first of which
 * is empty.
 *
 * A 'relative path' is a path that is not an absolute path. In other words,
 * it either comprises an empty component, or begins with a non-empty
 * component.
 *
 * POSIX doesn't have a concept about DOS drives. A path that does not have a
 * drive letter starts from the same drive as the current working directory.
 *
 * For example:
 * (Examples without drive letters match POSIX.)
 *
 *   Argument                 dirname() returns        basename() returns
 *   --------                 -----------------        ------------------
 *   `` or NULL               `.`                      `.`
 *   `usr`                    `.`                      `usr`
 *   `usr\`                   `.`                      `usr`
 *   `\`                      `\`                      `\`
 *   `\usr`                   `\`                      `usr`
 *   `\usr\lib`               `\usr`                   `lib`
 *   `\home\\dwc\\test`       `\home\\dwc`             `test`
 *   `\\host\usr`             `\\host\.`               `usr`
 *   `\\host\usr\lib`         `\\host\usr`             `lib`
 *   `\\host\\usr`            `\\host\\`               `usr`
 *   `\\host\\usr\lib`        `\\host\\usr`            `lib`
 *   `C:`                     `C:.`                    `.`
 *   `C:usr`                  `C:.`                    `usr`
 *   `C:usr\`                 `C:.`                    `usr`
 *   `C:\`                    `C:\`                    `\`
 *   `C:\\`                   `C:\`                    `\`
 *   `C:\\\`                  `C:\`                    `\`
 *   `C:\usr`                 `C:\`                    `usr`
 *   `C:\usr\lib`             `C:\usr`                 `lib`
 *   `C:\\usr\\lib\\`         `C:\\usr`                `lib`
 *   `C:\home\\dwc\\test`     `C:\home\\dwc`           `test`
 */

struct path_info
  {
    /* This points to end of the UNC prefix and drive letter, if any.  */
    char* prefix_end;

    /* These point to the directory separator in front of the last non-empty
     * component.  */
    char* base_sep_begin;
    char* base_sep_end;

    /* This points to the last directory separator sequence if no other
     * non-separator characters follow it.  */
    char* term_sep_begin;

    /* This points to the end of the string.  */
    char* path_end;
  };

#define IS_DIR_SEP(c)  ((c) == '/' || (c) == '\\')

static
void
do_get_path_info(struct path_info* info, char* path)
  {
    char* pos = path;
    int unc_ncoms = 0;
    DWORD cp;
    int dbcs_tb, prev_dir_sep, dir_sep;

    /* Get the code page for paths in the same way as `fopen()`.  */
    cp = AreFileApisANSI() ? CP_ACP : CP_OEMCP;

    /* Set the structure to 'no data'.  */
    info->prefix_end = NULL;
    info->base_sep_begin = NULL;
    info->base_sep_end = NULL;
    info->term_sep_begin = NULL;

    if(IS_DIR_SEP(pos[0]) && IS_DIR_SEP(pos[1])) {
      /* The path is UNC.  */
      pos += 2;

      /* Seek to the end of the share/device name.  */
      dbcs_tb = 0;
      prev_dir_sep = 0;

      while(*pos != 0) {
        dir_sep = 0;

        if(dbcs_tb)
          dbcs_tb = 0;
        else if(IsDBCSLeadByteEx(cp, *pos))
          dbcs_tb = 1;
        else
          dir_sep = IS_DIR_SEP(*pos);

        /* If a separator has been encountered and the previous character
         * was not, mark this as the end of the current component.  */
        if(dir_sep && !prev_dir_sep) {
          unc_ncoms ++;

          /* The first component is the host name, and the second is the
           * share name. So  we stop at the end of the second component.  */
          if(unc_ncoms == 2)
            break;
        }

        prev_dir_sep = dir_sep;
        pos ++;
      }

      /* The UNC prefix terminates here. The terminating directory separator
       * is not part of the prefix, and initiates a new absolute path.  */
      info->prefix_end = pos;
    }
    else if((pos[0] >= 'A' && pos[0] <= 'Z' && pos[1] == ':')
            || (pos[0] >= 'a' && pos[0] <= 'z' && pos[1] == ':')) {
      /* The path contains a DOS drive letter in the beginning.  */
      pos += 2;

      /* The DOS drive prefix terminates here. Unlike UNC paths, the remaing
       * part can be relative. For example, `C:foo` denotes `foo` in the
       * working directory of drive `C:`.  */
      info->prefix_end = pos;
    }

    /* The remaining part of the path is almost the same as POSIX.  */
    dbcs_tb = 0;
    prev_dir_sep = 0;

    while(*pos != 0) {
      dir_sep = 0;

      if(dbcs_tb)
        dbcs_tb = 0;
      else if(IsDBCSLeadByteEx(cp, *pos))
        dbcs_tb = 1;
      else
        dir_sep = IS_DIR_SEP(*pos);

      /* If a separator has been encountered and the previous character
       * was not, mark this as the beginning of the terminating separator
       * sequence.  */
      if(dir_sep && !prev_dir_sep)
        info->term_sep_begin = pos;

      /* If a non-separator character has been encountered and a previous
       * terminating separator sequence exists, start a new component.  */
      if(!dir_sep && prev_dir_sep) {
        info->base_sep_begin = info->term_sep_begin;
        info->base_sep_end = pos;
        info->term_sep_begin = NULL;
      }

      prev_dir_sep = dir_sep;
      pos ++;
    }

    /* Store the end of the path for convenience.  */
    info->path_end = pos;
  }

char*
dirname(char* path)
  {
    struct path_info info;
    char* upath;
    const char* top;
    static char* static_path_copy;

    if(path == NULL || path[0] == 0)
      return (char*) ".";

    do_get_path_info(&info, path);
    upath = info.prefix_end ? info.prefix_end : path;
    top = (IS_DIR_SEP(path[0]) || IS_DIR_SEP(upath[0])) ? "\\" : ".";

    /* If a non-terminating directory separator exists, it terminates the
     * dirname. Truncate the path there.  */
    if(info.base_sep_begin) {
      info.base_sep_begin[0] = 0;

      /* If the unprefixed path has not been truncated to empty, it is now
       * the dirname, so return it.  */
      if(upath[0])
        return path;
    }

    /* The dirname is empty. In principle we return `<prefix>.` if the
     * path is relative and `<prefix>\` if it is absolute. This can be
     * optimized if there is no prefix.  */
    if(upath == path)
      return (char*) top;

    /* When there is a prefix, we must append a character to the prefix.
     * If there is enough room in the original path, we just reuse its
     * storage.  */
    if(upath != info.path_end) {
      upath[0] = *top;
      upath[1] = 0;
      return path;
    }

    /* This is only the last resort. If there is no room, we have to copy
     * the prefix elsewhere.  */
    upath = realloc(static_path_copy, info.prefix_end - path + 2);
    if(!upath)
      return (char*) top;

    static_path_copy = upath;
    memcpy(upath, path, info.prefix_end - path);
    upath += info.prefix_end - path;
    upath[0] = *top;
    upath[1] = 0;
    return static_path_copy;
  }

char*
basename(char* path)
  {
    struct path_info info;
    char* upath;

    if(path == NULL || path[0] == 0)
      return (char*) ".";

    do_get_path_info(&info, path);
    upath = info.prefix_end ? info.prefix_end : path;

    /* If the path is non-UNC and empty, then it's relative. POSIX says '.'
     * shall be returned.  */
    if(IS_DIR_SEP(path[0]) == 0 && upath[0] == 0)
      return (char*) ".";

    /* If a terminating separator sequence exists, it is not part of the
     * name and shall be truncated.  */
    if(info.term_sep_begin)
      info.term_sep_begin[0] = 0;

    /* If some other separator sequence has been found, the basename
     * immediately follows it.  */
    if(info.base_sep_end)
      return info.base_sep_end;

    /* If removal of the terminating separator sequence has caused the
     * unprefixed path to become empty, it must have comprised only
     * separators. POSIX says `/` shall be returned, but on Windows, we
     * return `\` instead.  */
    if(upath[0] == 0)
      return (char*) "\\";

    /* Return the unprefixed path.  */
    return upath;
  }

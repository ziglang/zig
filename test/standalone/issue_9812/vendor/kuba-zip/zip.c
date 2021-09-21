/*
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */
#define __STDC_WANT_LIB_EXT1__ 1

#include <errno.h>
#include <sys/stat.h>
#include <time.h>

#if defined(_WIN32) || defined(__WIN32__) || defined(_MSC_VER) ||              \
    defined(__MINGW32__)
/* Win32, DOS, MSVC, MSVS */
#include <direct.h>

#define MKDIR(DIRNAME) _mkdir(DIRNAME)
#define STRCLONE(STR) ((STR) ? _strdup(STR) : NULL)
#define HAS_DEVICE(P)                                                          \
  ((((P)[0] >= 'A' && (P)[0] <= 'Z') || ((P)[0] >= 'a' && (P)[0] <= 'z')) &&   \
   (P)[1] == ':')
#define FILESYSTEM_PREFIX_LEN(P) (HAS_DEVICE(P) ? 2 : 0)

#else

#include <unistd.h> // needed for symlink()

#define MKDIR(DIRNAME) mkdir(DIRNAME, 0755)
#define STRCLONE(STR) ((STR) ? strdup(STR) : NULL)

#endif

#ifdef __MINGW32__
#include <sys/types.h>
#include <unistd.h>
#endif

#include "miniz.h"
#include "zip.h"

#ifdef _MSC_VER
#include <io.h>

#define ftruncate(fd, sz) (-(_chsize_s((fd), (sz)) != 0))
#define fileno _fileno
#endif

#ifndef HAS_DEVICE
#define HAS_DEVICE(P) 0
#endif

#ifndef FILESYSTEM_PREFIX_LEN
#define FILESYSTEM_PREFIX_LEN(P) 0
#endif

#ifndef ISSLASH
#define ISSLASH(C) ((C) == '/' || (C) == '\\')
#endif

#define CLEANUP(ptr)                                                           \
  do {                                                                         \
    if (ptr) {                                                                 \
      free((void *)ptr);                                                       \
      ptr = NULL;                                                              \
    }                                                                          \
  } while (0)

struct zip_entry_t {
  int index;
  char *name;
  mz_uint64 uncomp_size;
  mz_uint64 comp_size;
  mz_uint32 uncomp_crc32;
  mz_uint64 offset;
  mz_uint8 header[MZ_ZIP_LOCAL_DIR_HEADER_SIZE];
  mz_uint64 header_offset;
  mz_uint16 method;
  mz_zip_writer_add_state state;
  tdefl_compressor comp;
  mz_uint32 external_attr;
  time_t m_time;
};

struct zip_t {
  mz_zip_archive archive;
  mz_uint level;
  struct zip_entry_t entry;
};

enum zip_modify_t {
  MZ_KEEP = 0,
  MZ_DELETE = 1,
  MZ_MOVE = 2,
};

struct zip_entry_mark_t {
  int file_index;
  enum zip_modify_t type;
  mz_uint64 m_local_header_ofs;
  mz_uint64 lf_length;
};

static const char *const zip_errlist[30] = {
    NULL,
    "not initialized\0",
    "invalid entry name\0",
    "entry not found\0",
    "invalid zip mode\0",
    "invalid compression level\0",
    "no zip 64 support\0",
    "memset error\0",
    "cannot write data to entry\0",
    "cannot initialize tdefl compressor\0",
    "invalid index\0",
    "header not found\0",
    "cannot flush tdefl buffer\0",
    "cannot write entry header\0",
    "cannot create entry header\0",
    "cannot write to central dir\0",
    "cannot open file\0",
    "invalid entry type\0",
    "extracting data using no memory allocation\0",
    "file not found\0",
    "no permission\0",
    "out of memory\0",
    "invalid zip archive name\0",
    "make dir error\0",
    "symlink error\0",
    "close archive error\0",
    "capacity size too small\0",
    "fseek error\0",
    "fread error\0",
    "fwrite error\0",
};

const char *zip_strerror(int errnum) {
  errnum = -errnum;
  if (errnum <= 0 || errnum >= 30) {
    return NULL;
  }

  return zip_errlist[errnum];
}

static const char *zip_basename(const char *name) {
  char const *p;
  char const *base = name += FILESYSTEM_PREFIX_LEN(name);
  int all_slashes = 1;

  for (p = name; *p; p++) {
    if (ISSLASH(*p))
      base = p + 1;
    else
      all_slashes = 0;
  }

  /* If NAME is all slashes, arrange to return `/'. */
  if (*base == '\0' && ISSLASH(*name) && all_slashes)
    --base;

  return base;
}

static int zip_mkpath(char *path) {
  char *p;
  char npath[MAX_PATH + 1];
  int len = 0;
  int has_device = HAS_DEVICE(path);

  memset(npath, 0, MAX_PATH + 1);
  if (has_device) {
    // only on windows
    npath[0] = path[0];
    npath[1] = path[1];
    len = 2;
  }
  for (p = path + len; *p && len < MAX_PATH; p++) {
    if (ISSLASH(*p) && ((!has_device && len > 0) || (has_device && len > 2))) {
#if defined(_WIN32) || defined(__WIN32__) || defined(_MSC_VER) ||              \
    defined(__MINGW32__)
#else
      if ('\\' == *p) {
        *p = '/';
      }
#endif

      if (MKDIR(npath) == -1) {
        if (errno != EEXIST) {
          return ZIP_EMKDIR;
        }
      }
    }
    npath[len++] = *p;
  }

  return 0;
}

static char *zip_strrpl(const char *str, size_t n, char oldchar, char newchar) {
  char c;
  size_t i;
  char *rpl = (char *)calloc((1 + n), sizeof(char));
  char *begin = rpl;
  if (!rpl) {
    return NULL;
  }

  for (i = 0; (i < n) && (c = *str++); ++i) {
    if (c == oldchar) {
      c = newchar;
    }
    *rpl++ = c;
  }

  return begin;
}

static char *zip_name_normalize(char *name, char *const nname, size_t len) {
  size_t offn = 0;
  size_t offnn = 0, ncpy = 0;

  if (name == NULL || nname == NULL || len <= 0) {
    return NULL;
  }
  // skip trailing '/'
  while (ISSLASH(*name))
    name++;

  for (; offn < len; offn++) {
    if (ISSLASH(name[offn])) {
      if (ncpy > 0 && strcmp(&nname[offnn], ".\0") &&
          strcmp(&nname[offnn], "..\0")) {
        offnn += ncpy;
        nname[offnn++] = name[offn]; // append '/'
      }
      ncpy = 0;
    } else {
      nname[offnn + ncpy] = name[offn];
      ncpy++;
    }
  }

  // at the end, extra check what we've already copied
  if (ncpy == 0 || !strcmp(&nname[offnn], ".\0") ||
      !strcmp(&nname[offnn], "..\0")) {
    nname[offnn] = 0;
  }
  return nname;
}

static mz_bool zip_name_match(const char *name1, const char *name2) {
  int len2 = strlen(name2);
  char *nname2 = zip_strrpl(name2, len2, '\\', '/');
  if (!nname2) {
    return MZ_FALSE;
  }

  mz_bool res = (strcmp(name1, nname2) == 0) ? MZ_TRUE : MZ_FALSE;
  CLEANUP(nname2);
  return res;
}

static int zip_archive_truncate(mz_zip_archive *pzip) {
  mz_zip_internal_state *pState = pzip->m_pState;
  mz_uint64 file_size = pzip->m_archive_size;
  if ((pzip->m_pWrite == mz_zip_heap_write_func) && (pState->m_pMem)) {
    return 0;
  }
  if (pzip->m_zip_mode == MZ_ZIP_MODE_WRITING_HAS_BEEN_FINALIZED) {
    if (pState->m_pFile) {
      int fd = fileno(pState->m_pFile);
      return ftruncate(fd, file_size);
    }
  }
  return 0;
}

static int zip_archive_extract(mz_zip_archive *zip_archive, const char *dir,
                               int (*on_extract)(const char *filename,
                                                 void *arg),
                               void *arg) {
  int err = 0;
  mz_uint i, n;
  char path[MAX_PATH + 1];
  char symlink_to[MAX_PATH + 1];
  mz_zip_archive_file_stat info;
  size_t dirlen = 0;
  mz_uint32 xattr = 0;

  memset(path, 0, sizeof(path));
  memset(symlink_to, 0, sizeof(symlink_to));

  dirlen = strlen(dir);
  if (dirlen + 1 > MAX_PATH) {
    return ZIP_EINVENTNAME;
  }

  memset((void *)&info, 0, sizeof(mz_zip_archive_file_stat));

#if defined(_MSC_VER)
  strcpy_s(path, MAX_PATH, dir);
#else
  strcpy(path, dir);
#endif

  if (!ISSLASH(path[dirlen - 1])) {
#if defined(_WIN32) || defined(__WIN32__)
    path[dirlen] = '\\';
#else
    path[dirlen] = '/';
#endif
    ++dirlen;
  }

  // Get and print information about each file in the archive.
  n = mz_zip_reader_get_num_files(zip_archive);
  for (i = 0; i < n; ++i) {
    if (!mz_zip_reader_file_stat(zip_archive, i, &info)) {
      // Cannot get information about zip archive;
      err = ZIP_ENOENT;
      goto out;
    }

    if (!zip_name_normalize(info.m_filename, info.m_filename,
                            strlen(info.m_filename))) {
      // Cannot normalize file name;
      err = ZIP_EINVENTNAME;
      goto out;
    }
#if defined(_MSC_VER)
    strncpy_s(&path[dirlen], MAX_PATH - dirlen, info.m_filename,
              MAX_PATH - dirlen);
#else
    strncpy(&path[dirlen], info.m_filename, MAX_PATH - dirlen);
#endif
    err = zip_mkpath(path);
    if (err < 0) {
      // Cannot make a path
      goto out;
    }

    if ((((info.m_version_made_by >> 8) == 3) ||
         ((info.m_version_made_by >> 8) ==
          19)) // if zip is produced on Unix or macOS (3 and 19 from
               // section 4.4.2.2 of zip standard)
        && info.m_external_attr &
               (0x20 << 24)) { // and has sym link attribute (0x80 is file, 0x40
                               // is directory)
#if defined(_WIN32) || defined(__WIN32__) || defined(_MSC_VER) ||              \
    defined(__MINGW32__)
#else
      if (info.m_uncomp_size > MAX_PATH ||
          !mz_zip_reader_extract_to_mem_no_alloc(zip_archive, i, symlink_to,
                                                 MAX_PATH, 0, NULL, 0)) {
        err = ZIP_EMEMNOALLOC;
        goto out;
      }
      symlink_to[info.m_uncomp_size] = '\0';
      if (symlink(symlink_to, path) != 0) {
        err = ZIP_ESYMLINK;
        goto out;
      }
#endif
    } else {
      if (!mz_zip_reader_is_file_a_directory(zip_archive, i)) {
        if (!mz_zip_reader_extract_to_file(zip_archive, i, path, 0)) {
          // Cannot extract zip archive to file
          err = ZIP_ENOFILE;
          goto out;
        }
      }

#if defined(_MSC_VER)
      (void)xattr; // unused
#else
      xattr = (info.m_external_attr >> 16) & 0xFFFF;
      if (xattr > 0) {
        if (chmod(path, (mode_t)xattr) < 0) {
          err = ZIP_ENOPERM;
          goto out;
        }
      }
#endif
    }

    if (on_extract) {
      if (on_extract(path, arg) < 0) {
        goto out;
      }
    }
  }

out:
  // Close the archive, freeing any resources it was using
  if (!mz_zip_reader_end(zip_archive)) {
    // Cannot end zip reader
    err = ZIP_ECLSZIP;
  }
  return err;
}

static inline void zip_archive_finalize(mz_zip_archive *pzip) {
  mz_zip_writer_finalize_archive(pzip);
  zip_archive_truncate(pzip);
}

static int zip_entry_mark(struct zip_t *zip,
                          struct zip_entry_mark_t *entry_mark, int n,
                          char *const entries[], const size_t len) {
  int err = 0;
  if (!zip || !entry_mark || !entries) {
    return ZIP_ENOINIT;
  }

  mz_zip_archive_file_stat file_stat;
  mz_uint64 d_pos = ~0;
  for (int i = 0; i < n; ++i) {

    if ((err = zip_entry_openbyindex(zip, i))) {
      return err;
    }

    mz_bool name_matches = MZ_FALSE;
    for (int j = 0; j < (const int)len; ++j) {
      if (zip_name_match(zip->entry.name, entries[j])) {
        name_matches = MZ_TRUE;
        break;
      }
    }
    if (name_matches) {
      entry_mark[i].type = MZ_DELETE;
    } else {
      entry_mark[i].type = MZ_KEEP;
    }

    if (!mz_zip_reader_file_stat(&zip->archive, i, &file_stat)) {
      return ZIP_ENOENT;
    }

    zip_entry_close(zip);

    entry_mark[i].m_local_header_ofs = file_stat.m_local_header_ofs;
    entry_mark[i].file_index = -1;
    entry_mark[i].lf_length = 0;
    if ((entry_mark[i].type) == MZ_DELETE &&
        (d_pos > entry_mark[i].m_local_header_ofs)) {
      d_pos = entry_mark[i].m_local_header_ofs;
    }
  }
  for (int i = 0; i < n; ++i) {
    if ((entry_mark[i].m_local_header_ofs > d_pos) &&
        (entry_mark[i].type != MZ_DELETE)) {
      entry_mark[i].type = MZ_MOVE;
    }
  }
  return err;
}

static int zip_index_next(mz_uint64 *local_header_ofs_array, int cur_index) {
  int new_index = 0;
  for (int i = cur_index - 1; i >= 0; --i) {
    if (local_header_ofs_array[cur_index] > local_header_ofs_array[i]) {
      new_index = i + 1;
      return new_index;
    }
  }
  return new_index;
}

static int zip_sort(mz_uint64 *local_header_ofs_array, int cur_index) {
  int nxt_index = zip_index_next(local_header_ofs_array, cur_index);

  if (nxt_index != cur_index) {
    mz_uint64 temp = local_header_ofs_array[cur_index];
    for (int i = cur_index; i > nxt_index; i--) {
      local_header_ofs_array[i] = local_header_ofs_array[i - 1];
    }
    local_header_ofs_array[nxt_index] = temp;
  }
  return nxt_index;
}

static int zip_index_update(struct zip_entry_mark_t *entry_mark, int last_index,
                            int nxt_index) {
  for (int j = 0; j < last_index; j++) {
    if (entry_mark[j].file_index >= nxt_index) {
      entry_mark[j].file_index += 1;
    }
  }
  entry_mark[nxt_index].file_index = last_index;
  return 0;
}

static int zip_entry_finalize(struct zip_t *zip,
                              struct zip_entry_mark_t *entry_mark,
                              const int n) {

  mz_uint64 *local_header_ofs_array = (mz_uint64 *)calloc(n, sizeof(mz_uint64));
  if (!local_header_ofs_array) {
    return ZIP_EOOMEM;
  }

  for (int i = 0; i < n; ++i) {
    local_header_ofs_array[i] = entry_mark[i].m_local_header_ofs;
    int index = zip_sort(local_header_ofs_array, i);

    if (index != i) {
      zip_index_update(entry_mark, i, index);
    }
    entry_mark[i].file_index = index;
  }

  mz_uint64 *length = (mz_uint64 *)calloc(n, sizeof(mz_uint64));
  if (!length) {
    CLEANUP(local_header_ofs_array);
    return ZIP_EOOMEM;
  }
  for (int i = 0; i < n - 1; i++) {
    length[i] = local_header_ofs_array[i + 1] - local_header_ofs_array[i];
  }
  length[n - 1] = zip->archive.m_archive_size - local_header_ofs_array[n - 1];

  for (int i = 0; i < n; i++) {
    entry_mark[i].lf_length = length[entry_mark[i].file_index];
  }

  CLEANUP(length);
  CLEANUP(local_header_ofs_array);
  return 0;
}

static int zip_entry_set(struct zip_t *zip, struct zip_entry_mark_t *entry_mark,
                         int n, char *const entries[], const size_t len) {
  int err = 0;

  if ((err = zip_entry_mark(zip, entry_mark, n, entries, len)) < 0) {
    return err;
  }
  if ((err = zip_entry_finalize(zip, entry_mark, n)) < 0) {
    return err;
  }
  return 0;
}

static mz_int64 zip_file_move(MZ_FILE *m_pFile, const mz_uint64 to,
                              const mz_uint64 from, const mz_uint64 length,
                              mz_uint8 *move_buf,
                              const mz_int64 capacity_size) {
  if ((mz_int64)length > capacity_size) {
    return ZIP_ECAPSIZE;
  }
  if (MZ_FSEEK64(m_pFile, from, SEEK_SET)) {
    MZ_FCLOSE(m_pFile);
    return ZIP_EFSEEK;
  }

  if (fread(move_buf, 1, length, m_pFile) != length) {
    MZ_FCLOSE(m_pFile);
    return ZIP_EFREAD;
  }
  if (MZ_FSEEK64(m_pFile, to, SEEK_SET)) {
    MZ_FCLOSE(m_pFile);
    return ZIP_EFSEEK;
  }
  if (fwrite(move_buf, 1, length, m_pFile) != length) {
    MZ_FCLOSE(m_pFile);
    return ZIP_EFWRITE;
  }
  return (mz_int64)length;
}

static mz_int64 zip_files_move(MZ_FILE *m_pFile, mz_uint64 writen_num,
                               mz_uint64 read_num, mz_uint64 length) {
  int n = 0;
  const mz_int64 page_size = 1 << 12; // 4K
  mz_uint8 *move_buf = (mz_uint8 *)calloc(1, page_size);
  if (move_buf == NULL) {
    return ZIP_EOOMEM;
  }

  mz_int64 moved_length = 0;
  mz_int64 move_count = 0;
  while ((mz_int64)length > 0) {
    move_count = ((mz_int64)length >= page_size) ? page_size : (mz_int64)length;
    n = zip_file_move(m_pFile, writen_num, read_num, move_count, move_buf,
                      page_size);
    if (n < 0) {
      moved_length = n;
      goto cleanup;
    }

    if (n != move_count) {
      goto cleanup;
    }

    writen_num += move_count;
    read_num += move_count;
    length -= move_count;
    moved_length += move_count;
  }

cleanup:
  CLEANUP(move_buf);
  return moved_length;
}

static int zip_central_dir_move(mz_zip_internal_state *pState, int begin,
                                int end, int entry_num) {
  if (begin == entry_num) {
    return 0;
  }

  mz_uint64 l_size = 0;
  mz_uint64 r_size = 0;
  mz_uint64 d_size = 0;
  mz_uint8 *next = NULL;
  mz_uint8 *deleted = &MZ_ZIP_ARRAY_ELEMENT(
      &pState->m_central_dir, mz_uint8,
      MZ_ZIP_ARRAY_ELEMENT(&pState->m_central_dir_offsets, mz_uint32, begin));
  l_size = (mz_uint32)(deleted - (mz_uint8 *)(pState->m_central_dir.m_p));
  if (end == entry_num) {
    r_size = 0;
  } else {
    next = &MZ_ZIP_ARRAY_ELEMENT(
        &pState->m_central_dir, mz_uint8,
        MZ_ZIP_ARRAY_ELEMENT(&pState->m_central_dir_offsets, mz_uint32, end));
    r_size = pState->m_central_dir.m_size -
             (mz_uint32)(next - (mz_uint8 *)(pState->m_central_dir.m_p));
    d_size = next - deleted;
  }

  if (l_size == 0) {
    memmove(pState->m_central_dir.m_p, next, r_size);
    pState->m_central_dir.m_p = MZ_REALLOC(pState->m_central_dir.m_p, r_size);
    for (int i = end; i < entry_num; i++) {
      MZ_ZIP_ARRAY_ELEMENT(&pState->m_central_dir_offsets, mz_uint32, i) -=
          d_size;
    }
  }

  if (l_size * r_size != 0) {
    memmove(deleted, next, r_size);
    for (int i = end; i < entry_num; i++) {
      MZ_ZIP_ARRAY_ELEMENT(&pState->m_central_dir_offsets, mz_uint32, i) -=
          d_size;
    }
  }

  pState->m_central_dir.m_size = l_size + r_size;
  return 0;
}

static int zip_central_dir_delete(mz_zip_internal_state *pState,
                                  int *deleted_entry_index_array,
                                  int entry_num) {
  int i = 0;
  int begin = 0;
  int end = 0;
  int d_num = 0;
  while (i < entry_num) {
    while ((!deleted_entry_index_array[i]) && (i < entry_num)) {
      i++;
    }
    begin = i;

    while ((deleted_entry_index_array[i]) && (i < entry_num)) {
      i++;
    }
    end = i;
    zip_central_dir_move(pState, begin, end, entry_num);
  }

  i = 0;
  while (i < entry_num) {
    while ((!deleted_entry_index_array[i]) && (i < entry_num)) {
      i++;
    }
    begin = i;
    if (begin == entry_num) {
      break;
    }
    while ((deleted_entry_index_array[i]) && (i < entry_num)) {
      i++;
    }
    end = i;
    int k = 0;
    for (int j = end; j < entry_num; j++) {
      MZ_ZIP_ARRAY_ELEMENT(&pState->m_central_dir_offsets, mz_uint32,
                           begin + k) =
          (mz_uint32)MZ_ZIP_ARRAY_ELEMENT(&pState->m_central_dir_offsets,
                                          mz_uint32, j);
      k++;
    }
    d_num += end - begin;
  }

  pState->m_central_dir_offsets.m_size =
      sizeof(mz_uint32) * (entry_num - d_num);
  return 0;
}

static int zip_entries_delete_mark(struct zip_t *zip,
                                   struct zip_entry_mark_t *entry_mark,
                                   int entry_num) {
  mz_uint64 writen_num = 0;
  mz_uint64 read_num = 0;
  mz_uint64 deleted_length = 0;
  mz_uint64 move_length = 0;
  int i = 0;
  int deleted_entry_num = 0;
  int n = 0;

  mz_bool *deleted_entry_flag_array =
      (mz_bool *)calloc(entry_num, sizeof(mz_bool));
  if (deleted_entry_flag_array == NULL) {
    return ZIP_EOOMEM;
  }

  mz_zip_internal_state *pState = zip->archive.m_pState;
  zip->archive.m_zip_mode = MZ_ZIP_MODE_WRITING;

  if (MZ_FSEEK64(pState->m_pFile, 0, SEEK_SET)) {
    CLEANUP(deleted_entry_flag_array);
    return ZIP_ENOENT;
  }

  while (i < entry_num) {
    while ((entry_mark[i].type == MZ_KEEP) && (i < entry_num)) {
      writen_num += entry_mark[i].lf_length;
      read_num = writen_num;
      i++;
    }

    while ((entry_mark[i].type == MZ_DELETE) && (i < entry_num)) {
      deleted_entry_flag_array[i] = MZ_TRUE;
      read_num += entry_mark[i].lf_length;
      deleted_length += entry_mark[i].lf_length;
      i++;
      deleted_entry_num++;
    }

    while ((entry_mark[i].type == MZ_MOVE) && (i < entry_num)) {
      move_length += entry_mark[i].lf_length;
      mz_uint8 *p = &MZ_ZIP_ARRAY_ELEMENT(
          &pState->m_central_dir, mz_uint8,
          MZ_ZIP_ARRAY_ELEMENT(&pState->m_central_dir_offsets, mz_uint32, i));
      if (!p) {
        CLEANUP(deleted_entry_flag_array);
        return ZIP_ENOENT;
      }
      mz_uint32 offset = MZ_READ_LE32(p + MZ_ZIP_CDH_LOCAL_HEADER_OFS);
      offset -= (mz_uint32)deleted_length;
      MZ_WRITE_LE32(p + MZ_ZIP_CDH_LOCAL_HEADER_OFS, offset);
      i++;
    }

    n = zip_files_move(pState->m_pFile, writen_num, read_num, move_length);
    if (n != (mz_int64)move_length) {
      CLEANUP(deleted_entry_flag_array);
      return n;
    }
    writen_num += move_length;
    read_num += move_length;
  }

  zip->archive.m_archive_size -= deleted_length;
  zip->archive.m_total_files = entry_num - deleted_entry_num;

  zip_central_dir_delete(pState, deleted_entry_flag_array, entry_num);
  CLEANUP(deleted_entry_flag_array);

  return deleted_entry_num;
}

struct zip_t *zip_open(const char *zipname, int level, char mode) {
  struct zip_t *zip = NULL;

  if (!zipname || strlen(zipname) < 1) {
    // zip_t archive name is empty or NULL
    goto cleanup;
  }

  if (level < 0)
    level = MZ_DEFAULT_LEVEL;
  if ((level & 0xF) > MZ_UBER_COMPRESSION) {
    // Wrong compression level
    goto cleanup;
  }

  zip = (struct zip_t *)calloc((size_t)1, sizeof(struct zip_t));
  if (!zip)
    goto cleanup;

  zip->level = (mz_uint)level;
  switch (mode) {
  case 'w':
    // Create a new archive.
    if (!mz_zip_writer_init_file(&(zip->archive), zipname, 0)) {
      // Cannot initialize zip_archive writer
      goto cleanup;
    }
    break;

  case 'r':
  case 'a':
  case 'd':
    if (!mz_zip_reader_init_file(
            &(zip->archive), zipname,
            zip->level | MZ_ZIP_FLAG_DO_NOT_SORT_CENTRAL_DIRECTORY)) {
      // An archive file does not exist or cannot initialize
      // zip_archive reader
      goto cleanup;
    }
    if ((mode == 'a' || mode == 'd') &&
        !mz_zip_writer_init_from_reader(&(zip->archive), zipname)) {
      mz_zip_reader_end(&(zip->archive));
      goto cleanup;
    }
    break;

  default:
    goto cleanup;
  }

  return zip;

cleanup:
  CLEANUP(zip);
  return NULL;
}

void zip_close(struct zip_t *zip) {
  if (zip) {
    // Always finalize, even if adding failed for some reason, so we have a
    // valid central directory.
    mz_zip_writer_finalize_archive(&(zip->archive));
    zip_archive_truncate(&(zip->archive));
    mz_zip_writer_end(&(zip->archive));
    mz_zip_reader_end(&(zip->archive));

    CLEANUP(zip);
  }
}

int zip_is64(struct zip_t *zip) {
  if (!zip || !zip->archive.m_pState) {
    // zip_t handler or zip state is not initialized
    return ZIP_ENOINIT;
  }

  return (int)zip->archive.m_pState->m_zip64;
}

int zip_entry_open(struct zip_t *zip, const char *entryname) {
  size_t entrylen = 0;
  mz_zip_archive *pzip = NULL;
  mz_uint num_alignment_padding_bytes, level;
  mz_zip_archive_file_stat stats;
  int err = 0;

  if (!zip) {
    return ZIP_ENOINIT;
  }

  if (!entryname) {
    return ZIP_EINVENTNAME;
  }

  entrylen = strlen(entryname);
  if (entrylen == 0) {
    return ZIP_EINVENTNAME;
  }

  /*
    .ZIP File Format Specification Version: 6.3.3

    4.4.17.1 The name of the file, with optional relative path.
    The path stored MUST not contain a drive or
    device letter, or a leading slash.  All slashes
    MUST be forward slashes '/' as opposed to
    backwards slashes '\' for compatibility with Amiga
    and UNIX file systems etc.  If input came from standard
    input, there is no file name field.
  */
  if (zip->entry.name) {
    CLEANUP(zip->entry.name);
  }
  zip->entry.name = zip_strrpl(entryname, entrylen, '\\', '/');
  if (!zip->entry.name) {
    // Cannot parse zip entry name
    return ZIP_EINVENTNAME;
  }

  pzip = &(zip->archive);
  if (pzip->m_zip_mode == MZ_ZIP_MODE_READING) {
    zip->entry.index =
        mz_zip_reader_locate_file(pzip, zip->entry.name, NULL, 0);
    if (zip->entry.index < 0) {
      err = ZIP_ENOENT;
      goto cleanup;
    }

    if (!mz_zip_reader_file_stat(pzip, (mz_uint)zip->entry.index, &stats)) {
      err = ZIP_ENOENT;
      goto cleanup;
    }

    zip->entry.comp_size = stats.m_comp_size;
    zip->entry.uncomp_size = stats.m_uncomp_size;
    zip->entry.uncomp_crc32 = stats.m_crc32;
    zip->entry.offset = stats.m_central_dir_ofs;
    zip->entry.header_offset = stats.m_local_header_ofs;
    zip->entry.method = stats.m_method;
    zip->entry.external_attr = stats.m_external_attr;
#ifndef MINIZ_NO_TIME
    zip->entry.m_time = stats.m_time;
#endif

    return 0;
  }

  zip->entry.index = (int)zip->archive.m_total_files;
  zip->entry.comp_size = 0;
  zip->entry.uncomp_size = 0;
  zip->entry.uncomp_crc32 = MZ_CRC32_INIT;
  zip->entry.offset = zip->archive.m_archive_size;
  zip->entry.header_offset = zip->archive.m_archive_size;
  memset(zip->entry.header, 0, MZ_ZIP_LOCAL_DIR_HEADER_SIZE * sizeof(mz_uint8));
  zip->entry.method = 0;

  // UNIX or APPLE
#if MZ_PLATFORM == 3 || MZ_PLATFORM == 19
  // regular file with rw-r--r-- persmissions
  zip->entry.external_attr = (mz_uint32)(0100644) << 16;
#else
  zip->entry.external_attr = 0;
#endif

  num_alignment_padding_bytes =
      mz_zip_writer_compute_padding_needed_for_file_alignment(pzip);

  if (!pzip->m_pState || (pzip->m_zip_mode != MZ_ZIP_MODE_WRITING)) {
    // Invalid zip mode
    err = ZIP_EINVMODE;
    goto cleanup;
  }
  if (zip->level & MZ_ZIP_FLAG_COMPRESSED_DATA) {
    // Invalid zip compression level
    err = ZIP_EINVLVL;
    goto cleanup;
  }
  // no zip64 support yet
  if ((pzip->m_total_files == 0xFFFF) ||
      ((pzip->m_archive_size + num_alignment_padding_bytes +
        MZ_ZIP_LOCAL_DIR_HEADER_SIZE + MZ_ZIP_CENTRAL_DIR_HEADER_SIZE +
        entrylen) > 0xFFFFFFFF)) {
    // No zip64 support yet
    err = ZIP_ENOSUP64;
    goto cleanup;
  }
  if (!mz_zip_writer_write_zeros(pzip, zip->entry.offset,
                                 num_alignment_padding_bytes +
                                     sizeof(zip->entry.header))) {
    // Cannot memset zip entry header
    err = ZIP_EMEMSET;
    goto cleanup;
  }

  zip->entry.header_offset += num_alignment_padding_bytes;
  if (pzip->m_file_offset_alignment) {
    MZ_ASSERT(
        (zip->entry.header_offset & (pzip->m_file_offset_alignment - 1)) == 0);
  }
  zip->entry.offset += num_alignment_padding_bytes + sizeof(zip->entry.header);

  if (pzip->m_pWrite(pzip->m_pIO_opaque, zip->entry.offset, zip->entry.name,
                     entrylen) != entrylen) {
    // Cannot write data to zip entry
    err = ZIP_EWRTENT;
    goto cleanup;
  }

  zip->entry.offset += entrylen;
  level = zip->level & 0xF;
  if (level) {
    zip->entry.state.m_pZip = pzip;
    zip->entry.state.m_cur_archive_file_ofs = zip->entry.offset;
    zip->entry.state.m_comp_size = 0;

    if (tdefl_init(&(zip->entry.comp), mz_zip_writer_add_put_buf_callback,
                   &(zip->entry.state),
                   (int)tdefl_create_comp_flags_from_zip_params(
                       (int)level, -15, MZ_DEFAULT_STRATEGY)) !=
        TDEFL_STATUS_OKAY) {
      // Cannot initialize the zip compressor
      err = ZIP_ETDEFLINIT;
      goto cleanup;
    }
  }

  zip->entry.m_time = time(NULL);

  return 0;

cleanup:
  CLEANUP(zip->entry.name);
  return err;
}

int zip_entry_openbyindex(struct zip_t *zip, int index) {
  mz_zip_archive *pZip = NULL;
  mz_zip_archive_file_stat stats;
  mz_uint namelen;
  const mz_uint8 *pHeader;
  const char *pFilename;

  if (!zip) {
    // zip_t handler is not initialized
    return ZIP_ENOINIT;
  }

  pZip = &(zip->archive);
  if (pZip->m_zip_mode != MZ_ZIP_MODE_READING) {
    // open by index requires readonly mode
    return ZIP_EINVMODE;
  }

  if (index < 0 || (mz_uint)index >= pZip->m_total_files) {
    // index out of range
    return ZIP_EINVIDX;
  }

  if (!(pHeader = &MZ_ZIP_ARRAY_ELEMENT(
            &pZip->m_pState->m_central_dir, mz_uint8,
            MZ_ZIP_ARRAY_ELEMENT(&pZip->m_pState->m_central_dir_offsets,
                                 mz_uint32, index)))) {
    // cannot find header in central directory
    return ZIP_ENOHDR;
  }

  namelen = MZ_READ_LE16(pHeader + MZ_ZIP_CDH_FILENAME_LEN_OFS);
  pFilename = (const char *)pHeader + MZ_ZIP_CENTRAL_DIR_HEADER_SIZE;

  /*
    .ZIP File Format Specification Version: 6.3.3

    4.4.17.1 The name of the file, with optional relative path.
    The path stored MUST not contain a drive or
    device letter, or a leading slash.  All slashes
    MUST be forward slashes '/' as opposed to
    backwards slashes '\' for compatibility with Amiga
    and UNIX file systems etc.  If input came from standard
    input, there is no file name field.
  */
  if (zip->entry.name) {
    CLEANUP(zip->entry.name);
  }
  zip->entry.name = zip_strrpl(pFilename, namelen, '\\', '/');
  if (!zip->entry.name) {
    // local entry name is NULL
    return ZIP_EINVENTNAME;
  }

  if (!mz_zip_reader_file_stat(pZip, (mz_uint)index, &stats)) {
    return ZIP_ENOENT;
  }

  zip->entry.index = index;
  zip->entry.comp_size = stats.m_comp_size;
  zip->entry.uncomp_size = stats.m_uncomp_size;
  zip->entry.uncomp_crc32 = stats.m_crc32;
  zip->entry.offset = stats.m_central_dir_ofs;
  zip->entry.header_offset = stats.m_local_header_ofs;
  zip->entry.method = stats.m_method;
  zip->entry.external_attr = stats.m_external_attr;
#ifndef MINIZ_NO_TIME
  zip->entry.m_time = stats.m_time;
#endif

  return 0;
}

int zip_entry_close(struct zip_t *zip) {
  mz_zip_archive *pzip = NULL;
  mz_uint level;
  tdefl_status done;
  mz_uint16 entrylen;
  mz_uint16 dos_time = 0, dos_date = 0;
  int err = 0;

  if (!zip) {
    // zip_t handler is not initialized
    err = ZIP_ENOINIT;
    goto cleanup;
  }

  pzip = &(zip->archive);
  if (pzip->m_zip_mode == MZ_ZIP_MODE_READING) {
    goto cleanup;
  }

  level = zip->level & 0xF;
  if (level) {
    done = tdefl_compress_buffer(&(zip->entry.comp), "", 0, TDEFL_FINISH);
    if (done != TDEFL_STATUS_DONE && done != TDEFL_STATUS_OKAY) {
      // Cannot flush compressed buffer
      err = ZIP_ETDEFLBUF;
      goto cleanup;
    }
    zip->entry.comp_size = zip->entry.state.m_comp_size;
    zip->entry.offset = zip->entry.state.m_cur_archive_file_ofs;
    zip->entry.method = MZ_DEFLATED;
  }

  entrylen = (mz_uint16)strlen(zip->entry.name);
  if ((zip->entry.comp_size > 0xFFFFFFFF) || (zip->entry.offset > 0xFFFFFFFF)) {
    // No zip64 support, yet
    err = ZIP_ENOSUP64;
    goto cleanup;
  }

#ifndef MINIZ_NO_TIME
  mz_zip_time_t_to_dos_time(zip->entry.m_time, &dos_time, &dos_date);
#endif

  if (!mz_zip_writer_create_local_dir_header(
          pzip, zip->entry.header, entrylen, 0, zip->entry.uncomp_size,
          zip->entry.comp_size, zip->entry.uncomp_crc32, zip->entry.method, 0,
          dos_time, dos_date)) {
    // Cannot create zip entry header
    err = ZIP_ECRTHDR;
    goto cleanup;
  }

  if (pzip->m_pWrite(pzip->m_pIO_opaque, zip->entry.header_offset,
                     zip->entry.header,
                     sizeof(zip->entry.header)) != sizeof(zip->entry.header)) {
    // Cannot write zip entry header
    err = ZIP_EWRTHDR;
    goto cleanup;
  }

  if (!mz_zip_writer_add_to_central_dir(
          pzip, zip->entry.name, entrylen, NULL, 0, "", 0,
          zip->entry.uncomp_size, zip->entry.comp_size, zip->entry.uncomp_crc32,
          zip->entry.method, 0, dos_time, dos_date, zip->entry.header_offset,
          zip->entry.external_attr)) {
    // Cannot write to zip central dir
    err = ZIP_EWRTDIR;
    goto cleanup;
  }

  pzip->m_total_files++;
  pzip->m_archive_size = zip->entry.offset;

cleanup:
  if (zip) {
    zip->entry.m_time = 0;
    CLEANUP(zip->entry.name);
  }
  return err;
}

const char *zip_entry_name(struct zip_t *zip) {
  if (!zip) {
    // zip_t handler is not initialized
    return NULL;
  }

  return zip->entry.name;
}

int zip_entry_index(struct zip_t *zip) {
  if (!zip) {
    // zip_t handler is not initialized
    return ZIP_ENOINIT;
  }

  return zip->entry.index;
}

int zip_entry_isdir(struct zip_t *zip) {
  if (!zip) {
    // zip_t handler is not initialized
    return ZIP_ENOINIT;
  }

  if (zip->entry.index < 0) {
    // zip entry is not opened
    return ZIP_EINVIDX;
  }

  return (int)mz_zip_reader_is_file_a_directory(&zip->archive,
                                                (mz_uint)zip->entry.index);
}

unsigned long long zip_entry_size(struct zip_t *zip) {
  return zip ? zip->entry.uncomp_size : 0;
}

unsigned int zip_entry_crc32(struct zip_t *zip) {
  return zip ? zip->entry.uncomp_crc32 : 0;
}

int zip_entry_write(struct zip_t *zip, const void *buf, size_t bufsize) {
  mz_uint level;
  mz_zip_archive *pzip = NULL;
  tdefl_status status;

  if (!zip) {
    // zip_t handler is not initialized
    return ZIP_ENOINIT;
  }

  pzip = &(zip->archive);
  if (buf && bufsize > 0) {
    zip->entry.uncomp_size += bufsize;
    zip->entry.uncomp_crc32 = (mz_uint32)mz_crc32(
        zip->entry.uncomp_crc32, (const mz_uint8 *)buf, bufsize);

    level = zip->level & 0xF;
    if (!level) {
      if ((pzip->m_pWrite(pzip->m_pIO_opaque, zip->entry.offset, buf,
                          bufsize) != bufsize)) {
        // Cannot write buffer
        return ZIP_EWRTENT;
      }
      zip->entry.offset += bufsize;
      zip->entry.comp_size += bufsize;
    } else {
      status = tdefl_compress_buffer(&(zip->entry.comp), buf, bufsize,
                                     TDEFL_NO_FLUSH);
      if (status != TDEFL_STATUS_DONE && status != TDEFL_STATUS_OKAY) {
        // Cannot compress buffer
        return ZIP_ETDEFLBUF;
      }
    }
  }

  return 0;
}

int zip_entry_fwrite(struct zip_t *zip, const char *filename) {
  int err = 0;
  size_t n = 0;
  FILE *stream = NULL;
  mz_uint8 buf[MZ_ZIP_MAX_IO_BUF_SIZE];
  struct MZ_FILE_STAT_STRUCT file_stat;

  if (!zip) {
    // zip_t handler is not initialized
    return ZIP_ENOINIT;
  }

  memset(buf, 0, MZ_ZIP_MAX_IO_BUF_SIZE);
  memset((void *)&file_stat, 0, sizeof(struct MZ_FILE_STAT_STRUCT));
  if (MZ_FILE_STAT(filename, &file_stat) != 0) {
    // problem getting information - check errno
    return ZIP_ENOENT;
  }

  if ((file_stat.st_mode & 0200) == 0) {
    // MS-DOS read-only attribute
    zip->entry.external_attr |= 0x01;
  }
  zip->entry.external_attr |= (mz_uint32)((file_stat.st_mode & 0xFFFF) << 16);
  zip->entry.m_time = file_stat.st_mtime;

#if defined(_MSC_VER)
  if (fopen_s(&stream, filename, "rb"))
#else
  if (!(stream = fopen(filename, "rb")))
#endif
  {
    // Cannot open filename
    return ZIP_EOPNFILE;
  }

  while ((n = fread(buf, sizeof(mz_uint8), MZ_ZIP_MAX_IO_BUF_SIZE, stream)) >
         0) {
    if (zip_entry_write(zip, buf, n) < 0) {
      err = ZIP_EWRTENT;
      break;
    }
  }
  fclose(stream);

  return err;
}

ssize_t zip_entry_read(struct zip_t *zip, void **buf, size_t *bufsize) {
  mz_zip_archive *pzip = NULL;
  mz_uint idx;
  size_t size = 0;

  if (!zip) {
    // zip_t handler is not initialized
    return (ssize_t)ZIP_ENOINIT;
  }

  pzip = &(zip->archive);
  if (pzip->m_zip_mode != MZ_ZIP_MODE_READING || zip->entry.index < 0) {
    // the entry is not found or we do not have read access
    return (ssize_t)ZIP_ENOENT;
  }

  idx = (mz_uint)zip->entry.index;
  if (mz_zip_reader_is_file_a_directory(pzip, idx)) {
    // the entry is a directory
    return (ssize_t)ZIP_EINVENTTYPE;
  }

  *buf = mz_zip_reader_extract_to_heap(pzip, idx, &size, 0);
  if (*buf && bufsize) {
    *bufsize = size;
  }
  return (ssize_t)size;
}

ssize_t zip_entry_noallocread(struct zip_t *zip, void *buf, size_t bufsize) {
  mz_zip_archive *pzip = NULL;

  if (!zip) {
    // zip_t handler is not initialized
    return (ssize_t)ZIP_ENOINIT;
  }

  pzip = &(zip->archive);
  if (pzip->m_zip_mode != MZ_ZIP_MODE_READING || zip->entry.index < 0) {
    // the entry is not found or we do not have read access
    return (ssize_t)ZIP_ENOENT;
  }

  if (!mz_zip_reader_extract_to_mem_no_alloc(pzip, (mz_uint)zip->entry.index,
                                             buf, bufsize, 0, NULL, 0)) {
    return (ssize_t)ZIP_EMEMNOALLOC;
  }

  return (ssize_t)zip->entry.uncomp_size;
}

int zip_entry_fread(struct zip_t *zip, const char *filename) {
  mz_zip_archive *pzip = NULL;
  mz_uint idx;
  mz_uint32 xattr = 0;
  mz_zip_archive_file_stat info;

  if (!zip) {
    // zip_t handler is not initialized
    return ZIP_ENOINIT;
  }

  memset((void *)&info, 0, sizeof(mz_zip_archive_file_stat));
  pzip = &(zip->archive);
  if (pzip->m_zip_mode != MZ_ZIP_MODE_READING || zip->entry.index < 0) {
    // the entry is not found or we do not have read access
    return ZIP_ENOENT;
  }

  idx = (mz_uint)zip->entry.index;
  if (mz_zip_reader_is_file_a_directory(pzip, idx)) {
    // the entry is a directory
    return ZIP_EINVENTTYPE;
  }

  if (!mz_zip_reader_extract_to_file(pzip, idx, filename, 0)) {
    return ZIP_ENOFILE;
  }

#if defined(_MSC_VER)
  (void)xattr; // unused
#else
  if (!mz_zip_reader_file_stat(pzip, idx, &info)) {
    // Cannot get information about zip archive;
    return ZIP_ENOFILE;
  }

  xattr = (info.m_external_attr >> 16) & 0xFFFF;
  if (xattr > 0) {
    if (chmod(filename, (mode_t)xattr) < 0) {
      return ZIP_ENOPERM;
    }
  }
#endif

  return 0;
}

int zip_entry_extract(struct zip_t *zip,
                      size_t (*on_extract)(void *arg, unsigned long long offset,
                                           const void *buf, size_t bufsize),
                      void *arg) {
  mz_zip_archive *pzip = NULL;
  mz_uint idx;

  if (!zip) {
    // zip_t handler is not initialized
    return ZIP_ENOINIT;
  }

  pzip = &(zip->archive);
  if (pzip->m_zip_mode != MZ_ZIP_MODE_READING || zip->entry.index < 0) {
    // the entry is not found or we do not have read access
    return ZIP_ENOENT;
  }

  idx = (mz_uint)zip->entry.index;
  return (mz_zip_reader_extract_to_callback(pzip, idx, on_extract, arg, 0))
             ? 0
             : ZIP_EINVIDX;
}

int zip_entries_total(struct zip_t *zip) {
  if (!zip) {
    // zip_t handler is not initialized
    return ZIP_ENOINIT;
  }

  return (int)zip->archive.m_total_files;
}

int zip_entries_delete(struct zip_t *zip, char *const entries[],
                       const size_t len) {
  int n = 0;
  int err = 0;
  struct zip_entry_mark_t *entry_mark = NULL;

  if (zip == NULL || (entries == NULL && len != 0)) {
    return ZIP_ENOINIT;
  }

  if (entries == NULL && len == 0) {
    return 0;
  }

  n = zip_entries_total(zip);

  entry_mark =
      (struct zip_entry_mark_t *)calloc(n, sizeof(struct zip_entry_mark_t));
  if (!entry_mark) {
    return ZIP_EOOMEM;
  }

  zip->archive.m_zip_mode = MZ_ZIP_MODE_READING;

  err = zip_entry_set(zip, entry_mark, n, entries, len);
  if (err < 0) {
    CLEANUP(entry_mark);
    return err;
  }

  err = zip_entries_delete_mark(zip, entry_mark, n);
  CLEANUP(entry_mark);
  return err;
}

int zip_stream_extract(const char *stream, size_t size, const char *dir,
                       int (*on_extract)(const char *filename, void *arg),
                       void *arg) {
  mz_zip_archive zip_archive;
  if (!stream || !dir) {
    // Cannot parse zip archive stream
    return ZIP_ENOINIT;
  }
  if (!memset(&zip_archive, 0, sizeof(mz_zip_archive))) {
    // Cannot memset zip archive
    return ZIP_EMEMSET;
  }
  if (!mz_zip_reader_init_mem(&zip_archive, stream, size, 0)) {
    // Cannot initialize zip_archive reader
    return ZIP_ENOINIT;
  }

  return zip_archive_extract(&zip_archive, dir, on_extract, arg);
}

struct zip_t *zip_stream_open(const char *stream, size_t size, int level,
                              char mode) {
  struct zip_t *zip = (struct zip_t *)calloc((size_t)1, sizeof(struct zip_t));
  if (!zip) {
    return NULL;
  }

  if (level < 0) {
    level = MZ_DEFAULT_LEVEL;
  }
  if ((level & 0xF) > MZ_UBER_COMPRESSION) {
    // Wrong compression level
    goto cleanup;
  }
  zip->level = (mz_uint)level;

  if ((stream != NULL) && (size > 0) && (mode == 'r')) {
    if (!mz_zip_reader_init_mem(&(zip->archive), stream, size, 0)) {
      goto cleanup;
    }
  } else if ((stream == NULL) && (size == 0) && (mode == 'w')) {
    // Create a new archive.
    if (!mz_zip_writer_init_heap(&(zip->archive), 0, 1024)) {
      // Cannot initialize zip_archive writer
      goto cleanup;
    }
  } else {
    goto cleanup;
  }
  return zip;

cleanup:
  CLEANUP(zip);
  return NULL;
}

ssize_t zip_stream_copy(struct zip_t *zip, void **buf, size_t *bufsize) {
  if (!zip) {
    return (ssize_t)ZIP_ENOINIT;
  }

  zip_archive_finalize(&(zip->archive));

  if (bufsize != NULL) {
    *bufsize = (size_t)zip->archive.m_archive_size;
  }
  *buf = calloc(sizeof(unsigned char), zip->archive.m_archive_size);
  memcpy(*buf, zip->archive.m_pState->m_pMem, zip->archive.m_archive_size);

  return (ssize_t)zip->archive.m_archive_size;
}

void zip_stream_close(struct zip_t *zip) {
  if (zip) {
    mz_zip_writer_end(&(zip->archive));
    mz_zip_reader_end(&(zip->archive));
    CLEANUP(zip);
  }
}

int zip_create(const char *zipname, const char *filenames[], size_t len) {
  int err = 0;
  size_t i;
  mz_zip_archive zip_archive;
  struct MZ_FILE_STAT_STRUCT file_stat;
  mz_uint32 ext_attributes = 0;

  if (!zipname || strlen(zipname) < 1) {
    // zip_t archive name is empty or NULL
    return ZIP_EINVZIPNAME;
  }

  // Create a new archive.
  if (!memset(&(zip_archive), 0, sizeof(zip_archive))) {
    // Cannot memset zip archive
    return ZIP_EMEMSET;
  }

  if (!mz_zip_writer_init_file(&zip_archive, zipname, 0)) {
    // Cannot initialize zip_archive writer
    return ZIP_ENOINIT;
  }

  if (!memset((void *)&file_stat, 0, sizeof(struct MZ_FILE_STAT_STRUCT))) {
    return ZIP_EMEMSET;
  }

  for (i = 0; i < len; ++i) {
    const char *name = filenames[i];
    if (!name) {
      err = ZIP_EINVENTNAME;
      break;
    }

    if (MZ_FILE_STAT(name, &file_stat) != 0) {
      // problem getting information - check errno
      err = ZIP_ENOFILE;
      break;
    }

    if ((file_stat.st_mode & 0200) == 0) {
      // MS-DOS read-only attribute
      ext_attributes |= 0x01;
    }
    ext_attributes |= (mz_uint32)((file_stat.st_mode & 0xFFFF) << 16);

    if (!mz_zip_writer_add_file(&zip_archive, zip_basename(name), name, "", 0,
                                ZIP_DEFAULT_COMPRESSION_LEVEL,
                                ext_attributes)) {
      // Cannot add file to zip_archive
      err = ZIP_ENOFILE;
      break;
    }
  }

  mz_zip_writer_finalize_archive(&zip_archive);
  mz_zip_writer_end(&zip_archive);
  return err;
}

int zip_extract(const char *zipname, const char *dir,
                int (*on_extract)(const char *filename, void *arg), void *arg) {
  mz_zip_archive zip_archive;

  if (!zipname || !dir) {
    // Cannot parse zip archive name
    return ZIP_EINVZIPNAME;
  }

  if (!memset(&zip_archive, 0, sizeof(mz_zip_archive))) {
    // Cannot memset zip archive
    return ZIP_EMEMSET;
  }

  // Now try to open the archive.
  if (!mz_zip_reader_init_file(&zip_archive, zipname, 0)) {
    // Cannot initialize zip_archive reader
    return ZIP_ENOINIT;
  }

  return zip_archive_extract(&zip_archive, dir, on_extract, arg);
}

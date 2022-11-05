/*
 * Copyright (c) 2018 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "windows_sdk.h"

#if defined(_WIN32)

#include "windows_com.hpp"
#include <inttypes.h>
#include <assert.h>

const char *ZIG_WINDOWS_KIT_REG_KEY = "SOFTWARE\\Microsoft\\Windows Kits\\Installed Roots";

struct ZigWindowsSDKPrivate {
    ZigWindowsSDK base;
};

enum NativeArch {
    NativeArchArm,
    NativeArchx86,
    NativeArchx86_64,
    NativeArchAarch64,
};

#if defined(_M_ARM) || defined(__arm_)
static const NativeArch native_arch = NativeArchArm;
#elif defined(_M_IX86) || defined(__i386__)
static const NativeArch native_arch = NativeArchx86;
#elif defined(_M_X64) || defined(__x86_64__)
static const NativeArch native_arch = NativeArchx86_64;
#elif defined(_M_ARM64) || defined(__aarch64__)
static const NativeArch native_arch = NativeArchAarch64;
#else
#error unsupported architecture
#endif

void zig_free_windows_sdk(struct ZigWindowsSDK *sdk) {
    if (sdk == nullptr) {
        return;
    }
    free((void*)sdk->path10_ptr);
    free((void*)sdk->version10_ptr);
    free((void*)sdk->path81_ptr);
    free((void*)sdk->version81_ptr);
    free((void*)sdk->msvc_lib_dir_ptr);
}

static ZigFindWindowsSdkError find_msvc_lib_dir(ZigWindowsSDKPrivate *priv) {
    //COM Smart Pointers requires explicit scope
    {
        HRESULT rc = CoInitializeEx(NULL, COINIT_MULTITHREADED);
        if (rc != S_OK && rc != S_FALSE) {
            goto com_done;
        }

        //This COM class is installed when a VS2017
        ISetupConfigurationPtr setup_config;
        rc = setup_config.CreateInstance(__uuidof(SetupConfiguration));
        if (rc != S_OK) {
            goto com_done;
        }

        IEnumSetupInstancesPtr all_instances;
        rc = setup_config->EnumInstances(&all_instances);
        if (rc != S_OK) {
            goto com_done;
        }

        ISetupInstance* curr_instance;
        ULONG found_inst;
        while ((rc = all_instances->Next(1, &curr_instance, &found_inst) == S_OK)) {
            BSTR bstr_inst_path;
            rc = curr_instance->GetInstallationPath(&bstr_inst_path);
            if (rc != S_OK) {
                goto com_done;
            }
            //BSTRs are UTF-16 encoded, so we need to convert the string & adjust the length
            //TODO call an actual function to do this
            UINT bstr_path_len = *((UINT*)bstr_inst_path - 1);
            ULONG tmp_path_len = bstr_path_len / 2 + 1;
            char* conv_path = (char*)bstr_inst_path;
            // TODO don't use alloca
            char *tmp_path = (char*)alloca(tmp_path_len);
            memset(tmp_path, 0, tmp_path_len);
            uint32_t c = 0;
            for (uint32_t i = 0; i < bstr_path_len; i += 2) {
                tmp_path[c] = conv_path[i];
                ++c;
                assert(c != tmp_path_len);
            }
            char output_path[4096];
            output_path[0] = 0;
            char *out_append_ptr = output_path;

            out_append_ptr += sprintf(out_append_ptr, "%s\\", tmp_path);

            char tmp_buf[4096];
            sprintf(tmp_buf, "%s%s", output_path, "VC\\Auxiliary\\Build\\Microsoft.VCToolsVersion.default.txt");
            FILE* tools_file = fopen(tmp_buf, "rb");
            if (!tools_file) {
                goto com_done;
            }
            memset(tmp_path, 0, tmp_path_len);
            fgets(tmp_path, tmp_path_len, tools_file);
            strtok(tmp_path, " \r\n");
            fclose(tools_file);
            out_append_ptr += sprintf(out_append_ptr, "VC\\Tools\\MSVC\\%s\\lib\\", tmp_path);
            switch (native_arch) {
            case NativeArchx86:
                out_append_ptr += sprintf(out_append_ptr, "x86\\");
                break;
            case NativeArchx86_64:
                out_append_ptr += sprintf(out_append_ptr, "x64\\");
                break;
            case NativeArchArm:
                out_append_ptr += sprintf(out_append_ptr, "arm\\");
                break;
            case NativeArchAarch64:
                out_append_ptr += sprintf(out_append_ptr, "arm64\\");
                break;
            }
            sprintf(tmp_buf, "%s%s", output_path, "vcruntime.lib");

            if (GetFileAttributesA(tmp_buf) != INVALID_FILE_ATTRIBUTES) {
                priv->base.msvc_lib_dir_ptr = strdup(output_path);
                if (priv->base.msvc_lib_dir_ptr == nullptr) {
                    return ZigFindWindowsSdkErrorOutOfMemory;
                }
                priv->base.msvc_lib_dir_len = strlen(priv->base.msvc_lib_dir_ptr);
                return ZigFindWindowsSdkErrorNone;
            }
        }
    }

com_done:;
    HKEY key;
    HRESULT rc = RegOpenKeyEx(HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\VisualStudio\\SxS\\VS7", 0,
        KEY_QUERY_VALUE | KEY_WOW64_32KEY, &key);
    if (rc != ERROR_SUCCESS) {
        return ZigFindWindowsSdkErrorNotFound;
    }

    DWORD dw_type = 0;
    DWORD cb_data = 0;
    rc = RegQueryValueEx(key, "14.0", NULL, &dw_type, NULL, &cb_data);
    if ((rc == ERROR_FILE_NOT_FOUND) || (REG_SZ != dw_type)) {
        return ZigFindWindowsSdkErrorNotFound;
    }

    char tmp_buf[4096];

    RegQueryValueExA(key, "14.0", NULL, NULL, (LPBYTE)tmp_buf, &cb_data);
    // RegQueryValueExA returns the length of the string INCLUDING the null terminator
    char *tmp_buf_append_ptr = tmp_buf + (cb_data - 1);
    tmp_buf_append_ptr += sprintf(tmp_buf_append_ptr, "VC\\Lib\\");
    switch (native_arch) {
    case NativeArchx86:
        //x86 is in the root of the Lib folder
        break;
    case NativeArchx86_64:
        tmp_buf_append_ptr += sprintf(tmp_buf_append_ptr, "amd64\\");
        break;
    case NativeArchArm:
        tmp_buf_append_ptr += sprintf(tmp_buf_append_ptr, "arm\\");
        break;
    case NativeArchAarch64:
        tmp_buf_append_ptr += sprintf(tmp_buf_append_ptr, "arm64\\");
        break;
    }

    char *output_path = strdup(tmp_buf);
    if (output_path == nullptr) {
        return ZigFindWindowsSdkErrorOutOfMemory;
    }

    tmp_buf_append_ptr += sprintf(tmp_buf_append_ptr, "vcruntime.lib");

    if (GetFileAttributesA(tmp_buf) != INVALID_FILE_ATTRIBUTES) {
        priv->base.msvc_lib_dir_ptr = output_path;
        priv->base.msvc_lib_dir_len = strlen(output_path);
        return ZigFindWindowsSdkErrorNone;
    } else {
        free(output_path);
        return ZigFindWindowsSdkErrorNotFound;
    }
}

static ZigFindWindowsSdkError find_10_version(ZigWindowsSDKPrivate *priv) {
    if (priv->base.path10_ptr == nullptr) {
        return ZigFindWindowsSdkErrorNone;
    }

	char reg_query[MAX_PATH] = { 0 };
	int n = snprintf(reg_query, MAX_PATH, "%s\\%s.0\\Installed Options", ZIG_WINDOWS_KIT_REG_KEY, priv->base.version10_ptr);
	if (n < 0 || n >= MAX_PATH) {
		return ZigFindWindowsSdkErrorPathTooLong;
	}

	HKEY options_key;
	HRESULT rc;
	rc = RegOpenKeyEx(HKEY_LOCAL_MACHINE, reg_query, 0,
		KEY_QUERY_VALUE | KEY_WOW64_32KEY | KEY_ENUMERATE_SUB_KEYS, &options_key);
	if (rc != ERROR_SUCCESS) {
		return ZigFindWindowsSdkErrorNotFound;
	}

	const char *option_name = nullptr;
	switch (native_arch) {
	case NativeArchArm:
		option_name = "OptionId.DesktopCPParm";
		break;
	case NativeArchAarch64:
		option_name = "OptionId.DesktopCPParm64";
		break;
	case NativeArchx86_64:
		option_name = "OptionId.DesktopCPPx64";
		break;
	case NativeArchx86:
		option_name = "OptionId.DesktopCPPx86";
		break;
	default:
		return ZigFindWindowsSdkErrorNotFound;
	}

	DWORD val_sz = sizeof(DWORD);
	DWORD reg_val = 0;
	DWORD type = REG_DWORD;
	rc = RegQueryValueEx(options_key, option_name, NULL, &type, (LPBYTE)&reg_val, &val_sz);
	if (rc != ERROR_SUCCESS || reg_val != 1) {
		return ZigFindWindowsSdkErrorNotFound;
	}
    return ZigFindWindowsSdkErrorNone;
}

static ZigFindWindowsSdkError find_81_version(ZigWindowsSDKPrivate *priv) {
    if (priv->base.path81_ptr == nullptr) {
        return ZigFindWindowsSdkErrorNone;
    }

    char sdk_lib_dir[4096];
    int n = snprintf(sdk_lib_dir, 4096, "%s\\Lib\\winv*", priv->base.path81_ptr);
    if (n < 0 || n >= 4096) {
        return ZigFindWindowsSdkErrorPathTooLong;
    }

    // enumerate files in sdk path looking for latest version
    WIN32_FIND_DATA ffd;
    HANDLE hFind = FindFirstFileA(sdk_lib_dir, &ffd);
    if (hFind == INVALID_HANDLE_VALUE) {
        return ZigFindWindowsSdkErrorNotFound;
    }
    int v0 = 0, v1 = 0;
    for (;;) {
        if (ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            int c0 = 0, c1 = 0;
            sscanf(ffd.cFileName, "winv%d.%d", &c0, &c1);

            if ( (c0 > v0) || (c0 == v0 && c1 > v1) ) {
                v0 = c0, v1 = c1;
                free((void*)priv->base.version81_ptr);
                priv->base.version81_ptr = strdup(ffd.cFileName);
                if (priv->base.version81_ptr == nullptr) {
                    FindClose(hFind);
                    return ZigFindWindowsSdkErrorOutOfMemory;
                }
            }
        }
        if (FindNextFile(hFind, &ffd) == 0) {
            FindClose(hFind);
            break;
        }
    }
    priv->base.version81_len = strlen(priv->base.version81_ptr);
    return ZigFindWindowsSdkErrorNone;
}

ZigFindWindowsSdkError zig_find_windows_sdk(struct ZigWindowsSDK **out_sdk) {
    ZigWindowsSDKPrivate *priv = (ZigWindowsSDKPrivate*)calloc(1, sizeof(ZigWindowsSDKPrivate));
    if (priv == nullptr) {
        return ZigFindWindowsSdkErrorOutOfMemory;
    }

	HRESULT rc;

	//note(dimenus): If this key doesn't exist, neither the Win 8 SDK nor the Win 10 SDK is installed
	HKEY roots_key;
	rc = RegOpenKeyEx(HKEY_LOCAL_MACHINE, ZIG_WINDOWS_KIT_REG_KEY, 0,
		KEY_QUERY_VALUE | KEY_WOW64_32KEY | KEY_ENUMERATE_SUB_KEYS, &roots_key);
	if (rc != ERROR_SUCCESS) {
		zig_free_windows_sdk(&priv->base);
		return ZigFindWindowsSdkErrorNotFound;
	}

    {
		HKEY v10_key;
		rc = RegOpenKeyEx(HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\Microsoft SDKs\\Windows\\v10.0", 0,
			KEY_QUERY_VALUE | KEY_WOW64_32KEY | KEY_ENUMERATE_SUB_KEYS, &v10_key);
		if (rc != ERROR_SUCCESS) {
			goto find_win10_sdk_done;
		}

        DWORD tmp_buf_len = MAX_PATH;
        priv->base.path10_ptr = (const char *)calloc(tmp_buf_len, 1);
        if (priv->base.path10_ptr == nullptr) {
            zig_free_windows_sdk(&priv->base);
            return ZigFindWindowsSdkErrorOutOfMemory;
        }
        rc = RegQueryValueEx(v10_key, "InstallationFolder", NULL, NULL, (LPBYTE)priv->base.path10_ptr, &tmp_buf_len);
        if (rc == ERROR_SUCCESS) {
            priv->base.path10_len = tmp_buf_len - 1;
            if (priv->base.path10_ptr[priv->base.path10_len - 1] == '\\') {
                priv->base.path10_len -= 1;
            }
        } else {
            free((void*)priv->base.path10_ptr);
            priv->base.path10_ptr = nullptr;
        }

		priv->base.version10_ptr = (const char*)calloc(tmp_buf_len, 1);
		rc = RegQueryValueEx(v10_key, "ProductVersion", NULL, NULL, (LPBYTE)priv->base.version10_ptr, &tmp_buf_len);
		if (rc == ERROR_SUCCESS) {
			snprintf((char*)priv->base.version10_ptr, MAX_PATH, "%s.0", priv->base.version10_ptr);
			priv->base.version10_len = tmp_buf_len - 1 + 2; // note(dimenus): Microsoft doesn't include the .0 in the ProductVersion key....
		} else {
			free((void*)priv->base.version10_ptr);
			priv->base.version10_ptr = nullptr;
		}
    }
	find_win10_sdk_done:
    {
        DWORD tmp_buf_len = MAX_PATH;
        priv->base.path81_ptr = (const char *)calloc(tmp_buf_len, 1);
        if (priv->base.path81_ptr == nullptr) {
            zig_free_windows_sdk(&priv->base);
            return ZigFindWindowsSdkErrorOutOfMemory;
        }
        rc = RegQueryValueEx(roots_key, "KitsRoot81", NULL, NULL, (LPBYTE)priv->base.path81_ptr, &tmp_buf_len);
        if (rc == ERROR_SUCCESS) {
            priv->base.path81_len = tmp_buf_len - 1;
            if (priv->base.path81_ptr[priv->base.path81_len - 1] == '\\') {
                priv->base.path81_len -= 1;
            }
        } else {
            free((void*)priv->base.path81_ptr);
            priv->base.path81_ptr = nullptr;
        }
    }

    {
        ZigFindWindowsSdkError err = find_10_version(priv);
        if (err == ZigFindWindowsSdkErrorOutOfMemory) {
            zig_free_windows_sdk(&priv->base);
            return err;
        }
    }
    {
        ZigFindWindowsSdkError err = find_81_version(priv);
        if (err == ZigFindWindowsSdkErrorOutOfMemory) {
            zig_free_windows_sdk(&priv->base);
            return err;
        }
    }

    {
        ZigFindWindowsSdkError err = find_msvc_lib_dir(priv);
        if (err == ZigFindWindowsSdkErrorOutOfMemory) {
            zig_free_windows_sdk(&priv->base);
            return err;
        }
    }

    *out_sdk = &priv->base;
    return ZigFindWindowsSdkErrorNone;
}

#else

void zig_free_windows_sdk(struct ZigWindowsSDK *sdk) {}
ZigFindWindowsSdkError zig_find_windows_sdk(struct ZigWindowsSDK **out_sdk) {
    return ZigFindWindowsSdkErrorNotFound;
}

#endif

/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#ifndef HighLevelMonitorConfigurationAPI_h
#define HighLevelMonitorConfigurationAPI_h

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <windows.h>
#include <physicalmonitorenumerationapi.h>

#define MC_CAPS_NONE 0x00000000
#define MC_CAPS_MONITOR_TECHNOLOGY_TYPE 0x00000001
#define MC_CAPS_BRIGHTNESS 0x00000002
#define MC_CAPS_CONTRAST 0x00000004
#define MC_CAPS_COLOR_TEMPERATURE 0x00000008
#define MC_CAPS_RED_GREEN_BLUE_GAIN 0x00000010
#define MC_CAPS_RED_GREEN_BLUE_DRIVE 0x00000020
#define MC_CAPS_DEGAUSS 0x00000040
#define MC_CAPS_DISPLAY_AREA_POSITION 0x00000080
#define MC_CAPS_DISPLAY_AREA_SIZE 0x00000100
#define MC_CAPS_RESTORE_FACTORY_DEFAULTS 0x00000400
#define MC_CAPS_RESTORE_FACTORY_COLOR_DEFAULTS 0x00000800
#define MC_RESTORE_FACTORY_DEFAULTS_ENABLES_MONITOR_SETTINGS 0x00001000

#define MC_SUPPORTED_COLOR_TEMPERATURE_NONE 0x00000000
#define MC_SUPPORTED_COLOR_TEMPERATURE_4000K 0x00000001
#define MC_SUPPORTED_COLOR_TEMPERATURE_5000K 0x00000002
#define MC_SUPPORTED_COLOR_TEMPERATURE_6500K 0x00000004
#define MC_SUPPORTED_COLOR_TEMPERATURE_7500K 0x00000008
#define MC_SUPPORTED_COLOR_TEMPERATURE_8200K 0x00000010
#define MC_SUPPORTED_COLOR_TEMPERATURE_9300K 0x00000020
#define MC_SUPPORTED_COLOR_TEMPERATURE_10000K 0x00000040
#define MC_SUPPORTED_COLOR_TEMPERATURE_11500K 0x00000080

#ifdef __cplusplus
extern "C" {
#endif

  typedef enum _MC_DISPLAY_TECHNOLOGY_TYPE {
    MC_SHADOW_MASK_CATHODE_RAY_TUBE,
    MC_APERTURE_GRILL_CATHODE_RAY_TUBE,
    MC_THIN_FILM_TRANSISTOR,
    MC_LIQUID_CRYSTAL_ON_SILICON,
    MC_PLASMA,
    MC_ORGANIC_LIGHT_EMITTING_DIODE,
    MC_ELECTROLUMINESCENT,
    MC_MICROELECTROMECHANICAL,
    MC_FIELD_EMISSION_DEVICE
  } MC_DISPLAY_TECHNOLOGY_TYPE,*LPMC_DISPLAY_TECHNOLOGY_TYPE;

  typedef enum _MC_DRIVE_TYPE {
    MC_RED_DRIVE,
    MC_GREEN_DRIVE,
    MC_BLUE_DRIVE
  } MC_DRIVE_TYPE;

  typedef enum _MC_GAIN_TYPE {
    MC_RED_GAIN,
    MC_GREEN_GAIN,
    MC_BLUE_GAIN
  } MC_GAIN_TYPE;

  typedef enum _MC_POSITION_TYPE {
    MC_HORIZONTAL_POSITION,
    MC_VERTICAL_POSITION
  } MC_POSITION_TYPE;

  typedef enum _MC_SIZE_TYPE {
    MC_WIDTH,
    MC_HEIGHT
  } MC_SIZE_TYPE;

  typedef enum _MC_COLOR_TEMPERATURE {
    MC_COLOR_TEMPERATURE_UNKNOWN,
    MC_COLOR_TEMPERATURE_4000K,
    MC_COLOR_TEMPERATURE_5000K,
    MC_COLOR_TEMPERATURE_6500K,
    MC_COLOR_TEMPERATURE_7500K,
    MC_COLOR_TEMPERATURE_8200K,
    MC_COLOR_TEMPERATURE_9300K,
    MC_COLOR_TEMPERATURE_10000K,
    MC_COLOR_TEMPERATURE_11500K
  } MC_COLOR_TEMPERATURE,*LPMC_COLOR_TEMPERATURE;

  _BOOL WINAPI DegaussMonitor (HANDLE hMonitor);
  _BOOL WINAPI GetMonitorBrightness (HANDLE hMonitor, LPDWORD pdwMinimumBrightness, LPDWORD pdwCurrentBrightness, LPDWORD pdwMaximumBrightness);
  _BOOL WINAPI GetMonitorCapabilities (HANDLE hMonitor, LPDWORD pdwMonitorCapabilities, LPDWORD pdwSupportedColorTemperatures);
  _BOOL WINAPI GetMonitorColorTemperature (HANDLE hMonitor, LPMC_COLOR_TEMPERATURE pctCurrentColorTemperature);
  _BOOL WINAPI GetMonitorContrast (HANDLE hMonitor, LPDWORD pdwMinimumContrast, LPDWORD pdwCurrentContrast, LPDWORD pdwMaximumContrast);
  _BOOL WINAPI GetMonitorDisplayAreaSize (HANDLE hMonitor, MC_SIZE_TYPE stSizeType, LPDWORD pdwMinimumWidthOrHeight, LPDWORD pdwCurrentWidthOrHeight, LPDWORD pdwMaximumWidthOrHeight);
  _BOOL WINAPI GetMonitorDisplayAreaPosition (HANDLE hMonitor, MC_POSITION_TYPE ptPositionType, LPDWORD pdwMinimumPosition, LPDWORD pdwCurrentPosition, LPDWORD pdwMaximumPosition);
  _BOOL WINAPI GetMonitorRedGreenOrBlueDrive (HANDLE hMonitor, MC_DRIVE_TYPE dtDriveType, LPDWORD pdwMinimumDrive, LPDWORD pdwCurrentDrive, LPDWORD pdwMaximumDrive);
  _BOOL WINAPI GetMonitorRedGreenOrBlueGain (HANDLE hMonitor, MC_GAIN_TYPE gtGainType, LPDWORD pdwMinimumGain, LPDWORD pdwCurrentGain, LPDWORD pdwMaximumGain);
  _BOOL WINAPI GetMonitorTechnologyType (HANDLE hMonitor, LPMC_DISPLAY_TECHNOLOGY_TYPE pdtyDisplayTechnologyType);
  _BOOL WINAPI RestoreMonitorFactoryColorDefaults (HANDLE hMonitor);
  _BOOL WINAPI RestoreMonitorFactoryDefaults (HANDLE hMonitor);
  _BOOL WINAPI SaveCurrentMonitorSettings (HANDLE hMonitor);
  _BOOL WINAPI SetMonitorBrightness (HANDLE hMonitor, DWORD dwNewBrightness);
  _BOOL WINAPI SetMonitorColorTemperature (HANDLE hMonitor, MC_COLOR_TEMPERATURE ctCurrentColorTemperature);
  _BOOL WINAPI SetMonitorContrast (HANDLE hMonitor, DWORD dwNewContrast);
  _BOOL WINAPI SetMonitorDisplayAreaSize (HANDLE hMonitor, MC_SIZE_TYPE stSizeType, DWORD dwNewDisplayAreaWidthOrHeight);
  _BOOL WINAPI SetMonitorDisplayAreaPosition (HANDLE hMonitor, MC_POSITION_TYPE ptPositionType, DWORD dwNewPosition);
  _BOOL WINAPI SetMonitorRedGreenOrBlueDrive (HANDLE hMonitor, MC_DRIVE_TYPE dtDriveType, DWORD dwNewDrive);
  _BOOL WINAPI SetMonitorRedGreenOrBlueGain (HANDLE hMonitor, MC_GAIN_TYPE gtGainType, DWORD dwNewGain);

#ifdef __cplusplus
}
#endif
#endif
#endif

# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(vito_app LANGUAGES CXX)

# Configuración de C++ estándar
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# === Forzar MSVC Runtime Library Dinámica (/MD, /MDd) ===
if(MSVC)
  # Activamos la política para exponer CMAKE_MSVC_RUNTIME_LIBRARY
  cmake_policy(SET CMP0091 NEW)

  # Reemplazamos /MT y /MTd por /MD y /MDd en todas las configuraciones
  foreach(_flag_var
          CMAKE_C_FLAGS            CMAKE_C_FLAGS_DEBUG
          CMAKE_C_FLAGS_RELEASE    CMAKE_C_FLAGS_PROFILE
          CMAKE_CXX_FLAGS          CMAKE_CXX_FLAGS_DEBUG
          CMAKE_CXX_FLAGS_RELEASE  CMAKE_CXX_FLAGS_PROFILE)
    string(REPLACE "/MTd" "/MDd" ${_flag_var} "${${_flag_var}}")
    string(REPLACE "/MT"  "/MD"  ${_flag_var} "${${_flag_var}}")
  endforeach()

  # Fijar directamente la variable CRT
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
  
  # Agregar las bibliotecas del sistema necesarias para Firebase
  link_libraries(
    legacy_stdio_definitions.lib
    vcruntime.lib
    msvcrt.lib
    msvcprt.lib
  )
endif()

# The name of the executable created for the application.
set(BINARY_NAME "vito_app")

# Opt in a comportamientos modernos de CMake para evitar warnings.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()

# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100" /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0" "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Generated plugin build rules.
include(flutter/generated_plugins.cmake)

# === Installation ===
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)
install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
endif()

set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)

# Evitar archivos obsoletos
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")" COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Instalar la AOT library en Profile y Release
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" CONFIGURATIONS Profile;Release COMPONENT Runtime)
# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(lc3_codec_library VERSION 0.1.0 LANGUAGES C)

set(LIBLC3_DIR "${CMAKE_CURRENT_SOURCE_DIR}/liblc3")

add_library(lc3_codec SHARED
  "lc3_codec.c"
  "${LIBLC3_DIR}/src/attdet.c"
  "${LIBLC3_DIR}/src/bits.c"
  "${LIBLC3_DIR}/src/bwdet.c"
  "${LIBLC3_DIR}/src/energy.c"
  "${LIBLC3_DIR}/src/lc3.c"
  "${LIBLC3_DIR}/src/ltpf.c"
  "${LIBLC3_DIR}/src/mdct.c"
  "${LIBLC3_DIR}/src/plc.c"
  "${LIBLC3_DIR}/src/sns.c"
  "${LIBLC3_DIR}/src/spec.c"
  "${LIBLC3_DIR}/src/tables.c"
  "${LIBLC3_DIR}/src/tns.c"
)

target_include_directories(lc3_codec PRIVATE "${LIBLC3_DIR}/include")

set_target_properties(lc3_codec PROPERTIES
  PUBLIC_HEADER lc3_codec.h
  OUTPUT_NAME "lc3_codec"
  C_STANDARD 11
)

target_compile_definitions(lc3_codec PUBLIC DART_SHARED_LIB)
target_compile_options(lc3_codec PRIVATE -O2)
target_link_libraries(lc3_codec PRIVATE m)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(lc3_codec PRIVATE "-Wl,-z,max-page-size=16384")
endif()

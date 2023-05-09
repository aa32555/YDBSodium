#################################################################
#								#
# Copyright (c) 2023 YottaDB LLC and/or its subsidiaries.	#
# All rights reserved.						#
#								#
#	This source code contains the intellectual property	#
#	of its copyright holder(s), and is made available	#
#	under a license.  If you do not know the terms of	#
#	the license, please stop and do not read further.	#
#								#
#################################################################

# Prelim
cmake_minimum_required(VERSION 3.14)
include(FetchContent)
# The GIT_TAG is, at the time of this writing, the latest commit in YDBCMake.
# It is fixed at that point to ensure reproducible builds.
# Keep this periodically up to date with future YDBCMake commits.
FetchContent_Declare(YDBCMake
	GIT_REPOSITORY	https://gitlab.com/YottaDB/Tools/YDBCMake.git
	GIT_TAG		e8d9a6d1209b0be88190056f9245671dfdee0713
)
FetchContent_MakeAvailable(YDBCMake)
message(STATUS "YDBCMake Source Directory: ${ydbcmake_SOURCE_DIR}")
set(CMAKE_MODULE_PATH "${ydbcmake_SOURCE_DIR}/ydbcmake/")

option(ENABLE_ASAN "Enable address sanitizer in build?" OFF)

# Needed because we are compiling C code with flags
if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "")
endif()
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")

project(ydbsodium
	LANGUAGES C M
	VERSION 1.0.0)
find_package(YOTTADB REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(sodium_PKG QUIET REQUIRED libsodium)
find_library(sodium_library NAMES ${sodium_PKG_LIBRARIES} HINTS ${sodium_PKG_LIBRARY_DIRS} REQUIRED)
message(STATUS "libsodium found at ${sodium_library}")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra -Werror -pedantic")

if(ENABLE_ASAN)
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=address -fsanitize-recover=address")
	execute_process(
		COMMAND gcc -print-file-name=libasan.so
		OUTPUT_VARIABLE LIBASAN_PATH
		OUTPUT_STRIP_TRAILING_WHITESPACE
	)
endif()

# Compile/Install the C callout library
add_library(sodium SHARED src/sodium_plugin.c)
target_include_directories(sodium PRIVATE ${YOTTADB_INCLUDE_DIRS})
target_link_libraries(sodium ${sodium_library})
install(TARGETS sodium DESTINATION ${YOTTADB_C_PLUGIN_DIR})

# Handle the .xc file
# Runtime version
set(install_dir ${YOTTADB_PLUGIN_PREFIX})
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/src/sodium.xc.in
  ${CMAKE_CURRENT_BINARY_DIR}/sodium.xc
)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/sodium.xc
  DESTINATION ${YOTTADB_PLUGIN_PREFIX}/
)
# Test version of xc file
set(install_dir ${CMAKE_CURRENT_BINARY_DIR})
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/src/sodium.xc.in
  ${CMAKE_CURRENT_BINARY_DIR}/sodium_test.xc
)

# Testing
enable_testing()
add_test(ydbsodium_regular ${CMAKE_M_COMPILER} -run %ydbsodiumtest)
set_tests_properties(ydbsodium_regular PROPERTIES FAIL_REGULAR_EXPRESSION "FAIL")
set_tests_properties(ydbsodium_regular PROPERTIES
	ENVIRONMENT "ydb_xc_sodium=${CMAKE_CURRENT_BINARY_DIR}/sodium_test.xc;ydb_routines=${CMAKE_CURRENT_BINARY_DIR}(${CMAKE_CURRENT_SOURCE_DIR}/src) ${mumps_dir}/libyottadbutil.so;ydb_chset=M")

# This test errors under ASAN due to limited memory
if(NOT ENABLE_ASAN)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/src/run_mem_test.sh.in
  ${CMAKE_CURRENT_BINARY_DIR}/run_mem_test.sh
  )
add_test(ydbsodium_memlimit ${CMAKE_CURRENT_BINARY_DIR}/run_mem_test.sh)
set_tests_properties(ydbsodium_memlimit PROPERTIES FAIL_REGULAR_EXPRESSION "FAIL")
set_tests_properties(ydbsodium_memlimit PROPERTIES
	ENVIRONMENT "ydb_xc_sodium=${CMAKE_CURRENT_BINARY_DIR}/sodium_test.xc;ydb_routines=${CMAKE_CURRENT_BINARY_DIR}(${CMAKE_CURRENT_SOURCE_DIR}/src) ${mumps_dir}/libyottadbutil.so;ydb_chset=M")
endif()

if(ENABLE_ASAN)
	set_property(TEST ydbsodium_regular APPEND PROPERTY ENVIRONMENT ";LD_PRELOAD=${LIBASAN_PATH}")
endif()

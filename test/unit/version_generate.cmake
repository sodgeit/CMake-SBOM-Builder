cmake_minimum_required(VERSION 3.16 FATAL_ERROR)

include(${CSB_PATH}/testing.cmake)

execute_process(
	COMMAND ${CMAKE_COMMAND}
		"-S${TEST_SOURCE_DIR}"
		"-B${TEST_BUILD_DIR}"
		"-DCSB_PATH=${CSB_PATH}"
		"-DTEST_NAME=${TEST_NAME}"
)

# These file are only guaranteed to exist after cmake is done.
# See file(GENERATE ...) in cmake documentation.
ASSERT_EXISTS(${TEST_BUILD_DIR}/version/scripts/version.ps1)
ASSERT_EXISTS(${TEST_BUILD_DIR}/version/scripts/version.sh)
ASSERT_EXISTS(${TEST_BUILD_DIR}/version/include/${TEST_NAME}_version.h)
ASSERT_EXISTS(${TEST_BUILD_DIR}/version/doc/version.txt)
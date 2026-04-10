cmake_minimum_required(VERSION 3.16 FATAL_ERROR)

include(testing)

execute_process(
	COMMAND ${CMAKE_COMMAND}
		"-S${TEST_SOURCE_DIR}"
		"-B${TEST_BUILD_DIR}"
		"-DCMAKE_MODULE_PATH=${CMAKE_MODULE_PATH}"
		"-DTEST_NAME=${TEST_NAME}"
)

# These file are only guaranteed to exist after cmake is done configuring.
# Running cmake as a seperate process allows us to verify the files were generated
ASSERT_EXISTS(${TEST_BUILD_DIR}/version/scripts/version.ps1)
ASSERT_EXISTS(${TEST_BUILD_DIR}/version/scripts/version.sh)
ASSERT_EXISTS(${TEST_BUILD_DIR}/version/include/${TEST_NAME}_version.h)
ASSERT_EXISTS(${TEST_BUILD_DIR}/version/doc/version.txt)
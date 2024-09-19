# Taken from https://github.com/cpm-cmake/CPM.cmake/blob/master/cmake/testing.cmake
# and modified to fit the project's needs

# File did not have a specfic license;
# license and copyright taken from the repository

# SPDX-License-Identifier: MIT

# Copyright (c) 2019-2022 Lars Melchior and contributors
# Copyright (c) 2024      Andreas Lay (Avus-c)

function(ASSERT_EQUAL)
	if(NOT ARGC EQUAL 2)
		message(FATAL_ERROR "assertion failed: invalid argument count: ${ARGC}")
	endif()

	if(NOT "${ARGV0}" STREQUAL "${ARGV1}")
		message(FATAL_ERROR "assertion failed: '${ARGV0}' != '${ARGV1}'")
	else()
		message(STATUS "test passed: '${ARGV0}' == '${ARGV1}'")
	endif()
endfunction()

function(ASSERT_NOT_EQUAL)
	if(NOT ARGC EQUAL 2)
		message(FATAL_ERROR "assertion failed: invalid argument count: ${ARGC}")
	endif()

	if("${ARGV0}" STREQUAL "${ARGV1}")
		message(FATAL_ERROR "assertion failed: '${ARGV0}' == '${ARGV1}'")
	else()
		message(STATUS "test passed: '${ARGV0}' != '${ARGV1}'")
	endif()
endfunction()

function(ASSERT_EMPTY)
	if(NOT ARGC EQUAL 0)
		message(FATAL_ERROR "assertion failed: input ${ARGC} not empty: '${ARGV}'")
	endif()
endfunction()

function(ASSERT_DEFINED KEY)
	if(DEFINED ${KEY})
		message(STATUS "test passed: '${KEY}' is defined")
	else()
		message(FATAL_ERROR "assertion failed: '${KEY}' is not defined")
	endif()
endfunction()

function(ASSERT_NOT_DEFINED KEY)
	if(DEFINED ${KEY})
		message(FATAL_ERROR "assertion failed: '${KEY}' is defined (${${KEY}})")
	else()
		message(STATUS "test passed: '${KEY}' is not defined")
	endif()
endfunction()

function(ASSERT_TRUTHY KEY)
	if(${${KEY}})
		message(STATUS "test passed: '${KEY}' is set truthy")
	else()
		message(FATAL_ERROR "assertion failed: value of '${KEY}' is not truthy (${${KEY}})")
	endif()
endfunction()

function(ASSERT_FALSY KEY)
	if(${${KEY}})
		message(FATAL_ERROR "assertion failed: value of '${KEY}' is not falsy (${${KEY}})")
	else()
		message(STATUS "test passed: '${KEY}' is set falsy")
	endif()
endfunction()

function(ASSERTION_FAILED)
	message(FATAL_ERROR "assertion failed: ${ARGN}")
endfunction()

function(ASSERT_EXISTS file)
	if(EXISTS ${file})
		message(STATUS "test passed: '${file}' exists")
	else()
		message(FATAL_ERROR "assertion failed: file ${file} does not exist")
	endif()
endfunction()

function(ASSERT_NOT_EXISTS file)
	if(NOT EXISTS ${file})
		message(STATUS "test passed: '${file}' does not exist")
	else()
		message(FATAL_ERROR "assertion failed: file ${file} exists")
	endif()
endfunction()

function(ASSERT_TARGET)
	if(TARGET ${ARGV0})
		message(STATUS "test passed: target '${ARGV0}' exists")
	else()
		message(FATAL_ERROR "assertion failed: target '${ARGV0}' does not exist")
	endif()
endfunction()

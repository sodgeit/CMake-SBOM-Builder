# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

if(NOT CMAKE_VERSION VERSION_LESS 3.17)
	set(rmdir rm -rf)
else()
	set(rmdir "remove_directory")
endif()

add_custom_target(tests ALL)

function(test name)
	set(_dir "${CMAKE_CURRENT_BINARY_DIR}/${name}")
	make_directory(${_dir}/src)
	make_directory(${_dir}/build)

	set(TEST_PREAMBLE
	    "cmake_minimum_required(VERSION 3.14)
project(${name})"
	)

	set(TEST_VERIFY
"install(CODE
	\"execute_process(
		COMMAND \\\"pyspdxtools\\\" \\\"-i\\\" \\\"\${SBOM_FILENAME}\\\"
		ERROR_VARIABLE _output
	)
	if(_output MATCHES \\\".*ERROR.*\\\")
		message(FATAL_ERROR \\\"SPDX verification failed:
\\\${_output}\\\")
	endif()\"
)"
	)

	configure_file("${name}.cmake" "${_dir}/src/CMakeLists.txt" @ONLY)

	add_custom_target(
		test-${name}
		DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${name}.cmake
		COMMAND
			${CMAKE_COMMAND} "${_dir}/src" -G "${CMAKE_GENERATOR}"
			"-DCMAKE_INSTALL_PREFIX=${_dir}/install"
			"-DCMAKE_MODULE_PATH=${PROJECT_SOURCE_DIR}/cmake"
			"-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
		COMMAND ${CMAKE_COMMAND} --build . --target install
		WORKING_DIRECTORY "${_dir}/build"
		COMMENT "Testing ${name}"
		VERBATIM
	)

	add_dependencies(tests test-${name})
endfunction()

test(minimal)
test(minimal2)
test(full_doc)
test(input_doc)
test(file)
test(package)
test(dir)
test(target)
test(external)

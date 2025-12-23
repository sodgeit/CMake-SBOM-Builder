project(IntegrationTests)

add_custom_target(${PROJECT_NAME} ALL)

function(add_integration_test name)
	set(_dir "${CMAKE_CURRENT_BINARY_DIR}/testcases/${name}")
	make_directory(${_dir}/src)
	make_directory(${_dir}/build)

	set(TEST_PREAMBLE
	"cmake_minimum_required(VERSION 3.14)
project(${name})"
	)

	set(TEST_VERIFY
"install(CODE
	\"
	message(STATUS \\\"Verifying:  \${SBOM_FILENAME}\\\")
	execute_process(
		COMMAND \\\"pyspdxtools\\\" \\\"-i\\\" \\\"\${SBOM_FILENAME}\\\"
		ERROR_VARIABLE _output
	)
	if(NOT _output STREQUAL \\\"\\\")
		message(FATAL_ERROR \\\"SPDX verification failed:
\\\${_output}\\\")
	endif()\"
)"
	)

	configure_file("testcases/${name}.cmake" "${_dir}/src/CMakeLists.txt" @ONLY)

	get_property(_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

	set(configure_args "")
	set(build_args "")
	if(NOT _is_multi_config)
		set(configure_args "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
	else()
		set(build_args "--config=$<CONFIG>")
	endif()

	add_custom_target(
		"${PROJECT_NAME}-${name}"
		DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/testcases/${name}.cmake
		COMMAND
			${CMAKE_COMMAND} "${_dir}/src" -G "${CMAKE_GENERATOR}"
			"-DCMAKE_INSTALL_PREFIX=${_dir}/install"
			"-DCMAKE_MODULE_PATH=${CMAKE_MODULE_PATH}"
			${configure_args}
		COMMAND ${CMAKE_COMMAND} --build . --target install ${build_args}
		WORKING_DIRECTORY "${_dir}/build"
		COMMENT "Testing ${name}"
		VERBATIM
	)

	add_dependencies(${PROJECT_NAME} "${PROJECT_NAME}-${name}")
endfunction()

add_integration_test(minimal)
add_integration_test(minimal2)
add_integration_test(full_doc)
add_integration_test(file)
add_integration_test(package)
add_integration_test(dir)
add_integration_test(target)
add_integration_test(external)
add_integration_test(external2)

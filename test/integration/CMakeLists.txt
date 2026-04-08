project(IntegrationTests)

function(add_integration_test name)
	set(_dir "${CMAKE_CURRENT_BINARY_DIR}/testcases/${name}")
	make_directory(${_dir}/src)
	make_directory(${_dir}/build)

	set(TEST_PREAMBLE
	"cmake_minimum_required(VERSION 3.14)
project(${name})"
	)

	# This is stupid... but,
	# I cannot reliably determine the actual filename (e.g. it may be overwritten in an integration test)
	# of the generated sbom.
	# Also, you cannot (apperantly) use wildcard symbols in a add_test(... COMMAND <something with wildcard symbol *>)
	# command. This means we cannot reliably call the verifier with the file it's supposed to check.
	# If we copy it to a known location with a known filename, we can run the verifier against the copy atleast.
	# TODO figure a better way out for this...
	# The following runs in the "test context", where SBOM_FILENAME is defined.
	set(TEST_VERIFY
"install(CODE
	\"
	message(STATUS \\\"Copying:  \${SBOM_FILENAME}\\\")
	execute_process(
		COMMAND \\\"${CMAKE_COMMAND}\\\" \\\"-E\\\" \\\"copy\\\" \\\"\${SBOM_FILENAME}\\\" \\\"${_dir}/install/share/tmp.json\\\"
	)
	\"
)"
	)

	configure_file("testcases/${name}.cmake" "${_dir}/CMakeLists.txt" @ONLY)

	get_property(_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

	set(configure_args "")
	set(build_args "")
	if(NOT _is_multi_config)
		set(configure_args "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
	else()
		set(build_args "--config=$<CONFIG>")
	endif()

	add_test(
		NAME "${name}-Configure"
		COMMAND ${CMAKE_COMMAND} "-S" "." "-B" "./build"
			"-G" "${CMAKE_GENERATOR}"
			"-DCMAKE_INSTALL_PREFIX=./install"
			"-DCMAKE_MODULE_PATH=${CMAKE_MODULE_PATH}"
			${configure_args}
		WORKING_DIRECTORY "${_dir}"
	)
	add_test(
		NAME "${name}-Install"
		COMMAND ${CMAKE_COMMAND} --build "./build" --target install ${build_args}
		WORKING_DIRECTORY "${_dir}"
	)

	# Probably abusing test fixtures a bit here.
	# For integration tests we want to run CMake the same way as a user would.
	# The actual final test should be the verification of the generated SBOM.
	# Setup fixtures which do the configure/build/install.
	# If CMake reports an error during configure/build/install, the verifier will
	# not run and test will fail.
	set_tests_properties( "${name}-Configure" PROPERTIES FIXTURES_SETUP "IntegrationTest-${name}")
	set_tests_properties( "${name}-Install" PROPERTIES DEPENDS "${name}-Configure")
	set_tests_properties( "${name}-Install" PROPERTIES FIXTURES_SETUP "IntegrationTest-${name}")

	if(RUN_VERIFICATION)
	# For some reason '*' can't be used in COMMAND, and we don't know the exact name of the sbom file.
	# We therefore generate a copy which we check against.
		add_test(
			NAME "${name}-Verify"
			COMMAND "${Java_JAVA_EXECUTABLE}" "-jar" "${Verifier_BIN}" "Verify" "tmp.json"
			WORKING_DIRECTORY "${_dir}/install/share"
		)
		set_tests_properties( "${name}-Verify" PROPERTIES FIXTURES_REQUIRED "IntegrationTest-${name}")
	endif()
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

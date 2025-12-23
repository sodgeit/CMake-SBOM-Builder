project(CSBUnitTests)

enable_testing()

file(GLOB tests "${CMAKE_CURRENT_SOURCE_DIR}/*.cmake")
foreach(test ${tests})
	get_filename_component(test_name ${test} NAME_WE)

	message(STATUS "adding test: ${test_name}")
	add_test(
		NAME ${test_name}
		COMMAND ${CMAKE_COMMAND}
		-DCMAKE_MODULE_PATH=${CMAKE_MODULE_PATH}
		-DTEST_NAME=${test_name}
		-DTEST_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/${test_name}
		-DTEST_BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}/${test_name}/build
		-P "${test}"
	)
endforeach()

add_custom_target(test-verbose COMMAND ${CMAKE_CTEST_COMMAND} -C Debug --verbose)

# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

sbom_generate(SUPPLIER PERSON target_test PACKAGE_URL https://www.target_test.com)

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/foo.c "int main() {}")

if(MSVC)
	set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS TRUE)
	set(BUILD_SHARED_LIBS TRUE)
endif()

add_executable(foo ${CMAKE_CURRENT_BINARY_DIR}/foo.c)
install(TARGETS foo)
sbom_add_target(foo)

add_library(libfoo STATIC ${CMAKE_CURRENT_BINARY_DIR}/foo.c)
install(TARGETS libfoo)
sbom_add_target(libfoo)

add_library(libfoo2 SHARED ${CMAKE_CURRENT_BINARY_DIR}/foo.c)
install(TARGETS libfoo2 ARCHIVE)
sbom_add_target(libfoo2)

# Headers are not included. You may want to add sbom_add_directory(include FILETYPE SOURCE).

sbom_finalize()

@TEST_VERIFY@

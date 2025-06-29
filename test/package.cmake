# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

sbom_generate(CREATOR PERSON package_test PACKAGE_URL https://www.package_test.com PACKAGE_LICENSE MIT)

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/foo.c "int main() {}")
add_executable(foo_exe ${CMAKE_CURRENT_BINARY_DIR}/foo.c)
install(TARGETS foo_exe)
sbom_add_target(foo_exe)
set(foo_exe_id ${SBOM_LAST_SPDXID})

add_executable(foo_exe2 ${CMAKE_CURRENT_BINARY_DIR}/foo.c)
install(TARGETS foo_exe2)
sbom_add_target(foo_exe2)
set(foo_exe2_id ${SBOM_LAST_SPDXID})

sbom_add_package(
	bar
	DOWNLOAD http://somwhere.com/bar
	LICENSE CC0-1.0
	SUPPLIER PERSON "me"
	VERSION 0.1
	RELATIONSHIP
		"${foo_exe_id} DEPENDS_ON \@SBOM_LAST_SPDXID\@"
		"${foo_exe2_id} DEPENDS_ON \@SBOM_LAST_SPDXID\@"
)

sbom_finalize()

@TEST_VERIFY@

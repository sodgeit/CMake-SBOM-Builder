# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

sbom_generate(CREATOR PERSON extref_test PACKAGE_URL https://www.extref_test.com PACKAGE_LICENSE MIT)

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/foo.c "int main() {}")
add_executable(foo_exe ${CMAKE_CURRENT_BINARY_DIR}/foo.c)
install(TARGETS foo_exe)
sbom_add_target(foo_exe)

sbom_add_package(
	bar
	LICENSE CC0-1.0
	SUPPLIER PERSON "me"
	VERSION 0.1
	EXTREF
		SECURITY cpe23Type "cpe:2.3:a:bar:bar:0.1:*:*:*:*:*:*:*"
		PACKAGE-MANAGER purl "pkg:nuget/bar@0.1"
		OTHER some-ref-type "https://example.com/ref"
			COMMENT "This is a comment on the other ref"
)

sbom_add_package(
	baz
	LICENSE MIT
	SUPPLIER PERSON "someone"
	VERSION 2.0
	EXTREF
		PACKAGE-MANAGER purl "pkg:npm/baz@2.0"
)

sbom_finalize()

@TEST_VERIFY@

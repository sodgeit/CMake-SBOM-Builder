# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

sbom_generate(SUPPLIER PERSON package_test PACKAGE_URL https://www.package_test.com)

sbom_add_package(foo)
sbom_add_package(foo DOWNLOAD_LOCATION http://foo.bar/baz)
sbom_add_package(
	bar
	DOWNLOAD_LOCATION http://somwhere.com/bar
	LICENSE CC0-1.0
	SUPPLIER "Person: me"
	VERSION 0.1
)

sbom_finalize()

@TEST_VERIFY@

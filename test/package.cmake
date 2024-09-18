# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

sbom_generate(CREATOR PERSON package_test PACKAGE_URL https://www.package_test.com PACKAGE_LICENSE MIT)

sbom_add_package(foo LICENSE GPL-3.0 VERSION 0.1 SUPPLIER PERSON "foo")
sbom_add_package(foo DOWNLOAD http://foo.bar/baz LICENSE GPL-3.0 VERSION 0.1 SUPPLIER PERSON "foo")
sbom_add_package(
	bar
	DOWNLOAD http://somwhere.com/bar
	LICENSE CC0-1.0
	SUPPLIER PERSON "me"
	VERSION 0.1
)

sbom_finalize()

@TEST_VERIFY@

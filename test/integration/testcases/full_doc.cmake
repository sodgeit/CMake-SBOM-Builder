# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

sbom_generate(
	PACKAGE_NAME "test-full_doc"
	OUTPUT "./full-sbom.spdx"
	PACKAGE_COPYRIGHT "2023 me"
	NAMESPACE "https://test.com/spdxdoc/me"
	CREATOR ORGANIZATION FullDocTest
	PACKAGE_URL https://www.fullDocTest.com
	PACKAGE_LICENSE MIT
	PACKAGE_CPE cpe:2.3:o:*:some-software:some-framework:*:*:*:*:*:x86_64:* #this is not a valid cpe :)
)

sbom_finalize()

@TEST_VERIFY@

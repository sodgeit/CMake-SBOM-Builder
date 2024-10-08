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
)

sbom_finalize()

@TEST_VERIFY@

# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

sbom_generate(CREATOR ORGANIZATION minimal_test PACKAGE_URL https://www.minimal_test.com)
sbom_finalize()

@TEST_VERIFY@

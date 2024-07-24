# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

set(SBOM_SUPPLIER minimal_test)
set(SBOM_SUPPLIER_URL https://minimal_test.com)

sbom_generate()
sbom_finalize()

@TEST_VERIFY@

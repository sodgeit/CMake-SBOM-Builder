# SPDX-FileCopyrightText: 2025 sodge IT
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@
include(sbom)

file(INSTALL @CMAKE_CURRENT_SOURCE_DIR@/testcases/external2-myother.spdx DESTINATION ${CMAKE_CURRENT_BINARY_DIR} )

sbom_generate(CREATOR ORGANIZATION external2 PACKAGE_URL https://www.external2.com PACKAGE_LICENSE MIT)
sbom_add_external(SPDXRef-other "external2-myother.spdx")
sbom_finalize()

@TEST_VERIFY@

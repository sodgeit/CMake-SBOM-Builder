# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

sbom_generate(INPUT @CMAKE_CURRENT_LIST_DIR@/input_doc.spdx.in PACKAGE_COPYRIGHT "2023 me")

sbom_finalize()

@TEST_VERIFY@

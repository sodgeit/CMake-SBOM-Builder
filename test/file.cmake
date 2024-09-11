# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

sbom_generate(CREATOR ORGANIZATION FileTest PACKAGE_URL https://www.fileTest.com)

install(FILES ${CMAKE_CURRENT_LIST_FILE} DESTINATION .)

# Does not exist before installing.
sbom_add_file(CMakeLists.txt FILETYPE OTHER)

# Twice the same file, should not conflict.
sbom_add_file(CMakeLists.txt FILETYPE OTHER)

# Once more, with specified SPDXID.
sbom_add_file(CMakeLists.txt FILETYPE OTHER SPDXID SPDXRef-again)

sbom_finalize()

@TEST_VERIFY@

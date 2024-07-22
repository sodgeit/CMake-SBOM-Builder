# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

sbom_generate(SUPPLIER DirectoryTest SUPPLIER_URL https://directoryTest.com)

install(FILES ${CMAKE_CURRENT_LIST_FILE} DESTINATION dir)
install(FILES ${CMAKE_CURRENT_LIST_FILE} DESTINATION dir RENAME file.txt)

sbom_add_directory(dir FILETYPE OTHER)
sbom_add_directory(dir FILETYPE DOCUMENTATION)

sbom_finalize()

# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

sbom_generate(CREATOR ORGANIZATION DirectoryTest PACKAGE_URL https://www.directoryTest.com)

install(FILES ${CMAKE_CURRENT_LIST_FILE} DESTINATION dir)
install(FILES ${CMAKE_CURRENT_LIST_FILE} DESTINATION dir RENAME file.txt)

sbom_add_directory(dir FILETYPE TEXT OTHER)
sbom_add_directory(dir FILETYPE DOCUMENTATION)

sbom_finalize()

@TEST_VERIFY@

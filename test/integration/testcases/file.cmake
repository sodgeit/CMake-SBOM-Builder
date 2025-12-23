# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

sbom_generate(CREATOR ORGANIZATION FileTest PACKAGE_URL https://www.fileTest.com PACKAGE_LICENSE MIT)

install(FILES ${CMAKE_CURRENT_LIST_FILE} DESTINATION .)

# Does not exist before installing.
sbom_add_file(CMakeLists.txt FILETYPE OTHER)

# Twice the same file, should not conflict.
sbom_add_file(CMakeLists.txt FILETYPE OTHER)
set(_id1 "${SBOM_LAST_SPDXID}")

# Once more, with specified SPDXID.
sbom_add_file(CMakeLists.txt FILETYPE OTHER SPDXID SPDXRef-again)
set(_id2 "${SBOM_LAST_SPDXID}")

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/doc.txt" "docstring...")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/doc.txt" DESTINATION .)

sbom_add_file("doc.txt"
	FILETYPE DOCUMENTATION
	RELATIONSHIP
		"\@SBOM_LAST_SPDXID\@ DOCUMENTATION_OF ${_id1}"
		"\@SBOM_LAST_SPDXID\@ DOCUMENTATION_OF ${_id2}"
)

sbom_finalize()

@TEST_VERIFY@

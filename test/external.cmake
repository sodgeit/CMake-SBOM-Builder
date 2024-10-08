# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

@TEST_PREAMBLE@

include(sbom)

make_directory(${CMAKE_CURRENT_BINARY_DIR}/other)
file(
	WRITE ${CMAKE_CURRENT_BINARY_DIR}/other/CMakeLists.txt
	"
	project(other)
	sbom_generate(CREATOR PERSON \"Other\" OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/other-sbom.spdx PACKAGE_URL https://www.externalTest.com PACKAGE_LICENSE MIT)
	sbom_finalize()
	"
)
add_subdirectory(${CMAKE_CURRENT_BINARY_DIR}/other ${CMAKE_CURRENT_BINARY_DIR}/other-build)

# Last generated SBOM file. It's valid until the next sbom_generate().
# this is just used for testing purposes. Do not rely on this in production code.
get_property(_sbom GLOBAL PROPERTY SBOM_FILENAME)

sbom_generate(CREATOR PERSON ExternalTest PACKAGE_URL https://www.externalTest.com PACKAGE_LICENSE MIT)
sbom_add_external(SPDXRef-other "${_sbom}")

sbom_add_external(SPDXRef-other "${_sbom}"
	RELATIONSHIP "\@SBOM_LAST_SPDXID\@:SPDXRef-other VARIANT_OF ${SBOM_LAST_SPDXID}:SPDXRef-other"
)
sbom_finalize()

@TEST_VERIFY@

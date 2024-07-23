# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: CC0-1.0

# ##################################################################################################
# Preamble

cmake_minimum_required(VERSION 3.16)

project(example-project)

# Set some install location. This should probably be done by scripts that control CMake, but for
# this example, embed it here.
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
	set(CMAKE_INSTALL_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/install" CACHE PATH "" FORCE)
endif()

if("${CMAKE_BUILD_TYPE}" STREQUAL "")
	set(CMAKE_BUILD_TYPE "Debug")
endif()

# ##################################################################################################
# SBOM setup

include(../cmake/sbom.cmake)

version_extract()

# Setup the SBOM to be generated during install.
sbom_generate(
	OUTPUT
		${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_DATAROOTDIR}/example/sbom-${GIT_VERSION_PATH}.spdx
	LICENSE CC0-1.0
	SUPPLIER Example
	SUPPLIER_URL https://example_company.com
)

# ##################################################################################################
# Example binary

# We now have set GIT_VERSION and friends set to the current project's version.  We also have a
# version static library, version.sh and version.txt for further processing.
version_generate()

add_executable(example example.cpp)
target_link_libraries(example example-project-version)

# Install the application.
install(TARGETS example RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

# Mention the example binary in the SBOM.
sbom_add_target(example)

# Install some other documentation (the version in this case).
install(FILES ${PROJECT_BINARY_DIR}/version.txt DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/example)

# Mention the version file in the SBOM.
sbom_add_file(${CMAKE_INSTALL_DATAROOTDIR}/example/version.txt FILETYPE DOCUMENTATION TEXT)

# Trigger SBOM finalization and verification.
sbom_finalize()

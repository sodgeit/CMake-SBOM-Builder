# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

# This file only performs a few sanity checks on the repo. No building is required to use the
# cmake/*.cmake files.

cmake_minimum_required(VERSION 3.16)

project(CMake-SBOM-Builder)

include(FetchContent)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake" )

find_package(Java COMPONENTS Runtime)
set(RUN_VERIFICATION ${Java_FOUND})

if(NOT Java_FOUND)
	message(WARNING
"Java Runtime was not found.
Verfication of generated sbom files will be skipped.
(Tests still run)"
	)
else()
	FetchContent_Declare(
		spdxtools
		SOURCE_DIR ${CMAKE_BINARY_DIR}/spdx-tools
		URL https://github.com/spdx/tools-java/releases/download/v2.0.5/tools-java-2.0.5.zip
		URL_HASH SHA256=ffd7efd930f29eebcba2942a12a829cd572b6e10edbd9caa5df86da311ca744e
		DOWNLOAD_EXTRACT_TIMESTAMP
	)
	FetchContent_MakeAvailable(spdxtools)
	set(Verifier_BIN "${CMAKE_BINARY_DIR}/spdx-tools/tools-java-2.0.5-jar-with-dependencies.jar")
endif()

enable_testing()

add_subdirectory(example)
add_subdirectory(test)

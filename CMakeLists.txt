# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

# This file only performs a few sanity checks on the repo. No building is required to use the
# cmake/*.cmake files.

cmake_minimum_required(VERSION 3.16)

project(CMake-SBOM-Builder)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake" )

add_subdirectory(example)
add_subdirectory(test)

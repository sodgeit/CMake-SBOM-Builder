# SPDX-FileCopyrightText: 2023-2024 Jochem Rutgers
#
# SPDX-License-Identifier: MIT

# This file only performs a few sanity checks on the repo. No building is required to use the
# cmake/*.cmake files.

cmake_minimum_required(VERSION 3.16)

project(cmake-sbom)

include(cmake/sbom.cmake)

add_subdirectory(example)
add_subdirectory(test)

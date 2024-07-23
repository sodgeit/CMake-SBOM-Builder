cmake_minimum_required(VERSION 3.16)

project(Example
	VERSION 0.2.1
	DESCRIPTION "Example project for SBOM-Builder"
	LANGUAGES CXX
	HOMEPAGE_URL "https://github.com/sodgeit/CMake-SBOM-Builder"
)

set(CMAKE_CXX_STANDARD 23)

# Set some install location. This should probably be done by scripts that control CMake, but for
# this example, embed it here.
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
	set(CMAKE_INSTALL_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/install" CACHE PATH "" FORCE)
endif()

if("${CMAKE_BUILD_TYPE}" STREQUAL "")
	set(CMAKE_BUILD_TYPE "Debug")
endif()

# Include CPM.cmake to download dependencies.
file(
	DOWNLOAD
	https://github.com/cpm-cmake/CPM.cmake/releases/latest/download/CPM.cmake
	${CMAKE_CURRENT_BINARY_DIR}/cmake/CPM.cmake
	EXPECTED_HASH SHA256=7b354f3a5976c4626c876850c93944e52c83ec59a159ae5de5be7983f0e17a2a
)

include(${CMAKE_CURRENT_BINARY_DIR}/cmake/CPM.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/deps.cmake)

# Include the SBOM.cmake file to generate the SBOM.
include(../cmake/sbom.cmake)

# generate the version header and script files
version_generate()

# Setup the SBOM to be generated during install.
sbom_generate(
	LICENSE CC0-1.0
	SUPPLIER ${PROJECT_NAME}
	SUPPLIER_URL ${PROJECT_HOMEPAGE_URL}
)

# mention the dependencies used in the SBOM
sbom_add_package(
	cxxopts
	VERSION 3.2.0
	SUPPLIER "Jarryd Beck (https://github.com/jarro2783/cxxopts)"
	LICENSE MIT
)

sbom_add_package(
	Boost
	VERSION "1.85.0"
	SUPPLIER "https://www.boost.org"
	LICENSE BSL-1.0
)

add_executable(example example.cpp)

target_link_libraries(example
	PRIVATE
	${PROJECT_NAME}-version
	cxxopts
	Boost::algorithm
)

# Install the version header and mention it in the SBOM.
install(FILES ${PROJECT_BINARY_DIR}/include/${PROJECT_NAME}_version.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
sbom_add_file(${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME}_version.h FILETYPE SOURCE)

# Install some other documentation (the version in this case).
install(FILES ${PROJECT_BINARY_DIR}/version.txt DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/example)
sbom_add_file(${CMAKE_INSTALL_DATAROOTDIR}/example/version.txt FILETYPE DOCUMENTATION TEXT)

# Install the application & mention the example binary in the SBOM.
install(TARGETS example RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
sbom_add_target(example)

# Trigger SBOM finalization and verification.
sbom_finalize()

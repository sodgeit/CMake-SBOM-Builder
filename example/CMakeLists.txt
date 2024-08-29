cmake_minimum_required(VERSION 3.16)

project(Example
	VERSION 0.3.0
	DESCRIPTION "Example project for SBOM-Builder"
	LANGUAGES CXX
	HOMEPAGE_URL "https://github.com/sodgeit/CMake-SBOM-Builder"
)

set(CMAKE_CXX_STANDARD 20)

# Set some install location. This should probably be done by scripts that control CMake, but for
# this example, embed it here.
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
	set(CMAKE_INSTALL_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/install" CACHE PATH "" FORCE)
endif()


# This example uses CPM to download dependencies. This is not required for SBOM generation,
# but for a simple example like this, it allows us to build the project without any dependencies.
file(
	DOWNLOAD
	https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.2/CPM.cmake
	${CMAKE_CURRENT_BINARY_DIR}/cmake/CPM.cmake
	EXPECTED_HASH SHA256=c8cdc32c03816538ce22781ed72964dc864b2a34a310d3b7104812a5ca2d835d
)
include(${CMAKE_CURRENT_BINARY_DIR}/cmake/CPM.cmake)


# Include the SBOM.cmake file to generate the SBOM.
include(../cmake/sbom.cmake)

# Now we can start building the sbom.
# This is the only required call to generate the SBOM. It has to be called before any other
# sbom_add_* function.
sbom_generate(
	LICENSE CC0-1.0
	SUPPLIER ${PROJECT_NAME}
	SUPPLIER_URL ${PROJECT_HOMEPAGE_URL}
)

# mention the dependencies used in the SBOM
CPMAddPackage( "gh:jarro2783/cxxopts@3.2.0" )
sbom_add_package(
	cxxopts
	VERSION 3.2.0
	SUPPLIER "Jarryd Beck (https://github.com/jarro2783/cxxopts)"
	LICENSE MIT
)

CPMAddPackage(
	NAME Boost
	VERSION 1.85.0
	URL https://github.com/boostorg/boost/releases/download/boost-1.85.0/boost-1.85.0-cmake.tar.gz
	URL_HASH SHA256=ab9c9c4797384b0949dd676cf86b4f99553f8c148d767485aaac412af25183e6
	OPTIONS "BOOST_INCLUDE_LIBRARIES algorithm"
)
sbom_add_package(
	Boost
	VERSION "1.85.0"
	SUPPLIER "https://www.boost.org"
	LICENSE BSL-1.0
)

# The SBOM-Builder does not have a built-in feature to add
# something conditionally. You have to use CMake's controlflow.
if(SOME_FLAG_ENABLED)
	find_package(some_package 8.0.1 REQUIRED)
	sbom_add_package(
		package
		VERSION 8.0.1
		SUPPLIER "Some Supplier"
		LICENSE MIT
	)
endif()

add_executable(example example.cpp)

# generate the version header and script files
version_generate()

target_link_libraries(example
	PRIVATE
	${PROJECT_NAME}-version # this is the generated version target
	cxxopts
	Boost::algorithm
)

# Now mention all files that would be contained in a distributed archive/package.

# Install the version header and mention it in the SBOM.
install(FILES ${VERSION_INC_DIR}/${PROJECT_NAME}_version.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
sbom_add_file(${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME}_version.h FILETYPE SOURCE)

# Install some other documentation (the version in this case).
install(FILES ${VERSION_DOC_DIR}/version.txt DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/example)
sbom_add_file(${CMAKE_INSTALL_DATAROOTDIR}/example/version.txt FILETYPE DOCUMENTATION TEXT)

# Install the application & mention the example binary in the SBOM.
install(TARGETS example RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
sbom_add_target(example)

# Trigger SBOM finalization.
sbom_finalize()

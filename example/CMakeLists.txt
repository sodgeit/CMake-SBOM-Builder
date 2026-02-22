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

# Include the SBOM.cmake file to generate the SBOM.
include(sbom)

# Now we can start building the sbom.
# This is the only required call to generate the SBOM. It has to be called before any other
# sbom_add_* function.
sbom_generate(
	CREATOR ORGANIZATION "Example Org" EMAIL "example@org.com"
	PACKAGE_URL ${PROJECT_HOMEPAGE_URL}
	PACKAGE_DOWNLOAD "http://example.org/download"
	PACKAGE_LICENSE "MIT"
	PACKAGE_NOTES SUMMARY "Just a simple example project, to demonstrate the SBOM-Builder"
	PACKAGE_PURPOSE "APPLICATION"
)

# mention the dependencies used in the SBOM
sbom_add_package(
	some_dep
	VERSION 1.1.1
	SUPPLIER PERSON "example person"
	LICENSE LGPL3.0
)
sbom_add_package(
	cxxopts
	VERSION 3.2.0
	SUPPLIER PERSON "Jarryd Beck"
	LICENSE MIT
)
sbom_add_package(
	nlohmann_json
	VERSION 3.12.0
	SUPPLIER PERSON "Niels Lohmann"
	LICENSE MIT
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
	# not installed just for SBOM demonstration
	#cxxopts
	#nlohmann_json
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

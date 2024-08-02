cmake_minimum_required(VERSION 3.16 FATAL_ERROR)

# catch and stop second call to this function
if(COMMAND sbom_generate)
	return()
endif()

include(GNUInstallDirs)

find_package(Git)

set(SBOM_BUILDER_VERSION "0.0.0-development-version" CACHE STRING "CMake-SBOM-Builder version")

if(SBOM_BUILDER_VERSION MATCHES "development-version")
	message( WARNING "Your project is using an unstable development version of CMake-SBOM-Builder. \
Consider switching to a stable release. https://github.com/sodgeit/CMake-SBOM-Builder" )
endif()

function(version_show)
	message(STATUS "${PROJECT_NAME} version is ${GIT_VERSION}")
endfunction()

# Extract version information from Git of the current project.
function(version_extract)
	if(DEFINED GIT_VERSION)
		return()
	endif()

	set(_git_short_hash "unknown")
	set(_git_full_hash "unknown")
	set(_git_branch "none")
	set(_git_describe "v0.0.0-0-g${_git_short_hash}")
	set(_git_tag "v0.0.0")
	set(_git_dirty "")

	if(Git_FOUND)
		execute_process(
			COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			OUTPUT_VARIABLE _git_short_hash
			ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
		)

		execute_process(
			COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			OUTPUT_VARIABLE _git_full_hash
			ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
		)

		execute_process(
			COMMAND ${GIT_EXECUTABLE} rev-parse --abbrev-ref HEAD
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			OUTPUT_VARIABLE _git_branch
			ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
		)

		if("${_git_branch}" STREQUAL "HEAD")
			if(NOT "$ENV{CI_COMMIT_BRANCH}" STREQUAL "")
				# Probably a detached head running on a gitlab runner
				set(_git_branch "$ENV{CI_COMMIT_BRANCH}")
			endif()
		endif()

		execute_process(
			COMMAND ${GIT_EXECUTABLE} describe --tags
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			OUTPUT_VARIABLE _git_describe
			ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
		)

		# don't rely on git describe for dirty status
		# we want to be really picky and include untracked files in the dirty check
		execute_process(
			COMMAND ${GIT_EXECUTABLE} status -s
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			OUTPUT_VARIABLE _git_dirty
			ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
		)
		if(NOT "${_git_dirty}" STREQUAL "")
			set(_git_dirty "+dirty")
		endif()

		execute_process(
			COMMAND ${GIT_EXECUTABLE} tag --points-at HEAD
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			OUTPUT_VARIABLE _git_tag
			ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
		)

		string(REGEX REPLACE "[ \t\r\n].*$" "" _git_tag "${_git_tag}")

		if("${_git_tag}" STREQUAL "")
			if(NOT "$ENV{CI_COMMIT_TAG}" STREQUAL "")
				# Probably a detached head running on a gitlab runner
				set(_git_tag "$ENV{CI_COMMIT_TAG}")
			endif()
		endif()
	else()
		message(WARNING "Git not found. Version information will use placeholders.")
	endif()

	if("$ENV{CI_BUILD_ID}" STREQUAL "")
		set(version_build "")
	else()
		set(version_build "+build$ENV{CI_BUILD_ID}")
	endif()

	# HEAD points directly to a tag
	if(NOT ${_git_tag} STREQUAL "")
		set(_git_version "${_git_tag}")
	else()
		set(_git_version "${_git_describe}+${_git_branch}${version_build}")
	endif()

	set(_git_version "${_git_version}${_git_dirty}")

	set(GIT_HASH "${_git_full_hash}" PARENT_SCOPE)
	set(GIT_HASH_SHORT "${_git_short_hash}" PARENT_SCOPE)
	set(GIT_VERSION "${_git_version}" PARENT_SCOPE)
	string(REGEX REPLACE "[^-a-zA-Z0-9_.+]+" "_" _git_version_path "${_git_version}")
	set(GIT_VERSION_PATH "${_git_version_path}" PARENT_SCOPE)

	if(_git_version MATCHES "^(v)?([0-9]+)\\.([0-9]+)\\.([0-9]+)(.+)$")
		set(GIT_VERSION_TRIPLET "${CMAKE_MATCH_2}.${CMAKE_MATCH_3}.${CMAKE_MATCH_4}" PARENT_SCOPE)
		set(GIT_VERSION_MAJOR "${CMAKE_MATCH_2}" PARENT_SCOPE)
		set(GIT_VERSION_MINOR "${CMAKE_MATCH_3}" PARENT_SCOPE)
		set(GIT_VERSION_PATCH "${CMAKE_MATCH_4}" PARENT_SCOPE)
		set(GIT_VERSION_SUFFIX "${CMAKE_MATCH_5}" PARENT_SCOPE)
	endif()

	string(TIMESTAMP VERSION_TIMESTAMP "%Y-%m-%d %H:%M:%S")
	set(VERSION_TIMESTAMP "${VERSION_TIMESTAMP}" PARENT_SCOPE)

	set(GIT_VERSION "${_git_version}") # required for version_show()
	version_show()
endfunction()

# Generate version files and a static library based on the extract version information of the
# current project.
function(version_generate)
	if(NOT DEFINED ${GIT_VERSION})
		version_extract()
	endif()

	string(TOUPPER "${PROJECT_NAME}" PROJECT_NAME_UC)
	string(REGEX REPLACE "[^A-Z0-9]+" "_" PROJECT_NAME_UC "${PROJECT_NAME_UC}")

	set(VERSION_DOC_DIR ${PROJECT_BINARY_DIR}/version/doc)
	set(VERSION_INC_DIR ${PROJECT_BINARY_DIR}/version/include)
	set(VERSION_SCRIPT_DIR ${PROJECT_BINARY_DIR}/version/scripts)

	file(
		GENERATE
		OUTPUT ${VERSION_SCRIPT_DIR}/version.sh
		CONTENT "#!/bin/bash

#This is a generated file. Do not edit.

GIT_HASH=\"${GIT_HASH}\"
GIT_HASH_SHORT=\"${GIT_HASH_SHORT}\"
GIT_VERSION=\"${GIT_VERSION}\"
GIT_VERSION_PATH=\"${GIT_VERSION_PATH}\"
VERSION_TIMESTAMP=\"${VERSION_TIMESTAMP}\"

$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>:#>GIT_VERSION_TRIPLET=\"${GIT_VERSION_TRIPLET}\"
$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>:#>GIT_VERSION_MAJOR=${GIT_VERSION_MAJOR}
$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>:#>GIT_VERSION_MINOR=${GIT_VERSION_MINOR}
$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>:#>GIT_VERSION_PATCH=${GIT_VERSION_PATCH}
$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>:#>GIT_VERSION_SUFFIX=\"${GIT_VERSION_SUFFIX}\"
"
	)

	file(
		GENERATE
		OUTPUT ${VERSION_SCRIPT_DIR}/version.ps1
		CONTENT "#This is a generated file. Do not edit.

$GIT_HASH=\"${GIT_HASH}\"
$GIT_HASH_SHORT=\"${GIT_HASH_SHORT}\"
$GIT_VERSION=\"${GIT_VERSION}\"
$GIT_VERSION_PATH=\"${GIT_VERSION_PATH}\"
$VERSION_TIMESTAMP=\"${VERSION_TIMESTAMP}\"

$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>:#>$GIT_VERSION_TRIPLET=\"${GIT_VERSION_TRIPLET}\"
$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>:#>$GIT_VERSION_MAJOR=${GIT_VERSION_MAJOR}
$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>:#>$GIT_VERSION_MINOR=${GIT_VERSION_MINOR}
$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>:#>$GIT_VERSION_PATCH=${GIT_VERSION_PATCH}
$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>:#>$GIT_VERSION_SUFFIX=\"${GIT_VERSION_SUFFIX}\"
"
	)

	file(
		GENERATE
		OUTPUT ${VERSION_INC_DIR}/${PROJECT_NAME}_version.h
		CONTENT "// clang-format off
#ifndef ${PROJECT_NAME_UC}_VERSION_H
#define ${PROJECT_NAME_UC}_VERSION_H

/* This is a generated file. Do not edit. */

#define ${PROJECT_NAME_UC}_HASH            \"${GIT_HASH}\"
#define ${PROJECT_NAME_UC}_HASH_SHORT      \"${GIT_HASH_SHORT}\"
#define ${PROJECT_NAME_UC}_VERSION         \"${GIT_VERSION}\"
#define ${PROJECT_NAME_UC}_VERSION_PATH    \"${GIT_PATH}\"
#define ${PROJECT_NAME_UC}_TIMESTAMP       \"${VERSION_TIMESTAMP}\"

$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>://>#define ${PROJECT_NAME_UC}_VERSION_TRIPLET \"${GIT_VERSION_TRIPLET}\"
$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>://>#define ${PROJECT_NAME_UC}_VERSION_MAJOR    ${GIT_VERSION_MAJOR}
$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>://>#define ${PROJECT_NAME_UC}_VERSION_MINOR    ${GIT_VERSION_MINOR}
$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>://>#define ${PROJECT_NAME_UC}_VERSION_PATCH    ${GIT_VERSION_PATCH}
$<$<NOT:$<BOOL:${GIT_VERSION_TRIPLET}>>://>#define ${PROJECT_NAME_UC}_VERSION_SUFFIX  \"${GIT_VERSION_SUFFIX}\"

#endif // ${PROJECT_NAME_UC}_VERSION_H
    // clang-format on
"
	)

	file(WRITE ${VERSION_DOC_DIR}/version.txt "${GIT_VERSION}")

	if(NOT TARGET ${PROJECT_NAME}-version)
		add_library(${PROJECT_NAME}-version INTERFACE)

		target_include_directories(${PROJECT_NAME}-version INTERFACE
			"$<BUILD_INTERFACE:${VERSION_INC_DIR}>"
			"$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
		)
	endif()

	set(VERSION_DOC_DIR ${VERSION_DOC_DIR} PARENT_SCOPE)
	set(VERSION_INC_DIR ${VERSION_INC_DIR} PARENT_SCOPE)
	set(VERSION_SCRIPT_DIR ${VERSION_SCRIPT_DIR} PARENT_SCOPE)

endfunction()

# Common Platform Enumeration: https://nvd.nist.gov/products/cpe
#
# TODO: This detection can be improved.
if(WIN32)
	if("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "AMD64")
		set(_arch "x64")
	elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "IA64")
		set(_arch "x64")
	elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "ARM64")
		set(_arch "arm64")
	elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "X86")
		set(_arch "x86")
	elseif(CMAKE_CXX_COMPILER MATCHES "64")
		set(_arch "x64")
	elseif(CMAKE_CXX_COMPILER MATCHES "86")
		set(_arch "x86")
	else()
		set(_arch "*")
	endif()

	if("${CMAKE_SYSTEM_VERSION}" STREQUAL "6.1")
		set(SBOM_CPE "cpe:2.3:o:microsoft:windows_7:-:*:*:*:*:*:${_arch}:*")
	elseif("${CMAKE_SYSTEM_VERSION}" STREQUAL "6.2")
		set(SBOM_CPE "cpe:2.3:o:microsoft:windows_8:-:*:*:*:*:*:${_arch}:*")
	elseif("${CMAKE_SYSTEM_VERSION}" STREQUAL "6.3")
		set(SBOM_CPE "cpe:2.3:o:microsoft:windows_8.1:-:*:*:*:*:*:${_arch}:*")
	elseif(NOT "${CMAKE_SYSTEM_VERSION}" VERSION_LESS 10)
		set(SBOM_CPE "cpe:2.3:o:microsoft:windows_10:-:*:*:*:*:*:${_arch}:*")
	else()
		set(SBOM_CPE "cpe:2.3:o:microsoft:windows:-:*:*:*:*:*:${_arch}:*")
	endif()
elseif(APPLE)
	set(SBOM_CPE "cpe:2.3:o:apple:mac_os:*:*:*:*:*:*:${CMAKE_SYSTEM_PROCESSOR}:*")
elseif(UNIX)
	set(SBOM_CPE "cpe:2.3:o:canonical:ubuntu_linux:-:*:*:*:*:*:${CMAKE_SYSTEM_PROCESSOR}:*")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm")
	set(SBOM_CPE "cpe:2.3:h:arm:arm:-:*:*:*:*:*:*:*")
else()
	message(FATAL_ERROR "Unsupported platform")
endif()

# Sets the given variable to a unique SPDIXID-compatible value.
function(sbom_spdxid)
	set(oneValueArgs VARIABLE CHECK)
	set(multiValueArgs HINTS)

	cmake_parse_arguments(
		SBOM_SPDXID "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN}
	)

	if(SBOM_SPDXID_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "Unknown arguments: ${SBOM_SPDXID_UNPARSED_ARGUMENTS}")
	endif()

	if(NOT DEFINED SBOM_SPDXID_VARIABLE)
		message(FATAL_ERROR "Missing VARIABLE")
	endif()

	if("${SBOM_SPDXID_CHECK}" STREQUAL "")
		get_property(_spdxids GLOBAL PROPERTY sbom_spdxids)
		set(_suffix "-${_spdxids}")
		math(EXPR _spdxids "${_spdxids} + 1")
		set_property(GLOBAL PROPERTY sbom_spdxids "${_spdxids}")

		foreach(_hint IN LISTS SBOM_SPDXID_HINTS)
			string(REGEX REPLACE "[^a-zA-Z0-9]+" "-" _id "${_hint}")
			string(REGEX REPLACE "-+$" "" _id "${_id}")

			if(NOT "${_id}" STREQUAL "")
				set(_id "${_id}${_suffix}")
				break()
			endif()
		endforeach()

		if("${_id}" STREQUAL "")
			set(_id "SPDXRef${_suffix}")
		endif()
	else()
		set(_id "${SBOM_SPDXID_CHECK}")
	endif()

	if(NOT "${_id}" MATCHES "^SPDXRef-[-a-zA-Z0-9]+$")
		message(FATAL_ERROR "Invalid SPDXID \"${_id}\"")
	endif()

	set(${SBOM_SPDXID_VARIABLE} "${_id}" PARENT_SCOPE)
endfunction()

# Starts SBOM generation. Call sbom_add() and friends afterwards. End with sbom_finalize(). Input
# files allow having variables and generator expressions.
function(sbom_generate)
	set(oneValueArgs
		OUTPUT
		LICENSE
		COPYRIGHT
		PROJECT
		SUPPLIER
		SUPPLIER_URL
		NAMESPACE
		ENABLE_CHECKS
	)
	set(multiValueArgs INPUT)
	cmake_parse_arguments(
		SBOM_GENERATE "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN}
	)

	if(SBOM_GENERATE_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "Unknown arguments: ${SBOM_GENERATE_UNPARSED_ARGUMENTS}")
	endif()

	if(NOT DEFINED SBOM_GENERATE_INPUT)
		if(NOT DEFINED SBOM_SUPPLIER AND NOT DEFINED SBOM_GENERATE_SUPPLIER)
			message(FATAL_ERROR "Specify a SUPPLIER, or set CACHE variable SBOM_SUPPLIER")
		elseif(DEFINED SBOM_SUPPLIER AND NOT DEFINED SBOM_GENERATE_SUPPLIER)
			set(SBOM_GENERATE_SUPPLIER ${SBOM_SUPPLIER})
		elseif(${SBOM_GENERATE_SUPPLIER} STREQUAL "")
			message(FATAL_ERROR "SUPPLIER is empty string")
		endif()

		if(NOT DEFINED SBOM_SUPPLIER_URL AND NOT DEFINED SBOM_GENERATE_SUPPLIER_URL)
			message(FATAL_ERROR "Specify a SUPPLIER_URL, or set CACHE variable SBOM_SUPPLIER_URL")
		elseif(DEFINED SBOM_SUPPLIER_URL AND NOT DEFINED SBOM_GENERATE_SUPPLIER_URL)
			set(SBOM_GENERATE_SUPPLIER_URL ${SBOM_SUPPLIER_URL})
		elseif(${SBOM_GENERATE_SUPPLIER_URL} STREQUAL "")
			message(FATAL_ERROR "SUPPLIER_URL is empty string")
		endif()
	endif()

	if(NOT DEFINED GIT_VERSION)
		version_extract()
	endif()

	string(TIMESTAMP NOW_UTC UTC)

	if(NOT DEFINED SBOM_GENERATE_OUTPUT)
		set(SBOM_GENERATE_OUTPUT "./${CMAKE_INSTALL_DATAROOTDIR}/${PROJECT_NAME}-sbom-${GIT_VERSION_PATH}.spdx")
	endif()

	if(NOT DEFINED SBOM_GENERATE_LICENSE)
		set(SBOM_GENERATE_LICENSE "NOASSERTION")
	endif()

	if(NOT DEFINED SBOM_GENERATE_PROJECT)
		set(SBOM_GENERATE_PROJECT ${PROJECT_NAME})
	endif()

	if(NOT DEFINED SBOM_GENERATE_COPYRIGHT)
		string(TIMESTAMP NOW_YEAR "%Y" UTC)
		set(SBOM_GENERATE_COPYRIGHT ${NOW_YEAR} ${SBOM_GENERATE_SUPPLIER})
	endif()

	if(NOT DEFINED SBOM_GENERATE_NAMESPACE)
		set(SBOM_GENERATE_NAMESPACE "${SBOM_GENERATE_SUPPLIER_URL}/spdxdocs/${PROJECT_NAME}-${GIT_VERSION}")
	endif()

	if(${SBOM_GENERATE_ENABLE_CHECKS})
		set(SBOM_CHECKS_ENABLED ON CACHE BOOL "Warn on important missing fields.")
	else()
		set(SBOM_CHECKS_ENABLED OFF CACHE BOOL "Warn on important missing fields.")
	endif()

	string(REGEX REPLACE "[^A-Za-z0-9.]+" "-" SBOM_GENERATE_PROJECT "${SBOM_GENERATE_PROJECT}")
	string(REGEX REPLACE "-+$" "" SBOM_GENERATE_PROJECT "${SBOM_GENERATE_PROJECT}")

	# Prevent collision with other generated SPDXID with -[0-9]+ suffix.
	string(REGEX REPLACE "-([0-9]+)$" "\\1" SBOM_GENERATE_PROJECT "${SBOM_GENERATE_PROJECT}")

	set(SBOM_FILENAME "${SBOM_GENERATE_OUTPUT}" PARENT_SCOPE)
	set(SBOM_BINARY_DIR "${PROJECT_BINARY_DIR}/sbom")
	set_property(GLOBAL PROPERTY SBOM_FILENAME "${SBOM_GENERATE_OUTPUT}")
	set_property(GLOBAL PROPERTY SBOM_BINARY_DIR "${SBOM_BINARY_DIR}")
	set_property(GLOBAL PROPERTY sbom_project "${SBOM_GENERATE_PROJECT}")
	set_property(GLOBAL PROPERTY sbom_spdxids 0)

	#REFAC(>=3.20): Use cmake_path() instead of get_filename_component().
	if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.20)
		cmake_path(GET SBOM_GENERATE_OUTPUT FILENAME doc_name)
	else()
		get_filename_component(doc_name "${SBOM_GENERATE_OUTPUT}" NAME_WLE)
	endif()

	file(MAKE_DIRECTORY ${SBOM_BINARY_DIR})

	# collect all sbom install instructions in a separate file.
	# Will be added as the last install instruction in sbom_finalize().
	# To keep things debuggable, we don't want to mix the sbom instructions with the rest of the install instructions.
	file(WRITE ${SBOM_BINARY_DIR}/CMakeLists.txt
"install(CODE \"
	if(IS_ABSOLUTE \\\"${SBOM_GENERATE_OUTPUT}\\\")
		set(SBOM_FILENAME \\\"${SBOM_GENERATE_OUTPUT}\\\")
	else()
		set(SBOM_FILENAME \\\"\${CMAKE_INSTALL_PREFIX}/${SBOM_GENERATE_OUTPUT}\\\")
	endif()
	set(SBOM_BINARY_DIR \\\"${SBOM_BINARY_DIR}\\\")
	set(SBOM_EXT_DOCS)
	message(STATUS \\\"Installing: \\\${SBOM_FILENAME}\\\")\"
)\n"
	)

	set(_sbom_intermediate_file "$<CONFIG>/sbom.spdx.in")

	file(APPEND ${SBOM_BINARY_DIR}/CMakeLists.txt
"# this file is used to collect all SPDX entries before final export
install(CODE \"
	set(SBOM_INTERMEDIATE_FILE \\\"\\\${SBOM_BINARY_DIR}/${_sbom_intermediate_file}\\\")
	file(WRITE \\\${SBOM_INTERMEDIATE_FILE} \\\"\\\")\"
)\n"
	)

	if(NOT DEFINED SBOM_GENERATE_INPUT)
		set(_sbom_document_template "$<CONFIG>/SPDXRef-DOCUMENT.spdx.in")

		file(APPEND ${SBOM_BINARY_DIR}/CMakeLists.txt
"install(CODE \"set(SBOM_DOCUMENT_TEMPLATE \\\"${_sbom_document_template}\\\")\")\n"
		)

		file(
			GENERATE
			OUTPUT "${SBOM_BINARY_DIR}/${_sbom_document_template}"
			CONTENT
			"SPDXVersion: SPDX-2.3
DataLicense: CC0-1.0
SPDXID: SPDXRef-DOCUMENT
DocumentName: ${doc_name}
DocumentNamespace: ${SBOM_GENERATE_NAMESPACE}
Creator: Organization: ${SBOM_GENERATE_SUPPLIER}
Creator: Tool: CMake-SBOM-Builder-${SBOM_BUILDER_VERSION}
CreatorComment: <text>This SPDX document was created from CMake ${CMAKE_VERSION}, using CMake-SBOM-Builder from https://github.com/sodgeit/CMake-SBOM-Builder</text>
Created: ${NOW_UTC}\${SBOM_EXT_DOCS}

PackageName: ${CMAKE_CXX_COMPILER_ID}
SPDXID: SPDXRef-compiler
PackageVersion: ${CMAKE_CXX_COMPILER_VERSION}
PackageDownloadLocation: NOASSERTION
PackageLicenseConcluded: NOASSERTION
PackageLicenseDeclared: NOASSERTION
PackageCopyrightText: NOASSERTION
PackageSupplier: Organization: Anonymous
FilesAnalyzed: false
PackageSummary: <text>The compiler as identified by CMake, running on ${CMAKE_HOST_SYSTEM_NAME} (${CMAKE_HOST_SYSTEM_PROCESSOR})</text>
PrimaryPackagePurpose: APPLICATION
Relationship: SPDXRef-compiler CONTAINS NOASSERTION
Relationship: SPDXRef-compiler BUILD_DEPENDENCY_OF SPDXRef-${SBOM_GENERATE_PROJECT}
RelationshipComment: <text>SPDXRef-${SBOM_GENERATE_PROJECT} is built by compiler ${CMAKE_CXX_COMPILER_ID} (${CMAKE_CXX_COMPILER}) version ${CMAKE_CXX_COMPILER_VERSION}</text>

PackageName: ${PROJECT_NAME}
SPDXID: SPDXRef-${SBOM_GENERATE_PROJECT}
ExternalRef: SECURITY cpe23Type ${SBOM_CPE}
ExternalRef: PACKAGE-MANAGER purl pkg:supplier/${SBOM_GENERATE_SUPPLIER}/${PROJECT_NAME}@${GIT_VERSION}
PackageVersion: ${GIT_VERSION}
PackageSupplier: Organization: ${SBOM_GENERATE_SUPPLIER}
PackageDownloadLocation: NOASSERTION
PackageLicenseConcluded: ${SBOM_GENERATE_LICENSE}
PackageLicenseDeclared: ${SBOM_GENERATE_LICENSE}
PackageCopyrightText: ${SBOM_GENERATE_COPYRIGHT}
PackageHomePage: ${SBOM_GENERATE_SUPPLIER_URL}
PackageComment: <text>Built by CMake ${CMAKE_VERSION} with $<CONFIG> configuration for ${CMAKE_SYSTEM_NAME} (${CMAKE_SYSTEM_PROCESSOR})</text>
PackageVerificationCode: \${SBOM_VERIFICATION_CODE}
BuiltDate: ${NOW_UTC}
Relationship: SPDXRef-DOCUMENT DESCRIBES SPDXRef-${SBOM_GENERATE_PROJECT}
"
		)

		file(APPEND ${SBOM_BINARY_DIR}/CMakeLists.txt
"install(CODE \"
	file(READ \\\"\\\${SBOM_BINARY_DIR}/\\\${SBOM_DOCUMENT_TEMPLATE}\\\" _f_contents)
	file(APPEND \\\"\\\${SBOM_INTERMEDIATE_FILE}\\\" \\\"\\\${_f_contents}\\\")\"
)\n"
		)

		set(SBOM_LAST_SPDXID "SPDXRef-${SBOM_GENERATE_PROJECT}" PARENT_SCOPE)
	else()
		foreach(_f IN LISTS SBOM_GENERATE_INPUT)
			get_filename_component(_f_name "${_f}" NAME) #REFAC(>=3.20): Use cmake_path() instead of get_filename_component().
			set(_f_in "${CMAKE_CURRENT_BINARY_DIR}/${_f_name}")
			set(_f_in_gen "${_f_in}_gen")
			configure_file("${_f}" "${_f_in}" @ONLY)
			file(
				GENERATE
				OUTPUT "${_f_in_gen}"
				INPUT "${_f_in}"
			)

			file(APPEND ${SBOM_BINARY_DIR}/CMakeLists.txt
"install(CODE \"
	file(READ \\\"${_f_in_gen}\\\" _f_contents)
	file(APPEND \\\"\\\${SBOM_INTERMEDIATE_FILE}\\\" \\\"\\\${_f_contents}\\\")
\")\n"
			)
		endforeach()

		set(SBOM_LAST_SPDXID "" PARENT_SCOPE)
	endif()

	file(APPEND ${SBOM_BINARY_DIR}/CMakeLists.txt
"install(CODE \"set(SBOM_VERIFICATION_CODES \\\"\\\")\")\n"

	)
endfunction()

# Finalize the generated SBOM. Call after sbom_generate() and other SBOM populating commands.
function(sbom_finalize)
	get_property(_sbom GLOBAL PROPERTY SBOM_FILENAME)
	get_property(_sbom_binary_dir GLOBAL PROPERTY SBOM_BINARY_DIR)
	get_property(_sbom_project GLOBAL PROPERTY sbom_project)

	if("${_sbom_project}" STREQUAL "")
		message(FATAL_ERROR "Call sbom_generate() first")
	endif()

	file(
		WRITE ${_sbom_binary_dir}/finalize.cmake
"message(STATUS \"Finalizing: \${SBOM_FILENAME}\")
list(SORT SBOM_VERIFICATION_CODES)
string(REPLACE \";\" \"\" SBOM_VERIFICATION_CODES \"\${SBOM_VERIFICATION_CODES}\")
file(WRITE \"\${SBOM_BINARY_DIR}/verification.txt\" \"\${SBOM_VERIFICATION_CODES}\")
file(SHA1 \"\${SBOM_BINARY_DIR}/verification.txt\" SBOM_VERIFICATION_CODE)
configure_file(\"\${SBOM_INTERMEDIATE_FILE}\" \"\${SBOM_FILENAME}\")
"
	)

	file(APPEND ${_sbom_binary_dir}/CMakeLists.txt
		"install(SCRIPT \"finalize.cmake\")\n"
	)

	add_subdirectory(${_sbom_binary_dir} ${_sbom_binary_dir}/generate )

	# Mark finalized.
	set(SBOM_FILENAME "${_sbom}" PARENT_SCOPE)
	set_property(GLOBAL PROPERTY sbom_project "")
endfunction()

macro(_sbom_builder_is_setup)
	get_property(_sbom_project GLOBAL PROPERTY sbom_project)

	if("${_sbom_project}" STREQUAL "")
		message(FATAL_ERROR "Call sbom_generate() first")
	endif()
endmacro()

function(_sbom_verify_filetype FILETYPE)
	# https://spdx.github.io/spdx-spec/v2.3/file-information/#83-file-type-field
	set(valid_entries "SOURCE" "BINARY" "ARCHIVE" "APPLICATION" "AUDIO" "IMAGE" "TEXT" "VIDEO" "DOCUMENTATION" "SPDX" "OTHER")
	list(FIND valid_entries "${FILETYPE}" _index)

	if(${_index} EQUAL -1)
		message(FATAL_ERROR "Invalid FILETYPE: ${FILETYPE}")
	endif()
endfunction()

# Append a file to the SBOM. Use this after calling sbom_generate().
function(sbom_add_file FILENAME)
	set(options OPTIONAL)
	set(oneValueArgs RELATIONSHIP SPDXID)
	set(multiValueArgs FILETYPE)
	cmake_parse_arguments(SBOM_FILE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	_sbom_builder_is_setup()

	if(SBOM_FILE_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "Unknown arguments: ${SBOM_FILE_UNPARSED_ARGUMENTS}")
	endif()

	if(NOT DEFINED SBOM_FILE_FILETYPE)
		message(FATAL_ERROR "Missing FILETYPE argument")
	endif()

	foreach(_filetype ${SBOM_FILE_FILETYPE})
		_sbom_verify_filetype("${_filetype}")
	endforeach()

	sbom_spdxid(
		VARIABLE SBOM_FILE_SPDXID
		CHECK "${SBOM_FILE_SPDXID}"
		HINTS "SPDXRef-${FILENAME}"
	)

	set(SBOM_LAST_SPDXID "${SBOM_FILE_SPDXID}" PARENT_SCOPE)

	if("${SBOM_FILE_RELATIONSHIP}" STREQUAL "")
		set(SBOM_FILE_RELATIONSHIP "SPDXRef-${_sbom_project} CONTAINS ${SBOM_FILE_SPDXID}")
	else()
		string(REPLACE "@SBOM_LAST_SPDXID@" "${SBOM_FILE_SPDXID}" SBOM_FILE_RELATIONSHIP
			"${SBOM_FILE_RELATIONSHIP}"
		)
	endif()

	get_property(_sbom_binary_dir GLOBAL PROPERTY SBOM_BINARY_DIR)

	file(
		GENERATE
		OUTPUT ${_sbom_binary_dir}/${SBOM_FILE_SPDXID}.cmake
		CONTENT
		"
cmake_policy(SET CMP0011 NEW)
cmake_policy(SET CMP0012 NEW)
if(NOT EXISTS \${CMAKE_INSTALL_PREFIX}/${FILENAME})
	if(NOT ${SBOM_FILE_OPTIONAL})
		message(FATAL_ERROR \"Cannot find ${FILENAME}\")
	endif()
else()
	file(SHA1 \${CMAKE_INSTALL_PREFIX}/${FILENAME} _sha1)
	list(APPEND SBOM_VERIFICATION_CODES \${_sha1})
	file(APPEND \"\${SBOM_INTERMEDIATE_FILE}\"
\"
FileName: ./${FILENAME}
SPDXID: ${SBOM_FILE_SPDXID}
\"
	)
	foreach(_filetype ${SBOM_FILE_FILETYPE})
		file(APPEND \"\${SBOM_INTERMEDIATE_FILE}\"
\"FileType: \${_filetype}
\"
		)
	endforeach()
	file(APPEND \"\${SBOM_INTERMEDIATE_FILE}\"
\"FileChecksum: SHA1: \${_sha1}
LicenseConcluded: NOASSERTION
LicenseInfoInFile: NOASSERTION
FileCopyrightText: NOASSERTION
Relationship: ${SBOM_FILE_RELATIONSHIP}
\"
	)
endif()
	"
	)

	file(APPEND ${_sbom_binary_dir}/CMakeLists.txt
		"install(SCRIPT \"${SBOM_FILE_SPDXID}.cmake\")\n"
	)

	set(SBOM_LAST_SPDXID "${SBOM_LAST_SPDXID}" PARENT_SCOPE)
endfunction()

# Append a target output to the SBOM. Use this after calling sbom_generate().
function(sbom_add_target NAME)
	_sbom_builder_is_setup()

	get_target_property(_type ${NAME} TYPE)

	if("${_type}" STREQUAL "EXECUTABLE")
		sbom_add_file(${CMAKE_INSTALL_BINDIR}/$<TARGET_FILE_NAME:${NAME}>
			FILETYPE BINARY ${ARGN}
		)
	elseif("${_type}" STREQUAL "STATIC_LIBRARY")
		sbom_add_file(${CMAKE_INSTALL_LIBDIR}/$<TARGET_FILE_NAME:${NAME}>
			FILETYPE BINARY ${ARGN}
		)
	elseif("${_type}" STREQUAL "SHARED_LIBRARY")
		if(WIN32)
			sbom_add_file(
				${CMAKE_INSTALL_BINDIR}/$<TARGET_FILE_NAME:${NAME}>
				FILETYPE BINARY ${ARGN}
			)
			sbom_add_file(
				${CMAKE_INSTALL_LIBDIR}/$<TARGET_LINKER_FILE_NAME:${NAME}>
				FILETYPE BINARY OPTIONAL ${ARGN}
			)
		else()
			sbom_add_file(
				${CMAKE_INSTALL_LIBDIR}/$<TARGET_FILE_NAME:${NAME}>
				FILETYPE BINARY ${ARGN}
			)
		endif()
	else()
		message(FATAL_ERROR "Unsupported target type ${_type}")
	endif()

	set(SBOM_LAST_SPDXID "${SBOM_LAST_SPDXID}" PARENT_SCOPE)
endfunction()

# Append all files recursively in a directory to the SBOM. Use this after calling sbom_generate().
function(sbom_add_directory PATH)
	cmake_parse_arguments(
		SBOM_DIRECTORY "" "RELATIONSHIP" "FILETYPE" ${ARGN}
	)

	_sbom_builder_is_setup()

	if(SBOM_DIRECTORY_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "Unknown arguments: ${SBOM_DIRECTORY_UNPARSED_ARGUMENTS}")
	endif()

	sbom_spdxid(VARIABLE SBOM_DIRECTORY_SPDXID HINTS "SPDXRef-${PATH}")

	set(SBOM_LAST_SPDXID "${SBOM_DIRECTORY_SPDXID}")

	if(NOT DEFINED SBOM_DIRECTORY_FILETYPE)
		message(FATAL_ERROR "Missing FILETYPE argument")
	endif()

	foreach(_filetype ${SBOM_DIRECTORY_FILETYPE})
		_sbom_verify_filetype("${_filetype}")
	endforeach()

	if("${SBOM_DIRECTORY_RELATIONSHIP}" STREQUAL "")
		set(SBOM_DIRECTORY_RELATIONSHIP
			"SPDXRef-${_sbom_project} CONTAINS ${SBOM_DIRECTORY_SPDXID}"
		)
	else()
		string(REPLACE "@SBOM_LAST_SPDXID@" "${SBOM_DIRECTORY_SPDXID}"
			SBOM_DIRECTORY_RELATIONSHIP "${SBOM_DIRECTORY_RELATIONSHIP}"
		)
	endif()

	get_property(_sbom_binary_dir GLOBAL PROPERTY SBOM_BINARY_DIR)

	file(
		GENERATE
		OUTPUT "${_sbom_binary_dir}/${SBOM_DIRECTORY_SPDXID}.cmake"
		CONTENT
		"
file(GLOB_RECURSE _files
	LIST_DIRECTORIES false RELATIVE \"\${CMAKE_INSTALL_PREFIX}\"
	\"\${CMAKE_INSTALL_PREFIX}/${PATH}/*\"
)

set(_count 0)
foreach(_f IN LISTS _files)
	file(SHA1 \"\${CMAKE_INSTALL_PREFIX}/\${_f}\" _sha1)
	list(APPEND SBOM_VERIFICATION_CODES \${_sha1})
	file(APPEND \"\${SBOM_INTERMEDIATE_FILE}\"
\"
FileName: ./\${_f}
SPDXID: ${SBOM_DIRECTORY_SPDXID}-\${_count}
\"
	)
	foreach(_filetype ${SBOM_DIRECTORY_FILETYPE})
		file(APPEND \"\${SBOM_INTERMEDIATE_FILE}\"
\"FileType: \${_filetype}
\"
		)
	endforeach()
	file(APPEND \"\${SBOM_INTERMEDIATE_FILE}\"
\"FileChecksum: SHA1: \${_sha1}
FileChecksum: SHA1: \${_sha1}
LicenseConcluded: NOASSERTION
LicenseInfoInFile: NOASSERTION
FileCopyrightText: NOASSERTION
Relationship: ${SBOM_DIRECTORY_RELATIONSHIP}-\${_count}
\"
	)
	math(EXPR _count \"\${_count} + 1\")
endforeach()
"
	)

	file(APPEND ${_sbom_binary_dir}/CMakeLists.txt
		"install(SCRIPT \"${SBOM_DIRECTORY_SPDXID}.cmake\")\n"
	)

	set(SBOM_LAST_SPDXID "" PARENT_SCOPE)
endfunction()

# Append a package (without files) to the SBOM. Use this after calling sbom_generate().
function(sbom_add_package NAME)
	set(oneValueArgs
		VERSION
		LICENSE
		DOWNLOAD_LOCATION
		RELATIONSHIP
		SPDXID
		SUPPLIER
	)
	set(multiValueArgs EXTREF)
	cmake_parse_arguments(
		SBOM_PACKAGE "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN}
	)

	_sbom_builder_is_setup()

	if(SBOM_PACKAGE_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "Unknown arguments: ${SBOM_PACKAGE_UNPARSED_ARGUMENTS}")
	endif()

	if("${SBOM_PACKAGE_DOWNLOAD_LOCATION}" STREQUAL "")
		set(SBOM_PACKAGE_DOWNLOAD_LOCATION NOASSERTION)
	endif()

	sbom_spdxid(
		VARIABLE SBOM_PACKAGE_SPDXID
		CHECK "${SBOM_PACKAGE_SPDXID}"
		HINTS "SPDXRef-${NAME}"
	)

	set(SBOM_LAST_SPDXID ${SBOM_PACKAGE_SPDXID} PARENT_SCOPE)

	set(_fields)

	if("${SBOM_PACKAGE_VERSION}" STREQUAL "")
		set(SBOM_PACKAGE_VERSION "unknown")

		if(${SBOM_CHECKS_ENABLED})
			message(WARNING "Version missing for package: ${NAME}. (semver/commit-hash)")
		endif()
	endif()

	if("${SBOM_PACKAGE_SUPPLIER}" STREQUAL "")
		set(SBOM_PACKAGE_SUPPLIER "Person: Anonymous")

		if(${SBOM_CHECKS_ENABLED})
			message(WARNING "Supplier missing for package: ${NAME}. (Person/Organization + email/url)")
		endif()
	endif()

	if(NOT "${SBOM_PACKAGE_LICENSE}" STREQUAL "")
		set(_fields "${_fields}
PackageLicenseConcluded: ${SBOM_PACKAGE_LICENSE}"
		)
	else()
		set(_fields "${_fields}
PackageLicenseConcluded: NOASSERTION"
		)

		if(${SBOM_CHECKS_ENABLED})
			message(WARNING "LICENSE missing for package ${NAME}. (SPDX license identifier)")
		endif()
	endif()

	foreach(_ref IN LISTS SBOM_PACKAGE_EXTREF)
		set(_fields "${_fields}
ExternalRef: ${_ref}"
		)
	endforeach()

	if("${SBOM_PACKAGE_RELATIONSHIP}" STREQUAL "")
		set(SBOM_PACKAGE_RELATIONSHIP
			"SPDXRef-${_sbom_project} DEPENDS_ON ${SBOM_PACKAGE_SPDXID}"
		)
	else()
		string(REPLACE "@SBOM_LAST_SPDXID@" "${SBOM_PACKAGE_SPDXID}"
			SBOM_PACKAGE_RELATIONSHIP "${SBOM_PACKAGE_RELATIONSHIP}"
		)
	endif()

	get_property(_sbom_binary_dir GLOBAL PROPERTY SBOM_BINARY_DIR)

	file(
		GENERATE
		OUTPUT ${_sbom_binary_dir}/${SBOM_PACKAGE_SPDXID}.cmake
		CONTENT
		"
			file(APPEND \"\${SBOM_INTERMEDIATE_FILE}\"
\"
PackageName: ${NAME}
SPDXID: ${SBOM_PACKAGE_SPDXID}
ExternalRef: SECURITY cpe23Type ${SBOM_CPE}
PackageDownloadLocation: ${SBOM_PACKAGE_DOWNLOAD_LOCATION}
PackageLicenseDeclared: NOASSERTION
PackageCopyrightText: NOASSERTION
PackageVersion: ${SBOM_PACKAGE_VERSION}
PackageSupplier: ${SBOM_PACKAGE_SUPPLIER}
FilesAnalyzed: false${_fields}
Relationship: ${SBOM_PACKAGE_RELATIONSHIP}
Relationship: ${SBOM_PACKAGE_SPDXID} CONTAINS NOASSERTION
\"
			)
			"
	)

	file(APPEND ${_sbom_binary_dir}/CMakeLists.txt
		"install(SCRIPT \"${SBOM_PACKAGE_SPDXID}.cmake\")\n"
	)

	set(SBOM_LAST_SPDXID "${SBOM_LAST_SPDXID}" PARENT_SCOPE)
endfunction()

# Add a reference to a package in an external file.
function(sbom_add_external ID PATH)
	set(oneValueArgs RENAME SPDXID RELATIONSHIP)
	cmake_parse_arguments(
		SBOM_EXTERNAL "" "${oneValueArgs}" "" ${ARGN}
	)

	_sbom_builder_is_setup()

	if(SBOM_EXTERNAL_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "Unknown arguments: ${SBOM_EXTERNAL_UNPARSED_ARGUMENTS}")
	endif()

	if("${SBOM_EXTERNAL_SPDXID}" STREQUAL "")
		get_property(_spdxids GLOBAL PROPERTY sbom_spdxids)
		set(SBOM_EXTERNAL_SPDXID "DocumentRef-${_spdxids}")
		math(EXPR _spdxids "${_spdxids} + 1")
		set_property(GLOBAL PROPERTY sbom_spdxids "${_spdxids}")
	endif()

	if(NOT "${SBOM_EXTERNAL_SPDXID}" MATCHES "^DocumentRef-[-a-zA-Z0-9]+$")
		message(FATAL_ERROR "Invalid DocumentRef \"${SBOM_EXTERNAL_SPDXID}\"")
	endif()

	set(SBOM_LAST_SPDXID "${SBOM_EXTERNAL_SPDXID}" PARENT_SCOPE)

	get_filename_component(sbom_dir "${_sbom}" DIRECTORY)

	if("${SBOM_EXTERNAL_RELATIONSHIP}" STREQUAL "")
		set(SBOM_EXTERNAL_RELATIONSHIP
			"SPDXRef-${_sbom_project} DEPENDS_ON ${SBOM_EXTERNAL_SPDXID}:${ID}"
		)
	else()
		string(REPLACE "@SBOM_LAST_SPDXID@" "${SBOM_EXTERNAL_SPDXID}"
			SBOM_EXTERNAL_RELATIONSHIP "${SBOM_EXTERNAL_RELATIONSHIP}"
		)
	endif()

	get_property(_sbom_binary_dir GLOBAL PROPERTY SBOM_BINARY_DIR)

	# Filename may not exist yet, and it could be a generator expression.
	file(
		GENERATE
		OUTPUT ${_sbom_binary_dir}/${SBOM_EXTERNAL_SPDXID}.cmake
		CONTENT
"file(SHA1 \"${PATH}\" ext_sha1)
file(READ \"${PATH}\" ext_content)
if(\"${SBOM_EXTERNAL_RENAME}\" STREQUAL \"\")
	get_filename_component(ext_name \"${PATH}\" NAME)
	file(WRITE \"${sbom_dir}/\${ext_name}\" \"\${ext_content}\")
else()
	file(WRITE \"${sbom_dir}/${SBOM_EXTERNAL_RENAME}\" \"\${ext_content}\")
endif()

if(NOT \"\${ext_content}\" MATCHES \"[\\r\\n]DocumentNamespace:\")
	message(FATAL_ERROR \"Missing DocumentNamespace in ${PATH}\")
endif()

string(REGEX REPLACE
	\"^.*[\\r\\n]DocumentNamespace:[ \\t]*([^#\\r\\n]*).*$\" \"\\\\1\" ext_ns \"\${ext_content}\")

list(APPEND SBOM_EXT_DOCS \"ExternalDocumentRef: ${SBOM_EXTERNAL_SPDXID} \${ext_ns} SHA1: \${ext_sha1}\")

file(APPEND \"\${SBOM_INTERMEDIATE_FILE}\" \"Relationship: ${SBOM_EXTERNAL_RELATIONSHIP}\")
"
	)

	file(APPEND ${_sbom_binary_dir}/CMakeLists.txt
		"install(SCRIPT \"${SBOM_EXTERNAL_SPDXID}.cmake\")\n"
	)

endfunction()

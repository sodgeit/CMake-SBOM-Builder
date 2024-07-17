cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

# catch and stop second call to this function
if(COMMAND sbom_generate)
	return()
endif()

include(GNUInstallDirs)

set(VERSION_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "")

find_package(Git)

function(version_show)
	message(STATUS "${PROJECT_NAME} version is ${GIT_VERSION}")
endfunction()

# Extract version information from Git of the current project.
function(version_extract)
	set(options VERBOSE)
	cmake_parse_arguments(
		VERSION_EXTRACT "${options}" "" "" ${ARGN}
	)

	if(DEFINED GIT_VERSION)
		return()
	endif()

	set(version_git_head "unknown")
	set(version_git_hash "")
	set(version_git_branch "dev")
	set(version_git_tag "")

	if(Git_FOUND)
		execute_process(
			COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			OUTPUT_VARIABLE version_git_head
			ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
		)

		execute_process(
			COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			OUTPUT_VARIABLE version_git_hash
			ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
		)

		execute_process(
			COMMAND ${GIT_EXECUTABLE} rev-parse --abbrev-ref HEAD
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			OUTPUT_VARIABLE version_git_branch
			ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
		)

		if("${version_git_branch}" STREQUAL "HEAD")
			if(NOT "$ENV{CI_COMMIT_BRANCH}" STREQUAL "")
				# Probably a detached head running on a gitlab runner
				set(version_git_branch "$ENV{CI_COMMIT_BRANCH}")
			endif()
		endif()

		execute_process(
			COMMAND ${GIT_EXECUTABLE} tag --points-at HEAD
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			OUTPUT_VARIABLE version_git_tag
			ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
		)

		string(REGEX REPLACE "[ \t\r\n].*$" "" version_git_tag "${version_git_tag}")

		if("${version_git_tag}" STREQUAL "")
			if(NOT "$ENV{CI_COMMIT_TAG}" STREQUAL "")
				# Probably a detached head running on a gitlab runner
				set(version_git_tag "$ENV{CI_COMMIT_TAG}")
			endif()
		endif()

		execute_process(
			COMMAND ${GIT_EXECUTABLE} status -s
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			OUTPUT_VARIABLE version_git_dirty
			ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
		)

		if(NOT "${version_git_dirty}" STREQUAL "")
			set(version_git_dirty "+dirty")
		endif()

		macro(git_hash TAG TAG_VAR)
			execute_process(
				COMMAND ${GIT_EXECUTABLE} rev-parse ${TAG}
				WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
				OUTPUT_VARIABLE ${TAG_VAR}_
				ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
			)

			set(${TAG_VAR} "${${TAG_VAR}_}" PARENT_SCOPE)
		endmacro()

		execute_process(
			COMMAND ${GIT_EXECUTABLE} tag
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			OUTPUT_VARIABLE GIT_TAGS
			ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
		)

		if(GIT_TAGS)
			string(REGEX REPLACE "[ \t\r\n]+" ";" GIT_TAGS_LIST ${GIT_TAGS})

			foreach(tag IN LISTS GIT_TAGS_LIST)
				git_hash(${tag} GIT_HASH_${tag})

				if(VERSION_EXTRACT_VERBOSE)
					message(STATUS "git hash of tag ${tag} is ${GIT_HASH_${tag}}")
				endif()
			endforeach()
		endif()
	else()
		message(WARNING "Git not found")
	endif()

	if("$ENV{CI_BUILD_ID}" STREQUAL "")
		set(version_build "")
	else()
		set(version_build "+build$ENV{CI_BUILD_ID}")
	endif()

	set(GIT_HASH "${version_git_hash}" PARENT_SCOPE)
	set(GIT_HASH_SHORT "${version_git_head}" PARENT_SCOPE)

	if(NOT ${version_git_tag} STREQUAL "")
		set(_GIT_VERSION "${version_git_tag}")

		if("${_GIT_VERSION}" MATCHES "^v[0-9]+\.")
			string(REGEX REPLACE "^v" "" _GIT_VERSION "${_GIT_VERSION}")
		endif()

		set(GIT_VERSION "${_GIT_VERSION}${version_git_dirty}")
	else()
		set(GIT_VERSION
			"${version_git_head}+${version_git_branch}${version_build}${version_git_dirty}"
		)
	endif()

	set(GIT_VERSION "${GIT_VERSION}" PARENT_SCOPE)
	string(REGEX REPLACE "[^-a-zA-Z0-9_.]+" "+" _GIT_VERSION_PATH "${GIT_VERSION}")
	set(GIT_VERSION_PATH "${_GIT_VERSION_PATH}" PARENT_SCOPE)

	if(VERSION_EXTRACT_VERBOSE)
		version_show()
	endif()
endfunction()

# Generate version files and a static library based on the extract version information of the
# current project.
function(version_generate)
	if(NOT DEFINED ${GIT_VERSION})
		version_extract()
	endif()

	string(TIMESTAMP VERSION_TIMESTAMP "%Y-%m-%d %H:%M:%S")
	set(VERSION_TIMESTAMP "${VERSION_TIMESTAMP}")
	set(VERSION_TIMESTAMP
		"${VERSION_TIMESTAMP}"
		PARENT_SCOPE
	)

	if("${GIT_VERSION}" MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+([-+].*)?$")
		set(GIT_VERSION_TRIPLET ${GIT_VERSION})
		string(REGEX REPLACE "^([0-9]+)\\.([0-9]+)\\.([0-9]+)([-+].*)?$" "\\1"
			GIT_VERSION_MAJOR "${GIT_VERSION}"
		)
		string(REGEX REPLACE "^([0-9]+)\\.([0-9]+)\\.([0-9]+)([-+].*)?$" "\\2"
			GIT_VERSION_MINOR "${GIT_VERSION}"
		)
		string(REGEX REPLACE "^([0-9]+)\\.([0-9]+)\\.([0-9]+)([-+].*)?$" "\\3"
			GIT_VERSION_PATCH "${GIT_VERSION}"
		)
		string(REGEX REPLACE "^([0-9]+)\\.([0-9]+)\\.([0-9]+)(([-+].*)?)$" "\\4"
			GIT_VERSION_SUFFIX "${GIT_VERSION}"
		)
	else()
		# Choose a high major number, such that it is always incompatible with existing
		# tags.
		set(GIT_VERSION_TRIPLET "9999.0.0")
		set(GIT_VERSION_MAJOR 9999)
		set(GIT_VERSION_MINOR 0)
		set(GIT_VERSION_PATCH 0)
		set(GIT_VERSION_SUFFIX "+${GIT_HASH_SHORT}")
	endif()

	set(GIT_VERSION_TRIPLET ${GIT_VERSION_TRIPLET} PARENT_SCOPE)
	set(GIT_VERSION_MAJOR ${GIT_VERSION_MAJOR} PARENT_SCOPE)
	set(GIT_VERSION_MINOR ${GIT_VERSION_MINOR} PARENT_SCOPE)
	set(GIT_VERSION_PATCH ${GIT_VERSION_PATCH} PARENT_SCOPE)
	set(GIT_VERSION_SUFFIX ${GIT_VERSION_SUFFIX} PARENT_SCOPE)

	string(TOUPPER "${PROJECT_NAME}" PROJECT_NAME_UC)
	string(REGEX REPLACE "[^A-Z0-9]+" "_" PROJECT_NAME_UC "${PROJECT_NAME_UC}")

	file(
		GENERATE
		OUTPUT ${PROJECT_BINARY_DIR}/version.sh
		CONTENT "#!/bin/bash

#This is a generated file. Do not edit.

GIT_VERSION=\"${GIT_VERSION}\"
GIT_HASH=\"${GIT_HASH}\"
GIT_VERSION_PATH=\"${GIT_VERSION_PATH}\"
"
	)

	file(
		GENERATE
		OUTPUT ${PROJECT_BINARY_DIR}/version.ps1
		CONTENT "#!/bin/bash

#This is a generated file. Do not edit.

$GIT_VERSION=\"${GIT_VERSION}\"
$GIT_HASH=\"${GIT_HASH}\"
$GIT_VERSION_PATH=\"${GIT_VERSION_PATH}\"
"
	)

	file(
		GENERATE
		OUTPUT ${PROJECT_BINARY_DIR}/include/${PROJECT_NAME}_version.h
		CONTENT "// clang-format off
#ifndef ${PROJECT_NAME_UC}_VERSION_H
#define ${PROJECT_NAME_UC}_VERSION_H

/* This is a generated file. Do not edit. */

#define ${PROJECT_NAME_UC}_VERSION_HASH    \"${GIT_HASH}\"
#define ${PROJECT_NAME_UC}_VERSION         \"${GIT_VERSION}\"
#define ${PROJECT_NAME_UC}_TIMESTAMP       \"${VERSION_TIMESTAMP}\"

#define ${PROJECT_NAME_UC}_VERSION_MAJOR    ${GIT_VERSION_MAJOR}
#define ${PROJECT_NAME_UC}_VERSION_MINOR    ${GIT_VERSION_MINOR}
#define ${PROJECT_NAME_UC}_VERSION_PATCH    ${GIT_VERSION_PATCH}
#define ${PROJECT_NAME_UC}_VERSION_SUFFIX  \"${GIT_VERSION_SUFFIX}\"

#if ${PROJECT_NAME_UC}_VERSION_MINOR >= 100L
#  error ${PROJECT_NAME_UC}_VERSION_MINOR (${GIT_VERSION_MINOR}) too large.
#endif

#if ${PROJECT_NAME_UC}_VERSION_PATCH >= 100L
#  error ${PROJECT_NAME_UC}_VERSION_PATCH (${GIT_VERSION_PATCH}) too large.
#endif

#define ${PROJECT_NAME_UC}_VERSION_NUM           \\
	(${PROJECT_NAME_UC}_VERSION_MAJOR * 10000L + \\
	 ${PROJECT_NAME_UC}_VERSION_MINOR * 100L +   \\
	 ${PROJECT_NAME_UC}_VERSION_PATCH * 1L)

#endif // ${PROJECT_NAME_UC}_VERSION_H
    // clang-format on
"
	)

	file(WRITE ${PROJECT_BINARY_DIR}/version.txt "${GIT_VERSION}")

	if(NOT TARGET ${PROJECT_NAME}-version)
		add_library(${PROJECT_NAME}-version INTERFACE)

		target_include_directories(${PROJECT_NAME}-version INTERFACE
			"$<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>"
			"$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
		)
	endif()
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
		set(SBOM_GENERATE_OUTPUT "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_DATAROOTDIR}/${PROJECT_NAME}/${PROJECT_NAME}-sbom-${GIT_VERSION_PATH}.spdx")
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

	install(
		CODE "
		message(STATUS \"Installing: ${SBOM_GENERATE_OUTPUT}\")
		set(SBOM_EXT_DOCS)
		file(WRITE \"${PROJECT_BINARY_DIR}/sbom/sbom.spdx.in\" \"\")
		"
	)

	file(MAKE_DIRECTORY ${PROJECT_BINARY_DIR}/sbom)

	if(NOT DEFINED SBOM_GENERATE_INPUT)
		set(_f "${CMAKE_CURRENT_BINARY_DIR}/SPDXRef-DOCUMENT.spdx.in")

		if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.20)
			cmake_path(GET SBOM_GENERATE_OUTPUT FILENAME doc_name)
		else()
			get_filename_component(doc_name "${SBOM_GENERATE_OUTPUT}" NAME_WLE)
		endif()

		file(
			GENERATE
			OUTPUT "${_f}"
			CONTENT
			"SPDXVersion: SPDX-2.3
DataLicense: CC0-1.0
SPDXID: SPDXRef-DOCUMENT
DocumentName: ${doc_name}
DocumentNamespace: ${SBOM_GENERATE_NAMESPACE}
Creator: Organization: ${SBOM_GENERATE_SUPPLIER}
Creator: Tool: cmake-sbom
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
PackageComment: <text>Built by CMake ${CMAKE_VERSION} with ${CMAKE_BUILD_TYPE} configuration for ${CMAKE_SYSTEM_NAME} (${CMAKE_SYSTEM_PROCESSOR})</text>
PackageVerificationCode: \${SBOM_VERIFICATION_CODE}
BuiltDate: ${NOW_UTC}
Relationship: SPDXRef-DOCUMENT DESCRIBES SPDXRef-${SBOM_GENERATE_PROJECT}
"
		)

		install(
			CODE "
				file(READ \"${_f}\" _f_contents)
				file(APPEND \"${PROJECT_BINARY_DIR}/sbom/sbom.spdx.in\" \"\${_f_contents}\")
			"
		)

		set(SBOM_LAST_SPDXID
			"SPDXRef-${SBOM_GENERATE_PROJECT}"
			PARENT_SCOPE
		)
	else()
		foreach(_f IN LISTS SBOM_GENERATE_INPUT)
			get_filename_component(_f_name "${_f}" NAME)
			set(_f_in "${CMAKE_CURRENT_BINARY_DIR}/${_f_name}")
			set(_f_in_gen "${_f_in}_gen")
			configure_file("${_f}" "${_f_in}" @ONLY)
			file(
				GENERATE
				OUTPUT "${_f_in_gen}"
				INPUT "${_f_in}"
			)
			install(
				CODE "
					file(READ \"${_f_in_gen}\" _f_contents)
					file(APPEND \"${PROJECT_BINARY_DIR}/sbom/sbom.spdx.in\" \"\${_f_contents}\")
				"
			)
		endforeach()

		set(SBOM_LAST_SPDXID
			""
			PARENT_SCOPE
		)
	endif()

	install(CODE "set(SBOM_VERIFICATION_CODES \"\")")

	set_property(GLOBAL PROPERTY SBOM_FILENAME "${SBOM_GENERATE_OUTPUT}")
	set(SBOM_FILENAME
		"${SBOM_GENERATE_OUTPUT}"
		PARENT_SCOPE
	)
	set_property(GLOBAL PROPERTY sbom_project "${SBOM_GENERATE_PROJECT}")
	set_property(GLOBAL PROPERTY sbom_spdxids 0)

	file(WRITE ${PROJECT_BINARY_DIR}/sbom/CMakeLists.txt "")
endfunction()

# Finalize the generated SBOM. Call after sbom_generate() and other SBOM populating commands.
function(sbom_finalize)
	get_property(_sbom GLOBAL PROPERTY SBOM_FILENAME)
	get_property(_sbom_project GLOBAL PROPERTY sbom_project)

	if("${_sbom_project}" STREQUAL "")
		message(FATAL_ERROR "Call sbom_generate() first")
	endif()

	file(
		WRITE ${PROJECT_BINARY_DIR}/sbom/finalize.cmake
		"
		message(STATUS \"Finalizing: ${_sbom}\")
		list(SORT SBOM_VERIFICATION_CODES)
		string(REPLACE \";\" \"\" SBOM_VERIFICATION_CODES \"\${SBOM_VERIFICATION_CODES}\")
		file(WRITE \"${PROJECT_BINARY_DIR}/sbom/verification.txt\" \"\${SBOM_VERIFICATION_CODES}\")
		file(SHA1 \"${PROJECT_BINARY_DIR}/sbom/verification.txt\" SBOM_VERIFICATION_CODE)
		configure_file(\"${PROJECT_BINARY_DIR}/sbom/sbom.spdx.in\" \"${_sbom}\")
		"
	)

	file(APPEND ${PROJECT_BINARY_DIR}/sbom/CMakeLists.txt "install(SCRIPT finalize.cmake)
"
	)

	# Workaround for pre-CMP0082.
	add_subdirectory(${PROJECT_BINARY_DIR}/sbom ${PROJECT_BINARY_DIR}/sbom)

	# Mark finalized.
	set(SBOM_FILENAME "${_sbom}" PARENT_SCOPE)
	set_property(GLOBAL PROPERTY sbom_project "")
endfunction()

# Append a file to the SBOM. Use this after calling sbom_generate().
function(_sbom_file)
	set(options OPTIONAL)
	set(oneValueArgs FILENAME FILETYPE RELATIONSHIP SPDXID)
	set(multiValueArgs)
	cmake_parse_arguments(SBOM_FILE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	if(SBOM_FILE_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "Unknown arguments: ${SBOM_FILE_UNPARSED_ARGUMENTS}")
	endif()

	if("${SBOM_FILE_FILENAME}" STREQUAL "")
		message(FATAL_ERROR "Missing FILENAME argument")
	endif()

	sbom_spdxid(
		VARIABLE SBOM_FILE_SPDXID
		CHECK "${SBOM_FILE_SPDXID}"
		HINTS "SPDXRef-${SBOM_FILE_FILENAME}"
	)

	set(SBOM_LAST_SPDXID
		"${SBOM_FILE_SPDXID}"
		PARENT_SCOPE
	)

	if("${SBOM_FILE_FILETYPE}" STREQUAL "")
		message(FATAL_ERROR "Missing FILETYPE argument")
	endif()

	if("${SBOM_FILE_RELATIONSHIP}" STREQUAL "")
		set(SBOM_FILE_RELATIONSHIP "SPDXRef-${_sbom_project} CONTAINS ${SBOM_FILE_SPDXID}")
	else()
		string(REPLACE "@SBOM_LAST_SPDXID@" "${SBOM_FILE_SPDXID}" SBOM_FILE_RELATIONSHIP
			"${SBOM_FILE_RELATIONSHIP}"
		)
	endif()

	file(
		GENERATE
		OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${SBOM_FILE_SPDXID}.cmake
		CONTENT
		"
			cmake_policy(SET CMP0011 NEW)
			cmake_policy(SET CMP0012 NEW)
			if(NOT EXISTS ${CMAKE_INSTALL_PREFIX}/${SBOM_FILE_FILENAME})
				if(NOT ${SBOM_FILE_OPTIONAL})
					message(FATAL_ERROR \"Cannot find ${SBOM_FILE_FILENAME}\")
				endif()
			else()
				file(SHA1 ${CMAKE_INSTALL_PREFIX}/${SBOM_FILE_FILENAME} _sha1)
				list(APPEND SBOM_VERIFICATION_CODES \${_sha1})
				file(APPEND \"${PROJECT_BINARY_DIR}/sbom/sbom.spdx.in\"
\"
FileName: ./${SBOM_FILE_FILENAME}
SPDXID: ${SBOM_FILE_SPDXID}
FileType: ${SBOM_FILE_FILETYPE}
FileChecksum: SHA1: \${_sha1}
LicenseConcluded: NOASSERTION
LicenseInfoInFile: NOASSERTION
FileCopyrightText: NOASSERTION
Relationship: ${SBOM_FILE_RELATIONSHIP}
\"
				)
			endif()
			"
	)

	install(SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/${SBOM_FILE_SPDXID}.cmake)
endfunction()

# Append a target output to the SBOM. Use this after calling sbom_generate().
function(_sbom_target)
	set(oneValueArgs TARGET)
	cmake_parse_arguments(
		SBOM_TARGET "" "${oneValueArgs}" "" ${ARGN}
	)

	if("${SBOM_TARGET_TARGET}" STREQUAL "")
		message(FATAL_ERROR "Missing TARGET argument")
	endif()

	get_target_property(_type ${SBOM_TARGET_TARGET} TYPE)

	if("${_type}" STREQUAL "EXECUTABLE")
		_sbom_file(FILENAME ${CMAKE_INSTALL_BINDIR}/$<TARGET_FILE_NAME:${SBOM_TARGET_TARGET}>
			FILETYPE BINARY ${SBOM_TARGET_UNPARSED_ARGUMENTS}
		)
	elseif("${_type}" STREQUAL "STATIC_LIBRARY")
		_sbom_file(FILENAME ${CMAKE_INSTALL_LIBDIR}/$<TARGET_FILE_NAME:${SBOM_TARGET_TARGET}>
			FILETYPE BINARY ${SBOM_TARGET_UNPARSED_ARGUMENTS}
		)
	elseif("${_type}" STREQUAL "SHARED_LIBRARY")
		if(WIN32)
			_sbom_file(
				FILENAME
				${CMAKE_INSTALL_BINDIR}/$<TARGET_FILE_NAME:${SBOM_TARGET_TARGET}>
				FILETYPE BINARY ${SBOM_TARGET_UNPARSED_ARGUMENTS}
			)
			_sbom_file(
				FILENAME
				${CMAKE_INSTALL_LIBDIR}/$<TARGET_LINKER_FILE_NAME:${SBOM_TARGET_TARGET}>
				FILETYPE BINARY OPTIONAL ${SBOM_TARGET_UNPARSED_ARGUMENTS}
			)
		else()
			_sbom_file(
				FILENAME
				${CMAKE_INSTALL_LIBDIR}/$<TARGET_FILE_NAME:${SBOM_TARGET_TARGET}>
				FILETYPE BINARY ${SBOM_TARGET_UNPARSED_ARGUMENTS}
			)
		endif()
	else()
		message(FATAL_ERROR "Unsupported target type ${_type}")
	endif()

	set(SBOM_LAST_SPDXID
		"${SBOM_LAST_SPDXID}"
		PARENT_SCOPE
	)
endfunction()

# Append all files recursively in a directory to the SBOM. Use this after calling sbom_generate().
function(_sbom_directory)
	set(oneValueArgs DIRECTORY FILETYPE RELATIONSHIP)
	cmake_parse_arguments(
		SBOM_DIRECTORY "" "${oneValueArgs}" "" ${ARGN}
	)

	if(SBOM_DIRECTORY_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "Unknown arguments: ${SBOM_DIRECTORY_UNPARSED_ARGUMENTS}")
	endif()

	if("${SBOM_DIRECTORY_DIRECTORY}" STREQUAL "")
		message(FATAL_ERROR "Missing DIRECTORY argument")
	endif()

	sbom_spdxid(VARIABLE SBOM_DIRECTORY_SPDXID HINTS "SPDXRef-${SBOM_DIRECTORY_DIRECTORY}")

	set(SBOM_LAST_SPDXID "${SBOM_DIRECTORY_SPDXID}")

	if("${SBOM_DIRECTORY_FILETYPE}" STREQUAL "")
		message(FATAL_ERROR "Missing FILETYPE argument")
	endif()

	if("${SBOM_DIRECTORY_RELATIONSHIP}" STREQUAL "")
		set(SBOM_DIRECTORY_RELATIONSHIP
			"SPDXRef-${_sbom_project} CONTAINS ${SBOM_DIRECTORY_SPDXID}"
		)
	else()
		string(REPLACE "@SBOM_LAST_SPDXID@" "${SBOM_DIRECTORY_SPDXID}"
			SBOM_DIRECTORY_RELATIONSHIP "${SBOM_DIRECTORY_RELATIONSHIP}"
		)
	endif()

	file(
		GENERATE
		OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${SBOM_DIRECTORY_SPDXID}.cmake"
		CONTENT
		"
			file(GLOB_RECURSE _files
				LIST_DIRECTORIES false RELATIVE \"${CMAKE_INSTALL_PREFIX}\"
				\"${CMAKE_INSTALL_PREFIX}/${SBOM_DIRECTORY_DIRECTORY}/*\"
			)

			set(_count 0)
			foreach(_f IN LISTS _files)
				file(SHA1 \"${CMAKE_INSTALL_PREFIX}/\${_f}\" _sha1)
				list(APPEND SBOM_VERIFICATION_CODES \${_sha1})
				file(APPEND \"${PROJECT_BINARY_DIR}/sbom/sbom.spdx.in\"
\"
FileName: ./\${_f}
SPDXID: ${SBOM_DIRECTORY_SPDXID}-\${_count}
FileType: ${SBOM_DIRECTORY_FILETYPE}
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

	install(SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/${SBOM_DIRECTORY_SPDXID}.cmake)

	set(SBOM_LAST_SPDXID
		""
		PARENT_SCOPE
	)
endfunction()

# Append a package (without files) to the SBOM. Use this after calling sbom_generate().
function(_sbom_package)
	set(oneValueArgs
		PACKAGE
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

	if(SBOM_PACKAGE_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "Unknown arguments: ${SBOM_PACKAGE_UNPARSED_ARGUMENTS}")
	endif()

	if("${SBOM_PACKAGE_PACKAGE}" STREQUAL "")
		message(FATAL_ERROR "Missing PACKAGE")
	endif()

	if("${SBOM_PACKAGE_DOWNLOAD_LOCATION}" STREQUAL "")
		set(SBOM_PACKAGE_DOWNLOAD_LOCATION NOASSERTION)
	endif()

	sbom_spdxid(
		VARIABLE SBOM_PACKAGE_SPDXID
		CHECK "${SBOM_PACKAGE_SPDXID}"
		HINTS "SPDXRef-${SBOM_PACKAGE_PACKAGE}"
	)

	set(SBOM_LAST_SPDXID ${SBOM_PACKAGE_SPDXID} PARENT_SCOPE)

	set(_fields)

	if("${SBOM_PACKAGE_VERSION}" STREQUAL "")
		set(SBOM_PACKAGE_VERSION "unknown")

		if(${SBOM_CHECKS_ENABLED})
			message(WARNING "Version missing for package: ${SBOM_PACKAGE_PACKAGE}. (semver/commit-hash)")
		endif()
	endif()

	if("${SBOM_PACKAGE_SUPPLIER}" STREQUAL "")
		set(SBOM_PACKAGE_SUPPLIER "Person: Anonymous")

		if(${SBOM_CHECKS_ENABLED})
			message(WARNING "Supplier missing for package: ${SBOM_PACKAGE_PACKAGE}. (Person/Organization + email/url)")
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
			message(WARNING "LICENSE missing for package ${SBOM_PACKAGE_PACKAGE}. (SPDX license identifier)")
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

	file(
		GENERATE
		OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${SBOM_PACKAGE_SPDXID}.cmake
		CONTENT
		"
			file(APPEND \"${PROJECT_BINARY_DIR}/sbom/sbom.spdx.in\"
\"
PackageName: ${SBOM_PACKAGE_PACKAGE}
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

	file(APPEND ${PROJECT_BINARY_DIR}/sbom/CMakeLists.txt
		"install(SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/${SBOM_PACKAGE_SPDXID}.cmake)
"
	)
endfunction()

# Add a reference to a package in an external file.
function(_sbom_external)
	set(oneValueArgs EXTERNAL FILENAME RENAME SPDXID RELATIONSHIP)
	cmake_parse_arguments(
		SBOM_EXTERNAL "" "${oneValueArgs}" "" ${ARGN}
	)

	if(SBOM_EXTERNAL_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "Unknown arguments: ${SBOM_EXTERNAL_UNPARSED_ARGUMENTS}")
	endif()

	if("${SBOM_EXTERNAL_EXTERNAL}" STREQUAL "")
		message(FATAL_ERROR "Missing EXTERNAL")
	endif()

	if("${SBOM_EXTERNAL_FILENAME}" STREQUAL "")
		message(FATAL_ERROR "Missing FILENAME")
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
			"SPDXRef-${_sbom_project} DEPENDS_ON ${SBOM_EXTERNAL_SPDXID}:${SBOM_EXTERNAL_EXTERNAL}"
		)
	else()
		string(REPLACE "@SBOM_LAST_SPDXID@" "${SBOM_EXTERNAL_SPDXID}"
			SBOM_EXTERNAL_RELATIONSHIP "${SBOM_EXTERNAL_RELATIONSHIP}"
		)
	endif()

	# Filename may not exist yet, and it could be a generator expression.
	file(
		GENERATE
		OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${SBOM_EXTERNAL_SPDXID}.cmake
		CONTENT
		"
			file(SHA1 \"${SBOM_EXTERNAL_FILENAME}\" ext_sha1)
			file(READ \"${SBOM_EXTERNAL_FILENAME}\" ext_content)
			if(\"${SBOM_EXTERNAL_RENAME}\" STREQUAL \"\")
				get_filename_component(ext_name \"${SBOM_EXTERNAL_FILENAME}\" NAME)
				file(WRITE \"${sbom_dir}/\${ext_name}\" \"\${ext_content}\")
			else()
				file(WRITE \"${sbom_dir}/${SBOM_EXTERNAL_RENAME}\" \"\${ext_content}\")
			endif()

			if(NOT \"\${ext_content}\" MATCHES \"[\\r\\n]DocumentNamespace:\")
				message(FATAL_ERROR \"Missing DocumentNamespace in ${SBOM_EXTERNAL_FILENAME}\")
			endif()

			string(REGEX REPLACE \"^.*[\\r\\n]DocumentNamespace:[ \\t]*([^#\\r\\n]*).*$\"
				\"\\\\1\" ext_ns \"\${ext_content}\")

			list(APPEND SBOM_EXT_DOCS \"
ExternalDocumentRef: ${SBOM_EXTERNAL_SPDXID} \${ext_ns} SHA1: \${ext_sha1}\")

			file(APPEND \"${PROJECT_BINARY_DIR}/sbom/sbom.spdx.in\"
\"
Relationship: ${SBOM_EXTERNAL_RELATIONSHIP}\")
		"
	)

	file(APPEND ${PROJECT_BINARY_DIR}/sbom/CMakeLists.txt
		"install(SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/${SBOM_EXTERNAL_SPDXID}.cmake)
"
	)
endfunction()

# Append something to the SBOM. Use this after calling sbom_generate().
function(sbom_add)
	set(options FILENAME DIRECTORY TARGET PACKAGE EXTERNAL)
	cmake_parse_arguments(
		SBOM_ADD "${options}" "" "" ${ARGN}
	)

	get_property(_sbom GLOBAL PROPERTY SBOM_FILENAME)
	get_property(_sbom_project GLOBAL PROPERTY sbom_project)

	if("${_sbom_project}" STREQUAL "")
		message(FATAL_ERROR "Call sbom_generate() first")
	endif()

	if(${SBOM_ADD_EXTERNAL})
		_sbom_external(${ARGV})
	elseif(${SBOM_ADD_FILENAME})
		_sbom_file(${ARGV})
	elseif(${SBOM_ADD_DIRECTORY})
		_sbom_directory(${ARGV})
	elseif(${SBOM_ADD_TARGET})
		_sbom_target(${ARGV})
	elseif(${SBOM_ADD_PACKAGE})
		_sbom_package(${ARGV})
	else()
		message(FATAL_ERROR "Unexpected argument")
	endif()

	set(SBOM_LAST_SPDXID "${SBOM_LAST_SPDXID}" PARENT_SCOPE)
endfunction()

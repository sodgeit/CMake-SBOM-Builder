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
#define ${PROJECT_NAME_UC}_VERSION_PATH    \"${GIT_VERSION_PATH}\"
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

macro(_sbom_log log_level log_message)
	message(${log_level} "SBOM-Builder: ${log_message}")
endmacro()

# Adds another level of escaping to the string in the given variable.
# For variables that will be used in generated CMake code. E.g. our generated install scripts
macro(_sbom_inplace_quote_escape var)
	string(REGEX REPLACE "\\\"" "\\\\\"" "${var}" "${${var}}")
endmacro()

# Joins the elements of the given list variable with ",\n" and stores the result back in the same variable.
# Useful for lists which will end up in readable format.
# e.g.:
#	- Json-arrays (without surrounding [] braces)
#	- Lists of Json-Object properties (without surrounding {} braces)
macro(_sbom_cmakelist_to_printable_list var)
	list(JOIN "${var}" ",\\n" "${var}")
endmacro()

macro(_sbom_propagate_spdxid_to_parentscope)
	set(SBOM_LAST_SPDXID "${SBOM_LAST_SPDXID}" PARENT_SCOPE)
	set(SBOM_LAST_SPDXID_PATH "${SBOM_LAST_SPDXID_PATH}" PARENT_SCOPE)
endmacro()

# Generates an URI-based SPDXID.
#
# _sbom_gen_spdxid(SCOPE <str> VARIABLE <str>)
#
# `SCOPE` is used to create a sort of namespace for the generated SPDXID, which reflect
# the hierarchy of the SBOM elements. E.g. "Document", "Agent", "Package", "Relationship", "License" etc.
# `VARIABLE` is a string which will be appended to the SCOPE to create the final SPDXID.
#
# In most cases this is simply the name of the element, e.g. the name of the license or package.
# For some elements `VARIABLE` takes a more complex value to guarantee uniqueness.
# e.g. for relationships: `hasConcludedLicense/from/package/some_deps/to/License/MIT`
# In some cases, e.g. for the root document element, `VARIABLE` can be left empty,
# and the SPDXID will just be based on the SCOPE.
# Because the SCOPE/VARIABLE will be used in filepaths as well, potentially problematic
# characters will be replaced with dashes.
#
# Note: Sets SBOM_LAST_SPDXID and SBOM_LAST_SPDXID_PATH variables as side effect,
#       in the parent scope of the caller.
#       SBOM_LAST_SPDXID will contain the full URI, while SBOM_LAST_SPDXID_PATH
#       will contain the path part without the generic uri prefix for use in filepaths.
function(_sbom_gen_spdxid)
	cmake_parse_arguments(_arg "ALLOW_DUPLICATES" "SCOPE;VARIABLE" "" ${ARGN})

	if(_arg_UNPARSED_ARGUMENTS)
		_sbom_log(FATAL_ERROR "Unknown arguments for _sbom_gen_spdxid: ${_arg_UNPARSED_ARGUMENTS}.")
	endif()

	# TODO probably should come up with a better prefix
	set(prefix "spdx://sbom/v1")
	string(REGEX REPLACE "[^a-zA-Z0-9_]+" "-" _arg_SCOPE "${_arg_SCOPE}")
	set(tmp "${_arg_SCOPE}")
	# to get aroung double '//' in some cases
	if(DEFINED _arg_VARIABLE)
		string(REGEX REPLACE "[^a-zA-Z0-9_]+" "-" _arg_VARIABLE "${_arg_VARIABLE}")
		string(APPEND tmp "/${_arg_VARIABLE}")
	endif()
	set(SBOM_LAST_SPDXID "${prefix}/${tmp}")
	set(SBOM_LAST_SPDXID_PATH "${tmp}")

	get_property(_generated_spdxids GLOBAL PROPERTY SBOM_SPDXID_IDS)

	list(FIND _generated_spdxids "${SBOM_LAST_SPDXID}" _index)

	if(_index GREATER -1)
		if(NOT DEFINED _arg_ALLOW_DUPLICATES)
			_sbom_log(
				FATAL_ERROR
				"Unable to generate unique SPDX-ID. <${SBOM_LAST_SPDXID}> has already been used for another SBOM element."
			)
		endif()
	else()
		list(APPEND _generated_spdxids "${SBOM_LAST_SPDXID}")
		set_property(GLOBAL PROPERTY SBOM_SPDXID_IDS "${_generated_spdxids}")
	endif()

	_sbom_propagate_spdxid_to_parentscope()
endfunction()


function(_sbom_serialize_package_dates package_dates out_var)
	set(oneValueArgs "BUILT;RELEASE;VALID_UNTIL")
	cmake_parse_arguments(_arg_dates "" "${oneValueArgs}" "" ${package_dates})

	foreach(_date ${oneValueArgs})
		if(DEFINED _arg_dates_${_date})
			string(REGEX MATCH "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$" _arg_dates_${_date} ${_arg_dates_${_date}})
			if(NOT _arg_dates_${_date})
				_sbom_log(FATAL_ERROR "Invalid date format for ${_date}: ${_arg_dates_${_date}}")
			endif()
		endif()
	endforeach()

	set(_built_field FALSE)
	set(_built_field_txt "")
	if(DEFINED _arg_dates_BUILT)
		set(_built_field TRUE)
		set(_built_field_txt "\"builtTime\":\"${_arg_dates_BUILT}\",")
	endif()

	set(_released_field FALSE)
	set(_released_field_txt "")
	if(DEFINED _arg_dates_RELEASE)
		set(_released_field TRUE)
		set(_released_field_txt "\"releaseTime\":\"${_arg_dates_RELEASE}\",")
	endif()

	set(_updated_field FALSE)
	set(_updated_field_txt "")
	if(DEFINED _arg_dates_VALID_UNTIL)
		set(_updated_field TRUE)
		set(_updated_field_txt "\"validUntilTime\":\"${_arg_dates_VALID_UNTIL}\",")
	endif()

	set(_genex_str
		"$<$<BOOL:${_built_field}>:${_built_field_txt}>"
		"$<$<BOOL:${_released_field}>:${_released_field_txt}>"
		"$<$<BOOL:${_updated_field}>:${_updated_field_txt}>"
	)
	set(_genex_str "$<JOIN:${_genex_str},\",\">")

	set(${out_var} "${_genex_str}" PARENT_SCOPE)
endfunction()

function(_sbom_serialize_package_notes _package_notes _output_var)
	set(oneValueArgs "SUMMARY" "DESC" "COMMENT")
	cmake_parse_arguments(_arg_notes "" "${oneValueArgs}" "" ${_package_notes})

	set(_pkg_summary_field FALSE)
	set(_pkg_summary_field_txt "")
	if(DEFINED _arg_notes_SUMMARY)
		set(_pkg_summary_field TRUE)
		set(_pkg_summary_field_txt "\"summary\":\"${_arg_notes_SUMMARY}\",")
	endif()

	set(_pkg_desc_field FALSE)
	set(_pkg_desc_field_txt "")
	if(DEFINED _arg_notes_DESC)
		set(_pkg_desc_field TRUE)
		set(_pkg_desc_field_txt "\"description\":\"${_arg_notes_DESC}\",")
	endif()

	set(_genex_str
		"$<$<BOOL:${_pkg_desc_field}>:${_pkg_desc_field_txt}>"
		"$<$<BOOL:${_pkg_summary_field}>:${_pkg_summary_field_txt}>"
	)
	set(_genex_str "$<JOIN:${_genex_str},\",\">")

	set(${_output_var} "${_genex_str}" PARENT_SCOPE)
endfunction()

function(_sbom_serialize_creator_tool creation_property out_var out_spdxid_var)
	_sbom_gen_spdxid(
		VARIABLE "CMake-SBOM-Builder-${SBOM_BUILDER_VERSION}"
		SCOPE "Agent"
	)

	set( out "
{
	${creation_property},
	\"type\":\"Tool\",
	\"name\":\"CMake-SBOM-Builder-${SBOM_BUILDER_VERSION}\",
	\"spdxId\":\"${SBOM_LAST_SPDXID}\"
}"
	)

	set(${out_var} "${out}" PARENT_SCOPE)
	set(${out_spdxid_var} "${SBOM_LAST_SPDXID}" PARENT_SCOPE)
endfunction()

function(_sbom_serialize_creator creator creation_property out_var out_spdxid_var)
	cmake_parse_arguments(_arg_CREATOR "" "PERSON;ORGANIZATION;EMAIL" "" ${creator})

	if(_arg_CREATOR_UNPARSED_ARGUMENTS)
		_sbom_log(FATAL_ERROR "Unknown subarguments for CREATOR: ${_arg_CREATOR_UNPARSED_ARGUMENTS}.")
	endif()
	if((NOT DEFINED _arg_CREATOR_PERSON) AND (NOT DEFINED _arg_CREATOR_ORGANIZATION))
		_sbom_log(FATAL_ERROR "Missing <PERSON|ORGANIZATION> <name> for argument CREATOR.")
	elseif(DEFINED _arg_CREATOR_PERSON AND DEFINED _arg_CREATOR_ORGANIZATION)
		_sbom_log(FATAL_ERROR "Specify either PERSON or ORGANIZATION, not both.")
	endif()

	if(DEFINED _arg_CREATOR_PERSON)
		set(creator_type "Person")
		set(creator_name "${_arg_CREATOR_PERSON}")
	elseif(DEFINED _arg_CREATOR_ORGANIZATION)
		set(creator_type "Organization")
		set(creator_name "${_arg_CREATOR_ORGANIZATION}")
	endif()

	_sbom_gen_spdxid(
		VARIABLE "${creator_type}/${creator_name}"
		SCOPE "Agent"
	)
	set(_creator_spdxid "${SBOM_LAST_SPDXID}")

	set(_email_obj FALSE)
	set(_email_obj_txt "")
	if(DEFINED _arg_CREATOR_EMAIL)
		set(_email_obj TRUE)
		set(_email_obj_txt "{
			\"type\":\"ExternalIdentifier\",
			\"externalIdentifierType\":\"email\",
			\"identifier\":\"${_arg_CREATOR_EMAIL}\"
		}")
	endif()

	set( out "
{
	${creation_property},
	\"type\":\"${creator_type}\",
	\"name\":\"${creator_name}\",
	\"spdxId\":\"${_creator_spdxid}\"$<$<BOOL:${_email_obj}>:,
	\"externalIdentifier\":[${_email_obj_txt}]>
}")

	set(${out_var} "${out}" PARENT_SCOPE)
	set(${out_spdxid_var} "${_creator_spdxid}" PARENT_SCOPE)

endfunction()

function(_sbom_serialize_creation_info creator_spdxid creator_tool_spdxid out_var out_id_var)
	set(_creation_info_id "_:creationInfo")

set( out "
{
	\"type\":\"CreationInfo\",
	\"created\":\"\${SBOM_CREATE_DATE}\",
	\"@id\":\"${_creation_info_id}\",
	\"specVersion\":\"3.0.1\",
	\"createdBy\":[
		\"${creator_spdxid}\"
	],
	\"createdUsing\":[
		\"${creator_tool_spdxid}\"
	],
	\"comment\":\"This SPDX document was created with CMake ${CMAKE_VERSION}, using CMake-SBOM-Builder from https://github.com/sodgeit/CMake-SBOM-Builder\"
}"
	)

	set(${out_var} "${out}" PARENT_SCOPE)
endfunction()

function(_sbom_serialize_license_entry)
	set(one_value_args "LICENSE_ID" "OUT_VAR")
	cmake_parse_arguments( _arg "" "${one_value_args}" "" ${ARGN})

	foreach(val IN LISTS one_value_args)
		if(NOT DEFINED _arg_${val})
			_sbom_log(FATAL_ERROR "Missing argument ${val} for _sbom_serialize_license_entry")
		endif()
	endforeach()

	_sbom_gen_spdxid(
		VARIABLE "${_arg_LICENSE_ID}"
		SCOPE "License"
		ALLOW_DUPLICATES
	)

	set(properties "")
	list(APPEND properties
		"\"creationInfo\":\"_:creationInfo\""
		"\"type\": \"simplelicensing_LicenseExpression\""
		"\"spdxId\": \"${SBOM_LAST_SPDXID}\""
		"\"simplelicensing_licenseExpression\": \"${_arg_LICENSE_ID}\""
	)
	_sbom_cmakelist_to_printable_list(properties)
	set(license_entry "{
${properties}
	}")

	set("${_arg_OUT_VAR}" "${license_entry}" PARENT_SCOPE)
	_sbom_propagate_spdxid_to_parentscope()
endfunction()

function(_sbom_serialize_relationship OUT_VAR)
	set(optional_one_value_arg "COMMENT")
	set(one_value_args "RELTYPE" "FROM" "TO" "FROM_ID" "TO_ID")
	cmake_parse_arguments( _arg "" "${one_value_args};${optional_one_value_arg}" "" "${ARGN}" )

	foreach(arg IN LISTS one_value_args)
		if(NOT DEFINED _arg_${arg})
			_sbom_log(FATAL_ERROR "Missing argument ${arg} for _sbom_serialize_relationship")
		endif()
	endforeach()

	_sbom_gen_spdxid(
		VARIABLE "${_arg_RELTYPE}/from/${_arg_FROM}/to/${_arg_TO}"
		SCOPE "Relationship"
	)

	set(properties "")
	list(APPEND properties
		"\"creationInfo\":\"_:creationInfo\""
		"\"type\": \"Relationship\""
		"\"spdxId\": \"${SBOM_LAST_SPDXID}\""
		"\"from\": \"${_arg_FROM_ID}\""
		"\"to\": [\"${_arg_TO_ID}\"]"
		"\"relationshipType\": \"${_arg_RELTYPE}\""
	)
	if(DEFINED _arg_COMMENT)
		list(APPEND properties "\"comment\": \"${_arg_COMMENT}\"")
	endif()

	_sbom_cmakelist_to_printable_list(properties)
	set(rel "{
${properties}
	}")

	set(${OUT_VAR} "${rel}" PARENT_SCOPE)
	_sbom_propagate_spdxid_to_parentscope()
endfunction()

function(_sbom_serialize_package
	name
	spdxid
	version
	copyright
	out_var)

	cmake_parse_arguments( _arg_ser_pkg "" "DOWNLOAD;URL;SOURCE_INFO" "NOTES;ATTRIBUTION" "${ARGN}")

	set(properties "")
	list( APPEND properties
		"\"creationInfo\":\"_:creationInfo\""
		"\"type\": \"software_Package\""
		"\"spdxId\": \"${spdxid}\""
		"\"name\": \"${name}\""
		"\"software_packageVersion\": \"${version}\""
		"\"software_copyrightText\": \"${copyright}\""
	)

	if(DEFINED _arg_ser_pkg_DOWNLOAD)
		list(APPEND properties "\"software_downloadLocation\": \"${_arg_ser_pkg_DOWNLOAD}\"")
	endif()

	if(DEFINED _arg_ser_pkg_URL)
		list(APPEND properties "\"homepage\": \"${_arg_ser_pkg_URL}\"")
	endif()

	if(DEFINED _arg_ser_pkg_SOURCE_INFO)
		list(APPEND properties "\"sourceInfo\": \"${_arg_ser_pkg_SOURCE_INFO}\"")
	endif()

	set(__attribution_property_txt "")
	if(DEFINED _arg_ser_pkg_ATTRIBUTION)
		foreach(_attr IN LISTS _arg_ser_pkg_ATTRIBUTION)
			string(APPEND __attribution_property_txt "\"${_attr}\",")
		endforeach()
		list(APPEND properties "\"attributionText\": [${__attribution_property_txt}]")
	endif()

	_sbom_serialize_package_notes("${_arg_ser_pkg_NOTES}" _sbom_gen_pkg_notes_genex)
	_sbom_serialize_package_dates("${_arg_ser_pkg_DATE}" _sbom_gen_pkg_dates_genex)

	_sbom_cmakelist_to_printable_list(properties)

	set( pkg
"{
${properties}
}"
	)

	set(${out_var} "${pkg}" PARENT_SCOPE)
endfunction()

macro(_sbom_generate_spdx3_template)
	set(_creator_type "")
	set(_creator_name "")
	set(_creator_email "")
	if(DEFINED _arg_sbom_gen_CREATOR_PERSON)
		set(_creator_type "Person")
		set(_creator_name "${_arg_sbom_gen_CREATOR_PERSON}")
	elseif(DEFINED _arg_sbom_gen_CREATOR_ORGANIZATION)
		set(_creator_type "Organization")
		set(_creator_name "${_arg_sbom_gen_CREATOR_ORGANIZATION}")
	endif()

	_sbom_serialize_package_notes("${_arg_sbom_gen_PACKAGE_NOTES}" _sbom_gen_pkg_notes_genex)

	set(_creation_info_property "\"creationInfo\":\"_:creationInfo\"")

	_sbom_gen_spdxid( SCOPE "Document")
	set(_spdx_document_id "${SBOM_LAST_SPDXID}")
	_sbom_gen_spdxid( SCOPE "Package")
	set(_spdx_software_pkg_id "${SBOM_LAST_SPDXID}")
	set(_spdx_software_pkg_id_path "${SBOM_LAST_SPDXID_PATH}")
	_sbom_gen_spdxid( SCOPE "BOM1")
	set(_spdx_software_sbom_id "${SBOM_LAST_SPDXID}")
	_sbom_gen_spdxid(
		VARIABLE "Compiler-${CMAKE_CXX_COMPILER_ID}"
		SCOPE "Package"
	)
	set(_spdx_software_pkg_compiler_id "${SBOM_LAST_SPDXID}")

	_sbom_serialize_creator_tool(
		"${_creation_info_property}"
		_sbom_gen_creator_tool
		_sbom_gen_creator_tool_spdxid
	)

	_sbom_serialize_creator(
		"${_arg_sbom_gen_CREATOR}"
		"${_creation_info_property}"
		_sbom_gen_creator
		_sbom_gen_creator_spdxid
	)

	_sbom_serialize_creation_info(
		"${_sbom_gen_creator_spdxid}"
		"${_sbom_gen_creator_tool_spdxid}"
		_sbom_gen_creation_info
		_sbom_gen_creation_info_id
	)

	_sbom_add_license(LICENSE_ID "${_arg_sbom_gen_PACKAGE_LICENSE}")
	set(_sbom_gen_pkg_license_spdxid "${SBOM_LAST_SPDXID}")
	set(_sbom_gen_pkg_license_spdxid_path "${SBOM_LAST_SPDXID_PATH}")

	_sbom_add_relationship(
		RELTYPE hasConcludedLicense
		FROM_ID "${_spdx_software_pkg_id}"
		TO_ID "${_sbom_gen_pkg_license_spdxid}"
		FROM "${_spdx_software_pkg_id_path}"
		TO "${_sbom_gen_pkg_license_spdxid_path}"
	)
	_sbom_add_relationship(
		RELTYPE hasDeclaredLicense
		FROM_ID "${_spdx_software_pkg_id}"
		TO_ID "${_sbom_gen_pkg_license_spdxid}"
		FROM "${_spdx_software_pkg_id_path}"
		TO "${_sbom_gen_pkg_license_spdxid_path}"
	)

	set(_sbom_doc_elem_list
		"${_spdx_software_sbom_id}"
		"${_sbom_gen_creator_spdxid}"
	)

	set(_sbom_software_pkg_elem_list
		"${_spdx_software_pkg_id}"
	)

	file(
		GENERATE
		OUTPUT "${SBOM_SNIPPET_DIR}/${_sbom_document_template}"
		CONTENT
"{
	\"@context\":\"https://spdx.org/rdf/3.0.1/spdx-context.jsonld\",
	\"@graph\":[
		${_sbom_gen_creator_tool},
		${_sbom_gen_creator},
		${_sbom_gen_creation_info},
		{
			${_creation_info_property},
			\"type\": \"SpdxDocument\",
			\"name\": \"${doc_name}\",
			\"spdxId\": \"${_spdx_document_id}\",
			\"rootElement\": [
				\"${_spdx_software_sbom_id}\"
			],
			\"element\": [
\${SBOM_DOCUMENT_ELEMENT_LIST}
			],
			\"profileConformance\": [
				\"lite\"
			]
		},
		{
			${_creation_info_property},
			\"type\": \"software_Sbom\",
			\"spdxId\": \"${_spdx_software_sbom_id}\",
			\"rootElement\": [
				\"${_spdx_software_pkg_id}\"
			],
			\"element\": [
\${SBOM_SOFTWARE_PKG_ELEMENT_LIST}
			],
			\"software_sbomType\": [
				\"build\"
			]
		},
		{
			${_creation_info_property},
			\"type\": \"software_Package\",
			\"spdxId\": \"${_spdx_software_pkg_id}\",
			\"name\": \"${_arg_sbom_gen_PACKAGE_NAME}\",
			\"software_packageVersion\": \"${_arg_sbom_gen_PACKAGE_VERSION}\",
			\"software_downloadLocation\": \"${_arg_sbom_gen_PACKAGE_DOWNLOAD}\",
			\"builtTime\": \"\${SBOM_CREATE_DATE}\",
			\"originatedBy\": [
				\"${_sbom_gen_creator_spdxid}\"
			],
			\"software_copyrightText\": \"${_arg_sbom_gen_PACKAGE_COPYRIGHT}\",
			${_sbom_gen_pkg_notes_genex}
			\"comment\": \"Built by CMake ${CMAKE_VERSION} with $<CONFIG> configuration for ${CMAKE_SYSTEM_NAME} (${CMAKE_SYSTEM_PROCESSOR})\"
		},
		{
			${_creation_info_property},
			\"type\": \"software_Package\",
			\"spdxId\": \"${_spdx_software_pkg_compiler_id}\",
			\"name\": \"Compiler-ID-${CMAKE_CXX_COMPILER_ID}\",
			\"software_packageVersion\": \"${CMAKE_CXX_COMPILER_VERSION}\",
			\"summary\": \"The compiler as identified by CMake, running on ${CMAKE_HOST_SYSTEM_NAME} (${CMAKE_HOST_SYSTEM_PROCESSOR})\",
			\"comment\": \"${_spdx_software_pkg_id} is built by compiler ${CMAKE_CXX_COMPILER_ID} (${CMAKE_CXX_COMPILER}) version ${CMAKE_CXX_COMPILER_VERSION}\"
		}
\${SBOM_CONTENT}
	]
}"
	)
endmacro()

function(_sbom_append_sbom_snippet SNIPPET_SCRIPT)
	get_property(_sbom_binary_dir GLOBAL PROPERTY SBOM_BINARY_DIR)
	get_property(_sbom_snippet_dir GLOBAL PROPERTY SBOM_SNIPPET_DIR)
	file(APPEND ${_sbom_binary_dir}/CMakeLists.txt
		"install(SCRIPT \"\${SBOM_SNIPPET_DIR}/${SNIPPET_SCRIPT}\")\n"
	)
endfunction()

function(_sbom_parse_package_supplier pkg_supplier_arg out_supplier_type out_supplier_name out_supplier_email)
	cmake_parse_arguments(_arg_supplier "NOASSERTION" "ORGANIZATION;PERSON;EMAIL" "" ${pkg_supplier_arg})

	if(_arg_supplier_UNPARSED_ARGUMENTS)
		_sbom_log(FATAL_ERROR "Unknown subarguments passed to SUPPLIER: ${_arg_supplier_UNPARSED_ARGUMENTS}")
	endif()

	if(_arg_supplier_NOASSERTION)
		set(${out_supplier_type} "NOASSERTION" PARENT_SCOPE)
		return()
	endif()
	if((NOT DEFINED _arg_supplier_PERSON) AND (NOT DEFINED _arg_supplier_ORGANIZATION))
		_sbom_log(FATAL_ERROR "Missing <NOASSERTION|PERSON|ORGANIZATION> <name> for argument SUPPLIER.")
	elseif(DEFINED _arg_supplier_PERSON AND DEFINED _arg_supplier_ORGANIZATION)
		_sbom_log(FATAL_ERROR "Specify either PERSON or ORGANIZATION, not both.")
	endif()

	if(DEFINED _arg_supplier_PERSON)
		set(${out_supplier_type} "Person:" PARENT_SCOPE)
		set(${out_supplier_name} "${_arg_supplier_PERSON}" PARENT_SCOPE)
	elseif(DEFINED _arg_supplier_ORGANIZATION)
		set(${out_supplier_type} "Organization:" PARENT_SCOPE)
		set(${out_supplier_name} "${_arg_supplier_ORGANIZATION}" PARENT_SCOPE)
	endif()

	if(DEFINED _arg_supplier_EMAIL)
		set(${out_supplier_email} "${_arg_supplier_EMAIL}" PARENT_SCOPE)
	endif()
endfunction()

function(_sbom_parse_license_argument)
	set(optional_one_value_args "CONCLUDED;DECLARED;COMMENT")
	set(required_one_value_args "OUT_CONCLUDED;OUT_DECLARED;OUT_COMMENT")
	cmake_parse_arguments(_arg_license "" "${optional_one_value_args};${required_one_value_args}" "" ${ARGN})

	set(missing_required_args "")
	foreach(req_arg IN LISTS required_one_value_args)
		if(NOT DEFINED _arg_license_${req_arg})
			string(APPEND missing_required_args "${req_arg} ")
		endif()
	endforeach()
	if(NOT "${missing_required_args}" STREQUAL "")
		_sbom_log(FATAL_ERROR "Missing required arguments: ${missing_required_args}")
	endif()

	if(DEFINED _arg_license_CONCLUDED)
		set(${_arg_license_OUT_CONCLUDED} "${_arg_license_CONCLUDED}" PARENT_SCOPE)
	else()
		set(${_arg_license_OUT_CONCLUDED} "NOASSERTION" PARENT_SCOPE)
	endif()

	if(DEFINED _arg_license_DECLARED)
		set(${_arg_license_OUT_DECLARED} "${_arg_license_DECLARED}" PARENT_SCOPE)
	else()
		set(${_arg_license_OUT_DECLARED} "NOASSERTION" PARENT_SCOPE)
	endif()

	if(DEFINED _arg_license_COMMENT)
		set(${_arg_license_OUT_COMMENT} "${_arg_license_COMMENT}" PARENT_SCOPE)
	endif()
endfunction()

function(_sbom_parse_dates pkg_dates_arg out_BUILD out_RELEASE out_VALID_UNTIL)
	set(oneValueArgs BUILT RELEASE VALID_UNTIL)
	cmake_parse_arguments(_arg_dates "" "${oneValueArgs}" "" ${pkg_dates_arg})

	if(_arg_dates_UNPARSED_ARGUMENTS)
		_sbom_log(FATAL_ERROR "Unknown subarguments for DATE: ${_arg_dates_UNPARSED_ARGUMENTS}")
	endif()

	foreach(_date ${oneValueArgs})
		if(DEFINED _arg_dates_${_date})
			string(REGEX MATCH "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$" _arg_dates_${_date} ${_arg_dates_${_date}})
			if(NOT _arg_dates_${_date})
				_sbom_log(FATAL_ERROR "Invalid date format for ${_date}: ${_arg_dates_${_date}}")
			endif()
			set(${out_${_date}} "${_arg_dates_${_date}}" PARENT_SCOPE)
		endif()

	endforeach()
endfunction()

function(_sbom_parse_package_notes pkg_notes_arg out_pkg_SUMMARY out_pkg_DESC out_pkg_COMMENT)
	set(oneValueArgs "SUMMARY;DESC;COMMENT")
	cmake_parse_arguments(_arg_notes "" "${oneValueArgs}" "" ${pkg_notes_arg})
	foreach(_note_type ${oneValueArgs})
		if(DEFINED _arg_notes_${_note_type})
			set(${out_pkg_${_note_type}} "${_arg_notes_${_note_type}}" PARENT_SCOPE)
		endif()
	endforeach()
endfunction()

function(_sbom_parse_package_purpose pkg_purpose_arg out_purpose)
	set(options "APPLICATION;FRAMEWORK;LIBRARY;CONTAINER;OPERATING-SYSTEM;DEVICE;FIRMWARE;SOURCE;ARCHIVE;FILE;INSTALL;OTHER")
	cmake_parse_arguments(_arg "${options}" "" "" ${pkg_purpose_arg})
	if(_arg_UNPARSED_ARGUMENTS)
		_sbom_log(FATAL_ERROR "Unknown keywords for PURPOSE: ${_arg_UNPARSED_ARGUMENTS}")
	endif()

	# only one option is allowed
	set(${out_purpose} "")
	foreach(opt ${options})
		if(_arg_${opt})
			set(${out_purpose} ${opt} PARENT_SCOPE)
			return()
		endif()
	endforeach()
endfunction()

function(_sbom_parse_filetype file_type_arg out_filetype_list)
	# https://spdx.github.io/spdx-spec/v2.3/file-information/#83-file-type-field
	set(valid_entries "SOURCE;BINARY;ARCHIVE;APPLICATION;AUDIO;IMAGE;TEXT;VIDEO;DOCUMENTATION;SPDX;OTHER")
	cmake_parse_arguments(_arg_filetype "${valid_entries}" "" "" ${file_type_arg})
	if(DEFINED _arg_filetype_UNPARSED_ARGUMENTS)
		_sbom_log(FATAL_ERROR "Unkown keywords for FILETYPE: ${_arg_filetype_UNPARSED_ARGUMENTS}")
	endif()

	set(${out_filetype_list} "")
	foreach(entry ${valid_entries})
		if(_arg_filetype_${entry})
			list(APPEND ${out_filetype_list} ${entry})
		endif()
	endforeach()

	set(${out_filetype_list} "${${out_filetype_list}}" PARENT_SCOPE)
endfunction()

function(_sbom_generate_relation_snippet)
	set(one_value_arg "SPDXID" "SPDXID_PATH" "RELATION_OBJECT")
	cmake_parse_arguments(_arg "" "${one_value_arg}" "" ${ARGN})

	foreach(val IN LISTS one_value_arg)
		if(NOT DEFINED _arg_${val})
			_sbom_log(FATAL_ERROR "Missing argument ${val}" )
		endif()
	endforeach()

	_sbom_append_sbom_snippet("${_arg_SPDXID_PATH}.cmake")

	_sbom_inplace_quote_escape( "_arg_RELATION_OBJECT" )

	get_property(_sbom_snippet_dir GLOBAL PROPERTY SBOM_SNIPPET_DIR)
	file(
		GENERATE
		OUTPUT "${_sbom_snippet_dir}/${_arg_SPDXID_PATH}.cmake"
		CONTENT
"
\# This file is generated by _sbom_generate_relation_snippet().

\# Add elements to the document and software package lists
\# Required in finalization step to generate the final SBOM.
list(APPEND SBOM_DOCUMENT_ELEMENT_LIST \"${_arg_SPDXID}\")
list(APPEND SBOM_SOFTWARE_PKG_ELEMENT_LIST \"${_arg_SPDXID}\")

list(APPEND SBOM_RELATION_LIST \"${_arg_RELATION_OBJECT}\")
"
	)

endfunction()

function(_sbom_add_relationship)
	_sbom_serialize_relationship(
		relation_obj_str
		${ARGN}
	)

	_sbom_generate_relation_snippet(
		RELATION_OBJECT "${relation_obj_str}"
		SPDXID          "${SBOM_LAST_SPDXID}"
		SPDXID_PATH     "${SBOM_LAST_SPDXID_PATH}"
	)
	_sbom_propagate_spdxid_to_parentscope()
endfunction()

function(_sbom_generate_license_snippet)
	set(one_value_arg "SPDXID" "SPDXID_PATH" "LICENSE_OBJECT")
	cmake_parse_arguments(_arg "" "${one_value_arg}" "" ${ARGN})

	foreach(val IN LISTS one_value_arg)
		if(NOT DEFINED _arg_${val})
			_sbom_log(FATAL_ERROR "Missing argument ${val}" )
		endif()
	endforeach()

	_sbom_append_sbom_snippet("${_arg_SPDXID_PATH}.cmake")

	_sbom_inplace_quote_escape( "_arg_LICENSE_OBJECT" )

	get_property(_sbom_snippet_dir GLOBAL PROPERTY SBOM_SNIPPET_DIR)
	file(
		GENERATE
		OUTPUT "${_sbom_snippet_dir}/${_arg_SPDXID_PATH}.cmake"
		CONTENT
"
\# This file is generated by _sbom_generate_license_snippet().

\# Add elements to the document and software package lists
\# Required in finalization step to generate the final SBOM.
list(APPEND SBOM_DOCUMENT_ELEMENT_LIST \"${_arg_SPDXID}\")
list(APPEND SBOM_SOFTWARE_PKG_ELEMENT_LIST \"${_arg_SPDXID}\")

list(APPEND SBOM_LICENSE_LIST \"${_arg_LICENSE_OBJECT}\")
"
	)

endfunction()

function(_sbom_register_license OUT_VAR)
	set(one_value_arg "LICENSE_ID")
	cmake_parse_arguments(_arg "" "${one_value_arg}" "" ${ARGN})
	if(NOT DEFINED _arg_LICENSE_ID)
		_sbom_log(FATAL_ERROR "Missing required argument LICENSE_ID")
	endif()

	if("${_arg_LICENSE_ID}" STREQUAL "NONE")
		set(_arg_LICENSE_ID "NoneLicense")
	elseif("${_arg_LICENSE_ID}" STREQUAL "NOASSERTION")
		set(_arg_LICENSE_ID "NoAssertionLicense")
	endif()

	_sbom_serialize_license_entry(
		LICENSE_ID "${_arg_LICENSE_ID}"
		OUT_VAR    license_entry
	)

	get_property(_sbom_license_list GLOBAL PROPERTY SBOM_LICENSE_LIST)
	list(FIND _sbom_license_list "${_arg_LICENSE_ID}" _license_index)
	if(_license_index GREATER -1)
		# this license was already parsed
		# causes cmake error if we generate the same file multiple times
		set("${OUT_VAR}" "FOUND" PARENT_SCOPE)
		_sbom_propagate_spdxid_to_parentscope()
		return()
	endif()

	list(APPEND _sbom_license_list "${_arg_LICENSE_ID}")
	set_property(GLOBAL PROPERTY SBOM_LICENSE_LIST "${_sbom_license_list}")

	set("${OUT_VAR}" "${license_entry}" PARENT_SCOPE)
	_sbom_propagate_spdxid_to_parentscope()
endfunction()

# this function should be called each time we parse a license,
# to create a license entry and add it to the list of licenses that will be included
# in the final SBOM.
# We keep track of the parsed licenses in a global property SBOM_LICENSE_LIST to avoid duplicates.
function(_sbom_add_license)
	_sbom_register_license( license_obj_str "${ARGN}")
	if(license_obj_str STREQUAL "FOUND")
		# this license was already parsed, no need to generate a new snippet
		_sbom_propagate_spdxid_to_parentscope()
		return()
	endif()

	_sbom_generate_license_snippet(
		LICENSE_OBJECT "${license_obj_str}"
		SPDXID         "${SBOM_LAST_SPDXID}"
		SPDXID_PATH    "${SBOM_LAST_SPDXID_PATH}"
	)
	_sbom_propagate_spdxid_to_parentscope()
endfunction()

# Starts SBOM generation. Call sbom_add() and friends afterwards. End with sbom_finalize(). Input
# files allow having variables and generator expressions.
function(sbom_generate)
	set(oneValueArgs
		OUTPUT
		NAMESPACE
		PACKAGE_NAME
		PACKAGE_VERSION
		PACKAGE_FILENAME
		PACKAGE_DOWNLOAD
		PACKAGE_URL
		PACKAGE_LICENSE
		PACKAGE_COPYRIGHT
		PACKAGE_CPE
	)
	set(multiValueArgs CREATOR PACKAGE_NOTES PACKAGE_PURPOSE)
	cmake_parse_arguments(
		_arg_sbom_gen "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN}
	)

	if(_arg_sbom_gen_UNPARSED_ARGUMENTS)
		_sbom_log(FATAL_ERROR "Unknown arguments: ${_arg_sbom_gen_UNPARSED_ARGUMENTS}")
	endif()

	if(NOT DEFINED GIT_VERSION)
		version_extract()
	endif()

	if(NOT DEFINED _arg_sbom_gen_CREATOR)
		_sbom_log(FATAL_ERROR "Missing required argument CREATOR.")
	endif()

	cmake_parse_arguments(_arg_sbom_gen_CREATOR "" "PERSON;ORGANIZATION;EMAIL" "" ${_arg_sbom_gen_CREATOR})
	if(_arg_sbom_gen_CREATOR_UNPARSED_ARGUMENTS)
		_sbom_log(FATAL_ERROR "Unknown subarguments for CREATOR: ${_arg_sbom_gen_CREATOR_UNPARSED_ARGUMENTS}.")
	endif()
	if((NOT DEFINED _arg_sbom_gen_CREATOR_PERSON) AND (NOT DEFINED _arg_sbom_gen_CREATOR_ORGANIZATION))
		_sbom_log(FATAL_ERROR "Missing <PERSON|ORGANIZATION> <name> for argument CREATOR.")
	elseif(DEFINED _arg_sbom_gen_CREATOR_PERSON AND DEFINED _arg_sbom_gen_CREATOR_ORGANIZATION)
		_sbom_log(FATAL_ERROR "Specify either PERSON or ORGANIZATION, not both.")
	endif()

	if(NOT DEFINED _arg_sbom_gen_PACKAGE_LICENSE)
		_sbom_log(FATAL_ERROR "Missing required argument PACKAGE_LICENSE.")
	endif()

	if(NOT DEFINED _arg_sbom_gen_PACKAGE_NAME)
		set(_arg_sbom_gen_PACKAGE_NAME ${PROJECT_NAME})
	endif()

	if(NOT DEFINED _arg_sbom_gen_PACKAGE_FILENAME)
		set(_arg_sbom_gen_PACKAGE_FILENAME "${_arg_sbom_gen_PACKAGE_NAME}-${_arg_sbom_gen_PACKAGE_VERSION}.zip")
	endif()

	if(NOT DEFINED _arg_sbom_gen_PACKAGE_DOWNLOAD)
		# if not defined, the creator made no attempt to specify a download location
		set(_arg_sbom_gen_PACKAGE_DOWNLOAD "NOASSERTION")
	else()
		cmake_parse_arguments(_arg_sbom_gen_PACKAGE_DOWNLOAD "NONE;NOASSERTION" "" "" ${_arg_sbom_gen_PACKAGE_DOWNLOAD})
		if(_arg_sbom_gen_PACKAGE_DOWNLOAD_NONE)
			set(_arg_sbom_gen_PACKAGE_DOWNLOAD "NONE")
		elseif(_arg_sbom_gen_PACKAGE_DOWNLOAD_NOASSERTION)
			set(_arg_sbom_gen_PACKAGE_DOWNLOAD "NOASSERTION")
		endif()
	endif()

	if(NOT DEFINED _arg_sbom_gen_PACKAGE_URL)
		if(NOT DEFINED _arg_sbom_gen_NAMESPACE)
			_sbom_log(FATAL_ERROR "Specify NAMESPACE when PACKAGE_URL is omitted.")
		endif()
	endif()

	string(TIMESTAMP NOW_UTC UTC)

	if(NOT DEFINED _arg_sbom_gen_PACKAGE_COPYRIGHT)
		string(TIMESTAMP NOW_YEAR "%Y" UTC)

		if(DEFINED _arg_sbom_gen_CREATOR_PERSON)
			set(_arg_sbom_gen_PACKAGE_COPYRIGHT "${NOW_YEAR} ${_arg_sbom_gen_CREATOR_PERSON}")
		elseif(DEFINED _arg_sbom_gen_CREATOR_ORGANIZATION)
			set(_arg_sbom_gen_PACKAGE_COPYRIGHT "${NOW_YEAR} ${_arg_sbom_gen_CREATOR_ORGANIZATION}")
		else()
			set(_arg_sbom_gen_PACKAGE_COPYRIGHT "NOASSERTION")
		endif()
	else()
		cmake_parse_arguments(_arg_sbom_gen_PACKAGE_COPYRIGHT "NONE;NOASSERTION" "" "" ${_arg_sbom_gen_PACKAGE_COPYRIGHT})
		if(_arg_sbom_gen_PACKAGE_COPYRIGHT_NONE)
			set(_arg_sbom_gen_PACKAGE_COPYRIGHT "NONE")
		elseif(_arg_sbom_gen_PACKAGE_COPYRIGHT_NOASSERTION)
			set(_arg_sbom_gen_PACKAGE_COPYRIGHT "NOASSERTION")
		endif()
	endif()

	if(DEFINED _arg_sbom_gen_PACKAGE_PURPOSE)
		_sbom_parse_package_purpose("${_arg_sbom_gen_PACKAGE_PURPOSE}" _arg_sbom_gen_PACKAGE_PURPOSE)
	endif()

	if(NOT DEFINED _arg_sbom_gen_OUTPUT)
		string(REGEX REPLACE "[^A-Za-z0-9.]+" "_" _safe_package_name "${_arg_sbom_gen_PACKAGE_NAME}")
		if(DEFINED _arg_sbom_gen_PACKAGE_VERSION)
			set(_pkg_version "${_arg_sbom_gen_PACKAGE_VERSION}")
		else()
			set(_pkg_version "${GIT_VERSION_PATH}")
		endif()
		set(_arg_sbom_gen_OUTPUT "./${CMAKE_INSTALL_DATAROOTDIR}/${_safe_package_name}-sbom-${_pkg_version}.spdx.json")
	endif()
	if(NOT IS_ABSOLUTE "${_arg_sbom_gen_OUTPUT}")
		set(_arg_sbom_gen_OUTPUT "\${CMAKE_INSTALL_PREFIX}/${_arg_sbom_gen_OUTPUT}")
	endif()

	if(NOT DEFINED _arg_sbom_gen_PACKAGE_VERSION)
		set(_arg_sbom_gen_PACKAGE_VERSION ${GIT_VERSION})
	endif()

	if(NOT DEFINED _arg_sbom_gen_NAMESPACE)
		if((NOT DEFINED _arg_sbom_gen_PACKAGE_URL) OR (_arg_sbom_gen_PACKAGE_URL STREQUAL "NONE") OR (_arg_sbom_gen_PACKAGE_URL STREQUAL "NOASSERTION"))
			_sbom_log(FATAL_ERROR "Specifiy PACKAGE_URL <url> when NAMESPACE is omitted.")
		endif()
		set(_arg_sbom_gen_NAMESPACE "${_arg_sbom_gen_PACKAGE_URL}/spdxdocs/${_arg_sbom_gen_PACKAGE_NAME}-${_arg_sbom_gen_PACKAGE_VERSION}")
	endif()

	# remove special characters from package name and replace with -
	string(REGEX REPLACE "[^A-Za-z0-9.]+" "-" _arg_sbom_gen_PACKAGE_NAME "${_arg_sbom_gen_PACKAGE_NAME}")
	# strip - from end of string
	string(REGEX REPLACE "-+$" "" _arg_sbom_gen_PACKAGE_NAME "${_arg_sbom_gen_PACKAGE_NAME}")

	set(SBOM_FILENAME "${_arg_sbom_gen_OUTPUT}" PARENT_SCOPE)
	set(SBOM_BINARY_DIR "${PROJECT_BINARY_DIR}/__sbom")
	set(SBOM_SNIPPET_DIR "${SBOM_BINARY_DIR}/sbom-src/$<CONFIG>")
	set_property(GLOBAL PROPERTY SBOM_FILENAME "${_arg_sbom_gen_OUTPUT}")
	set_property(GLOBAL PROPERTY SBOM_BINARY_DIR "${SBOM_BINARY_DIR}")
	set_property(GLOBAL PROPERTY SBOM_SNIPPET_DIR "${SBOM_SNIPPET_DIR}")
	set_property(GLOBAL PROPERTY sbom_package_spdxid "${_arg_sbom_gen_PACKAGE_NAME}")
	set_property(GLOBAL PROPERTY sbom_package_license "${_arg_sbom_gen_PACKAGE_LICENSE}")
	set_property(GLOBAL PROPERTY sbom_package_copyright "${_arg_sbom_gen_PACKAGE_COPYRIGHT}")
	set_property(GLOBAL PROPERTY sbom_spdxids 0)

	#REFAC(>=3.20): Use cmake_path() instead of get_filename_component().
	if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.20)
		cmake_path(GET _arg_sbom_gen_OUTPUT FILENAME doc_name)
	else()
		get_filename_component(doc_name "${_arg_sbom_gen_OUTPUT}" NAME_WLE)
	endif()

	file(MAKE_DIRECTORY ${SBOM_BINARY_DIR})

	# collect all sbom install instructions in a separate file.
	# To keep things debuggable, we don't want to mix the sbom instructions with the rest of the install instructions.
	# Will be added via add_subdirectory() to the main project.
	file(WRITE ${SBOM_BINARY_DIR}/CMakeLists.txt "set(SBOM_SNIPPET_DIR \"${SBOM_SNIPPET_DIR}\")\n")

	set(_sbom_intermediate_file "$<CONFIG>/sbom.json.in")
	set(_sbom_document_template "SPDXRef-DOCUMENT.json.in")

	_sbom_append_sbom_snippet("setup.cmake")

	_sbom_generate_spdx3_template()

	file(GENERATE
		OUTPUT ${SBOM_SNIPPET_DIR}/setup.cmake
		CONTENT "
macro(_sbom_log log_level log_message)
	message(\${log_level} \"SBOM-Builder: \${log_message}\")
endmacro()

macro(_sbom_cmakelist_to_printable_list var)
	list(JOIN \"\${var}\" \",\\n\" \"\${var}\")
endmacro()

set(SBOM_EXPORT_FILENAME \"${_arg_sbom_gen_OUTPUT}\")
set(SBOM_BINARY_DIR \"${SBOM_BINARY_DIR}\")
set(SBOM_SNIPPET_DIR \"${SBOM_SNIPPET_DIR}\")
set(SBOM_DOCUMENT_TEMPLATE \"${_sbom_document_template}\")
set(SBOM_EXT_DOCS)
_sbom_log(STATUS \"Installing \${SBOM_EXPORT_FILENAME}\")

# this file is used to collect all SPDX entries before final export
set(SBOM_INTERMEDIATE_FILE \"\${SBOM_BINARY_DIR}/sbom-build/${_sbom_intermediate_file}\")
file(WRITE \${SBOM_INTERMEDIATE_FILE} \"\")

file(READ \"\${SBOM_SNIPPET_DIR}/\${SBOM_DOCUMENT_TEMPLATE}\" _f_contents)
file(APPEND \"\${SBOM_INTERMEDIATE_FILE}\" \"\${_f_contents}\")

set(SBOM_VERIFICATION_CODES \"\")

\# contains the list of all document elements added
set(SBOM_DOCUMENT_ELEMENT_LIST \"${_sbom_doc_elem_list}\")
set(SBOM_SOFTWARE_PKG_ELEMENT_LIST \"${_sbom_software_pkg_elem_list}\")

\# contains the list of all package dependencies added via sbom_add_package
set(SBOM_PACKAGE_LIST \"\")

\# contains the list of all files that make up the package this cmakeproject produces
\# populated via sbom_add_file, sbom_add_directory, and sbom_add_target
set(SBOM_PACKAGE_CONTENT_LIST \"\")

\# contains the list of all licences mentioned in the SBOM
set(SBOM_LICENSE_LIST \"\")

\# contains the list of all relationships declared in the SBOM
set(SBOM_RELATION_LIST \"\")
"
	)
endfunction()

# Finalize the generated SBOM. Call after sbom_generate() and other SBOM populating commands.
function(sbom_finalize)
	get_property(_sbom GLOBAL PROPERTY SBOM_FILENAME)
	get_property(_sbom_binary_dir GLOBAL PROPERTY SBOM_BINARY_DIR)
	get_property(_sbom_snippet_dir GLOBAL PROPERTY SBOM_SNIPPET_DIR)
	get_property(_sbom_project GLOBAL PROPERTY sbom_package_spdxid)

	if("${_sbom_project}" STREQUAL "")
		_sbom_log(FATAL_ERROR "Call sbom_generate() first")
	endif()

	_sbom_append_sbom_snippet("finalize.cmake")
	file(GENERATE
		OUTPUT ${_sbom_snippet_dir}/finalize.cmake
		CONTENT
"
\# This file is generated at configure time with the sbom_finalize command,
\# and is used to finalize the SBOM generation during installation.

_sbom_log(STATUS \"Finalizing \${SBOM_EXPORT_FILENAME}\")

list(SORT SBOM_VERIFICATION_CODES)
string(REPLACE \";\" \"\" SBOM_VERIFICATION_CODES \"\${SBOM_VERIFICATION_CODES}\")
string(TIMESTAMP SBOM_CREATE_DATE UTC)
if(NOT \"\${SBOM_EXT_DOCS}\" STREQUAL \"\")
	string(REPLACE \";\" \"\\n\" SBOM_EXT_DOCS \"\${SBOM_EXT_DOCS}\")
	string(APPEND SBOM_EXT_DOCS \"\\n\")
endif()
file(WRITE \"\${SBOM_BINARY_DIR}/sbom-build/$<CONFIG>/verification.txt\" \"\${SBOM_VERIFICATION_CODES}\")
file(SHA1 \"\${SBOM_BINARY_DIR}/sbom-build/$<CONFIG>/verification.txt\" SBOM_VERIFICATION_CODE)

\#Transform cmakelists into valid Json array
\# 1. Surround each element with double quotes.
list(TRANSFORM SBOM_DOCUMENT_ELEMENT_LIST APPEND \"\\\"\")
list(TRANSFORM SBOM_DOCUMENT_ELEMENT_LIST PREPEND \"\\\"\")
list(TRANSFORM SBOM_SOFTWARE_PKG_ELEMENT_LIST APPEND \"\\\"\")
list(TRANSFORM SBOM_SOFTWARE_PKG_ELEMENT_LIST PREPEND \"\\\"\")

\# 2. Join list elements with comma and newline
_sbom_cmakelist_to_printable_list(\"SBOM_DOCUMENT_ELEMENT_LIST\")
_sbom_cmakelist_to_printable_list(\"SBOM_SOFTWARE_PKG_ELEMENT_LIST\")

_sbom_cmakelist_to_printable_list(\"SBOM_PACKAGE_LIST\")
_sbom_cmakelist_to_printable_list(\"SBOM_PACKAGE_CONTENT_LIST\")
_sbom_cmakelist_to_printable_list(\"SBOM_LICENSE_LIST\")
_sbom_cmakelist_to_printable_list(\"SBOM_RELATION_LIST\")

set(SBOM_CONTENT \"\")

set(CONTENT_LIST \"\${SBOM_PACKAGE_LIST}\" \"\${SBOM_PACKAGE_CONTENT_LIST}\" \"\${SBOM_LICENSE_LIST}\" \"\${SBOM_RELATION_LIST}\")

foreach(var IN LISTS CONTENT_LIST)
	if(NOT \"\${var}\" STREQUAL \"\")
		string(APPEND SBOM_CONTENT \",\\n\${var}\")
	endif()
endforeach()

configure_file(\"\${SBOM_INTERMEDIATE_FILE}\" \"\${SBOM_EXPORT_FILENAME}\")
"
	)

	# using a build dir will generate a seperate cmake_install.cmake file
	# which helps with debugging
	add_subdirectory(${_sbom_binary_dir} ${_sbom_binary_dir}/sbom-build )

	# Mark finalized.
	set(SBOM_FILENAME "${_sbom}" PARENT_SCOPE)
	set_property(GLOBAL PROPERTY sbom_package_spdxid "")
endfunction()

macro(_sbom_builder_is_setup)
	get_property(_sbom_project GLOBAL PROPERTY sbom_package_spdxid)

	if("${_sbom_project}" STREQUAL "")
		_sbom_log(FATAL_ERROR "Call sbom_generate() first")
	endif()
endmacro()

function(_sbom_add_pkg_content PATH)
	set(options OPTIONAL FILE DIR)
	set(oneValueArgs COPYRIGHT
					 COMMENT
					 NOTICE
					 CONTRIBUTORS
					 ATTRIBUTION
					 )
	set(multiValueArgs FILETYPE CHECKSUM LICENSE RELATIONSHIP)
	cmake_parse_arguments(_arg_add_pkg_content "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	_sbom_builder_is_setup()

	if(_arg_add_pkg_content_UNPARSED_ARGUMENTS)
		_sbom_log(FATAL_ERROR "Unknown arguments: ${_arg_add_pkg_content_UNPARSED_ARGUMENTS}")
	endif()

	_sbom_gen_spdxid(
		VARIABLE "${PATH}"
		SCOPE "File"
	)

	set(_properties "")

	set(filekind "file")
	# let's keep compatibility with old behavior of sbom_add_file and sbom_add_directory

	#if(_arg_add_pkg_content_DIR)
	#	set(filekind "directory")
	#endif()

	set(_hash_algo "SHA1;SHA256") # SHA1 is always required by SPDX, SHA256 required by TR-03183
	if(DEFINED _arg_add_pkg_content_CHECKSUM)
		set(_supported_algorithms "MD5;SHA224;SHA384;SHA512;SHA3-256;SHA3-384;SHA3-512")
		foreach(_checksum ${_arg_add_pkg_content_CHECKSUM})
			if("${_checksum}" IN_LIST _supported_algorithms)
				list(APPEND _hash_algo "${_checksum}")
			else()
				_sbom_log(FATAL_ERROR "Unsupported checksum algorithm: ${_checksum}")
			endif()
		endforeach()
	endif()

	if(NOT DEFINED _arg_add_pkg_content_COPYRIGHT)
		get_property(_sbom_package_copyright GLOBAL PROPERTY sbom_package_copyright)
		set(_arg_add_pkg_content_COPYRIGHT "${_sbom_package_copyright}")
	endif()

	list(APPEND _properties
		"\"creationInfo\": \"_:creationInfo\""
		"\"type\": \"software_File\""
		"\"software_fileKind\": \"${filekind}\""
		"\"software_copyrightText\": \"${_arg_add_pkg_content_COPYRIGHT}\""
	)

	if(DEFINED _arg_add_pkg_content_COMMENT)
		list(APPEND _properties "\"comment\": \"${_arg_add_pkg_content_COMMENT}\"")
	endif()

	_sbom_inplace_quote_escape( "_properties")

	get_property(_sbom_snippet_dir GLOBAL PROPERTY SBOM_SNIPPET_DIR)

	_sbom_append_sbom_snippet("${SBOM_LAST_SPDXID_PATH}.cmake")
	file(
		GENERATE
		OUTPUT ${_sbom_snippet_dir}/${SBOM_LAST_SPDXID_PATH}.cmake
		CONTENT
		"
cmake_policy(SET CMP0011 NEW)
cmake_policy(SET CMP0012 NEW)

set(properties \"${_properties}\")

set(ADDING_DIR ${_arg_add_pkg_content_DIR})

set(_files \"\")
if(ADDING_DIR)
	file(GLOB_RECURSE _files
		LIST_DIRECTORIES false RELATIVE \"\${CMAKE_INSTALL_PREFIX}\"
		\"\${CMAKE_INSTALL_PREFIX}/${PATH}/*\"
	)
else()
	set(_files \"${PATH}\")
endif()

set(relationships \"${_arg_add_pkg_content_RELATIONSHIP}\")

if((NOT ADDING_DIR) AND (NOT EXISTS \${CMAKE_INSTALL_PREFIX}/${PATH}))
	if(NOT ${_arg_add_pkg_content_OPTIONAL})
		_sbom_log(FATAL_ERROR \"Cannot find ./${PATH}\")
	endif()
endif()

foreach(_f IN LISTS _files)
	set(file_entry \"\${properties}\")

	set(_id \"${SBOM_LAST_SPDXID}\")
	if(ADDING_DIR)
		set(_id \"${SBOM_LAST_SPDXID}/\${_f}\")
	endif()

	list(PREPEND file_entry
		\"\\\"name\\\": \\\"\${_f}\\\"\"
		\"\\\"spdxId\\\": \\\"\${_id}\\\"\"
)

	set(_relations \"\")
	foreach(_rel IN LISTS relationships)
		string(REPLACE \"@SBOM_LAST_SPDXID@\" \"\${_id}\" _tmp \"\${_rel}\")
		string(APPEND _relations \"\\nRelationship: \${_tmp}\")
	endforeach()

	set(verifiedusing \"\")
	foreach(_algo ${_hash_algo})
		set(hash_properties \"\")
		file(\${_algo} \${CMAKE_INSTALL_PREFIX}/\${_f} _hash)
		if(\"\${_algo}\" STREQUAL \"SHA1\")
			list(APPEND SBOM_VERIFICATION_CODES \${_hash})
		endif()
		string(TOLOWER \"\${_algo}\" _algo)
		list(APPEND hash_properties
			\"\\t\\t\\\"type\\\": \\\"Hash\\\"\"
			\"\\t\\t\\\"algorithm\\\": \\\"\${_algo}\\\"\"
			\"\\t\\t\\\"hashValue\\\": \\\"\${_hash}\\\"\"
		)
		_sbom_cmakelist_to_printable_list(\"hash_properties\")
		set(hash_properties \"\\t{\\n\${hash_properties}\\n\\t}\")
		list(APPEND verifiedusing \${hash_properties})
	endforeach()

	_sbom_cmakelist_to_printable_list(\"verifiedusing\")
	set(verifiedusing \"\\\"verifiedUsing\\\": [\\n\${verifiedusing}\\n]\")
	list(APPEND file_entry \${verifiedusing})

	list(APPEND SBOM_DOCUMENT_ELEMENT_LIST \"\${_id}\")
	list(APPEND SBOM_SOFTWARE_PKG_ELEMENT_LIST \"\${_id}\")

	_sbom_cmakelist_to_printable_list(\"file_entry\")

	set( file_entry
\"{
\${file_entry}
}\"
	)

	list(APPEND SBOM_PACKAGE_CONTENT_LIST \"\${file_entry}\")
endforeach()
"
	)

	_sbom_propagate_spdxid_to_parentscope()
endfunction()

function(sbom_add_directory DIR_PATH)
	_sbom_add_pkg_content("${DIR_PATH}" "DIR" "${ARGN}")
	_sbom_propagate_spdxid_to_parentscope()
endfunction()

function(sbom_add_file FILENAME)
	_sbom_add_pkg_content("${FILENAME}" "${ARGN}")
	_sbom_propagate_spdxid_to_parentscope()
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
		_sbom_log(FATAL_ERROR "Unsupported target type ${_type}")
	endif()

	_sbom_propagate_spdxid_to_parentscope()
endfunction()

# Append a package (without files) to the SBOM. Use this after calling sbom_generate().
function(sbom_add_package NAME)
	set(oneValueArgs
		VERSION
		FILENAME
		COPYRIGHT
	)
	set(multiValueArgs
		SUPPLIER
		ORIGINATOR
		CHECKSUM
		RELATIONSHIP
		EXTREF
		LICENSE
		PURPOSE
	)
	cmake_parse_arguments(
		_arg_add_pkg "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN}
	)

	_sbom_builder_is_setup()

	_sbom_gen_spdxid(
		VARIABLE "${NAME}"
		SCOPE "Package"
	)
	set(_arg_add_pkg_SPDXID ${SBOM_LAST_SPDXID})
	set(_arg_add_pkg_SPDXID_PATH ${SBOM_LAST_SPDXID_PATH})

	_sbom_propagate_spdxid_to_parentscope()

	if(NOT DEFINED _arg_add_pkg_LICENSE)
		_sbom_log(FATAL_ERROR "Missing LICENSE argument for package ${NAME}.")
	endif()
	_sbom_parse_license_argument(
		"CONCLUDED;${_arg_add_pkg_LICENSE}"
		OUT_CONCLUDED _arg_add_pkg_LICENSE_CONCLUDED
		OUT_DECLARED _arg_add_pkg_LICENSE_DECLARED
		OUT_COMMENT _arg_add_pkg_LICENSE_COMMENT
	)
	set(comment "")
	if(DEFINED _arg_add_pkg_LICENSE_COMMENT)
		set(comment "${_arg_add_pkg_LICENSE_COMMENT}")
	endif()
	# TODO comments on declared and concluded licenses cannot be distinguished
	_sbom_add_license(LICENSE_ID "${_arg_add_pkg_LICENSE_CONCLUDED}")
	_sbom_add_relationship(
		RELTYPE "hasConcludedLicense"
		FROM_ID "${_arg_add_pkg_SPDXID}"
		TO_ID   "${SBOM_LAST_SPDXID}"
		FROM    "${_arg_add_pkg_SPDXID_PATH}"
		TO      "${SBOM_LAST_SPDXID_PATH}"
		COMMENT "${comment}"
	)

	_sbom_add_license(LICENSE_ID "${_arg_add_pkg_LICENSE_DECLARED}")
	_sbom_add_relationship(
		RELTYPE "hasDeclaredLicense"
		FROM_ID "${_arg_add_pkg_SPDXID}"
		TO_ID   "${SBOM_LAST_SPDXID}"
		FROM    "${_arg_add_pkg_SPDXID_PATH}"
		TO      "${SBOM_LAST_SPDXID_PATH}"
	)

	if(NOT DEFINED _arg_add_pkg_VERSION)
		_sbom_log(FATAL_ERROR "Missing VERSION argument for package ${NAME}.")
	endif()

	if(NOT DEFINED _arg_add_pkg_SUPPLIER)
		_sbom_log(FATAL_ERROR "Missing SUPPLIER argument for package ${NAME}.")
	endif()

	_sbom_serialize_creator(
		"${_arg_add_pkg_SUPPLIER}"
		"creation_info"
		_sbom_add_pkg_supplier
		_sbom_add_pkg_supplier_spdxid
	)

	if(DEFINED _arg_add_pkg_FILENAME)
		_sbom_log(WARNING "The FILENAME argument is not yet supported for SPDX3.")
	endif()

	if(DEFINED _arg_add_pkg_ORIGINATOR)
		_sbom_serialize_creator(
			"${_arg_add_pkg_ORIGINATOR}"
			"creation_info"
			_sbom_add_pkg_originator
			_sbom_add_pkg_originator_spdxid
		)
	endif()

	if(NOT DEFINED _arg_add_pkg_COPYRIGHT)
		set(_arg_add_pkg_COPYRIGHT "NOASSERTION")
	endif()

	# TODO: add CHECKSUM to serialization; didn't find how to add in SPDX3 spec
	# TODO: add EXTERNAL_REFERENCES to serialization: These function completely different from SPDX2.x
	# TODO: add PURPOSE to serialization: Uses different format and slightly different keywords in SPDX3
	# TODO: Look at relationship and how it can be serialized for spdx3, this one might require breaking changes

	get_property(_sbom_snippet_dir GLOBAL PROPERTY SBOM_SNIPPET_DIR)

	_sbom_serialize_package( "${NAME}"
		"${_arg_add_pkg_SPDXID}"
		"${_arg_add_pkg_VERSION}"
		"${_arg_add_pkg_COPYRIGHT}"
		"_sbom_add_pkg_package"
		"${_arg_add_pkg_UNPARSED_ARGUMENTS}"
	)

	_sbom_inplace_quote_escape( "_sbom_add_pkg_package" )

	_sbom_append_sbom_snippet("${_arg_add_pkg_SPDXID_PATH}.cmake")
	file(
		GENERATE
		OUTPUT "${_sbom_snippet_dir}/${_arg_add_pkg_SPDXID_PATH}.cmake"
		CONTENT
"
\# This file is generated by sbom_add_package() for package ${NAME}.

\# Add elements to the document and software package lists
\# Required in finalization step to generate the final SBOM.
list(APPEND SBOM_DOCUMENT_ELEMENT_LIST \"${_arg_add_pkg_SPDXID}\")
list(APPEND SBOM_SOFTWARE_PKG_ELEMENT_LIST \"${_arg_add_pkg_SPDXID}\")

list(APPEND SBOM_PACKAGE_LIST \"${_sbom_add_pkg_package}\")
"
	)
endfunction()

# Add a reference to a package in an external file.
function(sbom_add_external ID PATH)
	set(oneValueArgs RENAME SPDXID)
	set(multiValueArgs RELATIONSHIP)
	cmake_parse_arguments(
		_arg_add_extern "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN}
	)

	_sbom_builder_is_setup()

	if(_arg_add_extern_UNPARSED_ARGUMENTS)
		_sbom_log(FATAL_ERROR "Unknown arguments: ${_arg_add_extern_UNPARSED_ARGUMENTS}")
	endif()

	if("${_arg_add_extern_SPDXID}" STREQUAL "")
		get_property(_spdxids GLOBAL PROPERTY sbom_spdxids)
		set(_arg_add_extern_SPDXID "DocumentRef-${_spdxids}")
		math(EXPR _spdxids "${_spdxids} + 1")
		set_property(GLOBAL PROPERTY sbom_spdxids "${_spdxids}")
	endif()

	if(NOT "${_arg_add_extern_SPDXID}" MATCHES "^DocumentRef-[-a-zA-Z0-9]+$")
		_sbom_log(FATAL_ERROR "Invalid DocumentRef \"${_arg_add_extern_SPDXID}\"")
	endif()

	set(SBOM_LAST_SPDXID "${_arg_add_extern_SPDXID}")
	set(SBOM_LAST_SPDXID "${_arg_add_extern_SPDXID}" PARENT_SCOPE)

	get_property(_sbom GLOBAL PROPERTY SBOM_FILENAME)
	get_property(_sbom_project GLOBAL PROPERTY sbom_package_spdxid)

	get_filename_component(sbom_dir "${_sbom}" DIRECTORY)

	set(_fields)
	if(NOT DEFINED _arg_add_extern_RELATIONSHIP)
		set(_arg_add_extern_RELATIONSHIP "SPDXRef-${_sbom_project} DEPENDS_ON ${SBOM_LAST_SPDXID}:${ID}")
		string(APPEND _fields "\nRelationship: ${_arg_add_extern_RELATIONSHIP}")
	else()
		foreach(_relation IN LISTS _arg_add_extern_RELATIONSHIP)
			string(REPLACE "@SBOM_LAST_SPDXID@" "${SBOM_LAST_SPDXID}" _tmp "${_relation}")
			string(APPEND _fields "\nRelationship: ${_tmp}")
		endforeach()
	endif()

	get_property(_sbom_snippet_dir GLOBAL PROPERTY SBOM_SNIPPET_DIR)

	_sbom_append_sbom_snippet("${SBOM_LAST_SPDXID}.cmake")
	file(
		GENERATE
		OUTPUT ${_sbom_snippet_dir}/${SBOM_LAST_SPDXID}.cmake
		CONTENT
"file(SHA1 \"${PATH}\" ext_sha1)
file(READ \"${PATH}\" ext_content)
if(\"${_arg_add_extern_RENAME}\" STREQUAL \"\")
	get_filename_component(ext_name \"${PATH}\" NAME)
	file(WRITE \"${sbom_dir}/\${ext_name}\" \"\${ext_content}\")
else()
	file(WRITE \"${sbom_dir}/${_arg_add_extern_RENAME}\" \"\${ext_content}\")
endif()

if(NOT \"\${ext_content}\" MATCHES \"[\\r\\n]DocumentNamespace:\")
	_sbom_log(FATAL_ERROR \"Missing DocumentNamespace in ${PATH}\")
endif()

string(REGEX REPLACE
	\"^.*[\\r\\n]DocumentNamespace:[ \\t]*([^#\\r\\n]*).*$\" \"\\\\1\" ext_ns \"\${ext_content}\")

list(APPEND SBOM_EXT_DOCS \"ExternalDocumentRef: ${_arg_add_extern_SPDXID} \${ext_ns} SHA1: \${ext_sha1}\")

file(APPEND \"\${SBOM_INTERMEDIATE_FILE}\" \"${_fields}\")
"
	)
endfunction()

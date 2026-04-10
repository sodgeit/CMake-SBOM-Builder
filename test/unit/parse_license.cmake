cmake_minimum_required(VERSION 3.16 FATAL_ERROR)

include(sbom)
include(testing)

set(expected_concluded "MIT")
set(expected_declared "NONE")
set(expected_comment "File has no license, but is part of a project with an overall MIT license")

# Test parsing from a stringified list of arguments, as well as directly from arguments.
# Both should yield the same results.
set(test_string "CONCLUDED;${expected_concluded};DECLARED;${expected_declared};COMMENT;${expected_comment}")
_sbom_parse_license_argument(
	"${test_string}"
	OUT_CONCLUDED out_license_concluded
	OUT_DECLARED out_license_declared
	OUT_COMMENT out_license_comment
)

ASSERT_DEFINED(out_license_concluded)
ASSERT_EQUAL("${out_license_concluded}" "${expected_concluded}")
ASSERT_DEFINED(out_license_declared)
ASSERT_EQUAL("${out_license_declared}" "${expected_declared}")
ASSERT_DEFINED(out_license_comment)
ASSERT_EQUAL("${out_license_comment}" "${expected_comment}")

unset(out_license_concluded)
unset(out_license_declared)
unset(out_license_comment)

_sbom_parse_license_argument(
	CONCLUDED ${expected_concluded}
	DECLARED ${expected_declared}
	COMMENT ${expected_comment}
	OUT_CONCLUDED out_license_concluded
	OUT_DECLARED out_license_declared
	OUT_COMMENT out_license_comment
)

ASSERT_DEFINED(out_license_concluded)
ASSERT_EQUAL("${out_license_concluded}" "${expected_concluded}")
ASSERT_DEFINED(out_license_declared)
ASSERT_EQUAL("${out_license_declared}" "${expected_declared}")
ASSERT_DEFINED(out_license_comment)
ASSERT_EQUAL("${out_license_comment}" "${expected_comment}")

unset(out_license_concluded)
unset(out_license_declared)
unset(out_license_comment)

# - Default for CONCLUDED should be NOASSERTION if not provided
# - Default for DECLARED should be NOASSERTION if not provided
_sbom_parse_license_argument(
	#CONCLUDED ${expected_concluded}
	#DECLARED ${expected_declared}
	COMMENT ${expected_comment}
	OUT_CONCLUDED out_license_concluded
	OUT_DECLARED out_license_declared
	OUT_COMMENT out_license_comment
)

ASSERT_DEFINED(out_license_concluded)
ASSERT_EQUAL("${out_license_concluded}" "NOASSERTION")
ASSERT_DEFINED(out_license_declared)
ASSERT_EQUAL("${out_license_declared}" "NOASSERTION")

unset(out_license_concluded)
unset(out_license_declared)
unset(out_license_comment)

# - If COMMENT is not provided, OUT_COMMENT should not be set
_sbom_parse_license_argument(
	CONCLUDED ${expected_concluded}
	DECLARED ${expected_declared}
	#COMMENT ${expected_comment}
	OUT_CONCLUDED out_license_concluded
	OUT_DECLARED out_license_declared
	OUT_COMMENT out_license_comment
)

ASSERT_NOT_DEFINED(out_license_comment)

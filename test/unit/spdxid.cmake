cmake_minimum_required(VERSION 3.16 FATAL_ERROR)

include(sbom)
include(testing)

_sbom_gen_spdxid(
	VARIABLE "MIT"
	SCOPE "License"
)

ASSERT_DEFINED(SBOM_LAST_SPDXID)
ASSERT_DEFINED(SBOM_LAST_SPDXID_PATH)

ASSERT_EQUAL("${SBOM_LAST_SPDXID}" "spdx://sbom/v1/License/MIT")
ASSERT_EQUAL("${SBOM_LAST_SPDXID_PATH}" "License/MIT")

unset(SBOM_LAST_SPDXID)
unset(SBOM_LAST_SPDXID_PATH)

_sbom_gen_spdxid(SCOPE "License")

ASSERT_DEFINED(SBOM_LAST_SPDXID)
ASSERT_DEFINED(SBOM_LAST_SPDXID_PATH)

ASSERT_EQUAL("${SBOM_LAST_SPDXID}" "spdx://sbom/v1/License")
ASSERT_EQUAL("${SBOM_LAST_SPDXID_PATH}" "License")

unset(SBOM_LAST_SPDXID)
unset(SBOM_LAST_SPDXID_PATH)

_sbom_gen_spdxid(
	VARIABLE "replace:chars/which&may)break%when§used!as?Path"
	SCOPE "License"
)

ASSERT_DEFINED(SBOM_LAST_SPDXID)
ASSERT_DEFINED(SBOM_LAST_SPDXID_PATH)

ASSERT_EQUAL("${SBOM_LAST_SPDXID}" "spdx://sbom/v1/License/replace-chars-which-may-break-when-used-as-Path")
ASSERT_EQUAL("${SBOM_LAST_SPDXID_PATH}" "License/replace-chars-which-may-break-when-used-as-Path")

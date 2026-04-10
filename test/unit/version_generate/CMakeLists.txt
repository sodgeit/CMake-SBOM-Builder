cmake_minimum_required(VERSION 3.16 FATAL_ERROR)

project(${TEST_NAME})

include(sbom)
include(testing)

version_generate()

ASSERT_DEFINED(VERSION_INC_DIR)
ASSERT_DEFINED(VERSION_DOC_DIR)
ASSERT_DEFINED(VERSION_SCRIPT_DIR)

ASSERT_TARGET(${TEST_NAME}-version)


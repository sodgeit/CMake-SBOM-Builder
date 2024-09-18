# Full Function Signature

- [sbom\_generate](#sbom_generate)
- [sbom\_add\_\[file|directory|target\]](#sbom_add_filedirectorytarget)
- [sbom\_add\_package](#sbom_add_package)


## sbom_generate

```cmake
sbom_generate(
	CREATOR <PERSON|ORGANIZATION> <name> [EMAIL <email>]
	PACKAGE_LICENSE <SPDX License Expression>
	[PACKAGE_NAME <package_name>]
	[PACKAGE_VERSION <version_string>]
	[PACKAGE_FILENAME <filename>]
	[PACKAGE_DOWNLOAD <NOASSERTION|NONE|<url>>]
	[PACKAGE_URL <NOASSERTION|NONE|<url>>]
	[PACKAGE_COPYRIGHT <NOASSERTION|NONE|<copyright_text>>]
	[PACKAGE_NOTES [SUMMARY <summary_text>]
				   [DESCRIPTION <description_text>] ]
	[PACKAGE_PURPOSE <APPLICATION|FRAMEWORK|LIBRARY|
					  CONTAINER|OPERATING-SYSTEM|DEVICE|
					  FIRMWARE|SOURCE|ARCHIVE|
					  FILE|INSTALL|OTHER>...]
	[OUTPUT <filename>]
	[NAMESPACE <URI>]
)
```

- `CREATOR`: Supplier of the Package and Creator of the sbom
  - See [SPDX clause 6.8](https://spdx.github.io/spdx-spec/v2.3/document-creation-information/#68-creator-field) & [SPDX clause 7.5](https://spdx.github.io/spdx-spec/v2.3/package-information/#75-package-supplier-field) for more information.
  - One of the `<PERSON|ORGANIZATION>` keywords must be provided.
  - `EMAIL` is optional.
  - Usage:
    - `sbom_generate(... CREATOR ORGANIZATION "My Company" EMAIL "contact@company.com" ...)`
    - `sbom_generate(... CREATOR PERSON "Firstname Lastname" ...)`
  - ***Note:***
    - The SPDX specification differentiates between the creator of the SBOM and the supplier of the package it describes. However, this project treats them as the same entity. This is based on the assumption that whoever uses this project, uses it to generate a SBOM for a package they are building. In this case, the creator of the SBOM and the supplier of the package are the same entity.
    - The SBOM-Builder is always added as an additional creator of the SBOM.
- `PACKAGE_LICENSE`: License of the package described in the SBOM.
  - Requires a valid SPDX license expression. See [SPDX License Expressions](https://spdx.github.io/spdx-spec/v2.3/SPDX-license-expressions/) for more information.
  - ***Note:***
    - The SPDX specification differentiates between a declared and a concluded license. This argument sets both to the same value.
    - We assume that the creator of the SBOM is the supplier of the package, there should be no difference between the declared and concluded license.
    - See [SPDX clause 7.13](https://spdx.github.io/spdx-spec/v2.3/package-information/#713-concluded-license-field) & [SPDX clause 7.15](https://spdx.github.io/spdx-spec/v2.3/package-information/#715-declared-license-field) for more information.
    - The federal guidelines mentioned above do not explicitly allow the use of `NOASSERTION` or `NONE`. We therefore do not provide these options.
- `PACKAGE_NAME`: Package name.
  - Defaults to `${PROJECT_NAME}`.
  - See [SPDX clause 7.1](https://spdx.github.io/spdx-spec/v2.3/package-information/#71-package-name-field) for more information.
- `PACKAGE_VERSION`: Package version field
  - Defaults to `${GIT_VERSION}`. (see [Version Extraction](#version-extraction))
  - See [SPDX clause 7.3](https://spdx.github.io/spdx-spec/v2.3/package-information/#73-package-version-field) for more information.
- `PACKAGE_FILENAME`: Filename of the distributed package.
  - Defaults to `${PACKAGE_NAME}-${PACKAGE_VERSION}.zip`.
  - See [SPDX clause 7.4](https://spdx.github.io/spdx-spec/v2.3/package-information/#74-package-file-name-field) for more information.
- `PACKAGE_DOWNLOAD`: Download location of the distributed package.
  - Either `NOASSERTION`, `NONE`, or a `<url>`.
  - Defaults to `NOASSERTION`.
  - See [SPDX clause 7.7](https://spdx.github.io/spdx-spec/v2.3/package-information/#77-package-download-location-field) for more information.
- `PACKAGE_URL`: Package home page.
  - `NONE` or `NOASSERTION` require that `NAMESPACE` is provided.
  - otherwise `<url>` is required.
  - See [SPDX clause 7.11](https://spdx.github.io/spdx-spec/v2.3/package-information/#711-package-home-page-field) for more information.
- `PACKAGE_COPYRIGHT`: Copyright information.
  - Either `NOASSERTION`, `NONE`, or a `<copyright_text>`.
  - Defaults to `<year> <name>` where `<name>` is the `CREATOR` name.
  - See [SPDX clause 7.17](https://spdx.github.io/spdx-spec/v2.3/package-information/#717-copyright-text-field) for more information.
- `PACKAGE_NOTES`:
  - No SBOM entry when omitted.
  - `SUMMARY`: A short description of the package.
  - `DESC`: A detailed description of the package.
  - Usage:
    - `sbom_generate(... PACKAGE_NOTES SUMMARY "A short description" DESC "A detailed description" ...)`
    - `sbom_generate(... PACKAGE_NOTES SUMMARY "A short description" ...)`
    - `sbom_generate(... PACKAGE_NOTES DESC "A detailed description" ...)`
  - See [SPDX clause 7.18](https://spdx.github.io/spdx-spec/v2.3/package-information/#718-package-summary-description-field) & [SPDX clause 7.19](https://spdx.github.io/spdx-spec/v2.3/package-information/#719-package-detailed-description-field) for more information.
- `PACKAGE_PURPOSE`:
  - Optional. If omitted, no `PrimaryPackagePurpose` field is added to the SBOM.
  - One or many of the following keywords:
    - `APPLICATION`, `FRAMEWORK`, `LIBRARY`, `CONTAINER`, `OPERATING-SYSTEM`, `DEVICE`, `FIRMWARE`, `SOURCE`, `ARCHIVE`, `FILE`, `INSTALL`, `OTHER`.
  - Usage:
    - `sbom_generate(... PACKAGE_PURPOSE "APPLICATION" "FIRMWARE" ...)`
    - `sbom_generate(... PACKAGE_PURPOSE "FILE" "SOURCE" "LIBRARY" ...)`
  - See [SPDX clause 7.24](https://spdx.github.io/spdx-spec/v2.3/package-information/#724-primary-package-purpose-field) for more information.
- `OUTPUT`: Output filename + path.
  - Can be absolute or relative to `CMAKE_INSTALL_PREFIX`.
  - Default location is `${CMAKE_INSTALL_PREFIX}/share/${PACKAGE_NAME}-sbom-${GIT_VERSION_PATH}.spdx`.
  - `--prefix` option is honoured when added to the install command.
  - `--prefix` and `${CMAKE_INSTALL_PREFIX}` have no effect when `OUTPUT` is an absolute path.
- `NAMESPACE`: Document namespace.
  - If not specified, default to a URL based on `PACKAGE_URL`, `PACKAGE_NAME` and `PACKAGE_VERSION`.

## sbom_add_[file|directory|target]

```cmake
sbom_add_[file|directory|target](
	<filename|path|target>
	[LICENSE <SPDX License Expression> [COMMENT <comment_text>]]
	[SPDXID <id>]
	[RELATIONSHIP <string>]
	[FILETYPE <SOURCE|BINARY|ARCHIVE|APPLICATION|AUDIO|IMAGE|TEXT|VIDEO|DOCUMENTATION|SPDX|OTHER>...]
	[CHECKSUM <MD5|SHA224|SHA256|SHA386|SHA512|SHA3_256|SHA3_384|SHA3_512>...]
	[COPYRIGHT <NOASSERTION|NONE|<copyright_text>>]
	[COMMENT <comment_text>]
	[NOTICE <notice_text>]
	[CONTRIBUTORS <contributors>...]
	[ATTRIBUTION <attribution_text>...]
)
```

- `filename`: A path to the file to add, relative to `CMAKE_INSTALL_PREFIX`.
  - Generator expressions are supported.
  - See [SPDX clause 8.1](https://spdx.github.io/spdx-spec/v2.3/file-information/#81-file-name-field) for more information.
- `LICENSE`: License of the file.
  - Defaults to the license of the package. (`PACKAGE_LICENSE` from `sbom_generate()`)
  - See [SPDX clause 8.5](https://spdx.github.io/spdx-spec/v2.3/file-information/#85-concluded-license-field) for more information.
  - Requires a valid SPDX license expression. See [SPDX License Expressions](https://spdx.github.io/spdx-spec/v2.3/SPDX-license-expressions/) for more information.
  - If you are adding a target or file from one of your dependencies, specify their license.
    - Optionally, add `COMMENT` to record any additional information that went in to arriving at the concluded license.
      - See [SPDX clause 8.7](https://spdx.github.io/spdx-spec/v2.3/file-information/#87-comments-on-license-field) for more information.
- `SPDXID`: The ID to use for identifier generation.
  - If omitted generates a new one.
  - See [SPDX clause 8.2](https://spdx.github.io/spdx-spec/v2.3/file-information/#82-file-spdx-identifier-field) for more information.
  - Whether or not this is specified, the variable `SBOM_LAST_SPDXID` is set to just generated/used SPDXID, which could be used for later relationship definitions.
- `RELATIONSHIP`: A relationship definition related to this file.
  - If omitted a default relationship is added: `SPDXRef-${PACKAGE_NAME} CONTAINS @SBOM_LAST_SPDXID@`
    - `${PACKAGE_NAME}` is the `PACKAGE_NAME` argument given to `sbom_generate()`.
  - See [SPDX clause 11](https://spdx.github.io/spdx-spec/v2.3/relationships-between-SPDX-elements/) for more information.
  - The string `@SBOM_LAST_SPDXID@` will be replaced by the SPDXID that is used for this SBOM item.
  - ***Limitation:***
    - This will ***replace*** the default relationship added.
    - Only one relationship can be added.
- `FILETYPE`: One or more file types.
  - If omitted, no SBOM entry is generated.
  - See [SPDX clause 8.3](https://spdx.github.io/spdx-spec/v2.3/file-information/#83-file-type-field) for more information.
  - One or many of the following keywords:
    - `SOURCE`, `BINARY`, `ARCHIVE`, `APPLICATION`, `AUDIO`, `IMAGE`, `TEXT`, `VIDEO`, `DOCUMENTATION`, `SPDX`, `OTHER`.
  - Usage:
    - `sbom_add_file(... FILETYPE "SOURCE" "TEXT" ...)`
    - `sbom_add_file(... FILETYPE "BINARY" ...)`
    - `sbom_add_file(... FILETYPE "ARCHIVE" ...)`
- `CHECKSUM`: Checksums to be generated for the file.
  - SPDX and TR-03183 require a SHA1 and SHA256 respectively to be generated. This is always done automatically.
  - With this argument, additional checksums can be specified.
  - See [SPDX clause 8.4](https://spdx.github.io/spdx-spec/v2.3/file-information/#84-file-checksum-field) for more information.
  - One or many of the following keywords:
    - `MD5`, `SHA224`, `SHA384`, `SHA512`, `SHA3_256`, `SHA3_384`, `SHA3_512`.
    - These are the set of hash algorithms that CMake supports and are defined in the SPDX specification.
  - Usage:
    - `sbom_add_file(... CHECKSUM MD5 SHA3_512 ...)` This would in total generate SHA1, SHA256, MD5, and SHA3_512 checksums.
- `COPYRIGHT`: Copyright information.
  - Defaults to the copyright of the package. (`PACKAGE_COPYRIGHT` from `sbom_generate()`)
  - See [SPDX clause 8.8](https://spdx.github.io/spdx-spec/v2.3/file-information/#88-copyright-text-field) for more information.
  - If you are adding a target or file from one of your dependencies, specify their copyright text.
    - Use `NOASSERTION` or `NONE` if the information cannot be determined or is not specified.
- `COMMENT`: Additional comments about the file.
  - No SBOM entry when omitted.
  - See [SPDX clause 8.12](https://spdx.github.io/spdx-spec/v2.3/file-information/#812-file-comment-field) for more information.
- `NOTICE`: Notice text.
  - No SBOM entry when omitted.
  - See [SPDX clause 8.13](https://spdx.github.io/spdx-spec/v2.3/file-information/#813-file-notice-field) for more information.
- `CONTRIBUTORS`: Contributors to the file.
  - No SBOM entry when omitted.
  - See [SPDX clause 8.14](https://spdx.github.io/spdx-spec/v2.3/file-information/#814-file-contributor-field) for more information.
- `ATTRIBUTION`: Attribution text.
  - No SBOM entry when omitted.
  - See [SPDX clause 8.15](https://spdx.github.io/spdx-spec/v2.3/file-information/#815-file-attribution-text-field) for more information.

## sbom_add_package

```cmake
sbom_add_package(
	<name>
	LICENSE <SPDX License Expression>
	        [DECLARED <NOASSERTION|NONE|<SPDX License Expression>> ]
	        [COMMENT <comment_text> ]
	VERSION <version_string>
	SUPPLIER <PERSON|ORGANIZATION> <name> [EMAIL <email>]
	[SPDXID <id>]
	[RELATIONSHIP <string>]
	[FILENAME <filename>]
	[ORIGINATOR <NOASSERTION|PERSON|ORGANIZATION> <name> [EMAIL <email>]]
	[DOWNLOAD <NOASSERTION|NONE|<url|vcs>>]
	[CHECKSUM <<algorithm> <checksum>>...]
	[URL <NOASSERTION|NONE|<url>>]
	[SOURCE_INFO <source_info_text>]
	[COPYRIGHT <NOASSERTION|NONE|<copyright_text>>]
	[NOTES [SUMMARY <summary_text>]
	       [DESC <summary_text>]
		   [COMMENT <summary_text>] ]
	[EXTREF <<SECURITY|PACKAGE_MANAGER|PERSISTENT-ID|OTHER> <type> <locator> [COMMENT <comment_text>]>...]
	[ATTRIBUTION <attribution_text>...]
	[PURPOSE <APPLICATION|FRAMEWORK|LIBRARY|
			  CONTAINER|OPERATING-SYSTEM|DEVICE|
			  FIRMWARE|SOURCE|ARCHIVE|
			  FILE|INSTALL|OTHER>]
	[DATE [RELEASE <date>]
	      [BUILD <date>]
		  [VALID_UNTIL <date>] ]
)
```

- `name`: Name of the package to be added as a dependency to the SBOM. (spdx clause 7.1)
  - Use the name that is given by the author or package manager.
  - The package files are not analysed further.
  - It is assumed that this package is a dependency of the project.
- `LICENSE`: License of the package described in the SBOM.
  - Requires a valid SPDX license expression. See [SPDX License Expressions](https://spdx.github.io/spdx-spec/v2.3/SPDX-license-expressions/) for more information.
    - The federal guidelines mentioned above do not explicitly allow the use of `NOASSERTION` or `NONE`. We therefore do not provide these options.
  - This is the license that the creator of the SBOM concluded the package has, which may differ from the declared license of the package supplier.
    - See [SPDX clause 7.13](https://spdx.github.io/spdx-spec/v2.3/package-information/#713-concluded-license-field)
  - Add `DECLARED` to specify the declared license.
    - Either `NOASSERTION`, `NONE`, or a valid SPDX license expression must follow `DECLARED`.
    - When omitted defaults to `NOASSERTION`.
    - See [SPDX clause 7.15](https://spdx.github.io/spdx-spec/v2.3/package-information/#715-declared-license-field) for more information.
  - Add `COMMENT` to record any additional information that went in to arriving at the concluded license.
    - No SBOM entry when omitted.
    - See [SPDX clause 7.16](https://spdx.github.io/spdx-spec/v2.3/package-information/#716-comments-on-license-field) for more information.
    - SPDX recommends to use this field also when `NOASSERTION` is set.
  - Usage:
    - `sbom_add_package(... LICENSE "MIT" DECLARED "MIT" ...)`
    - `sbom_add_package(... LICENSE "MIT" DECLARED NONE COMMENT "No package level license can be found. The files are licensed individually. All files are MIT licensed." ...)`
- `VERSION`: Package version field
  - Required by the TR-03183.
  - See [SPDX clause 7.3](https://spdx.github.io/spdx-spec/v2.3/package-information/#73-package-version-field) for more information.
- `SUPPLIER`: Supplier of the Package
  - One of `<PERSON|ORGANIZATION>` keywords must follow `SUPPLIER`.
  - `EMAIL` is optional.
  - Usage:
    - `sbom_add_package(... SUPPLIER ORGANIZATION "Package Distributor" EMAIL "contact@email.com" ...)`
    - `sbom_add_package(... SUPPLIER PERSON "Firstname Lastname" ...)`
  - See [SPDX clause 7.5](https://spdx.github.io/spdx-spec/v2.3/package-information/#75-package-supplier-field) for more information.
- `SPDXID`: The ID to use for identifier generation. (spdx clause 7.2)
  - By default, generate a new one. Whether or not this is specified, the variable `SBOM_LAST_SPDXID` is set to just generated/used SPDXID, which could be used for later relationship definitions.
- `RELATIONSHIP`: A relationship definition related to this package.
  - If omitted a default relationship is added: `SPDXRef-${PACKAGE_NAME} DEPENDS_ON @SBOM_LAST_SPDXID@`
    - `${PACKAGE_NAME}` is the `PACKAGE_NAME` argument given to `sbom_generate()`.
  - See [SPDX clause 11](https://spdx.github.io/spdx-spec/v2.3/relationships-between-SPDX-elements/) for more information.
  - The string `@SBOM_LAST_SPDXID@` will be replaced by the SPDXID that is used for this SBOM item.
  - Usage:
    - `sbom_add_package( gtest ...)`
    - `set(GTEST_SPDX_ID ${SBOM_LAST_SPDXID})`
    - `sbom_add_package(... RELATIONSHIP "${GTEST_SPDX_ID} TEST_DEPENDENCY_OF @SBOM_LAST_SPDXID@" ...)`
    - To get the spdx-id of another package, save `SBOM_LAST_SPDXID` in a different variable after calling `sbom_add_package(...)`.
  - ***Limitation:***
    - This will ***replace*** the default relationship added, which is: `SPDXRef-${PACKAGE_NAME} DEPENDS_ON @SBOM_LAST_SPDXID@`
    - Only one relationship can be added.
    - The Relationship: `@SBOM_LAST_SPDXID@ CONTAINS NOASSERTION` is always added, which can cause confusion.
- `FILENAME`: Filename of the package.
  - No SBOM entry when omitted.
  - See [SPDX clause 7.4](https://spdx.github.io/spdx-spec/v2.3/package-information/#74-package-file-name-field) for more information.
  - Filename of the package as it is distributed.
  - Can include relative path from `CMAKE_INSTALL_PREFIX` if it part of your install artifacts.
  - Usage:
    - `sbom_add_package(... FILENAME "./lib/libmodbus.so" ...)`
- `ORIGINATOR`: Originator of the Package
  - No SBOM entry when omitted.
  - See [SPDX clause 7.6](https://spdx.github.io/spdx-spec/v2.3/package-information/#76-package-originator-field) for more information.
  - Same options/keywords as `SUPPLIER`.
  - The package may be acquired from a different source than the original creator of the package.
  - Usage:
    - `sbom_add_package(... ORIGINATOR ORGANIZATION "Package Creator" EMAIL "" ...)`
    - `sbom_add_package(... ORIGINATOR NOASSERTION ...)`
- `DOWNLOAD`: Download location of the package.
  - If omitted, defaults to `NOASSERTION`, as this field is required by SPDX.
  - See [SPDX clause 7.7](https://spdx.github.io/spdx-spec/v2.3/package-information/#77-package-download-location-field) for more information.
  - One of `NOASSERTION`, `NONE`, or a `<url|vcs>` must follow `DOWNLOAD`.
    - `<url|vcs>`: A URL or version control system location.
- `CHECKSUM`: Checksum of the package.
  - No SBOM entry when omitted.
  - See [SPDX clause 7.10](https://spdx.github.io/spdx-spec/v2.3/package-information/#710-package-checksum-field) for more information.
  - For `<algorithm>` check CMakes supported [hash algorithms](https://cmake.org/cmake/help/latest/command/string.html#hash).
    - We are bound to the hash algorithms that CMake supports, as we aren't doing anything with the checksums yet. In the future, we may add automatic checksum verification, etc. which would limit us to the algorithms CMake supports.
  - Multiple checksums can be provided.
  - Usage:
    - `sbom_add_package(... CHECKSUM SHA256 "######" ...)`
    - `sbom_add_package(... CHECKSUM SHA256 "######" SHA1 "######" ...)`
- `URL`: Package home page.
  - No SBOM entry when omitted.
  - See [SPDX clause 7.11](https://spdx.github.io/spdx-spec/v2.3/package-information/#711-package-home-page-field) for more information.
  - Either `NOASSERTION`, `NONE`, or a `<url>` must follow `URL`.
- `SOURCE_INFO`: Background information about the origin of the package.
  - No SBOM entry when omitted.
  - See [SPDX clause 7.12](https://spdx.github.io/spdx-spec/v2.3/package-information/#712-source-information-field) for more information.
- `COPYRIGHT`: Copyright information.
  - When omitted defaults to `NOASSERTION`.
    - This field is optional in the SPDX specification.
    - If the field is not present in the SBOM, `NOASSERTION` is implied as per SPDX specification.
  - See [SPDX clause 7.17](https://spdx.github.io/spdx-spec/v2.3/package-information/#717-copyright-text-field) for more information.
  - Either `NOASSERTION`, `NONE`, or a `<copyright_text>` must follow `COPYRIGHT`.
- `NOTES`:
  - No SBOM entry when omitted.
  - `SUMMARY`: A short description of the package.
    - See [SPDX clause 7.18](https://spdx.github.io/spdx-spec/v2.3/package-information/#718-package-summary-description-field) for more information.
  - `DESC`: A detailed description of the package.
    - See [SPDX clause 7.19](https://spdx.github.io/spdx-spec/v2.3/package-information/#719-package-detailed-description-field) for more information.
  - `COMMENT`: Additional comments about the package.
    - See [SPDX clause 7.20](https://spdx.github.io/spdx-spec/v2.3/package-information/#720-package-comment-field) for more information.
  - Usage:
    - `sbom_generate(... NOTES SUMMARY "A canbus library" DESC "Provides function specified by $someStandard and is certified by ... ." COMMENT "This package came with it's own sbom. Which is appended to this sbom" ...)`
- `EXTREF`: External references, such as security or package manager information.
  - No SBOM entry when omitted.
  - Refer to [SPDX clause 7.21](https://spdx.github.io/spdx-spec/v2.3/package-information/#721-external-reference-field) for details.
  - Add `COMMENT` to record any additional information about the external reference.
    - No SBOM entry when omitted.
    - Refer to [SPDX clause 7.22](https://spdx.github.io/spdx-spec/v2.3/package-information/#722-external-reference-comment-field) for details.
- `ATTRIBUTION`: Attribution text.
  - No SBOM entry when omitted.
  - See [SPDX clause 7.23](https://spdx.github.io/spdx-spec/v2.3/package-information/#723-package-attribution-text-field) for more information.
  - Multiple strings can be provided and will be added as separate fields to the SBOM.
  - Usage:
    - `sbom_add_package(... ATTRIBUTION "text" "text2" ...)`
- `PURPOSE`:
  - No SBOM entry when omitted.
  - See [SPDX clause 7.24](https://spdx.github.io/spdx-spec/v2.3/package-information/#724-primary-package-purpose-field) for more information.
  - One of the following keywords:
    - `APPLICATION`, `FRAMEWORK`, `LIBRARY`, `CONTAINER`, `OPERATING-SYSTEM`, `DEVICE`, `FIRMWARE`, `SOURCE`, `ARCHIVE`, `FILE`, `INSTALL`, `OTHER`.
- `DATE`:
  - No SBOM entries when omitted.
  - `RELEASE`: The date the package was released.
    - See [SPDX clause 7.25](https://spdx.github.io/spdx-spec/v2.3/package-information/#725-release-date) for more information.
  - `BUILD`: The date the package was built.
    - See [SPDX clause 7.26](https://spdx.github.io/spdx-spec/v2.3/package-information/#726-built-date) for more information.
  - `VALID_UNTIL`: End of support date.
    - See [SPDX clause 7.27](https://spdx.github.io/spdx-spec/v2.3/package-information/#727-valid-until-date) for more information.
  - `<date>`: A date in the format `YYYY-MM-DDThh:mm:ssZ`.
  - Usage:
    - `sbom_add_package(... DATE RELEASE "2024-01-10T00:00:00Z" BUILD "2024-01-07T00:00:00Z" VALID_UNTIL "2029-01-10T00:00:00Z" ...)`

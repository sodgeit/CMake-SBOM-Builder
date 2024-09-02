# CMake SBOM Builder

This project provides a CMake module that helps your to generate Software Bill of Materials (SBOM) in `SPDX`-format for an arbitrary CMake project.

This Project only supports SPDX version 2.3. The SPDX specification is available [here](https://spdx.github.io/spdx-spec/v2.3/).

It automates two tasks:

- extracting version information from Git, and passing it to CMake, shell scripts, and C/C++
- generating a SBOM in SPDX format, based on install artifacts

The version extraction helps to get the version in the application and SBOM right. The SBOM contains the files you mention explicitly, just like you mention what to `install()` in CMake.

To integrate this library in your project, see [below](#how-to-use) for basic instructions or the example for a simple example project.

---

**Note:**
This project was originally forked from [cmake-sbom](https://github.com/DEMCON/cmake-sbom).

While the original project provided a solid foundation, we identified several areas where modifications and improvements were necessary to align it more closely with our needs and to use it effectively in our workflows.

Major Changes include:

- **Single-File Integration**: We condensed everything into a single file to facilitate integration with CMake's `file` command, making it simpler and more efficient to use.
- **Multi Config Generator Enhancements**: The SBOM generation better integrates with multi-config generators like Visual Studio and Ninja Multi-Config. Different SBOM's are generated for each configuration.
- **Removed External Python Tools**: The verification process that relied on external Python tools has been removed to minimize dependencies and simplify the setup.
- **Modernized CMake**: A higher minimum required version (>=3.16), ensuring better compatibility and taking advantage of newer functionalities.
- **Wider support for SPDX fields**: While the original project focused on the most important SPDX fields, to keep SBOM generation simple, we added support for more SPDX fields to provide more flexibility and customization, while maintaining the initial vision of auto-generating most fields.

---

**Contents**

- [How to use](#how-to-use)
- [SBOM generation](#sbom-generation)
	- [`sbom_generate`](#sbom_generate)
	- [`sbom_add_file`](#sbom_add_file)
		- [`sbom_add_directory`](#sbom_add_directory)
		- [`sbom_add_target`](#sbom_add_target)
	- [`sbom_add_package`](#sbom_add_package)
	- [`sbom_add_external`](#sbom_add_external)
	- [`sbom_finalize`](#sbom_finalize)
	- [`sbom_spdxid`](#sbom_spdxid)
- [Version Extraction](#version-extraction)
	- [`version_extract()`](#version_extract)
	- [`version_generate()`](#version_generate)
- [Compatibility Strategy](#compatibility-strategy)
- [License](#license)
- [Acknowledgements](#acknowledgements)

---

## How to use

To use this CMake module, perform the following steps:

1. Put `sbom.cmake` somewhere in your project.

	There are a variety of way's to do this. We recommend to use CMake directly to keep things simple.

	To download a specifc version:

	```cmake
	file(
		DOWNLOAD
		https://github.com/sodgeit/CMake-SBOM-Builder/releases/download/v0.2.1/sbom.cmake
		${CMAKE_SOURCE_DIR}/cmake/sbom.cmake
		EXPECTED_HASH SHA256=7b354f3a5976c4626c876850c93944e52c83ec59a159ae5de5be7983f0e17a2a
	)
	```

	Or always download the latest release:

	```cmake
	file(
		DOWNLOAD
		https://github.com/sodgeit/CMake-SBOM-Builder/releases/latest/download/sbom.cmake
		${CMAKE_SOURCE_DIR}/cmake/sbom.cmake
		EXPECTED_HASH SHA256=7b354f3a5976c4626c876850c93944e52c83ec59a159ae5de5be7983f0e17a2a
	)
	```

	Although the later example always fetches the newest version when it's released,
	the CMake configure stage will fail due to the `EXPECTED_HASH` being different.

2. include `sbom.cmake`:

	```cmake
	include(cmake/sbom.cmake)
	```

3. Somewhere ***after*** `project(...)`, prepare the SBOM:

	```cmake
	sbom_generate(
		SUPPLIER ORGANIZATION "sodgeIT" EMAIL "kontakt@sodgeit.de"
		PACKAGE_URL "https://github.com/sodgeit/CMake-SBOM-Builder"
		PACKAGE_LICENSE "MIT"
	)

	# Add sbom_add_*() ...
	sbom_add_package(<library>)
	sbom_add_file(<file>)

	sbom_finalize()
	```

4. Build ***and install*** your project:

	Using single config generators (Makefiles, Ninja):

	```bash
	cmake -S . -B build -DCMAKE_INSTALL_PREFIX=build/install -DCMAKE_BUILD_TYPE={Debug,Release,...}
	cmake --build build --target all
	cmake --install build
	```

	Using multi config generators (Visual Studio, Ninja Multi-Config):

	```bash
	cmake -S . -B build -G "Ninja Multi-Config" -DCMAKE_INSTALL_PREFIX=build/install
	cmake --build build --target all --config {Debug,Release,...} #--target ALL_BUILD for Visual Studio
	cmake --install build --config {Debug,Release,...}
	```

	We recommend using the `--prefix` option to override the install prefix, when using multi-config generators. This allows the SBOM to be generated in different locations for each configuration.
	If you don't use the `--prefix` option, the SBOM will be generated in the same location for all configurations, overwriting each other.

	```bash
	cmake -S . -B build -G "Ninja Multi-Config"
	cmake --build build --target all --config {Debug,Release,...}
	cmake --install build --config {Debug,Release,...} --prefix build/install/{Debug,Release,...}
	```

	Per default the SBOM will be generated in `${CMAKE_INSTALL_PREFIX}/share/${PROJECT_NAME}-sbom-${GIT_VERSION_PATH}.spdx` (see also CMake output).

	```text
		-- Installing: .../build/install/share/example-sbom-example-0.2.1.spdx
		...
		-- Finalizing: .../build/install/share/example-sbom-example-0.2.1.spdx
	```

---

## SBOM generation

The concept is that an SBOM is generated for one project, and describes the output of that project as a single package, which contains files, and other package dependencies. The files are all installed under `CMAKE_INSTALL_PREFIX`. The package dependencies are all black boxes; their files are not specified.

Generally, the following sequence is executed to create the SBOM:

```cmake
# Start SBOM generation. Optionally, provide template files, licence, copyright.
sbom_generate(
	SUPPLIER ORGANIZATION "sodgeIT" EMAIL "kontakt@sodgeit.de"
	PACKAGE_URL "https://github.com/sodgeit/CMake-SBOM-Builder"
	PACKAGE_LICENSE "MIT"
)

# Call for every artifact that should be recorded/that is part of the distributed package.
sbom_add_target(some_target)
sbom_add_file(some_filename ...)
sbom_add_directory(all_files_from_some_directory ...)

# To indicate dependencies on other packages/libraries/etc.:
sbom_add_package(some_dependency ...)

# Finally:
sbom_finalize()
```

`cmake/sbom.cmake` provides the following functions:

### `sbom_generate`

Generates the SBOM creator information, as well as the information of the package that the SBOM describes. (see spdx clause 6 & 7)

```cmake
sbom_generate(
   [SUPPLIER <NOASSERTION|PERSON|ORGANIZATION> <name> [EMAIL <email>]]
   [PACKAGE_NAME <package_name>]
   [PACKAGE_VERSION <version_string>]
   [PACKAGE_FILENAME <filename>]
   [PACKAGE_DOWNLOAD <NOASSERTION|NONE|<url>>]
   [PACKAGE_URL <NOASSERTION|NONE|<url>>]
   [PACKAGE_LICENSE <NOASSERTION|NONE|<SPDX License Expression>>]
   [PACKAGE_COPYRIGHT <NOASSERTION|NONE|<copyright_text>>]
   [PACKAGE_SUMMARY <package_summary_text>]
   [PACKAGE_DESCRIPTION <package_description_text>]
   [OUTPUT <filename>]
   [INPUT <filename>...]
   [NAMESPACE <URI>]
)
```

- `SUPPLIER`: Supplier of the Package and Creator of the sbom (spdx clause 6.8 & clause 7.5)
  - May be omitted when any `INPUT` is given.
  - Adds both the `Creator` and `PackageSupplier` fields to the SBOM.
  - One of the `<NOASSERTION|PERSON|ORGANIZATION>` keywords must be provided.
    - For `NOASSERTION`: `<name>` and `EMAIL` are not used.
  - `<name>` is either a person or organization name.
  - `EMAIL` is optional.
  - Usage:
    - `sbom_generate(... SUPPLIER ORGANIZATION "My Company" EMAIL "contact@company.com" ...)`
    - `sbom_generate(... SUPPLIER PERSON "Firstname Lastname" ...)`
    - `sbom_generate(... SUPPLIER NOASSERTION ...)`
- `PACKAGE_NAME`: Package name. Defaults to `PROJECT_NAME`.
- `PACKAGE_VERSION`: Package version field (spdx clause 7.3)
  - Defaults to `${GIT_VERSION}`. (see [Version Extraction](#version-extraction))
- `PACKAGE_FILENAME`: Filename of the distributed package. (spdx clause 7.4)
  - Defaults to `${PACKAGE_NAME}-${PACKAGE_VERSION}.zip`.
- `PACKAGE_DOWNLOAD`: Download location of the distributed package. (spdx clause 7.7)
  - Either `NOASSERTION`, `NONE`, or a `<url>`.
  - If omitted, defaults to `NOASSERTION`.
- `PACKAGE_URL`: Package home page.
  - may be omitted when any `INPUT` is given.
  - `NONE` or `NOASSERTION` require that `NAMESPACE` is provided.
  - otherwise `<url>` is required.
- `PACKAGE_LICENSE`: License of the package described in the SBOM. (spdx clause 7.15 & 7.13)
  - Requires one of `NOASSERTION`, `NONE`, or a valid SPDX license expression.
  - If omitted, defaults to `NOASSERTION`.
  - Adds both the `PackageLicenseDeclared` and `PackageLicenseConcluded` fields to the SBOM.
    - Differentiating between declared and concluded licenses, does not make sense when the creator of the SBOM also supplies the package.
- `OUTPUT`: Output filename.
  - Can be absolute or relative to `CMAKE_INSTALL_PREFIX`.
  - Default location is `${CMAKE_INSTALL_PREFIX}/share/${PROJECT_NAME}-sbom-${GIT_VERSION_PATH}.spdx`.
  - `--prefix` option is honoured when added to the install command.
  - `--prefix` and `${CMAKE_INSTALL_PREFIX}` have no effect when `OUTPUT` is an absolute path.
- `INPUT`: One or more file names, which are concatenated into the SBOM output file.
  - ***Restrictions:***
    - Absolute paths only.
  - Variables and generator expressions are supported in these files.
  - Variables in the form `@var@` are replaced during config, `${var}` during install.
  - When omitted, a standard document/package SBOM is generated.
  - The other parameters can be referenced in the input files, prefixed with `SBOM_GENERATE_`.
- `PACKAGE_COPYRIGHT`: Copyright information. (spdx clause 7.17)
  - Either `NOASSERTION`, `NONE`, or a `<copyright_text>`.
  - If omitted, generates as `<year> <name>` where `<name>` is the `SUPPLIER` name.
    - If `NOASSERTION` was set for `SUPPLIER`, the `PACKAGE_COPYRIGHT` defaults to `NOASSERTION`.
- `PACKAGE_SUMMARY`: Package summary. (spdx clause 7.18)
  - Optional.
  - Free form text summarizing the package.
- `PACKAGE_DESCRIPTION`: (spdx clause 7.19)
  - Optional.
  - Free form text summarizing the package.
  - Similar to `PACKAGE_SUMMARY`, but more detailed.
- `NAMESPACE`: Document namespace.
  - may be omitted when any `INPUT` is given.
  - If not specified, default to a URL based on `PACKAGE_URL`, `PROJECT_NAME` and `GIT_VERSION`.

***Unsupported spdx fields:***

The unsupported fields are unlikely to needed in the scope and use case of this project.
Some fields are autogenerated. Others are defined by the SPDX specification as optional, and can be omitted.
If you need any of these fields for your use case/workflow, consider opening an issue or a pull request. We are happy to help you out or accept contributions.

- `Creator` (spdx clause 6.8)
  - This field is required by the SPDX specification, and autogenerated by this project based on the `SUPPLIER` argument.
  - Used to specify the creator of the SBOM.
  - The SPDX specification differentiates between Creator of the SBOM and Supplier of the Package it describes, while this project threats them as the same entity.
  - We base this on the assumption that whoever uses this project, uses it to generate a SBOM for a package they are building. In this case, the creator of the SBOM and the supplier of the package are the same entity.
- `PackageOriginator` (spdx clause 7.6)
  - This field is optional in the SPDX specification, and can be omitted.
  - Used to specify the original creator of the package.
  - In the use case of this project, the PackageOriginator is unlikely to be a different entity than the Supplier of the Package.
  - We base this on the assumption that whoever uses this project, uses it to generate a SBOM for a package they are building. In this case, the supplier mentioned in the `SUPPLIER` is also the initial distributor of the package.
- `PackageChecksum` (spdx clause 7.10)
  - This field is optional in the SPDX specification, and can be omitted.
  - Used to specify checksums of the package.
  - Not yet implemented.
- `PackageLicenseComments` (spdx clause 7.16)
  - Not yet implemented.

### `sbom_add_file`

```cmake
sbom_add_file(
	<filename>
	[FILETYPE <types>...]
	[RELATIONSHIP <string>]
	[SPDXID <id>]
)
```

- `filename`: A path to the file to add, relative to `CMAKE_INSTALL_PREFIX`. Generator expressions are supported.
- `FILETYPE`: One or more file types. Refer to the [SPDX specification Clause 8.3](https://spdx.github.io/spdx-spec/v2.3/file-information/#83-file-type-field).
- `RELATIONSHIP`: A relationship definition related to this file. The string `@SBOM_LAST_SPDXID@` will be replaced by the SPDXID that is used for this SBOM item. Refer to the [SPDX specification](https://spdx.github.io/spdx-spec/v2.3/).
- `SPDXID`: The ID to use for identifier generation. By default, generate a new one. Whether or not this is specified, the variable `SBOM_LAST_SPDXID` is set to just generated/used SPDXID, which could be used for later relationship definitions.

2 specializations of this function are provided.

#### `sbom_add_directory`

```cmake
sbom_add_directory(
	<path>
	...
)
```

- `path`: A path to the directory, relative to `CMAKE_INSTALL_PREFIX`, for which all files are to be added to the SBOM recursively. Generator expressions are supported.

The supported options for `sbom_add_directory` are the same as those for [`sbom_add_file`](#sbom_add_file), with the exception of `SPDXID`. The `SPDXID` will be autogenerated.

#### `sbom_add_target`

```cmake
sbom_add_target(
	<name>
	...
)
```

- `name`: Corresponds to the logical target name. Only executables are supported. It is assumed that the binary is installed under `CMAKE_INSTALL_BINDIR`.

The supported options for `sbom_add_target` are the same as those for [`sbom_add_file`](#sbom_add_file), with the exception of `FILETYPE`. The `FILETYPE` is set to BINARY.

### `sbom_add_package`

```cmake
sbom_add_package(
	<name>
	[DOWNLOAD_LOCATION <URL>]
	[EXTREF <ref>...]
	[LICENSE <string>]
	[RELATIONSHIP <string>]
	[SPDXID <id>]
	[SUPPLIER <name>]
	[VERSION <version>]
)
```

- `name`: A package to be added to the SBOM. The name is something that is identifiable by standard tools, so use the name that is given by the author or package manager. The package files are not analysed further. It is assumed that this package is a dependency of the project.
- `DOWNLOAD_LOCATION`: Package download location. The URL may be used by tools to identify the package.
- `EXTREF`: External references, such as security or package manager information. Refer to the [SPDX](https://spdx.github.io/spdx-spec/v2.3/) specification for details.
- `LICENSE`: License of the package. Defaults to `NOASSERTION` when not specified.
- `SUPPLIER`: Package supplier, which can be `Person: name (email)`, or `Organization: name (email)`.
- `VERSION`: Version of the package.

### `sbom_add_external`

```cmake
sbom_add_external(
	<id>
	<path>
	[RENAME <filename>]
	[RELATIONSHIP <string>]
	[SPDXID <id>]
)
```

- `id`: The SDPX identifier of a package in an external file.
- `path`: Reference to another SDPX file as External document reference. Then, depend on the package named in that document. The external SDPX file is copied next to the SBOM. Generator expressions are supported.
- `RENAME`: Rename the external document to the given filename, without directories.
- `SPDXID`: The identifier of the external document, which is used as prefix for the package identifier. Defaults to a unique identifier. The package identifier is added automatically. The variable `SBOM_LAST_SPDXID` is set to the used identifier.

### `sbom_finalize`

Finalize the SBOM.

```cmake
sbom_finalize()
```

### `sbom_spdxid`

***This should rarely be used directly.*** All sbom_add_* functions will use this function to automatically generate unique SPDX identifiers.

Generate a unique SPDX identifier.

```cmake
sbom_spdxid(
   VARIABLE <variable_name>
   [CHECK <id> | HINTS <hint>...]
)
```

- `VARIABLE`: The output variable to generate a unique SDPX identifier in.
- `CHECK`: Verify and return the given identifier.
- `HINTS`: One or more hints, which are converted into a valid identifier. The first non-empty hint is used. If no hint is specified, a unique identifier is returned, with unspecified format.

---

## Version Extraction

Version extraction is included in the `sbom.cmake` and used by the `sbom_generate()` function to fill in the version information in the SPDX document. It is also available for use in your project.

### `version_extract()`

This function sets the following variables in the current scope for the current project:

- `GIT_HASH`: The full Git hash.
- `GIT_HASH_SHORT`: The short Git hash.
- `GIT_VERSION`:
  - If the current commit is tagged, the tag name: `v1.2.3`
  - If not tagged, `git-describe` + `branch`: `v1.2.3-4-g1234567+feature/xyz`
  - If dirty, a `+dirty` suffix is added in both cases: `v1.2.3-4-g1234567+feature/xyz+dirty` or `v1.2.3+dirty`
    - We want to be very particular about what is considered dirty, so even untracked files are considered dirty.
- `GIT_VERSION_PATH`:
  - The value of `GIT_VERSION`, but safe to use in file names.
  - E.g., `v1.2.3-4-g1234567+feature/xyz+dirty` becomes `v1.2.3-4-g1234567+feature_xyz+dirty`
- `VERSION_TIMESTAMP`: The current build time.

Additionally, if `GIT_VERSION` starts with a tag that adheres to [Semantic Versioning 2.0.0](https://semver.org/) (optionally prefixed with `v`), the following variables are set:

- `GIT_VERSION_TRIPLET`: A major.minor.patch triplet, extracted from `GIT_VERSION`.
  - e.g., `v1.2.3-4-g1234567+feature/xyz+dirty` -> `1.2.3`
- `GIT_VERSION_MAJOR`: The major part of `GIT_VERSION_TRIPLET`.
- `GIT_VERSION_MINOR`: The minor part of `GIT_VERSION_TRIPLET`.
- `GIT_VERSION_PATCH`: The patch part of `GIT_VERSION_TRIPLET`.
- `GIT_VERSION_SUFFIX`: Everything after the triplet in `GIT_VERSION`.
  - - e.g., `v1.2.3-4-g1234567+feature/xyz+dirty` -> `-4-g1234567+feature/xyz+dirty`

### `version_generate()`

This function generates the following files, containing the above-mentioned variables:

- `version.[sh|ps1]`: Script files that set the variables in the environment.
- `version.txt`: A text file for documentation purposes.
  - This file only contains the `GIT_VERSION` variable.
- `${PROJECT_NAME}-version`: An interface library target that provides a single header file `${PROJECT_NAME}-version.h`.
  - **Note:** The variables are prefixed with `${PROJECT_NAME}_` instead of `GIT_`.
  - Link the target `${PROJECT_NAME}-version` and include `${PROJECT_NAME}-version.h` to access the version information in C/C++. [(example)](example/CMakeLists.txt).

All files are generated in `${PROJECT_BINARY_DIR}/version/[scripts|include|doc]`. The CMake variables `VERSION_SCRIPT_DIR`, `VERSION_INC_DIR`, and `VERSION_DOC_DIR` point to these directories.

---

## Compatibility Strategy

CMake frequently releases new features and improvements, and sometimes deprecates or supersedes old features. To ensure our script remains functional and takes advantage of these updates, we will update our minimum required CMake version in line with the oldest supported Ubuntu LTS release.

As of the time of writing, the oldest supported Ubuntu LTS release is Ubuntu 20.04, which includes CMake version 3.16. When support for Ubuntu 20.04 is dropped in May 2025, we will update our minimum required to align with the next oldest supported Ubuntu LTS release. (Ubuntu 22.04, which includes CMake version 3.22)

Our testing strategy will also be aligned with this approach.

We believe this approach strikes a balance between ensuring broad compatibility for users on stable and long-term platforms and leveraging updated features and improvements in CMake.

---

## License

Most of the code in this repository is licensed under MIT.

## Acknowledgements

We would like to thank the original authors and contributors of the project for their hard work. Their efforts have provided a strong foundation for this fork.

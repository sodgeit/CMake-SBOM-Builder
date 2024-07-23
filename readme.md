# CMake SBOM Builder

This project provides a CMake module that helps generate (*Produce (Build)*) a Software Bill of Materials (SBOM) in `SPDX`-format for an arbitrary CMake project.

It automates two tasks:

- extracting version information from Git, and passing it to CMake, shell scripts, and C/C++
- generating a SBOM in SPDX format, based on install artifacts

The version extraction helps to get the version in the application and SBOM right. The SBOM contains the files you mention explicitly, just like you mention what to `install()` in CMake.

To integrate this library in your project, see [below](#how-to-use) for basic instructions or the example for a simple example project.

[SPDX](https://spdx.github.io/spdx-spec/v2.3/)
[NTIA](http://ntia.gov/SBOM)

---

**Note:**
This project was originally forked from [cmake-sbom](https://github.com/DEMCON/cmake-sbom).

While the original project provided a solid foundation, we identified several areas where modifications and improvements were necessary to align it more closely with our needs and to use it effectively in our workflows.

Major Changes include:

- **Single-File Integration**: We condensed everything into a single file to facilitate integration with CMake's `file` command, making it simpler and more efficient to use.
- **CMake-Based Verification**: Some verification processes have been moved into CMake itself. (Though it does not replace external verification tools)
- **Removed External Python Tools**: The verification process that relied on external Python tools has been removed to minimize dependencies and simplify the setup.
- **Modernized CMake**: A higher minimum required version (>=3.14), ensuring better compatibility and taking advantage of newer functionalities.

---

**Contents**

- [How to use](#how-to-use)
- [SBOM generation](#sbom-generation)
	- [`sbom_spdxid`](#sbom_spdxid)
	- [`sbom_generate`](#sbom_generate)
	- [`sbom_add_file`](#sbom_add_file)
		- [`sbom_add_directory`](#sbom_add_directory)
		- [`sbom_add_target`](#sbom_add_target)
	- [`sbom_add_package`](#sbom_add_package)
	- [`sbom_add_external`](#sbom_add_external)
	- [`sbom_finalize`](#sbom_finalize)
- [Version extraction](#version-extraction)
- [License](#license)
- [Acknowledgements](#acknowledgements)

---

## How to use

To use this library, perform the following steps:

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
	sbom_generate(SUPPLIER you SUPPLIER_URL https://www.some.where)

	# Add sbom_add_*() ...
	sbom_add_package(<library>)
	sbom_add_file(<file>)

	sbom_finalize()
	```

4. Build ***and install*** your project:

	```bash
	cmake -S . -B build
	cmake --build build --target all
	cmake --install build
	```

The SBOM will by default be generated in your `CMAKE_INSTALL_PREFIX` directory (see also CMake output).

---

## SBOM generation

The concept is that an SBOM is generated for one project. It contains one package (the output of the project), which contains files, and other package dependencies. The files are all installed under `CMAKE_INSTALL_PREFIX`. The package dependencies are all black boxes; their files are not specified.

Generally, the following sequence is executed to create the SBOM:

```cmake
# Start SBOM generation. Optionally, provide template files, licence, copyright.
sbom_generate(OUTPUT some_output_file.spdx)

# Call for every artifact that should be recorded:
sbom_add_target(some_target)
sbom_add_file(some_filename ...)
sbom_add_directory(all_files_from_some_directory ...)

# To indicate dependencies on other packages/libraries/etc.:
sbom_add_package(some_dependency ...)

# Finally:
sbom_finalize()
```

`cmake/sbom.cmake` provides the following functions:

### `sbom_spdxid`

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

This should rarely be used directly. All sbom_add_* functions will use this function to automatically generate unique SPDX identifiers.

### `sbom_generate`

Generate the header of the SBOM, based on a standard template where the given details are filled in.

```cmake
sbom_generate(
   [OUTPUT <filename>]
   [INPUT <filename>...]
   [COPYRIGHT <string>]
   [LICENSE <string>]
   [NAMESPACE <URI>]
   [PROJECT <name>]
   [SUPPLIER <name>]
   [SUPPLIER_URL <name>]
)
```

- `OUTPUT`: Output filename. It should probably start with `${CMAKE_INSTALL_PREFIX}`, as the file is generated during `install`. The variable `SBOM_FILENAME` is set to the full path.
- `INPUT`: One or more file names, which are concatenated into the SBOM output file. Variables and generator expressions are supported in these files. Variables in the form `@var@` are replaced during config, `${var}` during install. When omitted, a standard document/package SBOM is generated. The other parameters can be referenced in the input files, prefixed with `SBOM_GENERATE_`.
- `COPYRIGHT`: Copyright information. If not specified, it is generated as `<year> <supplier>`.
- `LICENSE`: License information. If not specified, `NOASSERTION` is used.
- `NAMESPACE`: Document namespace. If not specified, default to a URL based on `SUPPLIER_URL`, `PROJECT_NAME` and `GIT_VERSION`.
- `PROJECT`: Project name. Defaults to `PROJECT_NAME`.
- `SUPPLIER`: Supplier name. It may be omitted when the variable `SBOM_SUPPLIER` is set or when any `INPUT` is given.
- `SUPPLIER_URL`: Supplier home page. It may be omitted when the variable `SBOM_SUPPLIER_URL` is set or when any `INPUT` is given.

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

---

## Version extraction

Version extraction is included in the `sbom.cmake`. Calling `version_extract()` will set the following variables in the current scope for the current project:

- `GIT_HASH`: The full Git hash.
- `GIT_HASH_SHORT`: The short Git hash.
- `GIT_HASH_<tag>`: The full Git hash for the given tag.
- `GIT_VERSION`: The Git tag, or a combination of the branch and hash if there is no tag set for the current commit.
- `GIT_VERSION_PATH`: `GIT_VERSION`, but safe to be used in file names.
- `GIT_VERSION_TRIPLET`: A major.minor.patch triplet, extracted from the current tag. For this, the tag shall adhere to [Semantic Versioning 2.0.0](https://semver.org/), optionally prefixed with `v`.
- `GIT_VERSION_MAJOR`: The major part of `GIT_VERSION_TRIPLET`.
- `GIT_VERSION_MINOR`: The minor part of `GIT_VERSION_TRIPLET`.
- `GIT_VERSION_PATCH`: The patch part of `GIT_VERSION_TRIPLET`.
- `GIT_VERSION_SUFFIX`: Everything after the triplet of `GIT_VERSION_TRIPLET`.
- `VERSION_TIMESTAMP`: The current build time.

*Note:* `sbom_generate()` will call `version_extract()` internally.

Additionally, you can call `version_generate()` to generate:

- `${PROJECT_BINARY_DIR}/version.[sh|ps1]`: A shell file that sets `GIT_VERSION`, `GIT_VERSION_PATH`, and `GIT_HASH`.
- `${PROJECT_BINARY_DIR}/version.txt`: A text file that contains `GIT_VERSION`.
- `${PROJECT_NAME}-version` interface library target: When linking to this target, one can access the version information in C/C++ by including the `<${PROJECT_NAME}-version.h>` header file. The file is generated in `${PROJECT_BINARY_DIR}/include`.

*Note:* `version_generate()` will internally call `version_extract().`

---

## License

Most of the code in this repository is licensed under MIT. This project complies with [REUSE](https://reuse.software/).

## Acknowledgements

We would like to thank the original authors and contributors of the project for their hard work. Their efforts have provided a strong foundation for this fork.

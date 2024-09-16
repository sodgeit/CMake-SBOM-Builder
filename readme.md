# CMake SBOM Builder

Generating SPDX Software Bill of Materials (SBOMs) for arbitrary CMake projects.

The CMake-SBOM-Builder aims to be compliant with:

- [Technical Guideline TR-03183](https://www.bsi.bund.de/SharedDocs/Downloads/EN/BSI/Publications/TechGuidelines/TR03183/BSI-TR-03183-2.pdf?__blob=publicationFile&v=5) of the German Federal Office for Information Security (BSI)
- The US [Executive Order 14028](https://www.nist.gov/itl/executive-order-14028-improving-nations-cybersecurity/software-security-supply-chains-software-1)
- [SPDX Specification 2.3](https://spdx.github.io/spdx-spec/v2.3/)

The SBOM-Builder is designed to seamlessly be integrated into your CMake project.  It generates a single SBOM for your project, based on the files you install and the package dependencies you specify.
It also comes with a version extraction feature, to generate version information from your Git repository and make it available in your CMake files, your C/C++ code via a cmake target, and in your shell environment via a script.

To get started, take a look at the [example](#example) and how to [add the SBOM-Builder to your project](#adding-sbom-builder-to-your-project).

---

**Note:**
This project was originally forked from [cmake-sbom](https://github.com/DEMCON/cmake-sbom).

While the original project provided a solid foundation, we identified several areas where modifications and improvements were necessary to align it more closely with our needs and to use it effectively in our workflows.

Major Changes include:

- **Single-File Integration**: We condensed everything into a single file to facilitate integration with CMake's `file` command, making it simpler and more efficient to use.
- **Multi Config Generator Enhancements**: The SBOM generation better integrates with multi-config generators like Visual Studio and Ninja Multi-Config. Different SBOM's are generated for each configuration.
- **Modernized CMake**: A higher minimum required version (>=3.16), ensuring better compatibility and taking advantage of newer functionalities.
- **Wider support for SPDX 2.3**: More SPDX fields are supported for better compliance with the SPDX 2.3 specification.
- **Compliance with BSI-Guidelines**
- **Improved Documentation**

---

**Contents**

- [How to use](#how-to-use)
	- [Adding SBOM-Builder to your project](#adding-sbom-builder-to-your-project)
	- [Steps to generate an SBOM](#steps-to-generate-an-sbom)
	- [Build and install your project](#build-and-install-your-project)
	- [Example](#example)
- [Available Functions and Arguments](#available-functions-and-arguments)
	- [`sbom_generate`](#sbom_generate)
	- [`sbom_add_[file|directory|target]`](#sbom_add_filedirectorytarget)
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

### Adding SBOM-Builder to your project

There are a variety of way's to do this. We recommend to use CMake directly to keep things simple.

To download a specific version:

```cmake
file(
	DOWNLOAD
	https://github.com/sodgeit/CMake-SBOM-Builder/releases/download/v0.2.1/sbom.cmake
	${CMAKE_CURRENT_BINARY_DIR}/cmake/sbom.cmake
	EXPECTED_HASH SHA256=7b354f3a5976c4626c876850c93944e52c83ec59a159ae5de5be7983f0e17a2a
)
```

Or always download the latest release:

```cmake
file(
	DOWNLOAD
	https://github.com/sodgeit/CMake-SBOM-Builder/releases/latest/download/sbom.cmake
	${CMAKE_CURRENT_BINARY_DIR}/cmake/sbom.cmake
	EXPECTED_HASH SHA256=7b354f3a5976c4626c876850c93944e52c83ec59a159ae5de5be7983f0e17a2a
)
```

And then just include the file:

```cmake
include(${CMAKE_CURRENT_BINARY_DIR}/cmake/sbom.cmake)
```

### Steps to generate an SBOM

1. Use `sbom_generate()` to define the SBOM creator and provide general information about the package you build. The assumption is that your CMake project produces a single package.

2. With `sbom_add_file()`, `sbom_add_directory()`, or `sbom_add_target()` you can declare the contents of the package. These should cover all files, executables, libraries, etc. that are part of the distribution and are installed using CMake's `install()` command.

3. `sbom_add_package()` is used to define dependencies for your package as a whole. For single-file dependencies, use the `RELATIONSHIP` argument to override the default behaviour. All dependencies are treated as black boxes, meaning their internal contents are not specified or analysed further.

4. Finally, call `sbom_finalize()` to finish the SBOM definition.

### Build and install your project

Using single config generators (Makefiles, Ninja):

```bash
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=build/install -DCMAKE_BUILD_TYPE={Debug,Release,...}
cmake --build build --target all
cmake --install build
```

Using multi config generators (Visual Studio, Ninja Multi-Config):

```bash
cmake -S . -B build -G "Ninja Multi-Config"
cmake --build build --target all --config {Debug,Release,...} #--target ALL_BUILD for Visual Studio
cmake --install build --config {Debug,Release,...} --prefix build/install/{Debug,Release,...}
```

We recommend using the `--prefix` option to override the install prefix, when using multi-config generators. This allows the SBOM to be generated in different locations for each configuration.
If you don't use the `--prefix` option, the SBOM will be generated in the same location for all configurations, overwriting each other.

Per default the SBOM will be generated in `${CMAKE_INSTALL_PREFIX}/share/${PROJECT_NAME}-sbom-${GIT_VERSION_PATH}.spdx` (see also CMake output).

```text
-- Installing: .../build/install/share/example-sbom-0.2.1.spdx
...
-- Finalizing: .../build/install/share/example-sbom-0.2.1.spdx
```

### Example

```cmake
cmake_minimum_required(VERSION 3.16)
project(Example)

include(cmake/sbom.cmake)

sbom_generate(
	SUPPLIER ORGANIZATION "sodgeIT"
	PACKAGE_NAME "Example"
	PACKAGE_VERSION "1.0.0"
	PACKAGE_LICENSE "MIT"
)

sbom_add_package(Boost
	VERSION 1.88
	SUPPLIER ORGANIZATION "Boost Foundation"
	LICENSE "BSL-1.0"
)
sbom_add_package(cxxopts
	VERSION 3.2.0
	SUPPLIER PERSON "Jarryd Beck"
	LICENSE "MIT"
)

add_library(example_lib SHARED)
target_sources(example_lib PRIVATE
	source1.c
	source2.cpp
	header1.h
)
target_link_libraries(example_lib PUBLIC Boost::algorithm)

add_executable(cli main.cpp)
target_link_libraries(cli PRIVATE example_lib cxxopts)

install(TARGETS cli	RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(TARGETS example_lib LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILE header1.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

sbom_add_target(cli)
sbom_add_target(example_lib)
sbom_add_file(${CMAKE_INSTALL_INCLUDEDIR}/header1.h LICENSE "MIT")

sbom_finalize()
```

---

## Available Functions and Arguments

Here is a brief overview of the functions provided by the SBOM-Builder. Shown here is only a subset of the available arguments, which we consider the most important and most likely to be used.
For the entire function signature take a look [here](./doc/full_signature.md).

### `sbom_generate`

```cmake
sbom_generate(
	CREATOR <PERSON|ORGANIZATION> <name> [EMAIL <email>]
	PACKAGE_LICENSE <SPDX License Expression>
	[PACKAGE_NAME <package_name>]
	[PACKAGE_VERSION <version_string>]
	[PACKAGE_COPYRIGHT <NOASSERTION|NONE|<copyright_text>>]
)
```

- `CREATOR`: Supplier of the Package and Creator of the sbom
  - One of the `<PERSON|ORGANIZATION>` keywords must be provided.
  - `EMAIL` is optional.
- `PACKAGE_LICENSE`: License of the package described in the SBOM.
- `PACKAGE_NAME`: Package name.
  - Defaults to `${PROJECT_NAME}`.
- `PACKAGE_VERSION`: Package version field
  - Defaults to `${GIT_VERSION}`. (see [Version Extraction](#version-extraction))
- `PACKAGE_COPYRIGHT`: Copyright information.
  - Defaults to `<year> <name>` where `<name>` is the `CREATOR` name.

### `sbom_add_[file|directory|target]`

```cmake
sbom_add_[file|directory|target](
	<filename|path|target>
	[LICENSE <SPDX License Expression>]
	[COPYRIGHT <NOASSERTION|NONE|<copyright_text>>]
	[RELATIONSHIP <string>]
)
```

- `filename|path|target`:
  - A path to a file/directory, relative to `CMAKE_INSTALL_PREFIX`, or a target name, to be added to the SBOM. Target have to be installed using `install(TARGETS ...)`.
  - Generator expressions are supported.
- `LICENSE`: License of the file.
  - Defaults to the license of the package. (`PACKAGE_LICENSE` from `sbom_generate()`)
  - If you are adding a target or file from one of your dependencies, specify their license.
    - Check the full signature for more information in such cases.
- `COPYRIGHT`:
  - Defaults to the copyright of the package. (`PACKAGE_COPYRIGHT` from `sbom_generate()`)
  - If you are adding a target or file from one of your dependencies, specify thier copyright text.
    - Use `NOASSERTION` or `NONE` if the information cannot be determined or is not specified.
- `RELATIONSHIP`:
  - Defaults to `<project_id> CONTAINS <id>`
    - `<project_id>` and `<id>`are placeholders for the SPDX identifiers that are automatically generated.
  - Use this argument to override the default relationship. See [SPDX clause 11](https://spdx.github.io/spdx-spec/v2.3/relationships-between-SPDX-elements/) for more information.

### `sbom_add_package`

```cmake
sbom_add_package(
	<name>
	LICENSE <SPDX License Expression>
	VERSION <version_string>
	SUPPLIER <PERSON|ORGANIZATION> <name> [EMAIL <email>]
	[RELATIONSHIP <string>]
	...
)
```

- `name`: The name of the package.
- `LICENSE`: License of the package.
  - Check the full signature for more information, if the license is not specified, cannot be determined, or contains exceptions.
- `VERSION`: Version of the package.
- `SUPPLIER`: Supplier of the package.
  - One of the `<PERSON|ORGANIZATION>` keywords must be provided.
  - `EMAIL` is optional.
- `RELATIONSHIP`:
  - Defaults to `<project_id> DEPENDS_ON <id>`.
    - `<project_id>` and `<id>`are placeholders for the SPDX identifiers that are automatically generated.
  - Use this argument to override the default relationship. See [SPDX clause 11](https://spdx.github.io/spdx-spec/v2.3/relationships-between-SPDX-elements/) for more information.
  - Eg: In the example above, the dependency `cxxopts` is only used by the `cli` and not the entire package.  The relationship can be overridden as follows:
  ```cmake
  sbom_add_target(cli)
  set(cli_spdxid ${SBOM_LAST_SPDXID})
  sbom_add_package(cxxopts ... RELATIONSHIP "${cli_spdxid} DEPENDS_ON @SBOM_LAST_SPDXID@" )
  ```
  - - `${SBOM_LAST_SPDXID}` is set to the SPDX identifier of the last added file/package/target.
    - `@SBOM_LAST_SPDXID@` is a placeholder for the SPDX identifier that will be generated for `cxxopts`.

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
- `RELATIONSHIP`: Defaults to `${Project} DEPENDS_ON <id>`

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

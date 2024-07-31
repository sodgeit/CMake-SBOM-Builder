CPMAddPackage( "gh:jarro2783/cxxopts@3.2.0" )

CPMAddPackage(
	NAME Boost
	VERSION 1.85.0
	URL https://github.com/boostorg/boost/releases/download/boost-1.85.0/boost-1.85.0-cmake.tar.gz
	URL_HASH SHA256=ab9c9c4797384b0949dd676cf86b4f99553f8c148d767485aaac412af25183e6
	OPTIONS "BOOST_INCLUDE_LIBRARIES algorithm\\\;asio"
)

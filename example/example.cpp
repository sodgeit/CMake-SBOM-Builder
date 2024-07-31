#include <print>

#include <Example_version.h>
#include <boost/algorithm/clamp.hpp>
#include <cxxopts.hpp>

int main( int argc, char *argv[] )
{
	std::println( "Example: Example-Project version {}", EXAMPLE_VERSION );

	// clang-format off
	cxxopts::Options options( "CPM-Test", "Testing CPM" );
	options.add_options()
	( "a", "Option A" )
	( "b", "Option B" )
	( "c", "Option C" );
	// clang-format on

	auto result = options.parse( argc, argv );

	if ( result[ "a" ].as<bool>() )
	{
		std::println( "Option 'a' is set" );
	}
	if ( result[ "b" ].as<bool>() )
	{
		std::println( "Option 'b' is set" );
	}
	if ( result[ "c" ].as<bool>() )
	{
		std::println( "Option 'c' is set" );
	}

	std::println( "Boost Algorithm Test: {}", boost::algorithm::clamp( 5, 0, 10 ) );
	std::println( "Boost Algorithm Test: {}", boost::algorithm::clamp( 5, 7, 10 ) );
	std::println( "Boost Algorithm Test: {}", boost::algorithm::clamp( 5, 0, 3 ) );

	exit( EXIT_SUCCESS );
}

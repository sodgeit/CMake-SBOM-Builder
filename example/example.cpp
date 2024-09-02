#include <cstdio>

#include <Example_version.h>
#include <boost/algorithm/clamp.hpp>
#include <cxxopts.hpp>

int main(int argc, char* argv[])
{
	printf("This projects version is: %s", EXAMPLE_VERSION);

	// clang-format off
	cxxopts::Options options("CPM-Test", "Testing CPM");
	options.add_options()
		("a", "Option A")
		("b", "Option B")
		("c", "Option C");
	// clang-format on

	auto result = options.parse(argc, argv);

	if (result["a"].as<bool>())
	{
		printf("Option 'a' is set");
	}
	if (result["b"].as<bool>())
	{
		printf("Option 'b' is set");
	}
	if (result["c"].as<bool>())
	{
		printf("Option 'c' is set");
	}

	printf("Boost clamp: %d", boost::algorithm::clamp(5, 0, 10));
	printf("Boost clamp: %d", boost::algorithm::clamp(5, 7, 10));
	printf("Boost clamp: %d", boost::algorithm::clamp(5, 0, 3));

	exit(EXIT_SUCCESS);
}

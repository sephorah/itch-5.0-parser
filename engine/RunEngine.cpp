#include "Engine.hpp"

int main(int argc, char **argv)
{
    if (argc != 2)
    {
        std::cerr << "Usage: " << argv[0] << " <itch_file>\n";
        return 1;
    }

    try
    {
        Engine engine(argv[1]);
        
        engine.run();
    }
    catch (const std::exception &e)
    {
        std::cerr << e.what() << std::endl;
        return EXIT_FAILURE;
    }
}
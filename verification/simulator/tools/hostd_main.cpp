#include "hostd.hpp"
#include <iostream>
#include <vector>
#include <string>

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cerr << "usage: hostd <root_dir> <cmd...>\n";
        return 1;
    }

    std::string root_dir = argv[1];
    std::vector<std::string> cmd_args;
    for (int i = 2; i < argc; ++i) {
        cmd_args.push_back(argv[i]);
    }

    return hostd::serve_with_subprocess(root_dir, cmd_args);
}

#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

static constexpr uint32_t PAGE_SIZE = 4096;
static constexpr uint32_t MAGIC = 0x53465332; // SFS2
static constexpr uint32_t MAX_INODES = 64;
static constexpr uint32_t DATA_BASE = 2;
static constexpr uint32_t BLOCKS_PER_FILE = 16;
static constexpr uint32_t TYPE_FILE = 1;
static constexpr uint32_t TYPE_DIR = 2;

struct Inode {
    char name[32];
    uint32_t type;
    uint32_t parent;
    uint32_t size;
    uint32_t data_slot;
    uint32_t used;
};

struct Super {
    uint32_t magic;
    uint32_t version;
    uint32_t inode_count;
    uint32_t next_slot;
    Inode inodes[MAX_INODES];
};

int main(int argc, char **argv) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " IMAGE ELF...\n";
        return 1;
    }

    Super super{};
    super.magic = MAGIC;
    super.version = 2;
    super.inode_count = 2;
    super.inodes[0] = Inode{{0}, TYPE_DIR, 0, 0, 0, 1};
    std::strcpy(super.inodes[1].name, "bin");
    super.inodes[1].type = TYPE_DIR;
    super.inodes[1].parent = 0;
    super.inodes[1].used = 1;

    std::vector<std::vector<uint8_t>> files;
    for (int arg = 2; arg < argc; arg++) {
        if (super.inode_count >= MAX_INODES) {
            std::cerr << "Too many files\n"; return 1;
        }
        std::ifstream input(argv[arg], std::ios::binary | std::ios::ate);
        if (!input) { std::cerr << "Cannot open " << argv[arg] << "\n"; return 1; }
        auto length = input.tellg();
        if (length > static_cast<std::streamoff>(BLOCKS_PER_FILE * PAGE_SIZE)) {
            std::cerr << argv[arg] << " exceeds per-file limit\n"; return 1;
        }
        input.seekg(0);
        std::vector<uint8_t> data(static_cast<size_t>(length));
        input.read(reinterpret_cast<char *>(data.data()), length);

        std::string path(argv[arg]);
        std::string name = path.substr(path.find_last_of("/\\") + 1);
        Inode &inode = super.inodes[super.inode_count++];
        std::strncpy(inode.name, name.c_str(), sizeof(inode.name) - 1);
        inode.type = TYPE_FILE;
        inode.parent = 1;
        inode.size = static_cast<uint32_t>(data.size());
        inode.data_slot = super.next_slot++;
        inode.used = 1;
        files.push_back(std::move(data));
    }

    std::ofstream output(argv[1], std::ios::binary | std::ios::trunc);
    if (!output) { std::cerr << "Cannot create image\n"; return 1; }
    std::vector<uint8_t> page(PAGE_SIZE, 0);
    static_assert(sizeof(Super) <= PAGE_SIZE);
    std::memcpy(page.data(), &super, sizeof(super));
    output.write(reinterpret_cast<char *>(page.data()), page.size());
    output.write(reinterpret_cast<char *>(page.data()), page.size());

    for (uint32_t slot = 0; slot < files.size(); slot++) {
        output.seekp(static_cast<std::streamoff>(DATA_BASE + slot * BLOCKS_PER_FILE) * PAGE_SIZE);
        output.write(reinterpret_cast<const char *>(files[slot].data()), files[slot].size());
        uint32_t padded = (files[slot].size() + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1);
        uint32_t padding = padded - files[slot].size();
        if (padding) output.write(reinterpret_cast<char *>(page.data()), padding);
    }

    std::cout << "Generated writable SFS2 image " << argv[1]
              << " with " << files.size() << " /bin files.\n";
    return 0;
}

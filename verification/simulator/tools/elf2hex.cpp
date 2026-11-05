#include "elf2hex.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <map>
#include <memory>
#include <cstring>
#include <elf.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifdef _WIN32
#include <direct.h>
#define mkdir(path, mode) _mkdir(path)
#else
// mkdir is already defined in <sys/stat.h>
#endif

static bool makeDirectory(const std::string& path) {
#ifdef _WIN32
    return _mkdir(path.c_str()) == 0 || errno == EEXIST;
#else
    return mkdir(path.c_str(), 0755) == 0 || errno == EEXIST;
#endif
}

bool convertElfToHex(const std::vector<std::string>& elf_paths, const Elf2HexConfig& config) {
    if (!makeDirectory(config.out_dir)) {
        std::cerr << "Error: Could not create output directory: " << config.out_dir << std::endl;
        return false;
    }

    // Map: bank_idx -> (sram_addr -> word_val).  SRAM banks are XLEN wide:
    // an RV64 boot image must therefore be interleaved in eight-byte words,
    // exactly as memory.sv addresses them.
    constexpr uint64_t word_bytes = sizeof(uint64_t);
    std::vector<std::map<uint64_t, uint64_t>> banks(config.num_banks);
    const uint64_t word_mask = (config.region_size / word_bytes) - 1;

    for (const auto& elf_path : elf_paths) {
        std::ifstream f(elf_path, std::ios::binary);
        if (!f) {
            std::cerr << "Error: Failed to open ELF file: " << elf_path << std::endl;
            return false;
        }

        // Read ELF header identifier
        unsigned char ident[EI_NIDENT];
        if (!f.read(reinterpret_cast<char*>(ident), EI_NIDENT)) {
            std::cerr << "Error: Failed to read ELF identification from " << elf_path << std::endl;
            return false;
        }

        if (std::memcmp(ident, ELFMAG, SELFMAG) != 0) {
            std::cerr << "Error: Invalid ELF magic in " << elf_path << std::endl;
            return false;
        }

        f.seekg(0, std::ios::beg);
        if (ident[EI_CLASS] == ELFCLASS32) {
            Elf32_Ehdr ehdr;
            if (!f.read(reinterpret_cast<char*>(&ehdr), sizeof(ehdr))) {
                std::cerr << "Error: Failed to read ELF32 header from " << elf_path << std::endl;
                return false;
            }

            std::vector<Elf32_Phdr> phdrs(ehdr.e_phnum);
            f.seekg(ehdr.e_phoff, std::ios::beg);
            if (!f.read(reinterpret_cast<char*>(phdrs.data()), ehdr.e_phnum * sizeof(Elf32_Phdr))) {
                std::cerr << "Error: Failed to read ELF32 program headers from " << elf_path << std::endl;
                return false;
            }

            for (const auto& phdr : phdrs) {
                if (phdr.p_type == PT_LOAD) {
                    std::vector<char> segment_data(phdr.p_filesz);
                    f.seekg(phdr.p_offset, std::ios::beg);
                    if (phdr.p_filesz > 0 && !f.read(segment_data.data(), phdr.p_filesz)) {
                        std::cerr << "Error: Failed to read segment data from " << elf_path << std::endl;
                        return false;
                    }

                    for (uint32_t b_idx = 0; b_idx < phdr.p_filesz; ++b_idx) {
                        const uint64_t addr = uint64_t(phdr.p_paddr) + b_idx;
                        const uint64_t word_addr = (addr / word_bytes) & word_mask;
                        const uint32_t target_bank = static_cast<uint32_t>(word_addr % config.num_banks);
                        const uint64_t sram_addr = word_addr / config.num_banks;
                        const uint64_t lane_shift = (addr % word_bytes) * 8;
                        uint64_t& word_val = banks[target_bank][sram_addr];
                        word_val = (word_val & ~(UINT64_C(0xff) << lane_shift)) |
                                   (uint64_t(static_cast<uint8_t>(segment_data[b_idx])) << lane_shift);
                    }
                }
            }
        } else if (ident[EI_CLASS] == ELFCLASS64) {
            Elf64_Ehdr ehdr;
            if (!f.read(reinterpret_cast<char*>(&ehdr), sizeof(ehdr))) {
                std::cerr << "Error: Failed to read ELF64 header from " << elf_path << std::endl;
                return false;
            }

            std::vector<Elf64_Phdr> phdrs(ehdr.e_phnum);
            f.seekg(ehdr.e_phoff, std::ios::beg);
            if (!f.read(reinterpret_cast<char*>(phdrs.data()), ehdr.e_phnum * sizeof(Elf64_Phdr))) {
                std::cerr << "Error: Failed to read ELF64 program headers from " << elf_path << std::endl;
                return false;
            }

            for (const auto& phdr : phdrs) {
                if (phdr.p_type == PT_LOAD) {
                    std::vector<char> segment_data(phdr.p_filesz);
                    f.seekg(phdr.p_offset, std::ios::beg);
                    if (phdr.p_filesz > 0 && !f.read(segment_data.data(), phdr.p_filesz)) {
                        std::cerr << "Error: Failed to read segment data from " << elf_path << std::endl;
                        return false;
                    }

                    for (uint64_t b_idx = 0; b_idx < phdr.p_filesz; ++b_idx) {
                        const uint64_t addr = phdr.p_paddr + b_idx;
                        const uint64_t word_addr = (addr / word_bytes) & word_mask;
                        const uint32_t target_bank = static_cast<uint32_t>(word_addr % config.num_banks);
                        const uint64_t sram_addr = word_addr / config.num_banks;
                        const uint64_t lane_shift = (addr % word_bytes) * 8;
                        uint64_t& word_val = banks[target_bank][sram_addr];
                        word_val = (word_val & ~(UINT64_C(0xff) << lane_shift)) |
                                   (uint64_t(static_cast<uint8_t>(segment_data[b_idx])) << lane_shift);
                    }
                }
            }
        } else {
            std::cerr << "Error: Unknown ELF class in " << elf_path << std::endl;
            return false;
        }
    }

    // Write out hex files for all banks
    for (uint32_t bank_idx = 0; bank_idx < config.num_banks; ++bank_idx) {
        std::string hex_file = config.out_dir + "/bank" + std::to_string(bank_idx) + ".hex";
        std::ofstream out(hex_file);
        if (!out) {
            std::cerr << "Error: Failed to open output file: " << hex_file << std::endl;
            return false;
        }

        const auto& bank_map = banks[bank_idx];
        if (!bank_map.empty()) {
            uint64_t max_addr = 0;
            for (const auto& pair : bank_map) {
                if (pair.first > max_addr) {
                    max_addr = pair.first;
                }
            }
            for (uint64_t addr = 0; addr <= max_addr; ++addr) {
                auto it = bank_map.find(addr);
                const uint64_t val = (it != bank_map.end()) ? it->second : 0;
                char hex_str[24];
                snprintf(hex_str, sizeof(hex_str), "%016llx\n", static_cast<unsigned long long>(val));
                out << hex_str;
            }
        }
    }

    std::cout << "Generated " << config.num_banks << " bank hex files in " << config.out_dir << "." << std::endl;
    return true;
}

#ifndef NO_ELF2HEX_MAIN
int main(int argc, char* argv[]) {
    std::vector<std::string> elf_files;
    Elf2HexConfig config;

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--out" || arg == "-o") {
            if (i + 1 < argc) {
                config.out_dir = argv[++i];
            } else {
                std::cerr << "Error: Missing argument for output directory." << std::endl;
                return 1;
            }
        } else if (arg == "--region-size") {
            if (i + 1 < argc) {
                std::string val = argv[++i];
                if (val.rfind("0x", 0) == 0 || val.rfind("0X", 0) == 0) {
                    config.region_size = std::stoull(val, nullptr, 16);
                } else {
                    config.region_size = std::stoull(val, nullptr, 10);
                }
            } else {
                std::cerr << "Error: Missing argument for region size." << std::endl;
                return 1;
            }
        } else if (arg == "--num-banks") {
            if (i + 1 < argc) {
                config.num_banks = std::stoul(argv[++i]);
            } else {
                std::cerr << "Error: Missing argument for number of banks." << std::endl;
                return 1;
            }
        } else if (arg == "--help" || arg == "-h") {
            std::cout << "Usage: elf2hex [options] <elf_files...>\n"
                      << "Options:\n"
                      << "  -o, --out <dir>          Output directory (default: boot_rom)\n"
                      << "  --region-size <size>     Region size in bytes (default: 0x00200000)\n"
                      << "  --num-banks <num>        Number of SRAM memory banks (default: 64)\n"
                      << "  -h, --help               Show this help message\n";
            return 0;
        } else {
            elf_files.push_back(arg);
        }
    }

    if (elf_files.empty()) {
        std::cerr << "Error: No ELF input files specified." << std::endl;
        return 1;
    }

    if (!convertElfToHex(elf_files, config)) {
        return 1;
    }

    return 0;
}
#endif

#ifndef ELF2HEX_H
#define ELF2HEX_H

#include <string>
#include <vector>
#include <cstdint>

struct Elf2HexConfig {
    uint64_t region_size = 0x00200000; // e.g., 2MB
    uint32_t num_banks = 64;
    std::string out_dir = "boot_rom";
};

// Reusable API function to convert multiple ELF files into SRAM bank hex files.
bool convertElfToHex(const std::vector<std::string>& elf_paths, const Elf2HexConfig& config);

#endif // ELF2HEX_H

#ifndef ELF2BIN_H
#define ELF2BIN_H

#include <string>
#include <vector>

// Reusable API function to convert an ELF file to a flat binary file.
bool convertElfToBin(const std::string& elf_path, const std::string& bin_path);

#endif // ELF2BIN_H

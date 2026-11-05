#include "elf2bin.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <cstring>
#include <elf.h>
#include <algorithm>

struct ElfSegment {
    uint64_t vaddr;
    uint64_t offset;
    uint64_t filesz;
    uint64_t memsz;
};

bool convertElfToBin(const std::string& elf_path, const std::string& bin_path) {
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
    std::vector<ElfSegment> segments;
    uint64_t min_vaddr = 0xFFFFFFFFFFFFFFFFULL;
    uint64_t max_vaddr = 0;

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
            if (phdr.p_type == PT_LOAD && phdr.p_memsz > 0) {
                segments.push_back({phdr.p_paddr, phdr.p_offset, phdr.p_filesz, phdr.p_memsz});
                min_vaddr = std::min(min_vaddr, static_cast<uint64_t>(phdr.p_paddr));
                max_vaddr = std::max(max_vaddr, static_cast<uint64_t>(phdr.p_paddr + phdr.p_memsz));
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
            if (phdr.p_type == PT_LOAD && phdr.p_memsz > 0) {
                segments.push_back({phdr.p_paddr, phdr.p_offset, phdr.p_filesz, phdr.p_memsz});
                min_vaddr = std::min(min_vaddr, static_cast<uint64_t>(phdr.p_paddr));
                max_vaddr = std::max(max_vaddr, static_cast<uint64_t>(phdr.p_paddr + phdr.p_memsz));
            }
        }
    } else {
        std::cerr << "Error: Unknown ELF class in " << elf_path << std::endl;
        return false;
    }

    if (segments.empty()) {
        std::ofstream out(bin_path, std::ios::binary);
        if (!out) {
            std::cerr << "Error: Failed to open output binary file: " << bin_path << std::endl;
            return false;
        }
        return true;
    }

    std::vector<char> bin_data(max_vaddr - min_vaddr, 0);

    for (const auto& seg : segments) {
        f.seekg(seg.offset, std::ios::beg);
        uint64_t start_offset = seg.vaddr - min_vaddr;
        if (seg.filesz > 0 && !f.read(&bin_data[start_offset], seg.filesz)) {
            std::cerr << "Error: Failed to read segment data from " << elf_path << std::endl;
            return false;
        }
    }

    std::ofstream out(bin_path, std::ios::binary);
    if (!out) {
        std::cerr << "Error: Failed to open output binary file: " << bin_path << std::endl;
        return false;
    }

    if (!bin_data.empty() && !out.write(bin_data.data(), bin_data.size())) {
        std::cerr << "Error: Failed to write to output binary file: " << bin_path << std::endl;
        return false;
    }

    std::cout << "Successfully generated binary: " << bin_path << " (size: " << bin_data.size() << " bytes)" << std::endl;
    return true;
}

#ifndef NO_ELF2BIN_MAIN
int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: elf2bin <input_elf> <output_bin>" << std::endl;
        return 1;
    }

    std::string elf_path = argv[1];
    std::string bin_path = argv[2];

    if (!convertElfToBin(elf_path, bin_path)) {
        return 1;
    }

    return 0;
}
#endif

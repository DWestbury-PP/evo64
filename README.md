# EVO64 Project

![EVO64 Logo](image-gallery/EVO_Rev1%20-%20Full%20Premium%20Build%20with%20NuTube64%20on%20Marble%20Counter.png)

## About EVO64

**EVO64** is a reimagining of the classic Commodore 64 with modern features and flourishes. This project brings the beloved C64 experience into the modern era while maintaining the authentic retro computing spirit that made the original so special.

### Key Features
![EVO64 Logo](image-gallery/EVO64-Features.png)

- **Modern Hardware Design** - Updated internals with contemporary components
- **Authentic Experience** - Maintains the classic C64 look, feel, and compatibility
- **Premium Build Quality** - High-quality components and construction
- **Extensive Documentation** - Comprehensive guides for builders and users
- **Community Support** - 3D printable accessories and mounting solutions

---

## Repository Contents

This repository contains supporting materials for the EVO64 project. While the hardware design and schematics remain proprietary, we're sharing essential resources for the community:

### Documentation (`/documentation/`)
Comprehensive guides and technical documentation:
- **EVO64 DIY Build Guide.pdf** - Complete assembly instructions
- **EVO64 Getting Started Guide.pdf** - Setup and initial configuration
- **EVO64 Product Brief.pdf** - Project overview and specifications
- **Technical Guides** - SID Audio, ROM Management, Tube Preamps, and more
- **Bill of Materials (BOM)** - Component lists for different configurations

### Image Gallery (`/image-gallery/`)
High-quality photos showcasing different EVO64 builds:
- Premium builds with NuTube64 and Triode64
- Various case configurations (Breadbin, Plexilaser, MODULR)
- Assembly photos and finished systems
- Prototype and development images

### Marketing Materials (`/promo-marketing/`)
- Project advertisements and promotional graphics

### 3D Printables (`/3D-printables/`)
Community-contributed 3D printing files organized by creator:
- **LCD Mounts** - 16x2 and 20x4 display mounting solutions
- **Keyboard Mounts** - Various case compatibility options
- **Cart Shield Covers** - Cartridge port protection
- **MSM Mounts** - Multi Switch Module mounting hardware
- **SIDKick & VIC-II Kawari** - Accessory housings
- **Case-Specific Mounts** - Plexi, C64c, and MODULR case accessories

### Interactive BOMs (`/ibom-html/`)
- Interactive HTML bill of materials for easy component identification

---

## Getting Started

### Prerequisites

This repository uses **Git Large File Storage (Git LFS)** to handle large files efficiently. You'll need:

1. **Git** (standard installation)
2. **Git LFS** - For handling large documentation PDFs, images, and 3D files

### Installation

#### Install Git LFS

**macOS (Homebrew):**
```bash
brew install git-lfs
```

**Windows:**
Download from [git-lfs.github.io](https://git-lfs.github.io/)

**Linux (Ubuntu/Debian):**
```bash
sudo apt install git-lfs
```

#### Clone the Repository

```bash
# Clone the repository
git clone https://github.com/[username]/evo64.git
cd evo64

# Initialize Git LFS (one-time setup)
git lfs install

# Pull all LFS files
git lfs pull
```

---

## Large Files Information

This repository contains **90 files** managed by Git LFS, totaling approximately **411 MB** of content including:

- **Documentation PDFs** (up to 123MB each)
- **High-resolution images** (up to 30MB each)
- **3D printing files** (STL and 3MF formats)
- **Excel spreadsheets** (BOMs and specifications)

### File Types Tracked by Git LFS:
- `*.pdf` - Documentation and guides
- `*.png`, `*.jpg`, `*.jpeg` - Images and photos
- `*.stl`, `*.3mf` - 3D printing files
- `*.xlsx` - Spreadsheets and BOMs

### For Contributors

When contributing new files:
- **Large files** (>25MB) will automatically be tracked by Git LFS
- **No special commands needed** - just add and commit normally
- The `.gitattributes` file handles LFS routing automatically

---

## Project Structure

```
evo64/
├── documentation/           # Technical documentation and guides
├── image-gallery/           # Project photos and showcase images
├── promo-marketing/         # Marketing and promotional materials
├── 3D-printables/          # Community 3D printing files
│   ├── Cart Shield Cover/     # Cartridge port covers
│   ├── Keyboard Mounts/       # Various keyboard mounting solutions
│   ├── LCD Mounts/           # Display mounting hardware
│   ├── MSM Mounts/           # Multi Switch Module mounts
│   └── [Various creators]/    # Organized by contributor
├── ibom-html/              # Interactive bill of materials
└── README.md               # This file
```

---

## Contributing

We welcome contributions to the supporting materials! Here's how you can help:

### 3D Printables
- Submit STL/3MF files for new mounting solutions
- Include photos of printed parts and installations
- Provide clear documentation for your designs

### Documentation Improvements
- Corrections and clarifications to existing guides
- Additional setup instructions for different configurations
- Translation contributions

### Images
- High-quality photos of your EVO64 build
- Different case configurations and setups
- Assembly process documentation

### Contribution Process
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-mount-design`)
3. Add your files and documentation
4. Commit your changes (`git commit -m 'Add new LCD mount for XYZ case'`)
5. Push to the branch (`git push origin feature/new-mount-design`)
6. Open a Pull Request

---

## Important Notes

- **Hardware Design**: The PCB schematics and hardware design files are not included in this repository
- **Commercial Use**: Please respect any licensing terms associated with contributed files
- **File Sizes**: Large files are automatically handled by Git LFS - no special action required
- **Dependencies**: Some 3D printable designs may require specific hardware or case types

---

## Support & Community

- **Issues**: Report problems or request features via GitHub Issues
- **Discussions**: Join community discussions in GitHub Discussions
- **Documentation**: Check the `/documentation/` folder for detailed guides

---

## License

See the [LICENSE](LICENSE) file for details regarding the use of materials in this repository.

Individual contributors may have specific licensing terms for their submissions - please check individual file headers and accompanying documentation.

---

## Acknowledgments

Special thanks to all community contributors who have shared their 3D designs, documentation improvements, and build photos:

- **Sedor** - Multiple 3D printable designs and mounts
- **Jaystonian** - Keyboard mounting solutions
- **Perifractic** - C64c case compatibility mounts
- **BattleQuest** - MSM mounting hardware
- And many others in the EVO64 community!

---

*EVO64 - Bringing the C64 experience to the modern era*

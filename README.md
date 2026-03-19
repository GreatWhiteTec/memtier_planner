# MemTier Planner (Memory Tiering Sizer)

**MemTier Planner** is a workload planning and sizing utility designed to help system administrators, engineers, and architects evaluate and plan memory tiering deployments. This tool analyzes system requirements and helps optimize memory allocation across different performance tiers.

## 🗂️ Repository Contents

This repository provides multiple ways to run the tool, depending on your operating system and environment:

* **`MemTierSizer.ps1`**: The standard PowerShell script for Windows environments.
* **`MAC_Friendly_MemTierSizer.ps1`**: A macOS-optimized version of the PowerShell script (requires PowerShell Core).
* **`MemoryTieringSizer.exe`**: A standalone, compiled Windows executable. No PowerShell scripting experience required to run.
* **`Sizer_Tool.mp4`**: A video demonstration showing how to use the tool and interpret its output. 

## 🚀 Installation & Setup

### For Windows (Using the Executable)
1. Download `MemoryTieringSizer.exe` from the repository.
2. Double-click the executable to launch the sizing tool.

### For Windows (Using PowerShell)
1. Clone the repository or download `MemTierSizer.ps1`.
2. Open PowerShell as an Administrator.
3. Ensure your execution policy allows scripts to run:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

Execute the script 
   .\MemTierSizer.ps1

   ### For Mac OS (Using PowerShell)
1. Ensure you have PowerShell for macOS installed.
2. Clone the repository or download MAC_Friendly_MemTierSizer.ps1.
3. Open your terminal and launch PowerShell by typing pwsh.
4. Navigate to the directory containing the script and run:
    .\MAC_Friendly_MemTierSizer.ps1


## 📝 License

This project is licensed under a Custom Non-Commercial License. You are free to use and modify the tool for personal or internal use, but you may not sell, sub-license, or commercialize this software. See the [LICENSE](LICENSE) file for full details.

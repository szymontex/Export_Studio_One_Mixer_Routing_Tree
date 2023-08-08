# Studio One Mixer Tree Script

This script provides a simple way to visualize the mixer connections in Presonus Studio One by generating a clear text-based tree structure, making it easier to understand the connections between tracks, groups, and FX channels.

## Overview

When exporting stems after a mix session in Studio One, the exported files include regular stems, FX channels, and groups. This can be overwhelming and confusing. This tool generates a clear representation of how everything is connected, which is particularly useful when collaborating with others or for documentation purposes.

## Prerequisites

- **PowerShell**: The script is written in PowerShell, so you need a Windows-based system to run it.
- **Python**: Required to process and generate the mixer tree.

## How to Use

1. **Place the Script in Your Project Folder**: Ensure that the `.ps1` (PowerShell) and `.py` (Python) scripts are located in the same folder as your `.song` files.
2. **Run the PowerShell Script**: This will search for the most recent `.song` file in the directory, extract the necessary information, and then call the Python script.
    ```powershell
    .\MixerTree.ps1
    ```
3. **Check the Output**: After running the scripts, you'll find an `output.txt` file in the same directory. This file contains the mixer connection tree.

## How It Works

1. **Extracting the Mixer Data**: The PowerShell script first identifies the latest `.song` file and extracts its content. Studio One's `.song` files are essentially ZIP archives. The script locates the `audiomixer.xml` file within, which contains details about the mixer connections.
2. **Processing the Mixer Data**: The XML data from the `.song` file is processed to identify track, group, and FX connections.
3. **Generating the Tree**: The Python script then takes this data and constructs a text-based tree structure, showing how all the elements are interconnected.

## Note

This script is designed for use with Presonus Studio One. Using it with other DAWs or non-compatible files may lead to unexpected results.

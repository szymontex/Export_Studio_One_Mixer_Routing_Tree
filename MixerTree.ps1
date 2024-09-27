# Find the latest .song file in the current directory
$filePath = Get-ChildItem -Filter "*.song" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

if (-not $filePath) {
    Write-Error "No .song file found in the current directory."
    exit
}

Write-Output "Found the latest .song file: $filePath"

# Copy the .song file as .zip
$zipPath = "$filePath.zip"
Copy-Item -Path $filePath -Destination $zipPath

# Create a directory for unzipped content in the same directory as the .song file
$unzipDir = Join-Path -Path (Get-Item $filePath).DirectoryName -ChildPath "Unzipped_Content"
if (-Not (Test-Path $unzipDir)) {
    New-Item -Path $unzipDir -ItemType Directory | Out-Null
}

# Unzip the .zip file to the created directory using System.IO.Compression.ZipFile
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $unzipDir)

# Navigate to the Devices folder and locate the audiomixer.xml file
$audioMixerPath = Join-Path -Path $unzipDir -ChildPath "Devices\audiomixer.xml"

# Check if the audiomixer.xml file exists
if (Test-Path $audioMixerPath) {
    Write-Output "Found audiomixer.xml file"
} else {
    Write-Error "audiomixer.xml file not found"
    exit
}

# Load XML content as text
$xmlContent = Get-Content -Path $audioMixerPath -Raw

# Remove all occurrences of "x:" from the content
$xmlContent = $xmlContent -replace 'x:', ''

# Convert content to XML
[xml]$xmlData = $xmlContent

# Locate the main channel (AudioOutput)
$masterChannel = $xmlData.SelectSingleNode("//ChannelGroup[@name='AudioOutput']/AudioOutputChannel")
if ($masterChannel) {
    $masterName = $masterChannel.label
    Write-Output "Found master channel: $masterName"
} else {
    Write-Error "Master channel not found!"
    exit
}

# Function to extract connections from XML
function ExtractConnections {
    param ([xml]$xmlData)

    $connections = @()

    # Add the main channel (master) to the connections list
    $connections += [PSCustomObject]@{
        Name          = $masterName
        Connection    = ""
        SpeakerType   = ""
        Type          = "Master"
    }
    # List of FX channels
    $fxChannels = @()

    # Search for AudioEffectChannel (FX) channels
    foreach ($fx in $xmlData.SelectNodes('//AudioEffectChannel')) {
        if ($fx.disabled -ne "1") { # Exclude disabled channels
            $name = $fx.label
            $connection = $fx.Connection.friendlyName
            $speakerType = $fx.SpeakerSetup.type

            # If the connection contains "· Inserts", it's a sidechain - skip it
            if ($connection -like "*Insert*") {
                continue
            }

            $fxChannels += $name

            $connections += [PSCustomObject]@{
                Name          = $name
                Connection    = $connection
                SpeakerType   = $speakerType
                Type          = "FX"
            }
        }
    }

    # Search for AudioTrackChannel channels
    foreach ($channel in $xmlData.SelectNodes('//AudioTrackChannel')) {
        if ($channel.disabled -ne "1") { # Exclude disabled channels
            $name = $channel.label
            $connection = $channel.Connection.friendlyName
            $speakerType = $channel.SpeakerSetup.type

            # If the connection contains "· Inserts", it's a sidechain - skip it
            if ($connection -notlike "*Insert*") {
                $connections += [PSCustomObject]@{
                    Name          = $name
                    Connection    = $connection
                    SpeakerType   = $speakerType
                    Type          = "Audio"
                }
            }

            # Locate sends for the channel
            foreach ($send in $channel.Attributes.Attributes) {
                $sendName = $name
                $sendConnection = $send.Connection.friendlyName

                # Only add sends that are connected to FX channels
                if ($fxChannels -contains $sendConnection) {
                    $connections += [PSCustomObject]@{
                        Name          = $sendName
                        Connection    = $sendConnection
                        SpeakerType   = "Send"
                        Type          = "Send"
                    }
                }
            }
        }
    }

    # Search for AudioGroupChannel groups
    foreach ($group in $xmlData.SelectNodes('//AudioGroupChannel')) {
        if ($group.disabled -ne "1") { # Exclude disabled groups
            $name = $group.label
            $connection = $group.Connection.friendlyName

            $connections += [PSCustomObject]@{
                Name          = $name
                Connection    = $connection
                SpeakerType   = "Stereo"  # Assuming all groups are stereo
                Type          = "Group"
            }
        }
    }

    return $connections
}


# Extract connections from XML
$connections = ExtractConnections -xmlData $xmlData

# Display connections
$connections | Format-Table -AutoSize

# Save connections to a CSV file
$connections | Export-Csv -Path "connections.csv" -NoTypeInformation

# Optionally, run your Python script if necessary
python MixerTree.py

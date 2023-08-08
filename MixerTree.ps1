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

# Unzip the .zip file to a temporary directory
$tempDir = [System.IO.Path]::GetTempFileName()
Remove-Item $tempDir
Expand-Archive -Path $zipPath -DestinationPath $tempDir

# Navigate to the Devices folder and locate the audiomixer.xml file
$audioMixerPath = Join-Path -Path $tempDir -ChildPath "Devices\audiomixer.xml"

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

    # Search for AudioTrackChannel channels
    foreach ($channel in $xmlData.SelectNodes('//AudioTrackChannel')) {
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

    # Search for AudioGroupChannel groups
    foreach ($group in $xmlData.SelectNodes('//AudioGroupChannel')) {
        $name = $group.label
        $connection = $group.Connection.friendlyName

        $connections += [PSCustomObject]@{
            Name          = $name
            Connection    = $connection
            SpeakerType   = "Stereo"  # Assuming all groups are stereo
            Type          = "Group"
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

python MixerTree.py

#Template and rendering definitions
# Define the input dialog using Read-Variable
$dialog = @{
    Title = "Create Template and Rendering"
    Parameters = @(
        @{ Name = "TemplateName"; Title = "Template Name"; Tooltip = "Enter the name of the template"; Type = "String"; Mandatory = $true },
        @{ Name = "TemplateDisplayName"; Title = "Template Display Name(optional)"; Tooltip = "Enter the display name for the template"; Type = "String"; }
        @{ Name = "RenderingName"; Title = "Rendering Name"; Tooltip = "Enter the name of the rendering"; Type = "String"; Mandatory = $true },
        @{ Name = "RenderingDisplayName"; Title = "Rendering Display Name(optional)"; Tooltip = "Enter the display name for the rendering"; Type = "String"; },
        @{ Name = "RenderingComponentName"; Title = "Rendering Component Name"; Tooltip = "Enter name of the component"; Type = "String"; Mandatory = $true}
         @{ Name = "SourceFilePath"; Title = "Source File Path"; Tooltip = "Enter name of the component"; Type = "String"; Mandatory = $true}
    )
}

# Show the input dialog to the user
$result = Read-Variable @dialog

# If the user cancels the form, stop the script
if ($result -ne "ok") { return }

# Extract user inputs
$templateName = $TemplateName
$templateDisplayName = $TemplateDisplayName

# Define paths for template and rendering
$templateFolderPath = "/sitecore/templates/Project/BrandCenter/Basic Content"
$renderingFolderPath = "/sitecore/layout/Renderings/Project/BrandCenter/Basic Content"

# Define the paths where the new template and rendering will be created
$templatePath = "$templateFolderPath/$TemplateName"
$renderingPath = "$renderingFolderPath/$RenderingName"


# Step 1: Define the media item path or ID
$mediaItemPath = $SourceFilePath 

# Step 2: Get the media item
$mediaItem = Get-Item -Path $mediaItemPath

# Step 3: Check if the media item exists
if (-not $mediaItem) {
    Write-Host "Media item not found at the specified path: $mediaItemPath" -ForegroundColor Red
    return
}

# Step 4: Cast the item to a MediaItem
$mediaItem = [Sitecore.Data.Items.MediaItem]$mediaItem

# Step 5: Get the media file content
$fileStream = $mediaItem.GetMediaStream()

if (-not $fileStream) {
    Write-Host "Failed to retrieve the media stream." -ForegroundColor Red
    return
}

# Step 6: Save the file temporarily to process it
$tempFilePath = [System.IO.Path]::GetTempFileName() + ".tsx"
try {
    # Create a file stream to write to a temporary file
    $fileStreamObject = [System.IO.File]::Create($tempFilePath)
    $buffer = New-Object byte[] 8192
    $bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)

    while ($bytesRead -gt 0) {
        $fileStreamObject.Write($buffer, 0, $bytesRead)
        $bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)
    }

    $fileStreamObject.Close()

    # Step 7: Read the content of the .tsx file
    $reactCode = Get-Content -Path $tempFilePath -Raw

    # Step 8: Use regex to extract field names and types
    $fieldPattern = '(\w+)\??:\s+Field<string>;|(\w+)\??:\s+ImageField;|(\w+)\??:\s+LinkField;|(\w+)\??:\s+Field<Date>;|(\w+)\??:\s+Field<boolean>;'
    $fieldMatches = [regex]::Matches($reactCode, $fieldPattern)

    # Initialize an array to store the extracted fields and their types
    $fieldInfo = @()

    # Extract and store the field names and their types
    foreach ($match in $fieldMatches) {
        if ($match.Groups[1].Success) {
            $fieldName = $match.Groups[1].Value
            $fieldType = "Single-Line Text"
        } elseif ($match.Groups[2].Success) {
            $fieldName = $match.Groups[2].Value
            $fieldType = "Image"
        }elseif ($match.Groups[3].Success) {
            $fieldName = $match.Groups[3].Value
            $fieldType = "General Link"
        } elseif ($match.Groups[4].Success) {
            $fieldName = $match.Groups[4].Value
            $fieldType = "Date"
        } elseif ($match.Groups[5].Success) {
            $fieldName = $match.Groups[5].Value
            $fieldType = "Checkbox"
        }
        $fieldInfo += [PSCustomObject]@{ Name = $fieldName; Type = $fieldType }
    }

    # Display the extracted fields
    Write-Host "Extracted Fields:"
    $fieldInfo | ForEach-Object { Write-Host "$($_.Name): $($_.Type)" }
    
    
    #create the folder under the specified parent template folder path
   $templateFolderFullPath = "$templateFolderPath/$TemplateName"
   
   # Step 1: Check if the folder already exists, if not create it
    if (-not (Test-Path -Path $templateFolderFullPath)) {
    # Create the folder under the template folder path
    New-Item -Path $templateFolderFullPath -ItemType "/sitecore/templates/System/Templates/Template Folder"
    Write-Host "Folder '$templateFolderName' created at path: $templateFolderFullPath"
    } else {
    Write-Host "Folder '$templateFolderName' already exists at path: $templateFolderFullPath"
  }

    
    
    # Create the template in Sitecore
    $templateItem = New-Item -Path $templateFolderFullPath  -Name $TemplateName  -ItemType "/sitecore/templates/System/Templates/Template" -ErrorAction Stop
    $standardvalues = New-Item -Parent $templateItem -Name "__Standard Values" -type $templateItem.ID
    $templateItem.Editing.BeginEdit()
    $templateItem["__Display name"] = $templateDisplayName
    $templateItem["__Standard values"] = $standardvalues.ID
    $templateItem.Editing.EndEdit()
    
     #create a folder template for the template data item insertions.
    $templateFolderItem = New-Item -Path $templateFolderFullPath  -Name "$TemplateName Folder"  -ItemType "/sitecore/templates/System/Templates/Template" -ErrorAction Stop
    $standardvaluesForFolderItem = New-Item -Parent $templateFolderItem -Name "__Standard Values" -type $templateFolderItem.ID
    #add folder icon to the above created folder template
     $templateFolderItem.Editing.BeginEdit()
    $templateFolderItem["__Icon"] = "/~/icon/office/32x32/folder_open.png"
     $templateFolderItem.Editing.EndEdit()
      $standardvaluesForFolderItem.Editing.BeginEdit()
    $standardvaluesForFolderItem["__Masters"] = $templateItem.ID
    $standardvaluesForFolderItem.Editing.EndEdit()
 

    # Create the Template Section (Optional)
    $templateSection = New-Item -Path "$($templateItem.Paths.FullPath)" -Name "Content" -ItemType "/sitecore/templates/System/Templates/Template section"

    #  Create fields in the "Content" section for each extracted field
    foreach ($field in $fieldInfo) {
        $templateField = New-Item -Path $templateSection.Paths.FullPath -Name $field.Name -ItemType "/sitecore/templates/System/Templates/Template field"
        $templateField.Editing.BeginEdit()
        $templateField["Type"] = $field.Type  # Set the field type (e.g., Single-Line Text or Image)
        $templateField["Title"] = $field.Name
        $templateField.Editing.EndEdit()
        Write-Host "Created field: $($field.Name) of type: $($field.Type)"
    }

    #Output success message
    Write-Host "Template and fields created successfully!"
}
finally {
    # Clean up: Delete the temporary file if it exists
    if (Test-Path $tempFilePath) {
        Remove-Item -Path $tempFilePath -Force
    }
}

if (Get-Item -Path $renderingPath -ErrorAction SilentlyContinue)
{
    Write-Host "Rendering is already existed at path $renderingPath"
}
else 
{
    # --- Step 2: Create the Rendering ---
$renderingItem = New-Item -Path $renderingPath -ItemType "/sitecore/templates/Foundation/JavaScript Services/Json Rendering" -ErrorAction Stop
$renderingItem.Editing.BeginEdit()
$renderingItem["__Display name"] = $RenderingDisplayName
$renderingItem["componentName"] = $RenderingComponentName
#set datasource template
if ($null -ne $templateItem)
{
    $renderingItem["Datasource Template"] = $templateItem.Paths.FullPath
    
}
$renderingItem.Editing.EndEdit()
}


    # Create the data item under the data folder path
     $dataFolderItem = New-Item -Path "/sitecore/content/BrandCenter/brandcenter/Data" -Name "$TemplateName Folder"  -ItemType $templateFolderItem.Paths.FullPath -ErrorAction Stop
     if ($null -ne $dataFolderItem)
     {
         $dataItem = New-Item -Parent $dataFolderItem  -Name "$TemplateName Item"  -ItemType $templateItem.Paths.FullPath -ErrorAction Stop
         
     }
    Write-Host "Folder '$templateFolderName' created at path: $templateFolderFullPath"
    
   
    #create page item
     $pageItem = New-Item -Path "/sitecore/content/BrandCenter/brandcenter/Home" -Name "$TemplateName Test Page"  -ItemType '/sitecore/templates/Foundation/JSS Experience Accelerator/Multisite/Base Page' -ErrorAction Stop
     
    Write-Host "Page item created"
    

   #add rendering to the page item

$renderingItemAsRendering = $renderingItem | New-Rendering -Placeholder "headless-main"

# Add the rendering to the item
Add-Rendering -Item $pageItem -PlaceHolder "headless-main" -Instance $renderingItemAsRendering -Parameter @{ "Reset Caching Options" = "1" } -DataSource $dataItem.Paths.FullPath -FinalLayout
    
    
Show-Alert "Script Executed successfully!"
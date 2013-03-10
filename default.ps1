$framework = '4.0x86'

properties {
	$base_dir = resolve-path .
	$build_dir = "$base_dir\build"
	$dist_dir = "$base_dir\release"
	$source_dir = "$base_dir\src"
	$tools_dir = "$base_dir\tools"
	$test_dir = "$build_dir\test"
	$result_dir = "$build_dir\results"
	$lib_dir = "$base_dir\lib"
	$pkgVersion = if ($env:build_number -ne $NULL) { $env:build_number } else { '2.3.0' }
	$version = $pkgVersion -replace "-.*$", ""
	$buildNumber = $version + '.0'
	$global:config = "debug"
	$framework_dir = Get-FrameworkDirectory
}


task default -depends local
task local -depends compile, test
task full -depends local, dist
task ci -depends clean, release, commonAssemblyInfo, local, dist

task clean {
	delete_directory "$build_dir"
	delete_directory "$dist_dir"
}

task release {
    $global:config = "release"
}

task compile -depends clean { 
    exec { msbuild /t:Clean /t:Build /p:Configuration=$config /v:q /p:NoWarn=1591 /nologo $source_dir\AutoMapper.sln }
}

task commonAssemblyInfo {
    $commit = if ($env:BUILD_VCS_NUMBER -ne $NULL) { $env:BUILD_VCS_NUMBER } else { git log -1 --pretty=format:%H }
    create-commonAssemblyInfo "$buildNumber" "$commit" "$source_dir\CommonAssemblyInfo.cs"
}

task test {
	create_directory "$build_dir\results"
    exec { & $lib_dir\xunit.net\xunit.console.clr4.x86.exe $source_dir/UnitTests/bin/NET4/$config/AutoMapper.UnitTests.dll /xml $result_dir\AutoMapper.NET4.xml }
    exec { & $tools_dir\statlight\statlight.exe -x $source_dir/UnitTests/bin/SL4/$config/AutoMapper.UnitTests.xap -d $source_dir/UnitTests/bin/SL4/$config/AutoMapper.UnitTests.dll --ReportOutputFile=$result_dir\AutoMapper.SL4.xml --ReportOutputFileType=NUnit }
    exec { & $lib_dir\xunit.net\xunit.console.clr4.x86.exe $source_dir/UnitTests/bin/WinRT/$config/AppX/AutoMapper.UnitTests.dll /xml $result_dir\AutoMapper.WinRT.xml }
}

task dist {
	create_directory $dist_dir
	copy_files "$build_dir\$config\AutoMapper" "$dist_dir\net40-client"
    create-nuspec "$pkgVersion" "AutoMapper.nuspec"
}

# -------------------------------------------------------------------------------------------------------------
# generalized functions 
# --------------------------------------------------------------------------------------------------------------
function Get-FrameworkDirectory()
{
    $([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory().Replace("v2.0.50727", "v4.0.30319"))
}

function global:zip_directory($directory, $file)
{
    delete_file $file
    cd $directory
    exec { & "$tools_dir\7-zip\7za.exe" a $file *.* }
    cd $base_dir
}

function global:delete_directory($directory_name)
{
  rd $directory_name -recurse -force  -ErrorAction SilentlyContinue | out-null
}

function global:delete_file($file)
{
    if($file) {
        remove-item $file  -force  -ErrorAction SilentlyContinue | out-null} 
}

function global:create_directory($directory_name)
{
  mkdir $directory_name  -ErrorAction SilentlyContinue  | out-null
}

function global:copy_files($source, $destination, $exclude = @()) {
    create_directory $destination
    Get-ChildItem $source -Recurse -Exclude $exclude | Copy-Item -Destination {Join-Path $destination $_.FullName.Substring($source.length)} 
}

function global:create-commonAssemblyInfo($version, $commit, $filename)
{
	$date = Get-Date
    "using System;
using System.Reflection;
using System.Runtime.InteropServices;

//------------------------------------------------------------------------------
// <auto-generated>
//     This code was generated by a tool.
//     Runtime Version:2.0.50727.4927
//
//     Changes to this file may cause incorrect behavior and will be lost if
//     the code is regenerated.
// </auto-generated>
//------------------------------------------------------------------------------

[assembly: AssemblyVersionAttribute(""$pkgVersion"")]
[assembly: AssemblyFileVersionAttribute(""$version"")]
[assembly: AssemblyCopyrightAttribute(""Copyright Jimmy Bogard 2008-" + $date.Year + """)]
[assembly: AssemblyProductAttribute(""AutoMapper"")]
[assembly: AssemblyTrademarkAttribute(""AutoMapper"")]
[assembly: AssemblyCompanyAttribute("""")]
[assembly: AssemblyConfigurationAttribute(""release"")]
[assembly: AssemblyInformationalVersionAttribute(""$commit"")]"  | out-file $filename -encoding "ASCII"    
}

function global:create-nuspec($version, $fileName)
{
    "<?xml version=""1.0""?>
<package xmlns=""http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd"">
  <metadata>
    <id>AutoMapper</id>
    <version>$version</version>
    <authors>Jimmy Bogard</authors>
    <owners>Jimmy Bogard</owners>
    <licenseUrl>https://github.com/AutoMapper/AutoMapper/blob/master/LICENSE.txt</licenseUrl>
    <projectUrl>http://automapper.org</projectUrl>
    <iconUrl>https://s3.amazonaws.com/automapper/icon.png</iconUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <summary>A convention-based object-object mapper</summary>
    <description>A convention-based object-object mapper. AutoMapper uses a fluent configuration API to define an object-object mapping strategy. AutoMapper uses a convention-based matching algorithm to match up source to destination values. Currently, AutoMapper is geared towards model projection scenarios to flatten complex object models to DTOs and other simple objects, whose design is better suited for serialization, communication, messaging, or simply an anti-corruption layer between the domain and application layer.</description>
  </metadata>
  <files>
    <file src=""$dist_dir\net40-client\AutoMapper.dll"" target=""lib\net40"" />
    <file src=""$dist_dir\net40-client\AutoMapper.pdb"" target=""lib\net40"" />
    <file src=""$dist_dir\net40-client\AutoMapper.xml"" target=""lib\net40"" />
    <file src=""**\*.cs"" target=""src"" />
  </files>
</package>" | out-file $build_dir\$fileName -encoding "ASCII"
}


# powershell -ExecutionPolicy Unrestricted tools/build.ps1 URL_BASE=https://www.ipvs.uni-stuttgart.de/files/pas/src
# powershell -ExecutionPolicy Unrestricted tools/build.ps1 URL_BASE=origin

set ErrorActionPreference Stop
Set-StrictMode -Version 2.0

$dbus_python_version="1.2.4"

echo "Starting..."

$URL_BASE = $env:URL_BASE
ForEach ($arg in $args) {
  if ($arg.StartsWith("URL_BASE=")) {
    $URL_BASE=$arg.Substring("URL_BASE=".Length)
  }
}

$dir = (Get-Item -Path ".\" -Verbose).FullName

function CheckErrorCode {
  if (-Not $?) {
    throw "Command execution failed: " + $args
  }
}

function RMrf {
  ForEach ($arg in $args) {
    if (Test-Path $arg) {
      rmdir -recurse -force $arg
      CheckErrorCode
    }
  }
}

function External {
  $args2 = $($args | % {$_})
  $par = $args2[1..($args2.Length-1)]
  &$args2[0] $par
  CheckErrorCode ($args2 -join ' ')
}

$files = @(
  "ICSharpCode.SharpZipLib.dll",
  "7za920.zip",
  "dbus-1.8.2.zip",
  "python-3.5.3-embed-amd64.zip",
  "python-3.5.3-amd64/dev.msi",
  "dbus-python-$dbus_python_version.tar.gz"
)

$files = New-Object System.Collections.ArrayList(,$files)

$pkgsStr = [IO.File]::ReadAllText("tools/msys2-pkglist.txt")
$pkgsStrInst = ""
if (Test-Path "build/msys2-pkglist-installed.txt") {
  $pkgsStrInst = [IO.File]::ReadAllText("build/msys2-pkglist-installed.txt")
}
$pkgs = New-Object System.Collections.ArrayList
ForEach ($pkg in $pkgsStr.Split("`n")) {
  $pkg = $pkg.Trim()
  if ($pkg -eq "") {
    continue
  }
  $pkgs.Add($pkg) | Out-Null
  $files.Add("msys2/" + $pkg + ".pkg.tar.xz") | Out-Null
}

#echo $files
echo "Checking files..."
$algorithm = [Security.Cryptography.HashAlgorithm]::Create("SHA512")
ForEach ($file in $files) {
  #echo $file
  $expSum = [IO.File]::ReadAllText("files/$file.sha512sum").Split(" ")[0]
  if ($expSum.Length -ne 128) {
    throw "Checksum in files/$file.sha512sum has length $($expSum.Length)"
  }
  if (Test-Path "files/$file") {
    $fileBytes = [IO.File]::ReadAllBytes("files/$file")
    $bytes = $algorithm.ComputeHash($fileBytes)
    $sum = -Join ($bytes | ForEach {"{0:x2}" -f $_})
    if ($sum -ne $expSum) {
      throw "Checksum for existing file files/$file does not match: Expected $expSum, got $sum"
    }
  } else {
    if ( $URL_BASE -eq "" -or $URL_BASE -eq $null ) {
      throw "URL_BASE not set and file $file not found"
    }
    Write-Host "Getting $file..." -NoNewLine
    if ( $URL_BASE -eq "origin" ) {
      $url = [IO.File]::ReadAllText("files/$file.url").Trim()
    } else {
      $url = "$URL_BASE/$file"
    }
    (New-Object System.Net.WebClient).DownloadFile($url, "files/$file.new")
    Write-Host " done"
    $fileBytes = [IO.File]::ReadAllBytes("files/$file.new")
    $bytes = $algorithm.ComputeHash($fileBytes)
    $sum = -Join ($bytes | ForEach {"{0:x2}" -f $_})
    if ($sum -ne $expSum) {
      throw "Checksum for downloaded file files/$file does not match: Expected $expSum, got $sum"
    }
    [IO.File]::Move("files/$file.new", "files/$file")
  }
}
echo "Done checking files."

if ($pkgsStr -ne $pkgsStrInst) {
  if (0) {
    Write-Host "Deleting build dir..." -NoNewLine
    RMrf build
    echo " done."
    New-Item -type directory build | Out-Null
  } else {
    Write-Host "Deleting build/msys2..." -NoNewLine
    RMrf build/msys2 build/msys2-tar build/msys2-pkglist-installed.txt
    echo " done."
  }
  
  [System.Reflection.Assembly]::LoadFile($dir + "/files/ICSharpCode.SharpZipLib.dll") | Out-Null
  (New-Object ICSharpCode.SharpZipLib.Zip.FastZip).ExtractZip("files/7za920.zip", "build", "7za.exe")
  
  # Unpack tar first, some packages contain hardlink which are broken when extracted with 7z: https://sourceforge.net/p/msys2/tickets/21/
  # for i in files/msys2/*.pkg.tar.xz; do tar tvf "$i" | grep -q ^h && echo $i; done
  $InitialPkgs=@("msys2-runtime", "libiconv", "libintl", "tar", "liblzma", "xz")
  Write-Host "Unpacking msys2 tar..." -NoNewLine
  New-Item -type directory build/msys2 | Out-Null
  New-Item -type directory build/msys2-tar | Out-Null
  $i = 0
  ForEach ($pkg in $pkgs) {
    $isInitial = 0
    ForEach ($pkg2 in $InitialPkgs) {
      if ($pkg.StartsWith($pkg2 + "-")) {
        $isInitial = 1
      }
    }
    if (-Not $isInitial) {
      continue
    }
    $i = $i + 1
    Write-Host " $i/$($InitialPkgs.Count)" -NoNewLine
    #External build/7za -obuild/msys2 x "files/msys2/$pkg.pkg.tar.xz"
    #External build/7za x "files/msys2/$pkg.pkg.tar.xz" -so | build/7za x -aoa -si -ttar -obuild/msys2
    External build/7za -obuild/msys2-tar x "files/msys2/$pkg.pkg.tar.xz" | Out-Null
    External build/7za -obuild/msys2 x -aoa "build/msys2-tar/$pkg.pkg.tar" | Out-Null
  }
  echo " done"
  RMrf build/msys2-tar
}

$env:PATH = "$dir/build/msys2/usr/bin;$dir/build/msys2/mingw64/bin;$env:PATH"
$env:MSYSTEM = "MINGW64"

if ($pkgsStr -ne $pkgsStrInst) {
  Write-Host "Extracting msys2..." -NoNewLine
  $i = 0
  ForEach ($pkg in $pkgs) {
    $isInitial = 0
    ForEach ($pkg2 in $InitialPkgs) {
      if ($pkg.StartsWith($pkg2 + "-")) {
        $isInitial = 1
      }
    }
    if ($isInitial) {
      continue
    }
    $i = $i + 1
    Write-Host " $i/$($pkgs.Count)" -NoNewLine
    External build/msys2/usr/bin/tar xf "files/msys2/$pkg.pkg.tar.xz" -C build/msys2
  }
  #External build/msys2/usr/bin/chmod u+w -R build/msys2
  echo " done"
  [IO.File]::WriteAllText("build/msys2-pkglist-installed.txt", $pkgsStr)
}

$dirmsys = (cygpath -u $dir) | Out-String
CheckErrorCode
$dirmsys = $dirmsys.TrimEnd()

echo "Unpacking python..."
RMrf $dir/build/python
New-Item -type directory $dir/build/python | Out-Null
External "$dir/build/7za" x "$dir/files/python-3.5.3-embed-amd64.zip" "-o$dir/build/python" | Out-Null
New-Item -type directory $dir/build/python/msi | Out-Null
External build/msys2/usr/lib/p7zip/7z.exe x "$dirmsys/files/python-3.5.3-amd64/dev.msi" "-o$dirmsys/build/python/msi" | Out-Null
Get-ChildItem $dir/build/python/msi | Foreach-Object {
  $name = $_.Name
  $array = $name.Split("_", 2)
  $dirn = $array[0]
  $file = $array[1]
  if (-Not (Test-Path $dir/build/python/$dirn)) {
    New-Item -type directory "$dir/build/python/$dirn" | Out-Null
  }
  [IO.File]::Move("build/python/msi/$name", "build/python/$dirn/$file")
}
rmdir $dir/build/python/msi
echo "Done."

function ConfigureBuild {
  $args2 = New-Object System.Collections.ArrayList
  ForEach ($arg in $args) { $args2.Add($arg) | Out-Null }
  $name = $args2[0]
  $args2.RemoveAt(0)
  $ext = $args2[0]
  $args2.RemoveAt(0)
  $method = $args2[0]
  $args2.RemoveAt(0)

  $new_PKG_CONFIG_PATH = "$dirmsys/build/$name-install/lib/pkgconfig:$env:PKG_CONFIG_PATH"
  $new_PATH = "$dirmsys/build/$name-install/bin;$env:PATH"
  if (Test-Path "$dir/build/$name.installed") {
    $env:PKG_CONFIG_PATH = $new_PKG_CONFIG_PATH
    $env:PATH = $new_PATH
    return
  }
  echo "Building $name"
  RMrf "$dir/build/$name" "$dir/build/$name-install" "$dir/build/$name.installed"
  if ( $ext -eq "zip" ) {
    External "$dir/build/7za" x "$dir/files/$name.$ext" "-o$dir/build" | Out-Null
  } else {
    External "$dir/build/msys2/usr/bin/tar" xf "$dirmsys/files/$name.$ext" -C "$dirmsys/build"
  }
  RMrf "$dir/build/$name/build-dir"
  New-Item -type directory "$dir/build/$name/build-dir" | Out-Null
  cd "$dir/build/$name/build-dir"
  if ( $method -eq "cmake" ) {
    $sedexpr = $args2[0]
    $args2.RemoveAt(0)
    External sed -i $sedexpr ../cmake/CMakeLists.txt ../cmake/*/CMakeLists.txt

    External env CFLAGS="-I.. -I../.." CXXFLAGS="-I.. -I../.." cmake "-DCMAKE_INSTALL_PREFIX=$dirmsys/build/$name-install" -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=Windows -G "Unix Makefiles" -Wno-dev $args2 ../cmake
  } elseif ( $method -eq "autoconf" ) {
    $sedexpr = $args2[0]
    $args2.RemoveAt(0)
    External sed -i $sedexpr ../Makefile.am ../Makefile.in

    External bash ../configure --prefix="$dirmsys/build/$name-install" $args2
  } else {
    throw "Unknown method: " + $method
  }
  External make -j8
  #External make V=1 VERBOSE=1
  External make install
  [IO.File]::WriteAllText("$dir/build/$name.installed", "")
  cd "$dir"
  $env:PKG_CONFIG_PATH = $new_PKG_CONFIG_PATH
  $env:PATH = $new_PATH
}

ConfigureBuild dbus-1.8.2 zip cmake 's,add_subdirectory( bus ),,;s,add_subdirectory( tools ),,;s,add_subdirectory( doc ),,;s,install(,set_target_properties(dbus-1 PROPERTIES PREFIX """")\ninstall(,' -DDBUS_BUILD_TESTS=OFF

$sedexp='s,noinst_LTLIBRARIES =.*,,'
$sedexp=$sedexp + ';/^\t_dbus_glib_bindings.la/d' # Don't build GLib bindings
#$python_include = "$dirmsys/build/python/include"
$python_include = "$dirmsys/build/msys2/mingw64/include/python3.5m" # Use includes from msys2/mingw because they include patches without which the resulting binary will be broken
ConfigureBuild dbus-python-$dbus_python_version tar.gz autoconf $sedexp PYTHON_CONFIG=":" PYTHON=$dirmsys/build/python/python.exe PYTHON_LIBS="-L$dirmsys/build/python/libs -lpython" PYTHON_INCLUDES="-I$python_include" --enable-shared --disable-static DBUS_CFLAGS="-I$dirmsys/build/dbus-1.8.2-install/include" DBUS_LIBS="-L$dirmsys/build/dbus-1.8.2-install/lib -ldbus-1" DBUS_GLIB_CFLAGS="-I." DBUS_GLIB_LIBS="-L."

cd "$dir"

RMrf build/out
New-Item -type directory build/out | Out-Null
CheckErrorCode

echo "Copying output files..."
Copy-Item "build/dbus-1.8.2-install/bin/*.dll" "build/out/"
Copy-Item -recurse "build/dbus-python-$dbus_python_version-install/lib/python3.5/site-packages/dbus" "build/out/"
Copy-Item "build/dbus-python-$dbus_python_version-install/lib/python3.5/site-packages/_dbus_bindings.pyd" "build/out/"
Copy-Item "build/dbus-1.8.2/COPYING" "build/out/COPYING.dbus.txt"
Copy-Item "build/dbus-python-$dbus_python_version/COPYING" "build/out/COPYING.dbus-python.txt"
sed 's/$/\r/' -i build/out/COPYING.*.txt
echo "Done copying output files."

$zipfile="dbus-$dbus_python_version-cp35-none-win_amd64.zip"
echo "Packing output files..."
RMrf build/$zipfile
cd build/out
External zip -r ../$zipfile . | Out-Null
cd ../..
echo "Done packing output files."
RMrf $zipfile
[IO.File]::Move("build/$zipfile", "$zipfile")

echo "Done"

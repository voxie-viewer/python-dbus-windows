Build scripts for dbus-python on Windows
========================================

This repository contains build scripts to compile the DBus library and the
dbus-python bindings for Windows (amd64). On the Github releases page you can
also find binary packages.

The build process can be started using

    powershell -ExecutionPolicy Unrestricted tools/build.ps1 URL_BASE=https://www.ipvs.uni-stuttgart.de/files/pas/src

or

    powershell -ExecutionPolicy Unrestricted tools/build.ps1 URL_BASE=origin

The first command will download dependencies from www.ipvs.uni-stuttgart.de,
the second command will download dependencies from the original server (which
will be a lot slower).

The script will then unpack msys2 and use it to compile the DBus library
(without the daemon) and the dbus-python bindings for CPython 3.5.
The results will be packed into a ZIP file.
As the ZIP file contains both the python bindings and the DBus library itself,
it can be used to connect to a DBus daemon without any dependencies other than
python, but the DBus daemon itself is not included.
The bindings for dbus-glib are also not included (because they would add a
dependency on glib), meaning that there currently is no mainloop support.

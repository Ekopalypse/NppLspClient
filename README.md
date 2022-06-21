# NppLSPClient
A [LSP](https://microsoft.github.io/language-server-protocol/) client plugin for Notepad++.

***NOTE: The latest builds assume that the Folder as Workspace (faw) dialog is used.  
This means that the rootPath component of the [initialize request](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#initializeParams) sent from the client to the server  
is set to the directory of the root item that contains the current buffer. 
If no faw dialog is used or the file is not part of one of the root elements, the directory of the file is used.***

## Installation

- Download and unpack the NppLspClient zip-archive (the NppLspClient_x*86 or 64*.zip) from https://github.com/Ekopalypse/NppLspClient/releases to the folder "Notepad++\plugins".
- Install a language server of your choice
- Configure it by calling "Open configuration" from the NppLspClient plugin menu. (You will find a more detailed description in the configuration file.)

## Usage example

- Start Notepad++
- Open a source file
- Run "Start server for current language"


## Building manually

This plugin is written in the [programming language V](https://github.com/vlang/v) and must therefore be available to build this plugin.  
Furthermore, a current version of the gcc compiler, >= version 10 recommended, must be installed.  
An example for the use with NppExec:

```
cd $(CURRENT_DIRECTORY)

set PROJECT=NppLspClient
set VEXE=d:\programdata\compiler\v\v.exe

set ARCH=x64
set CC=gcc

// build resources
set local RC = $(CURRENT_DIRECTORY)\$(NAME_PART).rc
cmd /c if not exist $(RC) exit -1
if $(EXITCODE) == -1 then
  set local RES_OBJ=
else
  set local RES_OBJ=-cflags $(CURRENT_DIRECTORY)\$(NAME_PART).res
endif

set NPPPATH=D:\Tests\npp\812\$(ARCH)
set PLUGIN_DIR=$(NPPPATH)\plugins\$(PROJECT)

cmd /c if not exist $(PLUGIN_DIR) exit -1

if $(EXITCODE) == -1 then
  cmd /c mkdir $(PLUGIN_DIR)
endif

set PLUGIN_PATH=$(PLUGIN_DIR)\$(PROJECT).dll

set COMPILER_FLAGS= -g -d static_boehm -gc boehm -keepc -enable-globals -shared -d no_backtrace

if $(ARCH)==x64 then
  if $(CC)==gcc then
    windres "$(RC)" -O coff -o "$(CURRENT_DIRECTORY)\$(NAME_PART).res"
    echo $(VEXE) -cc $(CC) $(COMPILER_FLAGS) -cflags -static-libgcc -cflags -I$(CURRENT_DIRECTORY) $(RES_OBJ) -o $(PLUGIN_PATH) .
    $(VEXE) -cc $(CC) $(COMPILER_FLAGS) -cflags -static-libgcc -cflags -I$(CURRENT_DIRECTORY) $(RES_OBJ) -o $(PLUGIN_PATH) .
  endif  
else
  if $(CC)==gcc then
    ENV_SET PATH=D:\ProgramData\Compiler\mingw32\bin
    windres "$(RC)" -O coff -o "$(CURRENT_DIRECTORY)\$(NAME_PART).res"
    $(VEXE) -cc $(CC) -m32 -g $(COMPILER_FLAGS) -cflags -static-libgcc -cflags -I$(CURRENT_DIRECTORY) $(RES_OBJ) -o $(PLUGIN_PATH) .
    ENV_UNSET PATH
  endif
endif

```


## Release History

* 0.0.13
    * Work in progress

## Meta

Distributed under the MIT license. See ``LICENSE`` for more information.

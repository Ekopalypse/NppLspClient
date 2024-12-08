# Tips & Tricks

1. USE Folder as Workspace(FAW).  
The language server protocol (lsp) specifies that the client must specify the root directory of the current source code files. This makes sense when you consider how language servers work. They need to know where the source files are located in order to provide completions, hints, etc. NppLspClient uses the root element of the FAW dialog, to determine this directory. If the currently opened file is not contained in any of the configured root elements or the FAW dialog is not active, the directory of the current file will be used instead.

2. DO NOT USE CLONED buffers.

3. DO NOT use Npp internal builtin functions to reload an open buffer.  
If an open file needs to be reloaded because it has changed externally, close the file and reopen it or use the 'Reload current file' function from the plug-in menu.

4. Use the console dialog  
Starting and stopping of a language server and other relevant information is logged in the console dialog. In addition, the entire communication between client and server is logged in debug mode in order to determine the cause in the event of a problem. Note that using debug mode has a significant impact on overall performance.

5. Use the documentation of the language servers  
There is no standard method for configuring language servers. Each has its own parameters or additional information about what needs to be done to make the communication between client and server work well. For example, language servers like clangd need information about how the code should be compiled.

# Known working language servers and their sample configuration in alphabetical order

***`Note that C:\WHATEVER_PATH must be replaced with the concrete full path.`***


## C/C++
### Installation
See https://clangd.llvm.org

### Notes
Checkout the information about compile_commands.
Test was done using clangd from the GCC and MinGW-w64 for Windows bundle from https://winlibs.com/#download-release

### Configuration
```toml
[lspservers."c++"]
mode = "io"
executable = 'D:\WHATEVER_PATH\clangd.exe'
args = '--offset-encoding=utf-8 --pretty --query-driver=D:/WHATEVER_PATH/clang++.exe'
auto_start_server = false

[lspservers."c"]
mode = "io"
executable = 'D:\WHATEVER_PATH\clangd.exe'
args = '--offset-encoding=utf-8 --log=verbose --query-driver=D:/WHATEVER_PATH/gcc.exe'
auto_start_server = false
```
## Clojure
### Installation
Use the binary from https://github.com/clojure-lsp/clojure-lsp/releases

### Notes
There is a known problem that is documented [here](https://github.com/Ekopalypse/NppLspClient/issues/6#issuecomment-1152931523).
Currently it appears that Npp and the initial source file used to start the language server must use the same drive.

### Configuration
```toml
[lspservers.clojure]
mode = "io"
executable = 'C:\WHATEVER_PATH\clojure-lsp.exe'
args = '--log-path D:\Tests\lsps\clojure'
auto_start_server = false
```

## D
### Installation
Use the binary from https://github.com/Pure-D/serve-d/releases

### Notes
See https://github.com/Pure-D/serve-d for more details.
When exiting Npp, the serve-d.exe may still be running.

### Configuration
```toml
[lspservers.d]
mode = "io"
executable = 'C:\WHATEVER_PATH\serve-d.exe'
args = '--wait true --logfile d:\serve_d.log --loglevel all'
auto_start_server = false
```

## Go
### Installation
After installing the go compiler use *go install golang.org/x/tools/gopls@latest* to install gopls.

### Configuration
```toml
[lspservers.go]
mode = "io"
executable = 'C:\WHATEVER_PATH\gopls.exe'
auto_start_server = false
```

## Python
### Installation
Use *`pip install python-lsp-server`* or *`pip install python-lsp-server[all]`*

### Notes
See https://github.com/python-lsp/python-lsp-server for more details.

### Configuration
```toml
[lspservers.python]
mode = "io"
executable = 'C:\WHATEVER_PATH\pylsp.exe'
args = '--check-parent-process --log-file D:\log.txt -vvv'
auto_start_server = false
```

## Rust
### Installation
Use *`rustup component add rust-analyzer`*

### Notes
See https://rust-analyzer.github.io/manual.html for more information about usage and installation.


### Configuration
```toml
[lspservers.rust]
mode = "io"
executable = 'C:\WHATEVER_PATH\rust-analyzer.exe'
auto_start_server = false
```

## V
### Installation
Use the binary from https://github.com/vlang/v-analyzer/releases

### Notes
This is a wip project and therefore not yet as stable as the others.
It works more or less, but expect v-analyzer.exe crashes.

### Configuration
```toml
[lspservers.vlang]
mode = "io"
executable = 'C:\WHATEVER_PATH\v-analyzer.exe'
auto_start_server = false
```

## Terraform/HCL
### Installation
Use the binary from https://releases.hashicorp.com/terraform-ls/

### Notes

Terraform/HCL isn't an officially supported language, so you need to add it as a user defined language with name 'terraform'. One example how to do that could be found on [Notepad++ forum](https://community.notepad-plus-plus.org/topic/20295/terraform-hcl-syntax-highlighting-support/14).

Terraform-ls has a bug [#791](https://github.com/hashicorp/terraform-ls/issues/791) that prevents it from exiting when receiving a SIGTERM signal from NppLspClient plugin. You may need to kill server manually to avoid memory leaks.

### Configuration
```toml
[lspservers.terraform]
mode = "io"
executable = 'C:\WHATEVER_PATH\terraform-ls.exe'
args = 'serve'
auto_start_server = false
```

*If you are using another language server and want to tell the community how to configure it, \
I would ask you to either open an issue with the tag "Tips & Tricks" and explain it there or, \
if you want to, open a pull request. \
Thanks in advance.*

# Tips & Tricks

1. USE Folder as Workspace(FAW).  
The language server protocol (lsp) specifies that the client must specify the root directory of the current source code files. This makes sense when you consider how language servers work. They need to know where the source files are located in order to provide completions, hints, etc. NppLspClient uses the root element of the FAW dialog, to determine this directory. If the currently opened file is not contained in any of the configured root elements or the FAW dialog is not active, the directory of the current file will be used instead.

2. DO NOT reload an open buffer.  
If the current active file or another previously opened file needs to be reloaded because it has changed externally close the file and reopen it instead. Once you open a source file in Npp, the language servers assumes that the client is providing the information about changes. However, currently the client does not monitor these files.

3. DO NOT USE CLONED buffers.

4. Avoid using rectangular or multi-cursor inserts.
Although this works in most cases, we may either hit a deadlock situation or the server will crash from time to time. I am not 100% sure if this is a client or server issue.

5. Restart the language server
In cases where Npp seems to hang, try stopping the language server. If this doesn't help, kill the process via task manager.

6. Use the log dialog
In debug mode, all client and server communication and other relevant actions are logged via the console log to help identify the cause in case of a problem.

7. Use the documentation of the language servers  
There is no standard way to configure language servers. Each has its own parameters or additional information about what to do to make the communication between client and server good. For example, language servers like clangd need the  information on how to compile the code.

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
executable = 'C:\WHATEVER_PATH\clangd.exe'
args = '--offset-encoding=utf-8 --pretty'
auto_start_server = false

[lspservers."c"]
mode = "io"
executable = 'C:\WHATEVER_PATH\clangd.exe'
args = '--offset-encoding=utf-8 --pretty'
auto_start_server = false
```
## Clojure
### Installation
Use the binary from https://github.com/clojure-lsp/clojure-lsp/releases

### Notes
There is known issue documented [here](https://github.com/Ekopalypse/NppLspClient/issues/6#issuecomment-1152931523).  
Currently it seems that Npp and the initial source file used to start the language server must use the same drive.

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
Use *`rustup component add rls rust-analysis rust-src`*

### Notes
See https://github.com/rust-lang/rls for more information about usage and installation.  
There seems to be a problem when using comments, it slows down the communication between client and server noticeably. Needs to be investigated further.

### Configuration
```toml
[lspservers.rust]
mode = "io"
executable = 'C:\WHATEVER_PATH\rls.exe'
auto_start_server = false
```

## V
### Installation
Use the binary from https://github.com/vlang/vls/releases

### Notes
This is a wip project and therefore not yet as stable as the others.  
It works more or less, but expect crashes.  
Also, when starting the server, watch out for a hanging v.exe process that is blocking vls. Kill this process via the task manager and communication to vls should work.

### Configuration
```toml
[lspservers.vlang]
mode = "io"
executable = 'C:\WHATEVER_PATH\vls.exe'
args = '--vroot=D:\ProgramData\Compiler\v --timeout=10 --debug'
auto_start_server = false
```


*If you are using another language server and want to tell the community how to configure it, \
I would ask you to either open an issue with the tag "Tips & Tricks" and explain it there or, \
if you want to, open a pull request. \
Thanks in advance.*

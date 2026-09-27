choco install -y msys2

# update $env:PATH et all.
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"
Update-SessionEnvironment

# configure the msys2 launcher to let the shell inherit the PATH.
$msys2BasePath = "$env:ChocolateyToolsLocation\msys64"
@(
    'clang64.ini'
    'mingw32.ini'
    'mingw64.ini'
    'msys2.ini'
    'ucrt64.ini'
) | ForEach-Object {
    $msys2ConfigPath = "$msys2BasePath\$_"
    [IO.File]::WriteAllText(
        $msys2ConfigPath,
        ([IO.File]::ReadAllText($msys2ConfigPath) `
            -replace '#?(MSYS2_PATH_TYPE=).+','$1inherit')
    )
}

# configure msys2.
[IO.File]::WriteAllText(
    "$msys2BasePath\etc\nsswitch.conf",
    ([IO.File]::ReadAllText("$msys2BasePath\etc\nsswitch.conf") `
        -replace '(db_home: ).+','$1windows')
)
Write-Output 'C:\Users /home' | Out-File -Encoding ASCII -Append "$msys2BasePath\etc\fstab"

# define a function for easing the execution of bash scripts.
$bashPath = "$msys2BasePath\usr\bin\bash.exe"
function Bash($script) {
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # we also redirect the stderr to stdout because PowerShell
        # oddly interleaves them.
        # see https://www.gnu.org/software/bash/manual/bash.html#The-Set-Builtin
        echo 'exec 2>&1; export PATH="/usr/bin:$PATH"; MSYS2_PATH_TYPE=inherit; source shell ucrt64; set -eu;' $script | &$bashPath
        if ($LASTEXITCODE) {
            throw "bash execution failed with exit code $LASTEXITCODE"
        }
    } finally {
        $ErrorActionPreference = $eap
    }
}

# configure the shell.
Bash @'
pacman --noconfirm -Sy make zip unzip tar dos2unix
pacman --noconfirm -Sy netcat procps
pacman --noconfirm -Sy vim

cat>~/.bash_history<<"EOF"
EOF

cat>~/.bash_profile<<"EOF"
# ~/.bash_profile: executed by bash(1) for login shells.

export EDITOR=vim
export PAGER=less

alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF

cat>~/.inputrc<<"EOF"
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
set show-all-if-ambiguous on
set completion-ignore-case on
EOF

cat>~/.minttyrc<<"EOF"
Term=xterm-256color
EOF

cat>~/.vimrc<<"EOF"
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup

autocmd BufNewFile,BufRead Vagrantfile set ft=ruby
autocmd BufNewFile,BufRead *.config set ft=xml

" Usefull setting for working with Ruby files.
autocmd FileType ruby set tabstop=2 shiftwidth=2 smarttab expandtab softtabstop=2 autoindent
autocmd FileType ruby set smartindent cinwords=if,elsif,else,for,while,try,rescue,ensure,def,class,module

" Usefull setting for working with Python files.
autocmd FileType python set tabstop=4 shiftwidth=4 smarttab expandtab softtabstop=4 autoindent
" Automatically indent a line that starts with the following words (after we press ENTER).
autocmd FileType python set smartindent cinwords=if,elif,else,for,while,try,except,finally,def,class

" Usefull setting for working with Go files.
autocmd FileType go set tabstop=4 shiftwidth=4 smarttab expandtab softtabstop=4 autoindent
" Automatically indent a line that starts with the following words (after we press ENTER).
autocmd FileType go set smartindent cinwords=if,else,switch,for,func
EOF
'@

# install ucrt64-based tools.
# see https://github.com/msys2/MINGW-packages
# see https://packages.msys2.org/packages/?repo=ucrt64
Bash @'
pacman --noconfirm -Sy mingw-w64-ucrt-x86_64-gcc
pacman --noconfirm -Sy mingw-w64-ucrt-x86_64-jq
pacman --noconfirm -Sy mingw-w64-ucrt-x86_64-python
pacman --noconfirm -Sy mingw-w64-ucrt-x86_64-python-pip
pacman --noconfirm -Sy mingw-w64-ucrt-x86_64-python-pygments
# NB this is commented because httpie is currently failing to build/install in msys2.
#python3 -m pip install httpie
'@

# add MSYS2 shortcut to the Desktop and Start Menu.
Install-ChocolateyShortcut `
    -ShortcutFilePath "$env:USERPROFILE\Desktop\MSYS2 Bash.lnk" `
    -TargetPath "$env:ChocolateyToolsLocation\msys64\ucrt64.exe" `
    -WorkingDirectory '%USERPROFILE%'
Install-ChocolateyShortcut `
    -ShortcutFilePath "C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\MSYS2 Bash.lnk" `
    -TargetPath "$env:ChocolateyToolsLocation\msys64\ucrt64.exe" `
    -WorkingDirectory '%USERPROFILE%'

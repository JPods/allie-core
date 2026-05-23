
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/williamjames/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/williamjames/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/williamjames/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/williamjames/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

alias python="python3"
alias pip="pip3"
export PATH=$(brew --prefix)/bin:$PATH
alias usb="system_profiler SPUSBDataType"
export PATH="$HOME/.local/bin:$PATH"

# Allie — did not work (process capture)
alias dnw='bash $HOME/Allie/scripts/allie-dnw.sh'
alias tf='bash $HOME/Allie/scripts/allie-tf.sh'
# to activate uncomment following in ~/.zshrc and run % source ~/.zshrc 
alias claude='claude --dangerously-skip-permissions'
# to de-activate comment above and run % source ~/.zshrc 

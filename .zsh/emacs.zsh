mkdir -p ~/.emacs.d/backup
if [ ! -d ~/.emacs.d/replace-colorthemes ]; then
	git clone https://github.com/emacs-jp/replace-colorthemes.git ~/.emacs.d/replace-colorthemes
fi
if [ ! -d ~/.emacs.d/powerline ]; then
	git clone https://github.com/Dewdrops/powerline.git ~/.emacs.d/powerline
fi

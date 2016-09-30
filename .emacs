;;; package --- emacs settings

;;; Commentary:

;;; Code:

; Add melpa packages
(require 'package)
(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))
(package-initialize)
;(package-refresh-contents)

; line numbers
(global-linum-mode t)

;; Please set your themes directory to 'custom-theme-load-path
; git clone https://github.com/emacs-jp/replace-colorthemes.git ~/.emacs.d/replace-colorthemes
(add-to-list 'custom-theme-load-path (file-name-as-directory "~/.emacs.d/replace-colorthemes"))
;; load your favorite theme
(load-theme 'desert t t)
(enable-theme 'desert)

; git
(package-install 'git-commit)
(package-install 'gitconfig)

; flycheck mode
(package-install 'flycheck)
(require 'flycheck)
(global-flycheck-mode)

; evil mode
(package-install 'evil)
(require 'evil)
(evil-mode 1)

; powerline
; git clone https://github.com/Dewdrops/powerline.git ~/.emacs.d/powerline
; (package-install 'powerline)
(add-to-list 'load-path "~/.emacs.d/powerline")
(require 'powerline)
(powerline-center-evil-theme)

; go mode
(package-install 'go)
(package-install 'go-autocomplete)
(require 'go-mode-autoloads)
(add-to-list 'exec-path "/opt/go/bin")
(add-hook 'before-save-hook 'gofmt-before-save)
(add-hook 'go-mode-hook (lambda () (local-set-key (kbd "C-c C-r") 'go-remove-unused-imports)))

; gocode
(add-to-list 'load-path "~/.emacs.d/gocode/emacs")
(require 'go-autocomplete)
(require 'auto-complete-config)
(ac-config-default)

; goflymake
(add-to-list 'load-path "~/Documents/workspaces/go/src/github.com/dougm/goflymake")
(add-to-list 'exec-path "/Documents/workspaces/go/bin")
(require 'go-flymake)
(require 'go-flycheck)

; starts the emacs server
(server-start)

;;; .emacs ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   (quote
    (evil markdown-preview-mode git-commit-insert-issue gitignore-mode gitconfig-mode gitconfig gitattributes-mode git-commit git-command git flycheck auto-complete))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

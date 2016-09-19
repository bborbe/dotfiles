;;; package --- emacs settings

;;; Commentary:

;;; Code:

; Add melpa packages
(require 'package)
(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))
(package-initialize)
;(package-refresh-contents)

; flycheck mode
(package-install 'flycheck)
(global-flycheck-mode)

; evil mode
(add-to-list 'load-path "~/.emacs.d/evil")
(require 'evil)
(evil-mode 1)

; powerline
(add-to-list 'load-path "~/.emacs.d/powerline")
(require 'powerline)
(powerline-center-evil-theme)

; go mode
(add-to-list 'load-path "~/.emacs.d/go-mode.el")
(require 'go-mode-autoloads)
(add-to-list 'exec-path "/opt/go/bin")
(add-hook 'before-save-hook 'gofmt-before-save)
(add-hook 'go-mode-hook (lambda ()
			  (local-set-key (kbd "C-c C-r") 'go-remove-unused-imports)))

; gocode
(add-to-list 'load-path "~/.emacs.d/gocode/emacs")
(require 'go-autocomplete)
(require 'auto-complete-config)
(ac-config-default)

; goflymake
(add-to-list 'load-path "~/Documents/workspaces/go/src/github.com/dougm/goflymake")
(require 'go-flymake)
(require 'go-flycheck)

;starts the emacs server
(server-start)

;;; .emacs ends here

;;; package --- emacs settings

;;; Commentary:

;;; Code:

; Add melpa packages
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(when (< emacs-major-version 24)
  ;; For important compatibility libraries like cl-lib
  (add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/")))
(package-initialize)
;(package-refresh-contents)

; line numbers
(global-linum-mode t)

; shortcuts
(global-set-key (kbd "M-o") 'sr-open-file)

(global-set-key (kbd "M-i") 'helm-swoop)
(global-set-key (kbd "M-I") 'helm-swoop-back-to-last-point)
(define-key isearch-mode-map (kbd "M-i") 'helm-swoop-from-isearch)

(global-set-key (kbd "C-x b") 'ido-switch-buffer)
(global-set-key [(ctrl tab)] 'ido-switch-buffer)
(global-set-key [(ctrl shift tab)] 'ido-switch-buffer)
(add-hook 'ido-setup-hook
          (lambda ()
            (define-key ido-buffer-completion-map [(ctrl tab)] 'ido-next-match)
            (define-key ido-buffer-completion-map [(ctrl shift tab)] 'ido-prev-match)))

; prevent close
(setq confirm-kill-emacs 'y-or-n-p)

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
(evil-ex-define-cmd "wq" 'evil-save-and-close)
(evil-ex-define-cmd "wq!" 'evil-save-and-close)

; powerline
; git clone https://github.com/Dewdrops/powerline.git ~/.emacs.d/powerline
; (package-install 'powerline)
(add-to-list 'load-path "~/.emacs.d/powerline")
(require 'powerline)
(powerline-center-evil-theme)

; yaml-mode
(package-install 'yaml-mode)
(require 'yaml-mode)

; projectile
; sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.locate.plist
(package-install 'projectile)
(require 'projectile)
(package-install 'helm-projectile)
(require 'helm-projectile)
(package-install 'helm)
(require 'helm)
(package-install 'helm-swoop)
(require 'helm-swoop)

(projectile-global-mode)
(setq projectile-indexing-method 'native) ; use system command like find, git...
(setq projectile-enable-caching nil)
(setq projectile-require-project-root t)

;;;; Integrated find-file
;; If current working directory is project, use help-projectile
;; Else, use find-file
(defun sr-open-file ()
  "Open file using projectile+Helm or ido."
  (interactive)
  (if (projectile-project-p)
      (helm-projectile)
    (helm-for-files)))

; go mode
(package-install 'go)
(package-install 'go-autocomplete)
(require 'go-mode)
(add-to-list 'exec-path "/opt/go/bin")
(add-to-list 'exec-path "~/Documents/workspaces/go/bin")
(add-hook 'before-save-hook 'gofmt-before-save)
(add-hook 'go-mode-hook (lambda () (local-set-key (kbd "C-c C-r") 'go-remove-unused-imports)))

; gocode
(add-to-list 'load-path "~/.emacs.d/gocode/emacs")
(require 'go-autocomplete)
(require 'auto-complete-config)
(ac-config-default)

; goflymake
(add-to-list 'load-path "~/Documents/workspaces/go/src/github.com/dougm/goflymake")
(add-to-list 'exec-path "~/Documents/workspaces/go/bin")
(require 'go-flymake)
(require 'go-flycheck)

; Nope, I want my copies in the system temp dir.
(setq flymake-run-in-place nil)
; This lets me say where my temp dir is.
(setq temporary-file-directory "~/.emacs.d/tmp/")

; markdown
(package-install 'markdown-preview-mode)

; use custom markdown tool
; sudo port search pandoc
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(markdown-command "/opt/local/bin/pandoc")
 '(package-selected-packages
   (quote
    (yaml-mode evil-visual-mark-mode helm-swoop go-autocomplete go helm helm-projectile projectile let-alist ## evil markdown-preview-mode git-commit-insert-issue gitignore-mode gitconfig-mode gitconfig gitattributes-mode git-commit git-command git flycheck auto-complete))))

; set backup directory
(setq backup-directory-alist '(("." . "~/.emacs.d/backup"))
  backup-by-copying t    ; Don't delink hardlinks
  version-control t      ; Use version numbers on backups
  delete-old-versions t  ; Automatically delete excess backups
  kept-new-versions 20   ; how many of the newest versions to keep
  kept-old-versions 5    ; and how many of the old
  )

; starts the emacs server
(server-start)

;;; .emacs ends here

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

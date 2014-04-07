;;hide tool-bar
;;hide scroll-bar-mode
(tool-bar-mode 0)
(scroll-bar-mode 0)

;;add yasnippet

(add-to-list 'load-path
	     "~/.emacs.d/tools/yasnippet")
(require 'yasnippet)
(setq yas-snippet-dirs '("~/.emacs.d/tools/yasnippet/snippets" "~/.emacs.d/tools/yasnippet/yasmate/snippets"))


;; add ido
(require 'ido)

;; rinari
(add-to-list 'load-path
	     "~/.emacs.d/tools/rinari")
(require 'rinari)


(add-to-list 'load-path "~/.emacs.d/")
(require 'auto-complete-config)
(ac-config-default)

;; add js json js.erb mode
(add-to-list 'auto-mode-alist '("\\.erb$" . html-mode))
(add-to-list 'auto-mode-alist '("\\.js$" . js2-mode))
(add-to-list 'auto-mode-alist '("\\.json$" . js2-mode))
(add-to-list 'auto-mode-alist '("\\.js\.erb$" . js2-mode))

;;coffee-mode
(add-to-list 'load-path "~/.emacs.d/tools/coffee-mode")
(require 'coffee-mode)
(add-to-list 'auto-mode-alist '("\\.coffee$" . coffee-mode))
(add-to-list 'auto-mode-alist '("Cakefile" . coffee-mode))

;; jquery-doc
(add-to-list 'load-path
	     "~/.emacs.d/tools/jquery-doc/")
(require 'jquery-doc)
(add-hook 'js2-mode-hook 'jquery-doc-setup)

;; add slime
(add-to-list 'load-path "~/.emacs.d/elpa/slime/")  ; your SLIME directory
(require 'slime-autoloads)
;;;your Lisp system

;;linux
;;git clone git://git.code.sf.net/p/sbcl/sbcl
(setq inferior-lisp-program "/usr/bin/sbcl")
;(setq inferior-lisp-program "/usr/local/bin/sbcl")

;;windows
;;https://github.com/akovalenko/sbcl-win32-threads/wiki
;;(setq inferior-lisp-program "~/.emacs.d/sbcl.exe")

;(require 'slime)
;(slime-setup)
(slime-setup '(slime-fancy))
;(setq slime-contribs '(slime-fancy))

;;add scss mode

(add-to-list 'load-path
	     "~/.emacs.d/tools/yasnippet/snippets/scss-mode/")
(autoload 'scss-mode "scss-mode")
(add-to-list 'auto-mode-alist  '("\\.scss\\'" . scss-mode))

(add-to-list 'load-path
	     "~/.emacs.d/tools/yasnippet/snippets/yaml-mode/")
(require 'yaml-mode)
(add-to-list 'auto-mode-alist  '("\\.yml$'" . yaml-mode))

;;; auto-load progress-mode code
(autoload 'progress-mode "progress-mode")
(setq auto-mode-alist (cons '("\\.p\\'" . progress-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.i\\'" . progress-mode) auto-mode-alist))

(ido-mode t)
(yas-global-mode 1)
(global-rinari-mode t)
(global-auto-complete-mode 1)

;;hide tool-bar
;;hide scroll-bar-mode
(tool-bar-mode 0)
(scroll-bar-mode 0)

;;add yasnippet

(add-to-list 'load-path
	     "~/.emacs.d/tools/yasnippet")
(require 'yasnippet)
(setq yas-snippet-dirs '("~/.emacs.d/tools/yasnippet/snippets" "~/.emacs.d/tools/yasnippet/extras/imported"))
(yas-global-mode 1)

;; add ido
(require 'ido)
(ido-mode t)

;; rinari
(add-to-list 'load-path
	     "~/.emacs.d/tools/rinari")
(require 'rinari)
(global-rinari-mode 1)

(add-to-list 'load-path "~/.emacs.d/")
(require 'auto-complete-config)
(ac-config-default)
(global-auto-complete-mode 1)

;; add slime
(add-to-list 'load-path "~/.emacs.d/elpa/slime/")  ; your SLIME directory

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
(require 'slime-autoloads)
(slime-setup '(slime-fancy))

;;add scss mode

(add-to-list 'load-path
	     "~/.emacs.d/tools/scss-mode/")
(autoload 'scss-mode "scss-mode")
(add-to-list 'auto-mode-alist  '("\\.scss\\'" . scss-mode))

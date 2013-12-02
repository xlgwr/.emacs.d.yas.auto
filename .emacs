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

;;windows
;;https://github.com/akovalenko/sbcl-win32-threads/wiki
;;(setq inferior-lisp-program "~/.emacs.d/sbcl.exe")

(require 'slime)
(slime-setup '(slime-fancy))

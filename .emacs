(add-to-list 'load-path
	     "~/.emacs.d/plugins/yasnippet")
(require 'yasnippet)
(setq yas-snippet-dirs '("~/.emacs.d/plugins/yasnippet/snippets" "~/.emacs.d/plugins/yasnippet/extras/imported"))
(yas-global-mode 1)

;; add ido
(require 'ido)
(ido-mode t)

;; rinari
(add-to-list 'load-path
	     "~/.emacs.d/plugins/rinari")
(require 'rinari)
(global-rinari-mode 1)

(add-to-list 'load-path "~/.emacs.d/")
(require 'auto-complete-config)
(ac-config-default)
(global-auto-complete-mode 1)

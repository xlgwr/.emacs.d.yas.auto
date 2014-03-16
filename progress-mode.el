;;;; progress-mode.el --- Progress 4GL code editing commands for Emacs (modified!)
;;
;; Copyright (C) 1993 David Eddy.  All rights reserved.
;;
;; You may use and freely redistribute this software, provided the copyright
;; notice above remains intact.

;; This file was modified by Piotr Jurga (trachx@poczta.onet.pl) 
;; original file can be obtained from http://www.peg.com/utilities/pmode.zip

;; A smart editing mode for Progress code.  It knows a lot about Progress
;; syntax and tries to position the cursor according to Progress layout
;; conventions.  You can change the details of the layout style with option
;; variables.  Load it and do M-x describe-mode for details.

;;;  Add this to your ~/.emacs file
;;; auto-load progress-mode code
;;; (autoload 'progress-mode "progress-mode")
;;;  (setq auto-mode-alist (cons '("\\.p\\'" . progress-mode) auto-mode-alist))
;;;  (setq auto-mode-alist (cons '("\\.i\\'" . progress-mode) auto-mode-alist))

;; SCCS data: @(#) progress-mode.el 1.6 Created at 94/04/21 14:33:43
;; ver. 0.1   17NOV93:  Initial release for evaluation and comment.
;;                      Alpha-test.
;;      0.1.1 24NOV93:  Fixed block-end detection bug
;;      0.1.2 25NOV93:  Adjusted block-end; modified statement end logic
;;                      to recognize includes
;;      0.1.3 21APR94:  Added V7 primitives to block recognition

;;; AUTHOR
;;
;; The author of progress-mode.el is David Eddy of Perth, Western Australia.
;; My email address is dave@metapro.DIALix.oz.au.
;; Please sent bug notices, bug fixes, wish lists and enhancements to me
;; at that address.

;;; BUGS
;;
;; There are a number of known problems with progress-mode:
;;
;; * Indenting inside includes is somewhat buggy and less than perfect
;;   when it does work.
;; * Sub-expression indenting is not performed at all.
;; * Comments after an "end." statement interfere with proper indenting.
;; * END statements must be post-indented (i.e. you've gotta press TAB
;;   after typing "end." to get it properly indented).
;; * M-; handling works sometimes.
;; * Statement end recognition is less than perfect.
;; * Parsing is a bit slow.
;;

;;; TO DO
;;
;; There are a large number of things that progress-mode could do but
;; doesn't.  These and other features may (or may not) be included in
;; future versions of progress-mode.
;;
;; * M-x indent-region
;; * C-M-q (indent-pro-exp)
;; * M-q (pro-fill-paragraph)
;; * Conditional movement commands (and better syntax navigation commands
;;   generally)
;; * Faster parsing
;; * Keyword completion
;; * Keyword capitalization (yuk!  who wants it?)
;; * Sub-expression recognition and indenting logic
;; * Definable new-line preamble (e.g. for MFG/PRO coders etc.)
;; * Exotic comment handling commands (e.g. comment boxing, etc.)
;; * Add search paths to filename expansion (aka PROPATH)
;; * pro-visit-include
;;

(provide 'progress-mode)


;;;; Formatting definitions
;;
;; These definitions define the layout of idealized Progress code
;; Some formatting conventions that you may not like are controlled
;; using variables in this section.
;;
;; Note that there are functions which will set the indent depth and offset
;;
(defvar pro-block-indent nil
  "*Amount to indent a block body with respect to its header")
(if pro-block-indent ()
  (setq pro-block-indent 3))

(defvar pro-include-indent nil
  "*Amount to indent an inlclude body with respect to its start")
(if pro-include-indent ()
  (setq pro-include-indent 3))

(defvar pro-continuation-indent nil
  "*Amount to indent a statement continuation with respect to its header")
(if pro-continuation-indent ()
  (setq pro-continuation-indent 3))

(defvar pro-comment-continuation nil
  "*Amount to indent a comment continuation with respect to the basic indent")
(if pro-comment-continuation ()
  (setq pro-comment-continuation 3))

(defvar pro-indent-block-end nil
  "*Set to t if block end is to be indented with block body")

(defvar pro-auto-newline nil
  "*Set to t if certain characters become electric.")
(if pro-auto-newline ()
  (setq pro-auto-newline t))

(defvar pro-indent-offset 0
  "Internal use only -- offset from left for indenting calcs")



;;;; Syntax definitions:
;;;
;;; Whitespace
;;;
(defvar pro-whitespace nil
  "Progress whitespace characters (expressed for use in skip-chars)")
(if pro-whitespace ()
  (setq pro-whitespace " \t\n"))

(defvar pro-whitespace-regexp nil
  "Progress whitespace (expressed as a regexp)")
(if pro-whitespace-regexp ()
  (setq pro-whitespace-regexp
	(concat "[" pro-whitespace "]")))

;;;
;;; Statements
;;;
(defvar pro-statement-terminator nil
  "Description of statement termination (regexp)")
(if pro-statement-terminator ()
  (setq pro-statement-terminator
	(concat "\\(then\\|else\\|[:.]\\)" pro-whitespace-regexp
		"\\|}\n")))

(defvar pro-statement-terminator-offset nil
  "Offset with respect to match end after statement terminator location")
(if pro-statement-terminator-offset ()
  (setq pro-statement-terminator-offset -1))

(defvar pro-indent-after nil
  "Extra indenting is required after lines ending like this (regexp)")
(if pro-indent-after ()
  (setq pro-indent-after "then\\|else\\|{.*\\(\\([\'\"]\\).*\\1.*\\)*.*}"))

(defvar pro-unindent-after nil
  "Less indenting is required after lines ending like this (regexp)")
(if pro-unindent-after ()
  (setq pro-unindent-after "}"))


;;;
;;; Strings
;;;
(defvar pro-string-delim nil
  "String delimiter characters expressed as a regexp")
(if pro-string-delim ()
  (setq pro-string-delim "\\s\""))

(defvar pro-string-double-escape nil
  "t if a double quote character is recognized as an escaped quote")
(if pro-string-double-escape ()
  (setq pro-string-double-escape t))

(defvar pro-string-delim-offset nil
  "Offset with respect to match end after string delimiter location")
(if pro-string-delim-offset ()
  (setq pro-string-delim-offset 0))

;;;
;;; Comments
;;;
(defvar pro-comment-start nil
  "Comment start expressed as regexp")
(if pro-comment-start ()
  (setq pro-comment-start "/\\*"))

(defvar pro-comment-end nil
  "Comment end expressed as regexp")
(if pro-comment-end ()
  (setq pro-comment-end "\\*/"))

(defvar pro-comment-strings nil
  "Comment start and end strings as regexp (derived)")
(if pro-comment-strings ()
  (setq pro-comment-strings
	(concat pro-comment-start "\\|" pro-comment-end)))

(defvar pro-comments-nest nil
  "t if comments nest")		;; which they do in Progress
(if pro-comments-nest ()
  (setq pro-comments-nest t))

(defvar pro-comment-end-offset nil
  "Offset with respect to match end after finding comment end")
(if pro-comment-end-offset ()
  (setq pro-comment-end-offset 0))

(defvar pro-comment-start-offset nil
  "Offset with respect to match start after finding comment start")
(if pro-comment-start-offset ()
  (setq pro-comment-start-offset 0))


;;;
;;; Inclusions
;;;
(defvar pro-include-start nil
  "Start of an inclusion directive expressed as regexp")
(if pro-include-start ()
  (setq pro-include-start "{"))

(defvar pro-include-end nil
  "End of an inclusion directive expressed as regexp")
(if pro-include-end ()
  (setq pro-include-end "}"))

(defvar pro-include-arg-ref nil
  "Appearance of a reference to an inclusion argument (regexp)")
(if pro-include-arg-ref ()
  (setq pro-include-arg-ref "{[0-9]+}\\|{&\\sw}"))

(defvar pro-include-arg-ref-with-spaces nil
  "Appearance of a reference to an inclusion argument  with spaces (internal)")
(if pro-include-arg-ref-with-spaces ()
  (setq pro-include-arg-ref-with-spaces "{ [0-9]+}\\|{ &\\sw+}"))

(defvar pro-include-end-offset nil
  "Positioning offset after finding include end")
(if pro-include-end-offset ()
  (setq pro-include-end-offset 0))

(defvar pro-include-start-offset nil
  "Positioning offset after finding include start")
(if pro-include-start-offset ()
  (setq pro-include-start-offset 0))

(defvar pro-include-with-spaces nil
  "*Whether to add spaces before/after braces")
(if pro-include-with-spaces ()
  (setq pro-include-with-spaces t))

;;;
;;; Blocks
;;;
(defvar pro-block-start nil
  "Block start syntax (regexp)")
(if pro-block-start ()
  (setq pro-block-start
	"procedure\\s-[^:]*:\\|for\\s-[^:]*:\\|repeat\\(\\s-[^:]*\\)?:\\|do\\(\\s-[^:]*\\)?:\\|editing\\(\\s-[^:]*\\)?:"))

(defvar pro-block-end nil
  "Block end syntax (regexp)")
(if pro-block-end ()
  (setq pro-block-end "\\(^\\|\\s-\\)end\\.\\($\\|\\s-\\)"))

(defvar pro-block-end-offset nil
  "Positioning offset for block end location")
(if pro-block-end-offset ()
  (setq pro-block-end-offset -1))


;;;
;;; Syntax priorities & combination flags
;;;
(defvar pro-strings-valid-in-comments nil
  "t if string consistency is required inside comments")

(defvar pro-strings-valid-in-includes nil
  "t if string consistency is required inside inclusions")
(if pro-strings-valid-in-includes ()
  (setq pro-strings-valid-in-includes t))

(defvar pro-comments-valid-in-strings nil
  "t if comment consistency is required inside strings")

(defvar pro-comments-valid-in-includes nil
  "t if comments work in include argument string.
If nil comments are treated as normal arguments to an inclusion")

(defvar pro-includes-valid-in-strings nil
  "t if inclusions work in strings")
(if pro-includes-valid-in-strings ()
  (setq pro-includes-valid-in-strings t))

(defvar pro-includes-valid-in-comments nil
  "t if inclusions work in comments")

;;;
;;; Keywords
;;;




;;;; Emacs table definitions
;;;
;;; Abbreviation table
;;;
(defvar pro-mode-abbrev-table nil
  "Abbrev table in use in Progress mode.")
(define-abbrev-table 'pro-mode-abbrev-table ())

;;;
;;; Keymap
;;;
(defvar pro-mode-map ()
  "Keymap used in Progress mode.")
(if pro-mode-map
    ()
  (setq pro-mode-map (make-sparse-keymap))
  (define-key pro-mode-map "{" 'electric-pro-brace)
  (define-key pro-mode-map "}" 'electric-pro-brace)
;  (define-key pro-mode-map "\e\C-q" 'indent-pro-exp)
  (define-key pro-mode-map "\ea" 'pro-statement-backward)
  (define-key pro-mode-map "\ee" 'pro-statement-forward)
;  (define-key pro-mode-map "\eq" 'pro-fill-paragraph)
; (define-key pro-mode-map "\177" 'backward-delete-char-untabify)
 (define-key pro-mode-map "\C-c{" 'pro-insert-char-pair)
 (define-key pro-mode-map "\C-c\"" 'pro-insert-char-pair)
 (define-key pro-mode-map "\C-c\'" 'pro-insert-char-pair)
 (define-key pro-mode-map "\C-c\[" 'pro-insert-char-pair)
 (define-key pro-mode-map "\C-c;" 'pro-skip-ws-and-comment-forward)
 (define-key pro-mode-map "\C-c:" 'pro-skip-ws-and-comment-backward)
 (define-key pro-mode-map "\C-ci" 'pro-set-indent)
 (define-key pro-mode-map "\C-co" 'pro-set-indent-offset)
 (define-key pro-mode-map "\C-c\C-c"  'comment-region)
 (define-key pro-mode-map "\M-nd" 'pro-electric-progress-debug)
 (define-key pro-mode-map "\M-ne" 'pro-skip-block-backward)
 (define-key pro-mode-map "\M-na" 'pro-skip-block-forward)
 (define-key pro-mode-map "\t" 'electric-progress-tabulator)
 )

;;;
;;; Syntax table
;;;
(defvar pro-mode-syntax-table nil
  "Syntax table in use in Progress-Mode buffers.")
(if pro-mode-syntax-table
    ()
  (setq pro-mode-syntax-table (make-syntax-table))
  (modify-syntax-entry ?\\ "\\" pro-mode-syntax-table)
  (modify-syntax-entry ?~ "\\" pro-mode-syntax-table)
  (modify-syntax-entry ?/ ". 14" pro-mode-syntax-table)
  (modify-syntax-entry ?* ". 23" pro-mode-syntax-table)
  (modify-syntax-entry ?+ "." pro-mode-syntax-table)
  (modify-syntax-entry ?- "w" pro-mode-syntax-table)
  (modify-syntax-entry ?= "." pro-mode-syntax-table)
  (modify-syntax-entry ?% "w" pro-mode-syntax-table)
  (modify-syntax-entry ?$ "w" pro-mode-syntax-table)
  (modify-syntax-entry ?\' "\"" pro-mode-syntax-table)
  )


(defvar progress-font-lock-keywords nil
  "comment")

(setf progress-font-lock-keywords (purecopy 
  (list 
   '("\\({.*?}\\)\\|\\(&[^ ]+\\)" . font-lock-preprocessor-face )      
   '("\\<\\(B\\(IN\\|YTE\\)\\|CHAR\\(ACTER\\)?\\|D\\(ATE\\|EC\\(IMAL\\)?\\|OUBLE\\)\\|FLOAT\\|HANDLE\\|INT\\(EGER\\)?\\|LO\\(G\\(ICAL\\)?\\|NG\\)\\|MEMPTR\\|R\\(AW\\|ECID\\|OWID\\)\\|SHORT\\|WIDGET\\(-HANDLE\\)?\\)\\>" . font-lock-type-face)

    (cons (concat "\\<\\("
		  "A\\(C\\(CUM\\(ULATE\\)?\\)\\|DD\\|L\\(IAS\\|L\\|TER\\)\\|MBIG\\(UOUS\\)?\\|N[DY]\\|PPLY\\|S\\(C\\(ENDING\\)?\\|SIGN\\)\\|UTO-RETURN\\|VAIL\\(ABLE\\)?\\|[ST]\\)"
		  "\\|B\\(ACKGROUND\\|E\\(FORE-HIDE\\|GINS\\|LL\\|TWEEN\\)\\|LANK\\|REAK\\|TOS\\|Y\\)"
		  "\\|C\\(A\\(N-\\(DO\\|FIND\\)\\|SE\\(-SENSITIVE\\)?\\)\\|ENTER\\(ED\\)?\\|H\\(ECK\\|R\\)\\|L\\(EAR\\|IPBOARD\\)\\|O\\(L\\(O[NR]\\|UMN\\(-LABEL\\|S\\)?\\)?\\|MPILER\\|N\\(NECTED\\|TROL\\)\\|UNT-OF\\)\\|PSTREAM\\|REATE\\|TOS\\|UR\\(RENT\\(-\\(CHANGED\\|LANG\\(UAGE\\)?\\|WINDOW\\)\\)?\\|SOR\\)\\)"
		  "\\|D\\(DE\\|E\\(BLANK\\|C\\(IMALS\\|LARE\\)\\|F\\(AULT\\(-WINDOW\\)?\\|INE\\)?\\|L\\(ETE\\|IMITER\\)\\|SC\\(ENDING\\)?\\)\\|I\\(CT\\(IONARY\\)?\\|S\\(ABLE\\|CONNECT\\|P\\(LAY\\)?\\|TINCT\\)\\)\\|O\\(S\\|WN\\)?\\|ROP\\)"
		  "\\|E\\(ACH\\|DITING\\|LSE\\|N\\(ABLE\\|D\\|TRY\\)\\|RROR-STATUS\\|SCAPE\\|TIME\\|X\\(C\\(EPT\\|LUSIVE\\(-LOCK\\)?\\)\\|ISTS\\|PORT\\)\\)"
		  "\\|F\\(ALSE\\|ETCH\\|I\\(ELDS?\\|L\\(E-INFO\\(RMATION\\)?\\|L\\)\\|ND\\(-\\(CASE-SENSITIVE\\|GLOBAL\\|NEXT-OCCURRENCE\\|PREV-OCCURRENCE\\|SELECT\\|WRAP-AROUND\\)\\)?\\|RST\\(-OF\\)?\\)\\|O\\(CUS\\|NT\\(-BASED-GRID\\)?\\|R\\(M\\(AT\\)?\\)?\\)\\|R\\(AME\\(-\\(COL\\|D\\(B\\|OWN\\)\\|FI\\(ELD\\|LE\\)\\|INDEX\\|LINE\\|NAME\\|ROW\\|VAL\\(UE\\)?\\)\\)?\\|OM\\(-\\(CHARS\\|PIXELS\\)\\)?\\)\\)"
		  "\\|G\\(ATEWAYS\\|ET\\(-\\(BYTE\\|CO\\(DEPAGES\\|LLATIONS\\)\\|KEY-VALUE\\)\\|BYTE\\)\\|LOBAL\\|O-\\(ON\\|PENDING\\)\\|R\\(A\\(NT\\|PHIC-EDGE\\)\\|OUP\\)\\)"
		  "\\|H\\(AVING\\|E\\(ADER\\|LP\\)\\|IDE\\)"
		  "\\|I\\(MPORT\\|N\\(DEX\\|PUT\\(-OUTPUT\\)?\\|SERT\\|TO\\)\\|[FNS]\\)"
		  "\\|JOIN"
		  "\\|K\\(EY\\(-\\(CODE\\|FUNCTION\\|LABEL\\)\\|CODE\\|FUNCTION\\|LABEL\\|S\\|WORD\\)\\)"
		  "\\|L\\(A\\(BEL\\|ST\\(-\\(EVENT\\|KEY\\|OF\\)\\|KEY\\)?\\)\\|EAVE\\|I\\(BRARY\\|KE\\|NE-COUNT\\(ER\\)?\\|STING\\)\\|O\\(CKED\\|OKUP\\)\\)"
		  "\\|M\\(AP\\|E\\(MBER\\|SSAGE\\(-LINES\\)?\\)\\|OUSE\\)"
		  "\\|N\\(E\\(W\\|XT\\(-PROMPT\\)?\\)\\|O\\(-\\(ERROR\\|FILL\\|H\\(ELP\\|IDE\\)\\|L\\(ABELS?\\|OCK\\)\\|M\\(AP\\|ESSAGE\\)\\|P\\(AUSE\\|REFETCH\\)\\|UNDO\\|VALIDATE\\|WAIT\\)\\|T\\)?\\|U\\(LL\\|M-\\(ALIASES\\|DBS\\|ENTRIES\\)\\)\\)"
		  "\\|O\\(FF\\|LD\\|P\\(EN\\|SYS\\|TION\\)\\|S\\(-\\(APPEND\\|C\\(O\\(MMAND\\|PY\\)\\|REATE-DIR\\)\\|D\\(ELETE\\|IR\\)\\|RENAME\\)\\)\\|THERWISE\\|UTPUT\\|VERLAY\\|[FNR]\\)"
		  "\\|P\\(A\\(GE\\(-\\(BOTTOM\\|NUM\\(BER\\)?\\|TOP\\)\\)?\\|RAM\\(ETER\\)?\\|USE\\)\\|DBNAME\\|ERSISTENT\\|IXELS\\|R\\(EPROCESS\\|O\\(C\\(-\\(HANDLE\\|STATUS\\)\\|ESS\\)\\|GR\\(AM-NAME\\|ESS\\)\\|M\\(PT\\(-FOR\\)?\\|SGS\\)\\|PATH\\|VERSION\\)\\)\\|UT\\(-\\(BYTE\\|KEY-VALUE\\)\\|BYTE\\)?\\)"
		  "\\|QU\\(ERY\\|IT\\)"
		  "\\|R\\(-INDEX\\|E\\(ADKEY\\|C\\(ID\\|ORD-LENGTH\\|TANGLE\\)\\|LEASE\\|P\\(EAT\\|OSITION\\)\\|T\\(AIN\\|RY\\|URN\\)\\|V\\(ERT\\|OKE\\)\\)\\|UN\\)"
		  "\\|S\\(AVE\\|C\\(R\\(EEN\\(-\\(IO\\|LINES\\)\\)?\\|OLL\\)\\)\\|DBNAME\\|E\\(ARCH\\|EK\\|L\\(ECT\\|F\\)\\|SSION\\|T\\(USERID\\)?\\)\\|H\\(ARE\\(-LOCK\\|D\\)?\\|OW-STATS\\)\\|KIP\\|OME\\|PACE\\|T\\(ATUS\\|R\\(EAM\\(-IO\\)?\\|ING-XREF\\)\\)\\|YSTEM-DIALOG\\)"
		  "\\|T\\(ABLE\\|E\\(RM\\(INAL\\)?\\|XT\\(-\\(CURSOR\\)\\)?\\)\\|H\\(EN\\|IS-PROCEDURE\\)\\|I\\(ME\\|TLE\\)\\|O\\(P-ONLY\\)?\\|R\\(ANS\\(ACTION\\)?\\|I\\(GGERS?\\|M\\)\\|UE\\)\\)"
		  "\\|U\\(N\\(DO\\|FORMATTED\\|I\\(ON\\|QUE\\|X\\)\\)\\|P\\(DATE\\)?\\|S\\(E\\(-\\(INDEX\\|REVVIDEO\\|UNDERLINE\\)\\|R\\(ID\\)?\\)\\|ING\\)\\)"
		  "\\|V\\(ALUES?\\|IEW\\(-AS\\)?\\)"
		  "\\|W\\(AIT-FOR\\|H\\(E\\(N\\|RE\\)\\|ILE\\)\\|I\\(NDOW-NORMAL?\\|TH\\)\\|ORK\\(-TABLE\\|FILE\\)\\|RITE\\)"
		  "\\|YES"
		  "\\|_\\(C\\(BIT\\|ONTROL\\)\\|DCM\\|LIST\\|M\\(EMORY\\|SG\\)\\|TRACE\\)"
	       "\\)\\>\\([ .:]\\|$\\)") 'font-lock-keyword-face)


    (cons (concat "\\<\\("
		  "A\\(BS\\(OLUTE\\)?\\|C\\(CELERATOR\\|ROSS\\)\\|D\\(D-\\(FIRST\\|LAST\\)\\|VISE\\)\\|LERT-BOX\\|NYWHERE\\|PP\\(END\\|L\\(-ALERT\\(-BOXES\\)?\\|ICATION\\)\\)\\|S\\(-CURSOR\\|K-OVERWRITE\\)\\|UTO-\\(END\\(-KEY\\|KEY\\)\\|GO\\|INDENT\\|RESIZE\\|ZAP\\)\\|V\\(AILABLE-FORMATS\\|ERAGE\\|G\\)\\)\\|B\\(A\\(CKWARDS\\|SE-KEY\\|TCH\\(-MODE\\)?\\)\\|GC\\(OLOR\\)?\\|IN\\(ARY\\|D-WHERE\\)\\|LOCK-ITERATION-DISPLAY\\|O\\(RDER-\\(BOTTOM\\(-\\(CHARS\\|PIXELS\\)\\)?\\|LEFT\\(-\\(CHARS\\|PIXELS\\)\\)?\\|RIGHT\\(-\\(CHARS\\|PIXELS\\)\\)?\\|TOP\\(-\\(CHARS\\|PIXELS\\)\\)?\\)\\|T\\(H\\|TOM\\)\\|X\\(-SELECT\\(ABLE\\)?\\)?\\)\\|ROWSE\\(-HEADER\\)?\\|TN-\\(DOWN-ARROW\\|LEFT-ARROW\\|RIGHT-ARROW\\|UP-ARROW\\)\\|U\\(FFER\\(-\\(CHARS\\|LINES\\)\\)?\\|TTONS?\\)\\)"
		  "\\|C\\(A\\(CHE\\(-SIZE\\)?\\|N\\(-\\(QUERY\\|SET\\)\\|CEL-B\\(REAK\\|UTTON\\)\\)\\|PS\\)\\|DECL\\|H\\(AR\\(ACTER\\(_LENGTH\\)?\\|SET\\)?\\|ECKED\\|OOSE\\)\\|L\\(EAR-SELECT\\(ION\\)?\\|OSE\\)\\|O\\(DE\\(PAGE\\(-CONVERT\\)?\\)?\\|L\\(-OF\\|O\\(N-ALIGN\\(ED\\)?\\|R-TABLE\\)\\|UMN-\\(BGCOLOR\\|DCOLOR\\|F\\(GCOLOR\\|ONT\\)\\|LABEL-\\(BGCOLOR\\|DCOLOR\\|F\\(GCOLOR\\|ONT\\)\\)\\|OF\\|SCROLLING\\)\\)\\|M\\(BO-BOX\\|MAND\\|P\\(ILE\\|LETE\\)\\|[1-9]\\)\\|N\\(NECT\\|STRAINED\\|T\\(AINS\\|E\\(NTS\\|XT\\(-POPUP\\)?\\)\\|ROL-CONTAINER\\)\\|VERT\\(-TO-OFFSET\\)?\\)?\\|UNT\\)\\|P\\(C\\(ASE\\|OLL\\)\\|INTERNAL\\|LOG\\|PRINT\\|RCODE\\(IN\\|OUT\\)\\|TERM\\)\\|R\\(C-VALUE\\|EATE-\\(CONTROL\\|RESULT-LIST-ENTRY\\|TEST-FILE\\)\\)\\|UR\\(RENT\\(-\\(COLUMN\\|ITERATION\\|R\\(ESULT-ROW\\|OW-MODIFIED\\)\\)\\|_DATE\\)\\|SOR-\\(CHAR\\|LINE\\|OFFSET\\)\\)\\)"
		  "\\|D\\(A\\(T\\(A-\\(ENTRY-RETURN\\|TYPE\\)\\|E\\(-FORMAT\\)?\\)\\|Y\\)\\|COLOR\\|DE-\\(ERROR\\|I\\(D\\|TEM\\)\\|NAME\\|TOPIC\\)\\|E\\(BUG\\|C\\(IMAL\\)?\\|F\\(AULT-\\(BUTTON\\|EXTENSION\\)\\|INED\\)\\|LETE-\\(C\\(HAR\\|URRENT-ROW\\)\\|LINE\\|SELECTED-ROWS?\\)\\|S\\(ELECT-\\(FOCUSED-ROW\\|ROWS\\|SELECTED-ROW\\)\\|IGN-MODE\\)\\)\\|I\\(ALOG-\\(BOX\\|HELP\\)\\|R\\|S\\(ABLED\\|PLAY-\\(MESSAGE\\|TYPE\\)\\)\\)\\|OUBLE\\|R\\(AG-ENABLED\\|OP-DOWN\\(-LIST\\)?\\)\\|UMP\\|YNAMIC\\)\\|E\\(CHO\\|D\\(GE\\(-\\(CHARS\\|PIXELS\\)\\)?\\|ITOR\\)\\|MPTY\\|N\\(D\\(-KEY\\|KEY\\)\\|TERED\\)\\|Q\\|RROR\\(-\\(COL\\(UMN\\)?\\|ROW\\)\\)?\\|VENT\\(-TYPE\\|S\\)\\|X\\(ECUTE\\|P\\(AND\\)?\\|T\\(E\\(N\\(DED\\|T\\)\\|RNAL\\)\\|RACT\\)\\)\\)\\|F\\(ETCH-SELECTED-ROW\\|GC\\(OLOR\\)?\\|I\\(L\\(E\\(-\\(NAME\\|OFFSET\\|TYPE\\)\\|NAME\\)?\\|L\\(-IN\\|ED\\)\\|TERS\\)\\|RST-\\(C\\(HILD\\|OLUMN\\)\\|PROC\\(EDURE\\)?\\|TAB-ITEM\\)\\|XED-ONLY\\)\\|LOAT\\|O\\(CUSED-ROW\\|NT-TABLE\\|R\\(CE-FILE\\|EGROUND\\|WARDS\\)\\)\\|R\\(AME-\\(SPACING\\|[XY]\\)\\|EQUENCY\\|OM-CURRENT\\)\\|U\\(LL-\\(HEIGHT\\(-\\(CHARS\\|PIXELS\\)\\)?\\|PATHNAME\\|WIDTH\\(-\\(CHARS\\|PIXELS\\)\\)?\\)\\|NCTION\\)\\)\\|G\\(ET\\(-\\(BLUE\\(-VALUE\\)?\\|CHAR-PROPERTY\\|D\\(OUBL
\\|YNAMIC\\)\\|F\\(ILE\\|LOAT\\)\\|GREEN\\(-VALUE\\)?\\|ITERATION\\|L\\(ICENSE\\|ONG\\)\\|MESSAGE\\|NUMBER\\|POINTER-VALUE\\|RE\\(D\\(-VALUE\\)?\\|POSITIONED-ROW\\)\\|S\\(ELECTED\\(-WIDGET\\)?\\|HORT\\|I\\(GNATURE\\|ZE\\)\\|TRING\\)\\|T\\(AB-ITEM\\|EXT-\\(HEIGHT\\(-\\(CHARS\\|PIXELS\\)\\)?\\|WIDTH\\(-\\(CHARS\\|PIXELS\\)\\)?\\)\\)\\|UNSIGNED-SHORT\\)\\)?\\|R\\(AYED\\|ID-\\(FACTOR-\\(HORIZONTAL\\|VERTICAL\\|[HV]\\)\\|S\\(ET\\|NAP\\)\\|UNIT-\\(HEIGHT\\(-\\(CHARS\\|PIXELS\\)\\)?\\|WIDTH\\(-\\(CHARS\\|PIXELS\\)\\)?\\)\\|VISIBLE\\)\\)\\|[ET]\\)\\|H\\(ANDLE\\|E\\(IGHT\\(-\\(CHARS\\|PIXELS\\)\\)?\\|LP-CONTEXT\\)\\|IDDEN\\|ORIZONTAL\\|WND\\)\\|I\\(M\\(AGE\\(-\\(DOWN\\|INSENSITIVE\\|SIZE\\(-\\(CHARS\\|PIXELS\\)\\)?\\|UP\\)\\)?\\|MEDIATE-DISPLAY\\)\\|N\\(DEX\\(-HINT\\|ED-REPOSITION\\)\\|FO\\(RMATION\\)?\\|IT\\(IA\\(L\\(-\\(DIR\\|FILTER\\)\\)?\\|TE\\)\\)?\\|NER\\(-\\(CHARS\\|LINES\\)\\)?\\|SERT-\\(BACKTAB\\|FILE\\|ROW\\|STRING\\|TAB\\)\\|T\\(E\\(GER\\|RNAL-ENTRIES\\)\\)?\\)\\|S-\\(LEAD-BYTE\\|ROW-SELECTED\\|SELECTED\\)\\|TEM\\(S-PER-ROW\\)?\\)"
		  "\\|KE\\(EP-\\(FRAME-Z-ORDER\\|MESSAGES\\|TAB-ORDER\\)\\|Y\\(WORD-ALL\\)?\\)\\|L\\(A\\(BEL\\(-\\(BGC\\(OLOR\\)?\\|DC\\(OLOR\\)?\\|F\\(GC\\(OLOR\\)?\\|ONT\\)\\|PFC\\(OLOR\\)?\\)\\|S\\)\\|NGUAGES\\|RGE\\(-TO-SMALL\\)?\\|ST-\\(CHILD\\|PROC\\(EDURE\\)?\\|TAB-ITEM\\)\\)\\|E\\(ADING\\|FT\\(-\\(ALIGNED\\|TRIM\\)\\)?\\|NGTH\\)\\|I\\(NE\\|ST-\\(EVENTS\\|ITEMS\\|SET-ATTRS\\|WIDGETS\\)\\)\\|O\\(AD\\(-\\(CONTROL\\|I\\(CON\\|MAGE\\(-\\(DOWN\\|INSENSITIVE\\|UP\\)\\)?\\)\\|MOUSE-POINTER\\)\\)?\\|G\\(ICAL\\)?\\|WER\\)\\|PT[0-9]\\|[CET]\\)\\|M\\(A\\(RGIN-\\(EXTRA\\|HEIGHT\\(-\\(CHARS\\|PIXELS\\)\\)?\\|WIDTH\\(-\\(CHARS\\|PIXELS\\)\\)?\\)\\|TCHES\\|X\\(-\\(CHARS\\|DATA-GUESS\\|HEIGHT\\(-\\(CHARS\\|PIXELS\\)\\)?\\|ROWS\\|SIZE\\|VALUE\\|WIDTH\\(-\\(CHARS\\|PIXELS\\)\\)?\\)\\|IM\\(IZE\\|UM\\)\\)\\|[X]\\)\\|E\\(MORY\\|NU\\(-\\(BAR\\|ITEM\\|KEY\\|MOUSE\\)\\|BAR\\)?\\|SSAGE-\\(AREA\\(-FONT\\)?\\|LINE\\)\\)\\|IN\\(-\\(HEIGHT\\(-\\(CHARS\\|PIXELS\\)\\)?\\|SIZE\\|VALUE\\|WIDTH\\(-\\(CHARS\\|PIXELS\\)\\)?\\)\\|IMUM\\)?\\|O\\(D\\(IFIED\\|ULO\\)?\\|NTH\\|USE-POINTER\\|V\\(ABLE\\|E-\\(AFTER-TAB-ITEM\\|BEFORE-TAB-ITEM\\|COLUMN\\|TO-\\(BOTTOM\\|EOF\\|TOP\\)\\)\\)\\)\\|U\\(LTI\\(PLE\\(-KEY\\)?\\|TASKING-INTERVAL\\)\\|ST-EXIST\\)\\)\\|N\\(A\\(ME\\|TIVE\\)\\|E\\(W-ROW\\|XT-\\(COLUMN\\|SIBLING\\|TAB-ITEM\\|VALUE\\)\\)?\\|O-\\(A\\(PPLY\\|SSIGN\\)\\|B\\(IND-WHERE\\|OX\\)\\|C\\(O\\(LUMN-SCROLLING\\|NVERT\\)\\|URRENT-VALUE\\)\\|D\\(EBUG\\|RAG\\)\\|ECHO\\|INDEX-HINT\\|LOOKAHEAD\\|ROW-MARKERS\\|S\\(CROLLING\\|EPARAT\\(E-CONNECTION\\|ORS\\)\\)\\|UNDERLINE\\|WORD-WRAP\\)\\|UM\\(-\\(BUTTONS\\|CO\\(LUMNS\\|PIES\\)\\|FORMATS\\|ITE\\(MS\\|RATIONS\\)\\|L\\(INES\\|OCKED-COLUMNS\\)\\|MESSAGES\\|RESULTS\\|SELECTED\\(-\\(ROWS\\|WIDGETS\\)\\)?\\|T\\(ABS\\|O-RETAIN\\)\\)\\|ERIC\\(-FORMAT\\)?\\)\\)\\|O\\(CTET_LENGTH\\|K\\(-CANCEL\\)?\\|N-FRAME\\(-BORDER\\)?\\|R\\(DINAL\\|IENTATION\\)\\|S-\\(DRIVES\\|ERROR\\|GETENV\\)\\|UTER\\(-JOIN\\)?\\|WNER\\)\\|P\\(A\\(GE\\(-\\(SIZE\\|WIDTH\\)\\|D\\)\\|R\\(ENT\\|TIAL-KEY\\)\\|SCAL\\|THNAME\\)\\|FC\\(OLOR\\)?\\|I\\(NNABLE\\|XELS-PER-COL\\)\\|O\\(PUP-\\(MENU\\|ONLY\\)\\|SITION\\)\\|R\\(E\\(CISION\\|SELECT\\|V\\(-\\(COLUMN\\|SIBLING\\|TAB-ITEM\\)\\)?\\)\\|I\\(MARY\\|NTER-\\(CONTROL-HANDLE\\|SETUP\\)\\|VATE-DATA\\)\\|N\\|OCEDURE\\)\\|UT-\\(DOUBLE\\|FLOAT\\|LONG\\|S\\(HORT\\|TRING\\)\\|UNSIGNED-SHORT\\)\\)\\|QUE\\(RY-OFF-END\\|STION\\)\\|R\\(A\\(DIO-\\(BUTTONS\\|SET\\)\\|NDOM\\|W\\(-TRANSFER\\)?\\)\\|E\\(A\\(D-\\(FILE\\|ONLY\\)\\|L\\)\\|CURSIVE\\|FRESH\\(ABLE\\)?\\|PL\\(ACE\\(-SELECTION-TEXT\\)?\\|ICATION-\\(CREATE\\|DELETE\\|WRITE\\)\\)\\|QUEST\\|SIZ\\(ABLE\\|E\\)\\|T\\(RY-CANCEL\\|URN-\\(INSERTED\\|TO-START-DIR\\|VALUE\\)\\)\\)\\|IGHT\\(-\\(ALIGNED\\|TRIM\\)\\)?\\|O\\(UND\\|W\\(-\\(MARKERS\\|OF\\)\\|ID\\)?\\)\\|ULE\\(-\\(ROW\\|Y\\)\\)?\\)\\|S\\(AVE-\\(AS\\|FILE\\)\\|CR\\(EEN-VALUE\\|OLL\\(-\\(BARS\\|DELTA\\|HORIZ-VALUE\\|OFFSET\\|TO-\\(CURRENT-ROW\\|ITEM\\|SELECTED-ROW\\)\\|VERT-VALUE\\)\\|ABLE\\|BAR-\\(HORIZONTAL\\|VERTICAL\\|[HV]\\)\\|ED-ROW-POS\\(ITION\\)?\\|ING\\)\\)\\|E\\(-\\(CHECK-POOLS\\|ENABLE-O\\(FF\\|N\\)\\|NUM-POOLS\\|USE-MESSAGE\\)\\|CTION\\|LECT\\(-\\(FOCUSED-ROW\\|NEXT-ROW\\|PREV-ROW\\|R\\(EPOSITIONED-ROW\\|OW\\)\\)\\|ABLE\\|ED\\(-ITEMS\\)?\\|ION-\\(END\\|LIST\\|START\\|TEXT\\)\\)\\|N\\(D\\|SITIVE\\)\\|PARAT\\(E-CONNECTION\\|ORS\\)\\|T-\\(B\\(LUE\\(-VALUE\\)?\\|REAK\\)\\|C\\(ELL-FOCUS\\|ONTENTS\\)\\|DYNAMIC\\|GREEN\\(-VALUE\\)?\\|LEAKPOINT\\|P\\(OINTER-VALUE\\|ROPERTY\\)\\|RE\\(D\\(-VALUE\\)?\\|POSITIONED-ROW\\)\\|S\\(ELECTION\\|IZE\\)\\|WAIT-STATE\\)\\)\\|I\\(DE-LABEL\\(-HANDLE\\|S\\)\\|LENT\\|MPLE\\|NGLE\\|ZE\\(-\\(CHARS\\|PIXELS\\)\\)?\\)\\|LIDER\\|MALLINT\\|O\\(RT\\|URCE\\)\\|Q\\(L\\|RT\\)\\|T\\(A\\(RT\\|TUS-\\(AREA\\(-FONT\\)?\\|BAR\\)\\)\\|DCALL\\|ENCILED\\|O\\(P\\(PED\\)?\\|RED-PROCEDURE\\)\\|RING\\)\\|U\\(B\\(-\\(AVERAGE\\|COUNT\\|M\\(AX\\(IMUM\\)?\\|ENU\\(-HELP\\)?\\|IN\\(IMUM\\)?\\)\\|TOTAL\\)\\|ST\\(ITUTE\\|R\\(ING\\)?\\)\\|TYPE\\)\\|M\\|PPRESS-WARNINGS\\)\\|YSTEM-\\(ALERT-BOXES\\|HELP\\)\\)\\|T\\(A\\(B-POSITION\\|RGET\\)\\|E\\(MP-\\(DIR\\(ECTORY\\)?\\|TABLE\\)\\|RMINATE\\|XT-SELECTED\\)\\|HR\\(EE-D\\|OUGH\\|U\\)\\|I\\(C-MARKS\\|ME-SOURCE\\|TLE-\\(BGC\\(OLOR\\)?\\|DC\\(OLOR\\)?\\|F\\(GC\\(OLOR\\)?\\|ONT\\)\\)\\)\\|O\\(-ROWID\\|DAY\\|GGLE-BOX\\|OL-BAR\\|P\\(IC\\)?\\|TAL\\)\\|R\\(AILING\\|UNC\\(ATE\\)?\\)\\|YPE\\)\\|U\\(N\\(BUFFERED\\|LOAD\\)\\|PPER\\|SE\\(-\\(DICT-EXPS\\|FILENAME\\|TEXT\\)\\)?\\)\\|V\\(6DISPLAY\\|A\\(LID\\(-\\(EVENT\\|HANDLE\\)\\|ATE\\(-\\(CONDITION\\|MESSAGE\\)\\)?\\)\\|R\\(IABLE\\)?\\)\\|ERTICAL\\|I\\(RTUAL-\\(HEIGHT\\(-\\(CHARS\\|PIXELS\\)\\)?\\|WIDTH\\(-\\(CHARS\\|PIXELS\\)\\)?\\)\\|SIBLE\\)\\)\\|W\\(A\\(IT\\|RNING\\)\\|EEKDAY\\|I\\(D\\(GET\\(-\\(ENTER\\|HANDLE\\|LEAVE\\|POOL\\)\\)?\\|TH\\(-\\(CHARS\\|PIXELS\\)\\)?\\)\\|NDOW-\\(NAME\\|S\\(TATE\\|YSTEM\\)\\)\\)\\|ORD-WRAP\\)\\|X-OF\\|Y\\(-OF\\|E\\(AR\\|S-NO\\(-CANCEL\\)?\\)\\)\\|[XY]"
	       "\\)\\>") 'font-lock-function-name-face)
; 
    (cons (concat "\\(^\\|[ :,]?\\)\\<\\("
		  "\\(A\\(BORT\\|NY-\\(KEY\\|PRINTABLE\\)\\|PPEND-LINE\\)\\|B\\(ACK\\(-TAB\\|SPACE\\)\\|L\\(OCK\\|UE\\)\\|OTTOM-COLUMN\\|REAK-LINE\\|S\\)\\|C\\(ANCEL\\(-\\(MOVE\\|PICK\\|RESIZE\\)\\)?\\|HO\\(ICES\\|OSE\\)\\|LOSE\\|O\\(MPILE\\|PY\\)\\|R\\|TRL-\\(ALT-DEL\\|BREAK\\|[GJL]\\)\\|UT\\)\\|D\\(ATA-REFRESH-\\(LINE\\|PAGE\\)\\|E\\(FAULT-\\(ACTION\\|POP-UP\\)\\|L\\(-\\(CHAR\\|LINE\\)\\|ETE-\\(C\\(HAR\\(ACTER\\)?\\|OLUMN\\)\\|END-LINE\\|FIELD\\|LINE\\|WORD\\)\\)?\\|SELECT\\(-EXTEND\\|ION\\(-EXTEND\\)?\\)?\\)\\|ISMISS-MENU\\|O\\(S-END\\|WN-ARROW\\)\\)\\|E\\(DITOR-\\(BACKTAB\\|TAB\\)\\|MPTY-SELECTION\\|N\\(D\\(-\\(ERROR\\|MOVE\\|RESIZE\\|SEARCH\\)\\|KEY\\)\\|TER\\(-MENUBAR\\)?\\)\\|R\\(ASE\\|ROR\\)\\|SC\\|X\\(ECUTE\\|IT\\)\\)\\|F\\(F\\|IND-\\(NEXT\\|PREVIOUS\\)\\|O\\(CUS-IN\\|RMFEED\\)\\)\\|G\\(ET\\|O\\(TO\\)?\\)\\|H\\(ELP-KEY\\|O\\(ME\\|RIZ-\\(END\\|HOME\\|SCROLL-DRAG\\)\\)\\)\\|I\\(NS\\(-\\(CHAR\\|LINE\\)\\|ERT-\\(COLUMN\\|FIELD\\(-\\(DATA\\|LABEL\\)\\)?\\|HERE\\|MODE\\)\\)?\\|TERATION-CHANGED\\)\\|L\\(EFT\\(-\\(ARROW\\|END\\)\\)?\\|F\\|INE\\(-\\(D\\(EL\\|OWN\\)\\|ERASE\\|INS\\|LEFT\\|RIGHT\\|UP\\)\\|FEED\\)\\)\\|M\\(AIN-MENU\\|ENU-DROP\\|OVE\\)\\|NE\\(W-LINE\\|XT-\\(ERROR\\|FRAME\\|PAGE\\|SCRN\\|WORD\\)\\)\\|O\\(FF-\\(END\\|HOME\\)\\|P\\(EN-LINE-ABOVE\\|TIONS\\)\\|UT-OF-DATA\\)\\|P\\(A\\(GE-\\(DOWN\\|ERASE\\|LEFT\\|RIGHT\\(-TEXT\\)?\\|UP\\)\\|RENT-WINDOW-CLOSE\\|STE\\)\\|G\\(DN\\|UP\\)\\|ICK\\(-\\(AREA\\|BOTH\\)\\)?\\|OPUP-MENU-KEY\\|REV-\\(FRAME\\|PAGE\\|SCRN\\|WORD\\)\\)\\|R\\(E\\(CALL\\|D\\|MOVE\\|P\\(LACE\\|ORTS\\)\\|S\\(ET\\|UME-DISPLAY\\)\\)\\|IGHT\\(-\\(ARROW\\|END\\)\\)?\\|OW-\\(DISPLAY\\|ENTRY\\|LEAVE\\)\\)\\|S\\(AVE-AS\\|CROLL\\(-\\(LEFT\\|MODE\\|NOTIFY\\|RIGHT\\)\\)\\|E\\(LECT\\(-EXTEND\\|ION\\(-EXTEND\\)?\\)\\|TTINGS\\)\\|HIFT-TAB\\|T\\(ART-\\(BOX-SELECTION\\|EXTEND-BOX-SELECTION\\|MOVE\\|RESIZE\\|SEARCH\\)\\|OP\\(-DISPLAY\\)?\\)\\)\\|T\\(AB\\|OP-COLUMN\\)\\|U\\(10\\|NIX-END\\|P-ARROW\\|[1-9]\\)\\|VALUE-CHANGED\\|W\\(HITE\\|INDOW-\\(CLOSE\\|RES\\(IZED\\|TORED\\)\\)\\)\\)"
	       "\\)\\>") 'font-lock-reference-face)

)))


(put 'progress-mode 'font-lock-defaults '(progress-font-lock-keywords nil t))


;;;
;;; Progress major mode
;;;
(defun progress-mode ()
  "
Major mode for editing Progress code.
Expression and list commands understand Progress syntax.
Tab indents for Progress code.
Comments are delimited with /* ... */.
Paragraphs are separated by blank lines only.
Delete converts tabs to spaces as it moves back.
\\{pro-mode-map}

Turning on Progress mode calls the value of the variable pro-mode-hook
with no args, if that value is non-nil."
  (interactive)
  (kill-all-local-variables)
  (use-local-map pro-mode-map)
  (setq major-mode 'progress-mode)
  (setq mode-name "Progress")
  (setq local-abbrev-table pro-mode-abbrev-table)
  (set-syntax-table pro-mode-syntax-table)
  (make-local-variable 'paragraph-start)
  (setq paragraph-start (concat "^$\\|" page-delimiter))
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'paragraph-ignore-fill-prefix)
  (setq paragraph-ignore-fill-prefix t)
;  (make-local-variable 'indent-line-function)
;  (setq indent-line-function 'pro-indent-line)
;  (make-local-variable 'indent-region-function)
;  (setq indent-region-function 'pro-indent-region)
  (make-local-variable 'require-final-newline)
  (setq require-final-newline t)
  (make-local-variable 'comment-start)
  (setq comment-start "/* ")
  (make-local-variable 'comment-end)
  (setq comment-end " */")
  (make-local-variable 'comment-column)
  (setq comment-column 0)
  (make-local-variable 'comment-start-skip)
  (setq comment-start-skip "/\\*+ *")
;  (make-local-variable 'comment-indent-function)
; (setq comment-indent-function 'pro-indent-line) ; this is a possible bug
;  (setq indent-tabs-mode t)
  (run-hooks 'pro-mode-hook))


;;;; Tools
;;;
;;; char-at -- return the char following a particular point in the buffer
;;;
(defun char-at (arg)
  (save-excursion
    (goto-char arg)
    (following-char)))

;;;
;;; char-before -- return the char preceding a particular point in the buffer
;;;
(defun my-char-before (arg)
  (save-excursion
    (goto-char arg)
    (preceding-char)))

;;;
;;; Go backwards a function definition
;;;
;; This function is used in parsing to find a point known to be
;; a neutral starting point (not inside comment, string, or include;
;; block-level 0)
;;
;; Please, somebody come up with a better way of doing this!
;;
(defun pro-backward-defun ()
  (interactive)
  (goto-char (point-min))) ; obviously this should be something more sensible

;;;
;;; Looking backwards (reverse version of re-search-forward)
;;; (why didn't emacs have this already?)
;;;
(defun looking-back-at (search-string)
  "A reverse-acting version of looking-at.  See looking-at for details"
  (let ((data (match-data))
	(start-point (point))
	foundit)
    (save-excursion
      (unwind-protect
	  (and (re-search-backward search-string nil t)
	       (eq start-point (match-end 0))
	       (setq data (match-data)
		     foundit t))
	(save-match-data data)))
    foundit))



;;;; Parsing helper routines
;;;
;;; Skip to end of include given we're at include start
;;;
(defun pro-skip-include-forward (&optional lim start)
  "Skip to the end of an inclusion given that we're looking
at an include start.  If the optional LIM parameter is supplied, it is
the limit of the search.

Returns the new point, or NIL if the limit was reached.  If the
optional parameter START is provided, it is the actual start point of
the structure (rather than point, which is assumed if START is nil)."
  (interactive)
  ;;
  ;; Syntactic note -- although strings are legal in includes, and
  ;; vice versa, the arrangement is such that include brackets must
  ;; match.  Therefore we can use the forward-list command of e-lisp.
  ;;
  (let ((end-point 
	 (save-excursion
	   (if start (goto-char start))
	   (if (looking-at pro-include-start)
	       (let ((loc (forward-list)))
		 (if (and lim loc (> loc lim)) nil
		   (and loc (+ loc pro-include-end-offset))))
	     nil))))
    (if end-point
	(goto-char end-point))))

(defun pro-skip-include-backward (&optional lim end)
  "Skip to the beginning of an inclusion given that we're looking
at an include end.  If the optional LIM parameter is supplied, it is
the limit of the search.

Returns the new point, or NIL if the limit was reached.  If the
optional parameter END is provided, it is the actual end point of
the structure (rather than point, which is assumed if END is nil)."
  (interactive)
  (let ((start-point
	 (save-excursion
	   (if end (goto-char end))
	   (if (looking-back-at pro-include-end)
	       (let ((loc (backward-list)))
		 (if (and lim loc (> loc lim)) nil
		   (and loc (+ loc pro-include-start-offset))))
	     nil))))
    (if start-point
	(goto-char start-point))))

;;;
;;; Skip to end of comment given we're at comment start
;;; 
(defun pro-skip-comment-forward (&optional lim start)
  "Skip to the end of a comment given that we're looking at a comment start,
or we're inside the comment (and not in some other syntactic structure
within the comment.

If optional LIM parameter is supplied, it is the limit of the search.
If optional START parameter is supplied, it is the actual start point
of the comment.

Returns the new point, or NIL if the limit was reached"
  (interactive)
  (let (last-match pos)
    ;; check to make sure we're looking at a comment start
    (setq pos
	  (save-excursion
	    ;; skip over it
	    (and (looking-at pro-comment-start)
		 (goto-char (match-end 0)))
	    (catch 'endit
	      (while t
		;; look for a comment start or end
		;; (ignore starts if we're not nesting)
		(setq last-match
		      (re-search-forward (if pro-comments-nest
					     pro-comment-strings
					   pro-comment-start) lim t))

		;; if nothing came of it, fail
		(if (null last-match)
		    (throw 'endit nil))

		;; match succeeded
		;; if we found a comment-end, then that's all
		(goto-char (match-beginning 0))
		(if (looking-at pro-comment-end)
		    (throw 'endit
			   (+ last-match pro-comment-end-offset)))

		;; we found a comment-start
		;; if we're allowing nested comments, recur
		;; (otherwise ignore)
		(if pro-comments-nest
		    (setq last-match
			  (pro-skip-comment-forward lim)))

		;; goto last-match and keep looking
		(goto-char last-match)))))
    (if pos
	(goto-char pos))))

;;;
;;; Skip to start of comment given we're at comment end
;;; 
(defun pro-skip-comment-backward (&optional lim end)
  "Skip to the start of a comment given that we're looking at a comment end,
or we're inside the comment (and not in some other syntactic structure
within the comment).

If optional LIM parameter is supplied, it is the limit of the search.
If optional END parameter is supplied, it is the actual end point
of the comment.

Returns the new point, or NIL if the limit was reached"
  (interactive)
  (let (last-match pos)
    (setq pos
	  (save-excursion
	    ;; skip over comment end if we're looking at it
	    (and (looking-back-at pro-comment-end)
		 (goto-char (match-beginning 0)))
	    (catch 'endit
	      (while t
		;; look for a comment end or start
		;; (ignore ends if we're not nesting)
		(setq last-match
		      (re-search-backward (if pro-comments-nest
					     pro-comment-strings
					   pro-comment-end) lim t))

		;; if nothing came of it, fail
		(if (null last-match)
		    (throw 'endit nil))

		;; match succeeded
		;; if we found a comment-start, then that's all
		(if (looking-at pro-comment-start)
		    (throw 'endit
			   (+ last-match pro-comment-start-offset)))

		;; we found a comment-end
		;; we're allowing nested comments so recur
		(setq last-match
		      (pro-skip-comment-backward lim))

		;; goto last-match and keep looking
		(goto-char (if last-match last-match lim))))))
    (if pos
	(goto-char pos))))

;;;
;;; Skip comments and whitespace forward
;;;
(defun pro-skip-ws-and-comment-forward ()
  "Skip whitespace forward, comments being considered part of whitespace.
Returns the new point."
  (interactive)
  (skip-chars-forward pro-whitespace)
  (while (looking-at pro-comment-start)
    (pro-skip-comment-forward)
    (skip-chars-forward pro-whitespace))
  (point))

;;;
;;; Skip comments and whitespace backward
;;;
(defun pro-skip-ws-and-comment-backward ()
  "Skip whitespace backward, comments being considered part of whitespace.
Returns the new point."
  (interactive)
  (skip-chars-backward pro-whitespace)
  (while (looking-back-at pro-comment-end)
    (pro-skip-comment-backward)
    (skip-chars-backward pro-whitespace))
  (point))

;;;
;;; Skip to end of string given that we're looking at a string delimiter
;;;
(defun pro-skip-string-forward (&optional lim start)
  "Skip to the end of a string given that we're looking at a string
delimiter which we assume to be the start of a string.  If the
optional LIM parameter is supplied, it is the limit of the search.
If the optional START parameter is supplied, it is the actual start
of the string.

Returns the new point, or NIL if the limit was reached."
  (interactive)
  (let (last-match last-match-end last-beginning target
		   (match-char (char-to-string
				(char-at (if start start (point))))))
    (setq target (concat pro-include-start "\\|" match-char))
    (setq last-match
	  (save-excursion
	    (if (looking-at "\\s\"")
		;; skip over it
		(forward-char))
	    (catch 'endit
	      (while t
		;; look for another string delimiter or include delimiter
		;; if we find an include then process it normally
		(setq last-match-end
		      (re-search-forward target lim t))
		(setq last-beginning
		      (match-beginning 0))

		;; if nothing came of it, fail
		(cond
		 ((null last-match-end)
		  (throw 'endit nil))

		 ;; match succeeded
		 ;; if we found an include start then process it
		 ((save-excursion
		    (goto-char last-beginning)
		    (looking-at pro-include-start))
		  (goto-char last-beginning)
		  (setq last-match-end
			(pro-skip-include-forward lim))
		  (goto-char (if last-match-end last-match-end lim)))

		 ;; if we are looking at an escape then ignore it
		 ((save-excursion
		    (goto-char (1- last-beginning))
		    (looking-at "\\s\\"))
		  t)

		 ;; if we're looking at a double and we're supposed to
		 ;; ignore it, then do so by skipping second
		 ((and pro-string-double-escape
		       (looking-at match-char))
		  (forward-char))

		 ;; otherwise, we're looking at string end
		 (t
		  (throw 'endit
			 (+ (point) pro-string-delim-offset))))))))
    (if last-match
	(goto-char last-match))
    last-match))

;;;
;;; Skip to start of string given that we're looking at a string delimiter
;;;
(defun pro-skip-string-backward (&optional lim end)
  "Skip to the start of a string given that we're looking at a string
delimiter which we assume to be the end of a string.  If the
optional LIM parameter is supplied, it is the limit of the search.
If the optional END parameter is supplied, it is the actual end
of the string.

Returns the new point, or NIL if the limit was reached."
  (interactive)
  (let (last-match last-match-start last-end target
		   (match-char (char-to-string
				(my-char-before (if end end (point))))))
    (setq target (concat pro-include-end "\\|" match-char))
    (setq last-match
	  (save-excursion
	    (if (looking-back-at "\\s\"")
		;; skip over it
		(backward-char))
	    (catch 'search-end
	      (while t
		;; look for another string delimiter or include delimiter
		;; if we find an include then process it normally
		(setq last-match-start
		      (re-search-backward target lim t))
		(setq last-end
		      (match-beginning 0))

		;; if nothing came of it, fail
		(cond
		 ((null last-match-start)
		  (throw 'search-end nil))

		 ;; match succeeded
		 ;; if we found an include end then process it
		 ((save-excursion
		    (goto-char last-end)
		    (looking-back-at pro-include-end))
		  (goto-char last-end)
		  (setq last-match-start
			(pro-skip-include-backward lim))
		  (goto-char (if last-match-start last-match-start lim)))

		 ;; if we are looking at an escape then ignore it
		 ((save-excursion
		    (goto-char (1- last-end))
		    (looking-back-at "\\s\\"))
		  t)

		 ;; if we're looking at a double and we're supposed to
		 ;; ignore it, then do so by skipping second
		 ((and pro-string-double-escape
		       (looking-back-at match-char))
		  (backward-char))

		 ;; otherwise, we're looking at string start
		 (t
		  (throw 'search-end
			 (+ (point) pro-string-delim-offset))))))))
    (if last-match
	(goto-char last-match))
    last-match))

;;;
;;; Skip to the end of the current statement
;;;
(defun pro-skip-statement-forward (&optional lim start)
  "Skip to the end of a statement.  We don't have to be at the start of
the statement.  If optional point LIM is reached first, then NIL is
returned, otherwise the point of the statement end is returned.
Optional argument START represents the actual start of the statement,
which we ignore."
  (interactive)
  (let (pos last-match last-beginning
	    (target (concat pro-statement-terminator "\\|"
			    pro-include-start "\\|"
			    pro-comment-start "\\|\\s\"")))
    (setq pos
	  (save-excursion
	    (catch 'endit
	      (while t
		;; look for statement end or a major syntax element start
		;; if we encounter a major syntax element then skip it
		;; and re-search otherwise we've found the end of the
		;; statement
		(setq last-match
		      (re-search-forward target lim t))
		(setq last-beginning
		      (match-beginning 0))

		(cond
		 ;; if search found nothing, then fail
		 ((null last-match)
		  (throw 'endit last-match))

		 ;; match succeeded
		 ;; if we found an include start then process it
		 ((save-excursion
		    (goto-char last-beginning)
		    (looking-at pro-include-start))
		  (goto-char last-beginning)
		  (setq last-match
			(pro-skip-include-forward lim))
		  (goto-char (if last-match last-match lim)))
		 
		 ;; if we found a comment start then process it
		 ((save-excursion
		    (goto-char last-beginning)
		    (looking-at pro-comment-start))
		  (goto-char last-beginning)
		  (setq last-match
			(pro-skip-comment-forward lim))
		  (goto-char (if last-match last-match lim)))
		 
		 ;; if we found a string start then process it
		 ((save-excursion
		    (goto-char last-beginning)
		    (looking-at "\\s\""))
		  (goto-char last-beginning)
		  (setq last-match
			(pro-skip-string-forward lim))
		  (goto-char (if last-match last-match lim)))

		 ;; if we get here, we're looking at a statement end
		 (t
		  (throw 'endit
			 (pro-skip-ws-and-comment-forward))))))))
    (if pos (goto-char pos))
    pos))

;;;
;;; Skip to the start of the current statement
;;;
(defun pro-skip-statement-backward (&optional lim start)
  "Skip to the start of a statement.  We don't have to be at the end of
the statement.  If optional point LIM is reached first, then NIL is
returned, otherwise the point of the statement start is returned.
Optional argument START represents the actual start of the statement,
which we ignore."
  (interactive)
  (let ((target (concat pro-statement-terminator "\\|"
			pro-include-end "\\|"
			pro-comment-end "\\|\\s\""))
	pos last-match last-end)
    (setq pos
	  (save-excursion
	    ;; to prepare, skip backward over comments and whitespace
	    ;; and if we're then looking at a statement termination,
	    ;; then skip over that as well.
	    (if (looking-at pro-statement-terminator) ()
	      (pro-skip-ws-and-comment-backward)
	      (goto-char (- (point) pro-statement-terminator-offset))
	      (if (looking-back-at pro-statement-terminator)
		  (goto-char (match-beginning 0))))

	    ;; now skip over statement body
	    (catch 'foo
	      (while t
		;; look for statement end or a major syntax element start
		;; if we encounter a major syntax element then skip it
		;; and re-search otherwise we've found the start of the
		;; statement
		(setq last-match
		      (re-search-backward target lim t))
		(setq last-end
		      (match-end 0))

		(cond
		 ;; if search found nothing, then fail
		 ((null last-match)
		  (throw 'foo last-match))

		 ;; match succeeded
		 ;; if we found an include start then process it
		 ((save-excursion
		    (goto-char last-end)
		    (looking-back-at pro-include-end))
		  (goto-char last-end)
		  (setq last-match
			(pro-skip-include-backward lim))
		  (goto-char (if last-match last-match lim)))
		 
		 ;; if we found a comment start then process it
		 ((save-excursion
		    (goto-char last-end)
		    (looking-back-at pro-comment-end))
		  (goto-char last-end)
		  (setq last-match
			(pro-skip-comment-backward lim))
		  (goto-char (if last-match last-match lim)))
		 
		 ;; if we found a string start then process it
		 ((save-excursion
		    (goto-char last-end)
		    (looking-back-at "\\s\""))
		  (goto-char last-end)
		  (setq last-match
			(pro-skip-string-backward lim))
		  (goto-char (if last-match last-match lim)))

		 ;; if we get here, we're looking at a statement end
		 ;; skip forward over whitespace and comments to get to
		 ;; a statement start.
		 (t
		  (goto-char last-end)
		  (throw 'foo
			 (pro-skip-ws-and-comment-forward))))))))
    (if pos (goto-char pos))
    pos))

;;;
;;; Skip to the end of the current block
;;;
;;; (This is very similar to goto-statement-end)
;;;
(defun pro-skip-block-forward (&optional lim start)
  "Skip to the end of a block.  We don't have to be at the start of
the block.  If optional point LIM is reached first, then NIL is
returned, otherwise the end point of the block end is returned."
  (interactive)
  (let (pos last-match last-beginning
	    (target (concat pro-block-end "\\|"
			    pro-block-start "\\|"
			    pro-include-start "\\|"
			    pro-comment-start "\\|\\s\"")))
    (setq pos
	  (save-excursion
	    ;; if we're looking at a block start, skip over it
	    (if (looking-at pro-block-start)
		(goto-char (match-end 0)))
	    
	    ;; search for block end
	    (catch 'endit
	      (while t
		;; look for block end or a major syntax element start
		;; if we encounter a major syntax element then skip it
		;; and re-search otherwise we've found the end of the
		;; block
		(setq last-match
		      (re-search-forward target lim t))
		(setq last-beginning
		      (match-beginning 0))

		(cond
		 ;; if search found nothing, then fail
		 ((null last-match)
		  (throw 'endit last-match))

		 ;; match succeeded
		 ;; if we found an include start then process it
		 ((save-excursion
		    (goto-char last-beginning)
		    (looking-at pro-include-start))
		  (goto-char last-beginning)
		  (setq last-match
			(pro-skip-include-forward lim))
		  (goto-char (if last-match last-match lim)))
		 
		 ;; if we found a comment start then process it
		 ((save-excursion
		    (goto-char last-beginning)
		    (looking-at pro-comment-start))
		  (goto-char last-beginning)
		  (setq last-match
			(pro-skip-comment-forward lim))
		  (goto-char (if last-match last-match lim)))
		 
		 ;; if we found a string start then process it
		 ((save-excursion
		    (goto-char last-beginning)
		    (looking-at "\\s\""))
		  (goto-char last-beginning)
		  (setq last-match
			(pro-skip-string-forward lim))
		  (goto-char (if last-match last-match lim)))

		 ;; if we found a block start then process it
		 ((save-excursion
		    (goto-char last-beginning)
		    (looking-at pro-block-start))
		  (goto-char last-beginning)
		  (setq last-match
			(pro-skip-block-forward lim))
		  (goto-char (if last-match last-match lim)))

		 ;; if we get here, we're looking at a block end
		 (t
		  (throw 'endit
			 (+ (point) pro-block-end-offset))))))))
    (if pos (goto-char pos))
    pos))

;;;
;;; Skip to the start of the current block
;;;
;;; (This is very similar to goto-statement-start)
;;;
(defun pro-skip-block-backward (&optional lim end)
  "Skip to the start of a block.  We don't have to be at the end of
the block.  If optional point LIM is reached first, then NIL is
returned, otherwise the start point of the block start is returned."
  (interactive)
  (let (pos last-match last-end
	    (target (concat pro-block-start "\\|"
			    pro-block-end "\\|"
			    pro-include-end "\\|"
			    pro-comment-end "\\|\\s\"")))
    (setq pos
	  (save-excursion
	    ;; eat up any whitespace
	    (pro-skip-ws-and-comment-backward)
	    
	    ;; if we're looking at a block end, skip over it
	    (if (looking-back-at pro-block-end)
		(goto-char (match-beginning 0)))
	    
	    ;; search for block start
	    (catch 'foo
	      (while t
		;; look for block start or a major syntax element end
		;; if we encounter a major syntax element then skip it
		;; and re-search otherwise we've found the start of the
		;; block
		(setq last-match
		      (re-search-backward target lim t))
		(setq last-end
		      (match-end 0))

		(cond
		 ;; if search found nothing, then fail
		 ((null last-match)
		  (throw 'foo last-match))

		 ;; match succeeded
		 ;; if we found an include end then process it
		 ((looking-at pro-include-end)
		  (goto-char last-end)
		  (setq last-match
			(pro-skip-include-backward lim))
		  (goto-char (if last-match last-match lim)))
		 
		 ;; if we found a comment end then process it
		 ((looking-at pro-comment-end)
		  (setq last-match
			(pro-skip-comment-backward lim))
		  (goto-char (if last-match last-match lim)))
		 
		 ;; if we found a string end then process it
		 ((looking-at "\\s\"")
		  (goto-char last-end)
		  (setq last-match
			(pro-skip-string-backward lim))
		  (goto-char (if last-match last-match lim)))

		 ;; if we found a block end then process it
		 ((looking-at pro-block-end)
		  (goto-char last-end)
		  (setq last-match
			(pro-skip-block-backward lim))
		  (goto-char (if last-match last-match lim)))

		 ;; if we get here, we're looking at a block start
		 (t
		  (throw 'foo (point))))))))
    (if pos (goto-char pos))
    pos))

;;;
;;; Parsing syntactic components
;;;
;; The syntactic parsing routine attempts to use the shortcuts available
;; via the "goto" functions above, but if the limit intervenes then they
;; do it the hard way (*sigh*).
;;
;; Note that the point is moved to the end of their structure or to the
;; limit, whichever occurs earlier.
;;

;;;
;;; Skip to the end of the given structure
;;;
(defun pro-goto-end (struct lim &optional struct-start)
  "Skip to the end of the structure STRUCT (which we are currently looking
at) and return the new point, or if there is no end prior to the LIMIT
then return NIL.  If optional parameter STRUCT-START is provided, it is
the point that the structure begins at."
  (cond
   ((eq struct 'statement) (pro-skip-statement-forward lim struct-start))
   ((eq struct 'block) (pro-skip-block-forward lim struct-start))
   ((eq struct 'comment) (pro-skip-comment-forward lim struct-start))
   ((eq struct 'include) (pro-skip-include-forward lim struct-start))
   ((eq struct 'string) (pro-skip-string-forward lim struct-start))
   (t nil)))

;;;
;;; Return a string containing a regexp describing the search target
;;; valid for the inside of the syntactic structure STRUCT
;;;
(defun pro-start-search-target-for (struct)
  "Returns a target start-only search string tailored for STRUCT"
  (cond
   ((eq struct 'statement)
    (concat pro-include-start "\\|"
	    "\\s\"" "\\|"
	    pro-comment-start "\\|"
	    pro-statement-terminator))
   ((eq struct 'block)
    (concat pro-block-start "\\|"
	    pro-include-start "\\|"
	    pro-comment-start "\\|"
	    "\\s\""))
   ((eq struct 'comment) pro-comment-start)
   ((eq struct 'include) (concat pro-include-start "\\|\\s\""))
   ((eq struct 'string) pro-include-start)
   (t ".")))

;;;
;;; Return the start string for the given structure
;;;
(defun pro-start-string (struct)
  "Returns the search string (regexp) that will locate the start
of a syntactic structure of type STRUCT."
  (cond
   ((eq struct 'block) pro-block-start)
   ((eq struct 'include) pro-include-start)
   ((eq struct 'comment) pro-comment-start)
   ((eq struct 'string) "\\s\"")
   ((eq struct 'escape) "\\s\\")
   ((eq struct 'block-end) pro-block-end)
   ((eq struct 'statement) (concat "\\(" pro-statement-terminator
				   "\\)" pro-whitespace-regexp "*"))
   (t ".")))


;;;
;;; Determine the syntactic structure that starts at LOC, if any
;;;
(defun pro-what-is-at (loc)
  "Returns the syntactic structure name which begins at LOC, if
   there is one; nil otherwise."
  (save-excursion
    (goto-char loc)
    (cond
     ((looking-at "\\s\"") 'string)
     ((looking-at pro-include-start) 'include)
     ((looking-at pro-comment-start) 'comment)
     ((looking-at pro-block-start) 'block)
     ((looking-at "\\s\\") 'escape)
     ((and (skip-chars-backward pro-whitespace)
	   (backward-char)
	   (looking-at pro-statement-terminator))
      'statement)
     (t nil))))


;;;
;;; Parsing general syntax structures
;;;
(defun pro-parse-structure
  (struct lim state depth &optional target-depth stop-at carryon)
  "Parse an syntax element by skipping over it or analysing it up to
the limit.  Returns a state string as used in pro-parse.

Parameters:
    STRUCT -- The name of the structure to parse.  Can be one of:
        'comment   'include   'block   'string   'statement
    LIM -- The limit point.  Parsing continues up to this point.
    STATE -- The starting containing structures list.
    DEPTH -- The current block depth.

Optional Parameters:
    TARGET-DEPTH -- If this is non-nil, then parsing stops prior to
        the limit if this block depth is reached.
    STOP-AT -- If this is non-nil, then parsing stops when the named
        structure is encountered (see STRUCT for structure names).
    CARRYON -- If this is non-nil, it is assumed that the head element
        of the state list is for the structure we are being asked to
        parse."
  (cond
   ;; check to see if we've reached target depth, if any
   ((and target-depth
	 (eq struct 'block)
	 (eq depth target-depth))
    (if (looking-at pro-block-start)
	(goto-char (match-end 0)))
    (throw 'pro-parse-exit state))

   ;; check for an other stop-at condition
   ((and stop-at
	 (eq stop-at struct)
	 (eq stop-at (pro-what-is-at (point))))
    (throw 'pro-parse-exit state))

   ;; otherwise, parse normally
   (t
    (let ((actual-end (save-excursion
			(pro-goto-end struct lim
				      (if carryon
					  (cdr (car state))
					nil)))))
      (if actual-end
	  ;; we are able to use shortcut because the actual end of the
	  ;; structure falls inside the limit.
	  ;; return state we were passed
	  (and (goto-char actual-end)
	       (if carryon (cdr state) state))
      
	;; The limit occurs before the end of the structure, so
	;; we have to do it the hard way.
	(let ((target (pro-start-search-target-for struct))
	      cur-struct)
	
	  ;; Start by modifying state so that it's expanded to include
	  ;; a pointer to the current point as a structure start.
	  (or carryon
	      (setq state (cons (cons struct (point)) state)))

	  ;; ... and skip over the struct start itself
	  (and (looking-at (pro-start-string struct))
	       (goto-char (match-end 0)))

	  ;; skip over available syntactic structures until we hit limit
	  (while (and (< (point) lim)
		      (re-search-forward target lim 0))
	    ;; we found a syntax element start inside the limit
	    ;; use parse function to traverse it
	    (goto-char (match-beginning 0))
	    (setq cur-struct (pro-what-is-at (point)))
	    (setq state
		  (pro-parse-structure cur-struct lim state
				       (if (eq 'block cur-struct)
					   (1+ depth) depth)
				       target-depth stop-at)))
	  ;; when we get here, point is at the limit
	  ;; we return state as modified to include our own
	  ;; start notation and any other modifications due
	  ;; to called parsing functions finding the limit
	  state))))))

;;;
;;; Count number of structures appearing in a structure list
;;;
(defun pro-count-structures (struct struct-list)
  "Count the number of structures appearing in a structure list"
  (if struct
      (let (count func)
	(setq func (append '(+)
			   (mapcar
			    (lambda (a) (if (eq (car a) struct) 1 0))
			    struct-list)))
	(setq count (eval func)))
    0))


;;;
;;; General partial parse routine -- forward
;;;
(defun pro-parse-forward
  (start lim &optional
	 target-depth stop-at state)
  "Parse Progress code in a manner similar to parse-partial-sexp.
Starts at START and proceeds until LIMIT or a stop condition is reached.

If argument TARGET-DEPTH is non-nil, then parsing will stop when the block
depth reaches TARGET-DEPTH.

If argument STOP-AT is non-nil, then it indicates a request to stop at the
start of the indicated structure.  Valid structures are:
   'block  'comment  'string  'include  'statement
   A comment is reached (if STOP-COMMENT is t)
   A string is reached (if STOP-STRING is t)
   An inclusion directive is reached (if STOP-INCLUDE is t)

Parsing must start at a top-level, or STATE must be set to an initializing
list.  The state list is a list giving the start points of containing
syntactic structures.

This is an association list in dotted-pair format, with the innermost
containing syntactic structure at the head of the list.  Valid
association targets are:
   'include  'comment  'string  'block  'statement
"
  (save-excursion
    (let ((struct-list (if state state nil))
	  ;; state variables
	  block-depth
	  struct-list
	  struct
	  ;; start and finish adjustment
 	  (start-point (min start lim))
	  (limit (max start lim)))

    ;; initialize variables from state
    (setq block-depth (pro-count-structures 'block struct-list))

    ;; move to start position
    (goto-char start-point)

    ;; scan through code, parsing as we go
    (while (< (point) limit)
      (skip-chars-forward pro-whitespace)
      (cond
       ;; check to make sure we haven't gone past limit
       ((not (< (point) limit)) t)

       ;; if we're currently in a syntactic structure, try to skip to its end
       (struct-list
	(setq struct-list
	      (pro-parse-structure (car (car struct-list))
				   limit struct-list block-depth
				   target-depth stop-at t)))
       ;; otherwise if we're looking at a structure start, try to skip over it
       ((setq struct (pro-what-is-at (point)))
	(setq struct-list
	      (pro-parse-structure
	       struct limit struct-list
	       (if (eq struct 'block) (1+ block-depth) block-depth)
	       target-depth stop-at)))
       ;; otherwise skip over the current statement if we can and try again
       (t
	(setq struct-list
	      (pro-parse-structure
	       'statement limit struct-list block-depth target-depth stop-at)))
       ) ;end of cond
      ) ;end of while

    ;; evaluate structure list for return
    struct-list
    ) ;end of let
  )) ;end of defun



;;;; Syntax element motion commands
;;;
;;; Skipping statements forward
;;;
(defun pro-statement-forward (&optional arg)
  "Skip forward to the end of the current statement.  If optional argument
ARG is supplied, do it ARG times.  Comments are ignored.  Returns the
new point."
  (interactive "P")
  (cond
   ((eq arg 0) t)
   ((and arg (< arg 0)) (pro-statement-backward (- arg)))
   (t
    (let ((count 0) (lim (if arg arg 1)))
      (while (< count lim)
	(pro-skip-statement-forward)
	(setq count (1+ count)))
      (point)))))

;;;
;;; Skipping statements backward
;;;
(defun pro-statement-backward (&optional arg)
  "Skip backward to the start of the current statement.  If optional argument
ARG is supplied, do it ARG times.  Comments are ignored.  Returns the
new point."
  (interactive "P")
  (cond
   ((eq arg 0) t)
   ((and arg (< arg 0)) (pro-statement-forward (- arg)))
   (t
    (let ((count 0) (lim (if arg arg 1)))
      (while (< count lim)
	(pro-skip-statement-backward)
	(setq count (1+ count)))
      (point)))))


;;;; Indentation tool routines
;;;
;;; pro-current-block-depth -- Compute current block depth
;;;
(defun pro-current-block-depth ()
  "Returns the block depth at point as an integer"
  (pro-count-structures
   'block
   (pro-parse-forward
    (save-excursion (pro-backward-defun))
    (point))))


;;;
;;; Determine if we're inside a statement
;;;
(defun pro-inside-statement (&optional start-point)
  "Returns t if point (or START-POINT if supplied) is inside a statement.
Assumes that start point NOT inside a string or comment"
  (save-excursion
    (if start-point (goto-char start-point))
    (cond
     ((eq (point-min) (point))
	nil)
     ((save-excursion
	(pro-skip-ws-and-comment-forward)
	(eq (point-max) (point)))
      (pro-skip-ws-and-comment-backward)
      (forward-char)
      (not (looking-back-at pro-statement-terminator)))
     (t
      (let ((started-at (point))
	    start1 start2 finish1)
	(setq start1 (or (pro-skip-statement-backward)
			 (progn
			   (goto-char (point-min))
			   (pro-skip-ws-and-comment-forward))))
	(setq start2 (or (pro-skip-statement-forward)
			 (goto-char (point-max))))
	(setq finish1 (pro-skip-ws-and-comment-backward))
	(cond
	 ;; before 1st statement (also implies no statements)
	 ((not (> started-at start1)) nil)
	 ;; between statements
	 ((not (< started-at finish1)) nil)
	 ;; otherwise must be in statement
	 (t t)))))))

;;;
;;; Set indentation levels to argument
;;;
(defun pro-set-indent (amt)
  "Set indentation depth to AMT"
  (interactive "NIndentation step depth: ")
  (let ((indent-amt (if (listp amt) (car amt) amt)))
    (setq pro-block-indent indent-amt)
    (setq pro-include-indent indent-amt)
    (setq pro-continuation-indent indent-amt)))
       

;;;
;;; Set indentation offset
;;;
(defun pro-set-indent-offset (amt)
  "Set indentation offset to AMT"
  (interactive "P")
  (setq pro-indent-offset
	(cond
	 ((null amt) (current-column))
	 ((numberp amt) (1- amt))
	 (t pro-indent-offset))))



;;;; Indentation routines
;;;
;;; calculate-pro-indent -- Compute the appropriate indentation for 
;;;    the current line
;;;
(defun calculate-pro-indent (&optional parse-start)
  ;; parse-start is char to begin parse from
  "Return appropriate indentation for current line as Progress code.
In usual case returns an integer: the column to indent to.
Returns nil if line starts inside a string, t if in a comment."

  (save-excursion
    (beginning-of-line)
    (let ((indent-point (point))
	  (case-fold-search nil)
	  (target (concat "\\(" pro-statement-terminator
			  "\\|" pro-include-end
			  "\\)" pro-whitespace-regexp "*"))
	  (at-block-end
	   (looking-at (concat pro-whitespace-regexp "*" pro-block-end)))
	  statement1 statement2
	  state
	  basic-indent
	  innermost)

      ;; determine if we're in a comment or string
      (setq state
	    (pro-parse-forward
	     (if parse-start parse-start
	       (save-excursion (pro-backward-defun) (point)))
	     indent-point))
      (if state
	  (setq innermost (car (car state))))

      ;; Compute basic indent (i.e. indention of statement start)
      ;; by finding our current depth in indents & includes.
      (setq basic-indent
	    (if state
		(+ (* pro-block-indent
		      (pro-count-structures 'block state))
		   (* pro-include-indent
		      (pro-count-structures 'include state)))
	      0))

      ;; Adjust basic indent if we're looking at a block end
      (and at-block-end
	   (not pro-indent-block-end)
	   (> basic-indent 0)
	   (setq basic-indent (- basic-indent pro-block-indent)))

      ;; ... and add in offset, if any
      (setq basic-indent (+ basic-indent pro-indent-offset))

      (cond
       ((eq innermost 'comment) (list t basic-indent))
       ((eq innermost 'string) nil)
       (t
	;; We aren't in a comment or string.
	;; Adjust indentation if we're after a line requiring special handling
	(if (and pro-indent-after
		 (save-excursion
		   (pro-skip-ws-and-comment-backward)
		   (looking-back-at pro-indent-after)))
	    (setq basic-indent (+ basic-indent pro-continuation-indent)))
	(if (and pro-unindent-after
		 (save-excursion
		   (pro-skip-ws-and-comment-backward)
		   (looking-back-at pro-unindent-after)))
	    (setq basic-indent (- basic-indent pro-continuation-indent)))
	
	;; the actual indentation is the basic indent, plus
	;; the continuation offset if we're inside a statement
	(+ basic-indent
	   (if (pro-inside-statement) pro-continuation-indent 0)))))))


;;;
;;; Indent-line function -- called by TAB 
;;;
(defun pro-indent-line ()
  "Indent current line as Progress code.
Return the amount the indentation changed by."
  (let ((indent (calculate-pro-indent))
	beg shift-amt
	(case-fold-search nil)
	(pos (- (point-max) (point))))
    (beginning-of-line)
    (setq beg (point))
    (cond ((eq indent nil) ;string
	   (setq indent (current-indentation)))
	  ((and (listp indent) (eq (car indent) t)) ;comment
	   (setq indent (+ pro-comment-continuation (car (cdr indent)))))
	  (t nil))
    (skip-chars-forward " \t")
    (setq shift-amt (- indent (current-column)))
    (if (zerop shift-amt)
	(if (> (- (point-max) pos) (point))
	    (goto-char (- (point-max) pos)))
      (delete-region beg (point))
      (indent-to indent)
      ;; If initial point was within line's indentation,
      ;; position after the indentation.  Else stay at same point in text.
      (if (> (- (point-max) pos) (point))
	  (goto-char (- (point-max) pos))))
    shift-amt))


;;;; Insertion functions
;;;
;;; Insert character pair
;;;
(defun pro-insert-char-pair ()
  "Insert a matched pair of characters"
  (interactive)
  (cond
   ((eq last-command-char ?{)
    (insert-string "{  }")
    (backward-char 2))
   ((eq last-command-char ?\[)
    (insert-string "[  ]")
    (backward-char 2))
   ((eq last-command-char ?\")
    (insert-string "\"\"")
    (backward-char))
   ((eq last-command-char ?\')
    (insert-string "\'\'")
    (backward-char))))



;;;; Electric functions
;;;
;;; Electric braces -- inserts spacing as appropriate
;;;
(defun electric-pro-brace (arg)
  "Insert character and correct spacing around character."
  (interactive "P")
  (insert-char last-command-char 1)
  (cond
   (arg nil)
   ((not pro-include-with-spaces) nil)
   ((char-equal last-command-char ?{)
    (insert-char ?\  1))
   ((char-equal last-command-char ?})
    (save-excursion
      (cond
       ((looking-back-at pro-include-arg-ref-with-spaces)
	(goto-char (match-beginning 0))
	(forward-char)
	(if (looking-at " ")
	    (delete-char 1)))
       ((not (looking-back-at pro-include-arg-ref))
	(backward-char)
	(or (looking-back-at pro-whitespace-regexp)
	    (insert-char ?\  1))))))
   (t nil)))



(defun pro-electric-progress-debug ()
 (interactive)
 (insert "/*DEBUG*/ IF USERID = 'programist' THEN MESSAGE ")
 (save-excursion
      (insert "  VIEW-AS ALERT-BOX WARNING TITLE 'DEBUG'."))
)

;;; progress-mode.el ends here

(defun electric-progress-tabulator ()
 (interactive)
 (defvar cnst)
 (defvar spacesCnt)
 (setq cnst 2)
 (setq spacesCnt 1)

 (setq spacesCnt (mod (1+ (current-column)) cnst))
  (if (= spacesCnt 1) (insert "  "))
  (if (= spacesCnt 0) (insert " "))
)


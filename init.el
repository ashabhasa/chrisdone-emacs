
;; Standard libraries needed

(require 'cl)


;; Packages and configs to load

(defvar packages
  '(color-theme
    zenburn
    sunburn
    god-mode
    paredit
    audit
    haskell-mode
    smex
    magit
    goto-last-change
    markdown-mode
    dash
    elisp-slime-nav
    echo-keys
    align-by-current-symbol
    ag
    goto-last-point
    github-urls
    s
    hamlet-mode
    number
    hide-region
    ats-mode
    org-focus
    multiple-cursors
    toggl
    projects-mode
    resmacro
    flycheck
    json-reformat
    restclient
    purescript-mode
    yaml-mode
    websocket
    quickjump
    slow-keys
    stack-doc
    )
  "Packages whose location follows the
  packages/package-name/package-name.el format.")

(defvar custom-load-paths
  '("structured-haskell-mode/elisp"
    "hindent/elisp"
    "git-modes"
    "company-mode"
    "intero/elisp")
  "Custom load paths that don't follow the normal
  package-name/module-name.el format.")

(defvar configs
  '("global"
    "god"
    "haskell"
    "erc"
    "email"
    "lisp"
    "w3m"
    "markdown"
    "org")
  "Configuration files that follow the config/foo.el file path
  format.")


;; Load packages

(loop for location in custom-load-paths
      do (add-to-list 'load-path
             (concat (file-name-directory (or load-file-name
                                              (buffer-file-name)))
                     "packages/"
                     location)))

(loop for name in packages
      do (progn (unless (fboundp name)
                  (add-to-list 'load-path
                               (concat (file-name-directory (or load-file-name
                                                                (buffer-file-name)))
                                       "packages/"
                                       (symbol-name name)))
                  (require name))))

(require 'shm)
(require 'hindent)
(require 'org-multiclock)
(require 'shm-case-split)
(require 'shm-reformat)
(require 'org-multiclock)
(require 'company)
(require 'w3m-haddock)
(require 'magit-blame)
(require 'intero)
(require 'haskell-mode)
(require 'haskell-interactive-mode)
(require 'haskell)
(require 'haskell-simple-indent)
;(require 'dash)
;(require 's)


;; Emacs configurations

(loop for name in configs
      do (load (concat (file-name-directory load-file-name)
                       "config/"
                       name ".el")))


;; Mode initializations

(smex-initialize)
(sunburn)
(god-mode)
(goto-last-point-mode)
(turn-on-haskell-simple-indent)
(org-agenda-list)
(org-focus)

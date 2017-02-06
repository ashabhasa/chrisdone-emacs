(require 'markdown-mode)

(defvar markdown-code-languages
  '("haskell" "lisp" "javascript" "c"))

(defun markdown-code-fence (beg end)
  "Make a code fence of the given region."
  (interactive "r")
  (save-excursion
    (goto-char beg)
    (goto-char (line-beginning-position))
    (insert "``` "
            (ido-completing-read "Language: " markdown-code-languages)
            "\n")
    (goto-char end)
    (goto-char (line-end-position))
    (newline)
    (insert "```")))

(define-key markdown-mode-map (kbd "C-c C-f") 'markdown-code-fence)
(define-key markdown-mode-map (kbd "M-;") 'markdown-blockquote-region)

(define-key markdown-mode-map [f5] 'markdown-gist-refresh)
(defun markdown-gist-refresh ()
  (interactive)
  (when (not (string= "" (shell-command-to-string "git remote -v | grep ^origin | grep '(push)' | grep blah")))
    (message "OK, go!")))

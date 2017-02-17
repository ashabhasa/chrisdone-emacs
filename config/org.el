(defun org-fast-task-reclock (&optional no-clock)
  "Quickly make a new task and clock into it."
  (interactive "P")
  (let ((file (ido-completing-read "Org-file: " (reverse org-agenda-files))))
    (find-file file)
    (let ((headings (list)))
      (save-excursion
        (goto-char (point-min))
        (while (search-forward-regexp "^\\*" nil t)
          (destructuring-bind (_ _ status _ title _) (org-heading-components)
            (when (not status)
              (push title headings))
            (end-of-line))))
      (let ((heading (ido-completing-read "Project: " headings))
            (found nil))
        (goto-char (point-min))
        (while (and (not found)
                    (search-forward-regexp "^\\*" nil t))
          (destructuring-bind (_ _ status _ title _) (org-heading-components)
            (when (string= heading title)
              (setq found t)
              (org-insert-todo-heading-respect-content)
              (org-metaright 1)
              (org-todo "TODO")
              (insert (read-from-minibuffer "Task title: "))
              (unless no-clock (org-clock-in)))
            (end-of-line)))))))

(define-key org-mode-map (kbd "C-#") 'org-begin-template)
(defun org-begin-template ()
  "Make a template at point."
  (interactive)
  (if (org-at-table-p)
      (call-interactively 'org-table-rotate-recalc-marks)
    (let* ((choices '(("s" . "SRC")
                      ("e" . "EXAMPLE")
                      ("q" . "QUOTE")
                      ("v" . "VERSE")
                      ("c" . "CENTER")
                      ("l" . "LaTeX")
                      ("h" . "HTML")
                      ("a" . "ASCII")))
           (key
            (key-description
             (vector
              (read-key
               (concat (propertize "Template type: " 'face 'minibuffer-prompt)
                       (mapconcat (lambda (choice)
                                    (concat (propertize (car choice) 'face 'font-lock-type-face)
                                            ": "
                                            (cdr choice)))
                                  choices
                                  ", ")))))))
      (let ((result (assoc key choices)))
        (when result
          (let ((choice (cdr result)))
            (cond
             ((region-active-p)
              (let ((start (region-beginning))
                    (end (region-end)))
                (goto-char end)
                (insert "\n#+END_" choice)
                (goto-char start)
                (insert "#+BEGIN_" choice "\n")))
             (t
              (insert "#+BEGIN_" choice "\n")
              (save-excursion (insert "\n#+END_" choice))))))))))

(define-key org-mode-map (kbd "C-c C-e") 'org-focus-estimate)
(define-key org-mode-map (kbd "C-c C-s") 'org-focus-schedule)
(define-key org-mode-map (kbd "C-c C-x C-i") 'org-clock-in)
(define-key org-mode-map (kbd "C-c C-x C-b") 'org-focus-bump)
(setq org-clock-clocked-in-display nil)

(defun org-focus-contract-start ()
  (save-excursion
    (goto-char (point-min))
    (when (search-forward-regexp "#\\+CONTRACT_START: \\(.+\\)$" nil t 1)
      (org-focus-parse-time (match-string 1)))))

(defun org-focus-contract-hours ()
  (save-excursion
    (goto-char (point-min))
    (when (search-forward-regexp "#\\+CONTRACT_HOURS: \\([0-9]+\\)$" nil t 1)
      (string-to-number (match-string 1)))))

(defun org-toggl-client-id ()
  (save-excursion
    (goto-char (point-min))
    (when (search-forward-regexp "#\\+TOGGL_CLIENT_ID: \\([0-9]+\\)$" nil t 1)
      (string-to-number (match-string 1)))))

(defun org-toggl-project-id ()
  (save-excursion
    (goto-char (point-min))
    (when (search-forward-regexp "#\\+TOGGL_PROJECT_ID: \\([0-9]+\\)$" nil t 1)
      (string-to-number (match-string 1)))))

(defun org-focus-timesheet ()
  "Generate a work timesheet since DATE."
  (interactive)
  (let* ((contract-start (org-focus-contract-start))
         (start-date
          (org-focus-parse-time
           (read-from-minibuffer
            "Since date: "
            (if contract-start
                (format-time-string "%Y-%m-%d" contract-start)
              (format-time-string "%Y-%m-01")))))
         (hours-ordered (org-focus-contract-hours))
         (items (org-focus-buffer-items))
         (buffer-name (replace-in-string (buffer-name) ".org" ""))
         (histogram (make-hash-table :test 'equal))
         (hours-used 0.0))
    (mapc (lambda (item)
            (when (plist-get item :clocks)
              (mapc (lambda (clock)
                      (let* ((date (plist-get clock :date))
                             (hours (plist-get clock :hours))
                             (key (concat (format-time-string "%Y-%m-%d" date)
                                          "\t"
                                          (plist-get item :title))))
                        (when (and (> hours 0.0)
                                   (org-focus-day< start-date date))
                          (setq hours-used (+ hours-used hours))
                          (puthash key
                                   (+ (gethash key histogram 0)
                                      hours)
                                   histogram))))
                    (plist-get item :clocks))))
          items)
    (let ((buffer
           (get-buffer-create
            (format "*Timesheet from %s*"
                    (format-time-string "%Y-%m-%d" start-date)))))
      (with-current-buffer buffer
        (let ((inhibit-read-only t))
          (erase-buffer)
          (maphash (lambda (key hours)
                     (let* ((parts (split-string key "\t"))
                            (date (nth 0 parts))
                            (title (nth 1 parts)))
                       (insert (format "%s\t%.1f\t\t%s\n"
                                       (replace-regexp-in-string "[0-9]+-[0-9]+-" "" date)
                                       hours
                                       title))))
                   histogram)
          (sort-lines nil
                      (point-min)
                      (point-max))
          (goto-char (point-min))
          (insert (format "Reporting start: %s\n"
                          (format-time-string "%Y-%m-%d" start-date))
                  (format "Hours used: %.2f\n" hours-used)
                  "\n"
                  (format "Client: %s\n" buffer-name)
                  (if contract-start
                      (format "Contract start: %s\n"
                              (format-time-string "%Y-%m-%d" contract-start))
                    "")
                  (if (and contract-start
                           (org-focus-day= contract-start start-date)
                           hours-ordered)
                      (format "Hours left: %.2f\n" (- hours-ordered hours-used))
                    "")
                  "\n")))
      (switch-to-buffer-other-window buffer))))

(defun org-focus-toggl ()
  "Generate an import file for toggl."
  (interactive)
  (let* ((contract-start (org-focus-contract-start))
         (start-date
          (org-focus-parse-time
           (read-from-minibuffer
            "Since date: "
            (if contract-start
                (format-time-string "%Y-%m-%d" contract-start)
              (format-time-string "%Y-%m-01")))))
         (items (org-focus-buffer-items))
         (client (read-from-minibuffer "Client: "))
         (project (read-from-minibuffer "Project: "))
         (buffer
          (get-buffer-create
           (format "*Toggle from %s*"
                   (format-time-string "%Y-%m-%d" start-date)))))
    (with-current-buffer buffer
      (let ((inhibit-read-only t)
            (lasthash nil))
        (erase-buffer)
        (mapc
         (lambda (item)
           (mapc
            (lambda (clock)
              (let* ((hash (make-hash-table)))
                (when (and (> (plist-get clock :hours) 0.0)
                           (org-focus-day< start-date (plist-get clock :date)))
                  (puthash "Email" "chrisdone@fpcomplete.com" hash)
                  (puthash "Client" client hash)
                  (puthash "Description" (plist-get item :title) hash)
                  (puthash "Start date" (format-time-string "%F" (plist-get clock :date)) hash)
                  (puthash "Start time" (format-time-string "%T" (plist-get clock :date)) hash)
                  (puthash "Duration" (concat (plist-get clock :hours-stamp) ":00") hash)
                  (puthash "Billable" "Y" hash)
                  (mapc (lambda (key)
                          (insert (gethash key hash) "\t"))
                        (hash-table-keys hash))
                  (insert "\n")
                  (setq lasthash hash))))
            (plist-get item :clocks)))
         items)
        (goto-char (point-min))
        (insert (mapconcat #'identity (hash-table-keys lasthash) "\t")
                "\n")))
    (switch-to-buffer-other-window buffer)
    ))


(define-key org-focus-mode-map (kbd "t") 'org-focus-toggl)
(defvar org-focus-toggl-regex
  "[ ]+\\([^ ]+\\)[ ]+\\([0-9]+:[0-9]+\\)[ ]+/[ ]+[0-9:]+[ ]+[A-Z]+[ ]+\\(.+\\)")
(defvar org-focus-projects
  '())
(defun org-focus-toggl ()
  (interactive)
  (let ((this-time (get-text-property (point) 'time)))
    (when this-time
      (forward-line 1)
      (goto-char (line-beginning-position))
      (while (looking-at org-focus-toggl-regex)
        (let* ((fname (match-string-no-properties 1))
               (hours (match-string-no-properties 2))
               (description (match-string-no-properties 3))
               (pid (cdr (assoc fname org-focus-projects))))
          (toggl-submit
           pid
           (org-focus-trim-string description)
           this-time
           (* (org-focus-parse-hours hours) 60 60))
          (sit-for 1.5)
          (forward-line 1)))
      (message "Clocks toggl'd!")))))
(defun org-focus-trim-string (string)
  "Remove white spaces in beginning and ending of STRING.
White space here is any of: space, tab, emacs newline (line feed, ASCII 10)."
  (replace-regexp-in-string "\\`[ \t\n]*" "" (replace-regexp-in-string "[ \t\n]*\\'" "" string)))

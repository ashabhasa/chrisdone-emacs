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
                                          "Chris Done"
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
                     (insert (format "%s\t%.2f\n" key hours)))
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

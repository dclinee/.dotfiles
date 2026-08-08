;;; init-avy.el --- Integrated for the avy package -*- lexical-binding: t -*-
;;; Commentary:

;;; Code:

(use-package avy
  :ensure t
  :defer t
  :commands (avy--generic-jump)
  :bind
  (                         ; Commonly used shortcuts keys in avy mode
   ("C-;" . avy-goto-char-timer)        ;Goto a char
   ("C-'" . avy-goto-word-1)            ;Goto first char of one word
   ("M-g e" . avy-goto-word-0)          ;Goto x char of one word
   ("M-g t" . avy-goto-char-in-line)    ;Goto a char in current line
   ("M-g f" . avy-goto-line)            ;Goto one line
   ("M-g l" . avy-copy-line)            ;Copy whole line
   ("M-g m" . avy-move-line)            ;Move whole line
   ("M-g d" . avy-kill-whole-line)      ;Kill whole line
   ("M-g k" . avy-kill-ring-save-whole-line) ;copy whole line to kill-ring
   ("M-g y" . avy-copy-region)               ;Copy region
   ("M-g r" . avy-move-region)               ;Move region
   ("C-c C-j" . avy-resume))                 ;Last avy command
  :config
  ;; Basic configuration
  ;; Set avy-keys to a list containing all upper and lower case letters.
  (setq avy-keys (nconc (number-sequence ?a ?z)
                        ))
  ;;--------------------------------------------------------------------
  ;;Jumping to conditionals in Elisp
  (defun avy-goto-conditional ()
    "Jump to conditional keywords like,if, cond, when, unless
in the text."
    (interactive)
    (avy--generic-jump "\\s(\\(if\\|cond\\|when\\|unless\\)\\b" nil 0))
  (global-set-key (kbd "M-g c") 'avy-goto-conditional)
  ;;--------------------------------------------------------------------
  ;; Jumping to kill whole line
  (defun avy-action-kill-whole-line (pt)
    (save-excursion
      (goto-char pt)
      (kill-whole-line))
    (select-window
     (cdr
      (ring-ref avy-ring 0)))
    t)

  (setf (alist-get ?k avy-dispatch-alist) 'avy-action-kill-stay
        (alist-get ?K avy-dispatch-alist) 'avy-action-kill-whole-line)
  ;;--------------------------------------------------------------------
  ;; Official avy action
  (setf (alist-get ?\C-y avy-dispatch-alist) 'avy-action-yank
        (alist-get ?\M-w avy-dispatch-alist) 'avy-action-copy
        (alist-get ?\C-k avy-dispatch-alist) 'avy-action-kill-move
        (alist-get ?\C-t avy-dispatch-alist) 'avy-action-teleport)
  ;;--------------------------------------------------------------------

  )

(provide 'init-avy)
;;; init-avy.el ends here

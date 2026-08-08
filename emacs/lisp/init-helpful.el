;;; init-helpful.el --- Support for the helpful package -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

;; Note that the built-in `describe-function' includes both functions
;; and macros. `helpful-function' is functions only, so we provide
;; `helpful-callable' as a drop-in replacement.
(use-package helpful
  :ensure t
  :defer t
  :bind (("C-h f" . helpful-callable)
         ("C-h F" . helpful-function)
         ("C-h v" . helpful-variable)
         ("C-h k" . helpful-key)
         ("C-h x" . helpful-command)
         ;; Lookup the current symbol at point. C-c C-d is a common keybinding
         ;; for this in lisp modes.
         ("C-c C-d" . helpful-at-point))
  :config
  (setq helpful-max-buffers 5)
  (setq counsel-describe-function-function #'helpful-callable)
  (setq counsel-describe-variable-function #'helpful-variable)
  )

(provide 'init-helpful)
;;; init-helpful.el ends here

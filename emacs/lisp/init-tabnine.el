;;; init-tabnine.el --- Integration of the company-tabnine  -*- lexical-binding: t -*-

;;; Commentary:
;;; Configures company-tabnine with proper backend integration and settings.

;;; Code:

(use-package company-tabnine
  :ensure t
  :after company
  :config
  ;; Configure TabNine settings
  (setq company-tabnine--disable-auto-discover nil
        company-tabnine-show-deprecated-version nil
        company-idle-delay 0.1
        company-show-numbers t
        company-tabnine-max-num-results 5
        company-tabnine-use-deep-completions t))

(defun my/company-tabnine-setup ()
  "Configure company-backends for programming modes with TabNine integration."
  (setq-local company-backends
              '((company-tabnine)  ; Combine with standard completions
                company-files
                company-keywords)))

(add-hook 'prog-mode-hook #'my/company-tabnine-setup)

(provide 'init-tabnine)
;;; init-tabnine.el ends here

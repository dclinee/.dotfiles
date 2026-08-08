;;; init-helm.el --- Helm configuration for efficient navigation and completion -*- lexical-binding: t -*-
;;; Commentary:
;; This configuration provides a complete setup for Helm in Emacs,
;; offering efficient navigation, completion and search capabilities.

;;; Code:

;; =======================
;; 1. Package Installation
;; =======================

(use-package helm
  :ensure t

  ;; =======================
  ;; 2. Basic Configuration
  ;; =======================
  :config

  ;; Enable Helm mode globally
  (helm-mode 1)

  ;; Automatically resize Helm window
  ;;(setq helm-autoresize-max-height 40)
  ;;(setq helm-autoresize-min-height 20)
  (helm-autoresize-mode 1)
  (global-set-key (kbd "C-c h") #'helm-command-prefix)
  (global-unset-key (kbd "C-x c"))

  ;; Fuzzy matching
  (setq helm-mode-fuzzy-match t)
  (setq helm-completion-in-region-fuzzy-match t)
  (setq helm-M-x-fuzzy-match t)
  (setq helm-buffers-fuzzy-matching t)
  (setq helm-recentf-fuzzy-match t)
  (setq helm-semantic-fuzzy-match t)
  (setq helm-imenu-fuzzy-match t)

  :bind (("M-x" . helm-M-x)
         ("C-x b" . helm-mini)
         ("M-y" . helm-show-kill-ring)
         ("C-x C-f" . helm-find-files)
         ("C-s" . helm-occur)))
;;; Helm-org configuration
(use-package helm-org
  :ensure t)
;; Helm-projectile configuration
(use-package helm-projectile
  :ensure t
  :after (helm projectile))
;;; Helm-configuration
(use-package helm-rg
  :ensure t)

(provide 'init-helm)
;;; init-helm.el ends here

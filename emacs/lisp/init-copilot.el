;;; init-copilot.el --- GitHub Copilot AI 补全  -*- lexical-binding: t -*-

;;; Commentary:
;;; 使用 copilot.el 集成 GitHub Copilot。
;;; 首次使用需执行 M-x copilot-login 完成 GitHub 认证。
;;; 禁用自动启动: (setq copilot-enable-auto nil)

;;; Code:

(use-package copilot
  :ensure t
  :hook
  (prog-mode . copilot-mode)
  :bind
  (:map copilot-completion-map
        ("<tab>"       . copilot-accept-completion)
        ("TAB"         . copilot-accept-completion)
        ("C-<return>"  . copilot-accept-completion-by-word)
        ("C-<right>"   . copilot-next-completion)
        ("C-<left>"    . copilot-previous-completion))
  :config
  ;; 不自动启用，改为手动触发（避免与 TabNine 冲突）
  (setq copilot-enable-auto nil)
  ;; 启用缩进缓存（性能优化）
  (setq copilot-indent-cache t)
  ;; 日志级别（debug 调试时可设为 t）
  (setq copilot-enable-debug nil))

;; 手动切换 Copilot
(defun my/copilot-toggle ()
  "Toggle Copilot on/off."
  (interactive)
  (if (bound-and-true-p copilot-mode)
      (progn
        (copilot-mode -1)
        (message "Copilot 已关闭"))
    (copilot-mode 1)
    (message "Copilot 已开启")))

;; 快捷键: C-c C-a 切换 Copilot
(global-set-key (kbd "C-c C-a") #'my/copilot-toggle)

(provide 'init-copilot)
;;; init-copilot.el ends here
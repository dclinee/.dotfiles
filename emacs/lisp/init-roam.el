;;; init-roam.el --- Integrated for the org-roam package -*- lexical-binding: t -*-
;;; Commentary:

;;; Code:

(use-package org-roam
  :ensure t
  :init
  (setq org-roam-directory (file-truename "~/org-roam/")) ; 笔记存储目录
  :custom
  (org-roam-completion-everywhere t) ; 全局启用补全
  :bind (("C-c n l" . org-roam-buffer-toggle) ; 打开反向链接缓冲区
         ("C-c n f" . org-roam-node-find)    ; 查找笔记
         ("C-c n i" . org-roam-node-insert)  ; 插入笔记链接
         ("C-c n c" . org-roam-capture)      ; 创建新笔记
         :map org-mode-map
         ("C-c n r" . org-roam-refile)       ; 移动笔记到指定目录
         )
  :config
  (org-roam-db-autosync-mode)) ; 自动同步数据库

(provide 'init-roam)
;;; init-roam.el ends here

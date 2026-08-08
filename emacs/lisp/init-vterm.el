;;; init-xterm.el --- Integrate with terminals such as vterm -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

;; 确保依赖已安装 (需提前安装 libvterm 和 cmake)
;; Debian/Ubuntu: sudo apt install cmake libvterm-dev
;; macOS: brew install cmake libvterm

;; 使用 use-package 管理配置
(use-package vterm
  :defer t
  :ensure t
  :commands (vterm vterm-other-window vterm-install)
  :init
  ;; 基础配置
  (setq vterm-shell "/bin/zsh"            ; 默认 Shell（替换为你的路径）
        vterm-max-scrollback 10000        ; 滚动缓冲区大小
        vterm-cursor-type 'bar            ; 光标样式（bar/box/underscore）
        vterm-tramp-shells t              ; 支持 TRAMP 远程连接
        vterm-disable-bold-font nil       ; 允许粗体字体（若主题支持）
        vterm-keymap-exceptions '("C-c" "C-x" "C-u" "C-g" "C-h" "M-x" "M-o")) ; 避免快捷键冲突

  ;; 同步终端与 Emacs 的工作目录
  (add-hook 'vterm-mode-hook
            (lambda ()
              (add-hook 'vterm-cwd-changed-hook
                        (lambda (path)
                          (setq default-directory path)))))

  ;; 关闭行号和缩进提示（提升性能）
  (add-hook 'vterm-mode-hook (lambda () (display-line-numbers-mode -1)))
  (add-hook 'vterm-mode-hook (lambda () (hl-line-mode -1)))

  :config
  ;; 编译模块以确保性能（首次需手动运行一次）
  (unless (or (fboundp 'module-load)
              (get-buffer "*vterm*"))
    (vterm-install))

  ;; 自定义快捷键（与终端兼容）
  (with-eval-after-load 'vterm
    (define-key vterm-mode-map (kbd "C-c C-c") 'vterm-send-C-c) ; 发送 C-c
    (define-key vterm-mode-map (kbd "C-c C-n") 'vterm-next-prompt) ; 跳转到下一个提示符
    )
  )

;; 快速打开/切换 vterm 的快捷键
(global-set-key (kbd "C-c t") 'vterm)           ; 打开 vterm
(global-set-key (kbd "C-c T") 'vterm-other-window) ; 在其他窗口打开

(provide 'init-vterm)
;;; init-vterm.el ends here

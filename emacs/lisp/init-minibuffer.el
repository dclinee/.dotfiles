;;; init-minibuffer.el --- Config for minibuffer completion       -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:


(when (maybe-require-package 'vertico)
  (add-hook 'after-init-hook 'vertico-mode)

  (when (maybe-require-package 'embark)
    (with-eval-after-load 'vertico
      (define-key vertico-map (kbd "C-c C-o") 'embark-export)
      (define-key vertico-map (kbd "C-c C-c") 'embark-act)))

  (when (maybe-require-package 'consult)
    (defmacro sanityinc/no-consult-preview (&rest cmds)
      `(with-eval-after-load 'consult
         (consult-customize ,@cmds :preview-key (kbd "M-P"))))

    (sanityinc/no-consult-preview
     consult-ripgrep
     consult-git-grep consult-grep
     consult-bookmark consult-recent-file consult-xref
     consult-source-recent-file consult-source-project-recent-file consult-source-bookmark)

    (when (maybe-require-package 'projectile)
      (setq-default consult-project-root-function 'projectile-project-root))

    ;; consult-projectile：多源聚合（项目文件/buffer/最近文件/项目列表）
    (when (maybe-require-package 'consult-projectile)
      (with-eval-after-load 'projectile
        ;; projectile 命令（C-c p f/p/b 等）统一走 Vertico
        (setq projectile-completion-system 'default)
        ;; C-c p h：项目级聚合搜索
        (define-key projectile-command-map (kbd "h") #'consult-projectile)))

    ;; 全局补全按键
    (global-set-key (kbd "M-y")   'consult-yank-pop)   ; kill-ring 浏览
    (global-set-key (kbd "M-s l") 'consult-line)       ; 当前缓冲区内容搜索
    (global-set-key (kbd "M-s r") 'consult-ripgrep)    ; 项目内 ripgrep 全文搜索

    (when (and (executable-find "rg") (maybe-require-package 'affe))
      (defun sanityinc/affe-grep-at-point (&optional dir initial)
        (interactive (list prefix-arg (when-let ((s (symbol-at-point)))
                                        (symbol-name s))))
        (affe-grep dir initial))
      (global-set-key (kbd "M-?") 'sanityinc/affe-grep-at-point)
      (sanityinc/no-consult-preview sanityinc/affe-grep-at-point)
      (with-eval-after-load 'affe (sanityinc/no-consult-preview affe-grep)))

    (global-set-key [remap switch-to-buffer] 'consult-buffer)
    (global-set-key [remap switch-to-buffer-other-window] 'consult-buffer-other-window)
    (global-set-key [remap switch-to-buffer-other-frame] 'consult-buffer-other-frame)
    (global-set-key [remap goto-line] 'consult-goto-line)



    (when (maybe-require-package 'embark-consult)
      (with-eval-after-load 'embark
        (require 'embark-consult)
        (add-hook 'embark-collect-mode-hook 'embark-consult-preview-minor-mode)))

    (maybe-require-package 'consult-flycheck)))

(when (maybe-require-package 'marginalia)
  (add-hook 'after-init-hook 'marginalia-mode)

  ;; marginalia 202607+ 以 Emacs 31 的新签名调用
  ;;   (seconds-to-string DELAY &optional READABLE ABBREV PRECISION)
  ;; 但本地编译 marginalia.elc 时 compat-31 尚未加载，`compat-call' 被编译为
  ;; 直调 Emacs 30.2 仅接受单参数的原生 seconds-to-string，导致 consult-buffer
  ;; 注解文件相对时间时报 wrong-number-of-arguments。这里桥接到 compat-31 的
  ;; 扩展实现；Emacs 31 原生支持新签名后本 advice 自动不生效。
  (with-eval-after-load 'marginalia
    (when (and (require 'compat-31 nil t)
               (fboundp 'compat--seconds-to-string)
               (fboundp 'seconds-to-string)
               ;; 行为探针：Emacs 30 的 seconds-to-string 只接受 1 个参数；
               ;; Emacs 31 起支持 (delay &optional readable abbrev precision)，
               ;; 探针成功则无需桥接。
               (condition-case nil
                   (progn (seconds-to-string 1 'expanded 'abbrev) nil)
                 (wrong-number-of-arguments t)))
      (advice-add 'seconds-to-string :around
                  (lambda (orig seconds &optional readable abbrev precision)
                    (if (or readable abbrev precision)
                        (compat--seconds-to-string seconds readable abbrev precision)
                      (funcall orig seconds)))))))


(provide 'init-minibuffer)
;;; init-minibuffer.el ends here

;;; init-gptel.el --- ChatGPT / LLM 对话式 AI 编程  -*- lexical-binding: t -*-

;;; Commentary:
;;; 使用 gptel 在 Emacs 中与 ChatGPT 或兼容 API 对话。
;;;
;;; 快速开始:
;;;   - 设置 API Key: M-x setenv RET OPENAI_API_KEY RET sk-xxx
;;;   - 或设置: (setq gptel-api-key #'gptel-api-key-from-auth-source)
;;;   - 打开对话: M-x gptel
;;;   - 发送当前 buffer: M-x gptel-send
;;;   - 代码审查: M-x gptel-code-review
;;;
;;; 支持模型: OpenAI / Anthropic / Ollama / 国产兼容 API

;;; Code:

(use-package gptel
  :ensure t
  :commands (gptel gptel-send gptel-menu)
  :bind
  (("C-c RET" . gptel-send)         ; 发送选中区域/当前段落
   ("C-c M-'" . gptel-menu))        ; 快速菜单
  :config
  ;; ---------- 默认模型 ----------
  (setq gptel-model   "gpt-4o-mini"        ; 成本低、速度快
        gptel-max-tokens 4096)

  ;; ---------- API Key（从环境变量或 auth-source 读取）----------
  ;; 推荐方式: export OPENAI_API_KEY=sk-xxx
  (setq gptel-api-key
        (lambda ()
          (or (getenv "OPENAI_API_KEY")
              (auth-source-pick-first-password
               :host "api.openai.com"))))

  ;; ---------- 日志（可选）----------
  (setq gptel-log-level nil)

  ;; ---------- 快捷键 ----------
  ;; 在 gptel 对话中: C-c C-c 发送, C-c C-k 取消
  (with-eval-after-load 'gptel
    (define-key gptel-mode-map (kbd "C-c C-c") #'gptel-send)
    (define-key gptel-mode-map (kbd "C-c C-k") #'gptel-abort)))

;; ---------- 快捷命令 ----------
;; 代码审查
(defun my/gptel-code-review ()
  "Send current buffer to gptel for code review."
  (interactive)
  (gptel-request
   (buffer-string)
   :system "You are an expert code reviewer. Review the following code for bugs, security issues, and style problems. Respond in the same language as the code comments."
   :callback (lambda (resp _info)
               (with-current-buffer (get-buffer-create "*gptel-code-review*")
                 (erase-buffer)
                 (insert resp)
                 (goto-char (point-min))
                 (display-buffer (current-buffer))))))

;; 解释代码
(defun my/gptel-explain-code ()
  "Send selected region or current function to gptel for explanation."
  (interactive)
  (let ((code (if (region-active-p)
                  (buffer-substring-no-properties (region-beginning) (region-end))
                (buffer-substring-no-properties
                 (save-excursion (beginning-of-defun) (point))
                 (save-excursion (end-of-defun) (point))))))
    (gptel-request
     code
     :system "You are an expert programmer. Explain the following code concisely."
     :callback (lambda (resp _info)
                 (message "GPT: %s" (replace-regexp-in-string "\n" " " resp))))))

(provide 'init-gptel)
;;; init-gptel.el ends here
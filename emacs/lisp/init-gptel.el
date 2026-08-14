;;; init-gptel.el --- ChatGPT / DeepSeek / 豆包 对话式 AI 编程  -*- lexical-binding: t -*-

;;; Commentary:
;;; 使用 gptel 在 Emacs 中与 AI 模型对话。
;;; 支持: OpenAI / DeepSeek / 豆包(Doubao) / Ollama / Anthropic
;;;
;;; 快速开始:
;;;   - 设置 API Key（选一种）:
;;;     export DEEPSEEK_API_KEY=sk-xxx
;;;     export DOUBAO_API_KEY=xxx
;;;     export OPENAI_API_KEY=sk-xxx
;;;   - 切换模型: M-x gptel-menu → 选择后端
;;;   - 打开对话: M-x gptel
;;;   - 代码审查: M-x my/gptel-code-review
;;;
;;; 默认模型: DeepSeek（国产、便宜、代码能力强）

;;; Code:

(use-package gptel
  :ensure t
  :commands (gptel gptel-send gptel-menu)
  :bind
  (("C-c RET" . gptel-send)         ; 发送选中区域/当前段落
   ("C-c M-'" . gptel-menu))        ; 快速菜单
  :init
  ;; ---------- 注册 DeepSeek 后端 ----------
  ;; API: https://platform.deepseek.com/api_keys
  ;; 模型: deepseek-chat（通用）, deepseek-reasoner（推理）
  (gptel-make-openai "deepseek"
    :host "api.deepseek.com"
    :endpoint "/v1/chat/completions"
    :stream t
    :key (lambda ()
           (or (getenv "DEEPSEEK_API_KEY")
               (auth-source-pick-first-password :host "api.deepseek.com")))
    :models '(deepseek-chat deepseek-reasoner))

  ;; ---------- 注册豆包（火山引擎）后端 ----------
  ;; API: https://console.volcengine.com/ark
  ;; 模型: doubao-pro-32k（强）, doubao-lite-32k（快）
  (gptel-make-openai "doubao"
    :host "ark.cn-beijing.volces.com"
    :endpoint "/api/v3/chat/completions"
    :stream t
    :key (lambda ()
           (or (getenv "DOUBAO_API_KEY")
               (auth-source-pick-first-password :host "ark.cn-beijing.volces.com")))
    :models '(doubao-pro-32k doubao-lite-32k))

  ;; ---------- 注册 OpenAI 后端（需要时取消注释）----------
  ;; (gptel-make-openai "openai"
  ;;   :host "api.openai.com"
  ;;   :endpoint "/v1/chat/completions"
  ;;   :stream t
  ;;   :key (lambda ()
  ;;          (or (getenv "OPENAI_API_KEY")
  ;;              (auth-source-pick-first-password :host "api.openai.com")))
  ;;   :models '(gpt-4o-mini gpt-4o))

  :config
  ;; ---------- 默认后端和模型 ----------
  (setq gptel-backend (gptel-get-backend "deepseek")
        gptel-model   "deepseek-chat"
        gptel-max-tokens 4096)

  ;; ---------- 日志 ----------
  (setq gptel-log-level nil)

  ;; ---------- 快捷键 ----------
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

;; 切换模型
(defun my/gptel-switch-deepseek ()
  "Switch to DeepSeek backend."
  (interactive)
  (setq gptel-backend (gptel-get-backend "deepseek")
        gptel-model "deepseek-chat")
  (message "切换到 DeepSeek (deepseek-chat)"))

(defun my/gptel-switch-doubao ()
  "Switch to Doubao backend."
  (interactive)
  (setq gptel-backend (gptel-get-backend "doubao")
        gptel-model "doubao-pro-32k")
  (message "切换到豆包 (doubao-pro-32k)"))

(provide 'init-gptel)
;;; init-gptel.el ends here
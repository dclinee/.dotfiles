;;; init-ellama.el --- Ollama 本地 LLM 集成  -*- lexical-binding: t -*-

;;; Commentary:
;;; 使用 ellama 在 Emacs 中与本地 Ollama 模型对话。
;;; 特点: 免费、离线、隐私安全。
;;;
;;; 前置条件:
;;;   brew install ollama        # macOS
;;;   ollama pull llama3.2       # 下载模型
;;;   ollama serve               # 启动服务
;;;
;;; 快速开始:
;;;   M-x ellama-chat            # 打开对话
;;;   M-x ellama-code-review     # 代码审查
;;;   M-x ellama-code-complete   # 代码补全
;;;   M-x ellama-ask-about       # 询问选中代码

;;; Code:

(use-package ellama
  :ensure t
  :commands (ellama-chat ellama-code-review ellama-code-complete ellama-ask-about)
  :bind
  (("C-c e c" . ellama-chat)              ; 对话
   ("C-c e r" . ellama-code-review)       ; 代码审查
   ("C-c e p" . ellama-code-complete)     ; 补全
   ("C-c e a" . ellama-ask-about)         ; 询问
   ("C-c e i" . ellama-translate)         ; 翻译
   ("C-c e s" . ellama-summarize))        ; 摘要
  :config
  ;; ---------- 模型配置 ----------
  (setq ellama-language "Chinese"
        ellama-long-lines-length 80)

  ;; ---------- 默认模型 ----------
  ;; 推荐: llama3.2 (8B, 本地运行), codellama:7b (代码专用)
  (setopt ellama-provider
          (make-llm-ollama-provider
           :chat-model "llama3.2"          ; 通用对话
           :embedding-model "nomic-embed-text"
           :default-chat-non-standard-params
           '(("num_ctx" . 8192))))

  ;; ---------- 会话管理 ----------
  (setq ellama-sessions-directory
        (expand-file-name "ellama-sessions" user-emacs-directory))

  ;; ---------- 自动滚动 ----------
  (add-hook 'ellama-chat-mode-hook 'visual-line-mode))

;; ---------- 扩展: 翻译选中文本 ----------
(defun my/ellama-translate (text)
  "Translate TEXT to Chinese using Ollama."
  (interactive
   (list (if (region-active-p)
             (buffer-substring-no-properties (region-beginning) (region-end))
           (read-string "翻译: "))))
  (ellama-ask-about text "将以下内容翻译成中文，只输出翻译结果:"))

(provide 'init-ellama)
;;; init-ellama.el ends here
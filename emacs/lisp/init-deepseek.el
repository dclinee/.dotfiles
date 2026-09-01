;;; init-deepseek.el --- DeepSeek AI coding assistant  -*- lexical-binding: t -*-

;;; Commentary:

;; Integrates the DeepSeek LLM API (OpenAI-compatible) into Emacs.
;;
;; Features provided:
;;   - Inline code completion (via `completion-at-point' + corfu)
;;   - Interactive chat buffer with ellama
;;   - Code explain / refactor / fix / doc / test generation
;;   - Model switch between deepseek-chat and deepseek-reasoner
;;   - Context awareness: major-mode, eglot diagnostics, selected region
;;
;; Quick start:
;;   1. Set your API key:
;;      - Option A: export DEEPSEEK_API_KEY=sk-... in shell
;;      - Option B: M-x customize-variable RET deepseek-api-key
;;   2. Restart Emacs, or M-x load-library RET init-deepseek
;;   3. Press `C-c a c` to open a new DeepSeek chat session
;;      Press `C-c a i` to trigger inline AI completion (or just type + corfu auto)
;;
;; Default keybindings (prefix: C-c a = "AI"):
;;   C-c a c   Chat (new buffer)           C-c a C   Chat (continue last)
;;   C-c a i   Inline completion at point  C-c a I   Force AI completion popup
;;   C-c a e   Explain region              C-c a s   Summarize region
;;   C-c a r   Refactor (prompt)           C-c a R   Refactor with preset menu
;;   C-c a f   Fix diagnostics (eglot)     C-c a d   Add docstring / comments
;;   C-c a g   Generate code from desc     C-c a G   Generate & replace region
;;   C-c a t   Add tests for fn at point   C-c a o   Optimize region
;;   C-c a m   Switch model                C-c a SPC Custom prompt on region
;;   C-c a ?   Customize deepseek group

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'url)
(require 'url-http)
(require 'eglot nil t)         ; optional, for diagnostics context

;; ============================================================
;;  1. Customization group & variables
;; ============================================================

(defgroup deepseek nil
  "DeepSeek AI coding assistant integration."
  :group 'applications
  :prefix "deepseek-")

;; Normalize any pasted / env value right after getenv, BEFORE any other
;; logic runs. Keep this function standalone (no external deps) so the
;; later `defcustom deepseek-api-key' can use it at load time even in
;; bare -Q sessions.
(defun deepseek--normalize-key (k)
  "Normalize a raw API-key string K into a clean \"sk-…\" value.

Strips: leading/trailing whitespace (including CR/LF), outer
single/double quotes, and a mistaken \"Bearer \", \"bearer \",
or \"Authorization: Bearer \" prefix that users sometimes paste
alongside the key itself.

Returns nil for input that is empty after stripping, so callers
can treat nil uniformly as \"missing key\"."
  (when (stringp k)
    (let ((s k))
      (setq s (string-trim s))
      ;; one layer of matching outer quotes
      (when (and (>= (length s) 2)
                 (or (and (= (aref s 0) ?\") (= (aref s (1- (length s))) ?\"))
                     (and (= (aref s 0) ?\') (= (aref s (1- (length s))) ?\'))))
        (setq s (substring s 1 -1))
        (setq s (string-trim s)))
      ;; strip accidental "Authorization: Bearer ..." / "Bearer ..."
      (let ((case-fold-search t))
        (when (string-match-p "\\`Authorization:[[:space:]]*Bearer[[:space:]]+" s)
          (setq s (replace-match "" t t s)))
        (when (string-match-p "\\`Bearer[[:space:]]+" s)
          (setq s (replace-match "" t t s))))
      ;; any internal whitespace leftover from multiline pastes → collapse
      (while (string-match "[[:space:]]+" s)
        (setq s (replace-match "" t t s)))
      (and (> (length s) 0) s))))

(defcustom deepseek-api-key (let ((v (or (getenv "DEEPSEEK_API_KEY")
                                         (getenv "DS_API_KEY"))))
                              (and v (deepseek--normalize-key v)))
  "DeepSeek API key.
Prefer setting the DEEPSEEK_API_KEY environment variable, or
customize this variable via M-x customize-variable.
Never commit this value to a public repository."
  :type '(choice (const :tag "From env DEEPSEEK_API_KEY" nil)
                 (string :tag "API key string"))
  :group 'deepseek)

(defun deepseek--api-key-or-error ()
  "Return a cleaned, non-empty DeepSeek API key string, or signal a helpful user-error.

Checks in order:
  1. The `deepseek-api-key' defcustom (honours user customizations).
     Uses `deepseek--normalize-key' so saved customizations that
     accidentally contain a surrounding quotes or leading
     \"Bearer \" still work.
  2. Environment variables DEEPSEEK_API_KEY then DS_API_KEY,
     also normalized.

Raises a single unified `user-error' that tells the user exactly
what to do — never returns nil, \"\", or a value that would make
`Authorization: Bearer <empty>' hit the wire (which previously
showed as DeepSeek returning
  \"Authentication Fails (auth header format should be Bearer sk-...)\")
because the server was actually seeing `Bearer ' with no key."
  (let* ((raw-v (or deepseek-api-key
                    (getenv "DEEPSEEK_API_KEY")
                    (getenv "DS_API_KEY")))
         (v (deepseek--normalize-key raw-v)))
    (or v
        (let ((got (if raw-v (format " (got %S after strip: %S)"
                                     raw-v
                                     (substring raw-v 0 (min 24 (length raw-v))))
                     "")))
          (user-error
           (concat "DeepSeek API key not set or empty." got "

  • Option 1 (recommended, survives restarts):
      Add this line to ~/.zshenv (or ~/.zsh/.zshenv) exactly:
          export DEEPSEEK_API_KEY=\"sk-xxxxxxxxxxxxxxxxxxxxxxx\"
      then in Terminal run:
          source ~/.zshenv && launchctl setenv DEEPSEEK_API_KEY \"$DEEPSEEK_API_KEY\"
      and either restart Emacs, or for THIS running session evaluate:
          M-: (setenv \"DEEPSEEK_API_KEY\" (read-string \"Key: \") t)
          M-: (customize-set-variable 'deepseek-api-key (getenv \"DEEPSEEK_API_KEY\"))

  • Option 2 (Emacs-only): M-x customize-variable RET deepseek-api-key,
    paste the clean "sk-..." string, save and apply."))))))

(defcustom deepseek-base-url "https://api.deepseek.com/v1"
  "DeepSeek API base URL (OpenAI-compatible).
Users with self-hosted / proxied endpoints can override here."
  :type 'string
  :group 'deepseek)

(defcustom deepseek-chat-model "deepseek-chat"
  "Model identifier used for chat, refactor, explain, doc, tests.
Valid options from DeepSeek:
  - `deepseek-chat'    (V3 general-purpose, fast)
  - `deepseek-reasoner' (R1 reasoning, slower for complex debugging)
  - Older names (still work): `deepseek-coder'."
  :type '(choice (const "deepseek-chat")
                 (const "deepseek-reasoner")
                 (const "deepseek-coder")
                 string)
  :group 'deepseek)

(defcustom deepseek-completion-model "deepseek-chat"
  "Model identifier used for inline code completion.
Using the same chat model with a short max-tokens gives good
FIM (fill-in-the-middle) style completions."
  :type '(choice (const "deepseek-chat")
                 (const "deepseek-coder")
                 string)
  :group 'deepseek)

(defcustom deepseek-temperature 0.2
  "Default temperature (sampling randomness).
Lower values (0.0 - 0.3) are better for deterministic code work;
higher values (0.7+) are better for creative chat."
  :type 'float
  :group 'deepseek)

(defcustom deepseek-max-tokens 4096
  "Maximum output tokens for chat / refactor / explain calls.
Inline completion uses a fraction (see `deepseek-completion-max-tokens')."
  :type 'integer
  :group 'deepseek)

(defcustom deepseek-completion-max-tokens 128
  "Maximum output tokens for inline code completion."
  :type 'integer
  :group 'deepseek)

(defcustom deepseek-completion-prefix-length 1500
  "Characters of prefix context sent for inline completion."
  :type 'integer
  :group 'deepseek)

(defcustom deepseek-completion-suffix-length 500
  "Characters of suffix context sent for inline completion."
  :type 'integer
  :group 'deepseek)

(defcustom deepseek-request-timeout 60
  "Per-request timeout in seconds for HTTP calls."
  :type 'integer
  :group 'deepseek)

(defcustom deepseek-keymap-prefix (kbd "C-c a")
  "Top-level key prefix for DeepSeek commands.
Re-evaluate `deepseek-setup-keys' after changing this value."
  :type 'key-sequence
  :group 'deepseek)

(defcustom deepseek-auto-complete-capf t
  "When non-nil, add the DeepSeek capf to `completion-at-point-functions'.
This lets corfu (or company) show AI suggestions automatically
when typing in `prog-mode' buffers."
  :type 'boolean
  :group 'deepseek)

(defcustom deepseek-include-diagnostics t
  "When non-nil and eglot/flymake reports diagnostics, include them
in the system prompt for `deepseek-fix' and `deepseek-explain'."
  :type 'boolean
  :group 'deepseek)

(defcustom deepseek-debug nil
  "When non-nil, log request/response details to *deepseek-debug* buffer."
  :type 'boolean
  :group 'deepseek)

;; ============================================================
;;  2. Low-level HTTP client to DeepSeek (JSON POST, OpenAI-style)
;; ============================================================

(defvar deepseek--last-error nil
  "Most recent error message from the API, for debugging.")

;; NOTE: deepseek--api-key-or-error is now defined EARLIER in the file
;; (right after `defcustom deepseek-api-key') so that normalize-key +
;; robust empty-key validation runs as early as possible during load.
;; The duplicate definition that used to live here has been removed to
;; avoid shadowing / unbalanced parens.

(defun deepseek--chat-url ()
  "Full URL to the /chat/completions endpoint."
  (concat (string-trim-right deepseek-base-url "/")
          "/chat/completions"))

(defun deepseek--make-messages (system-prompt user-prompt &optional history)
  "Build the `messages' JSON array for DeepSeek chat completions.

Each element must be an alist ((role . ROLE) (content . TEXT))
because `json-encode' turns alists into JSON objects. HISTORY is
the canonical in-memory chat session store: a list of
 (ROLE-STRING . CONTENT-STRING) cons cells, newest on top (which is
how deepseek-chat-send pushes them via `push').

Final message order produced:
  1. system message (when provided, ALWAYS FIRST in the array)
  2. historical rounds from OLDEST to NEWEST
  3. current user turn (always last)"
  (let* (;; Convert each (role-string . content-string) cons cell to a proper
         ;; 2-element alist so `json-encode' treats it as a JSON object and
         ;; never complains about `listp' on a raw string.
         (history-alist
          (mapcar (lambda (h)
                    (list (cons 'role    (car h))
                          (cons 'content (cdr h))))
                  ;; newest-on-top → oldest-on-top for the wire.
                  (reverse history)))
         (msgs history-alist))
    (when system-prompt
      (setq msgs (cons (list (cons 'role "system") (cons 'content system-prompt))
                       msgs)))
    (append msgs (list (list (cons 'role "user") (cons 'content user-prompt))))))

(defun deepseek--request-body (messages &optional model stream temperature max-tokens extra-params)
  "Build the JSON request alist for the chat endpoint."
  (append
   `((model . ,(or model deepseek-chat-model))
     (messages . ,messages)
     (temperature . ,(or temperature deepseek-temperature)))
   (when max-tokens `((max_tokens . ,max-tokens)))
   (when stream      `((stream . t)))
   extra-params))

(defun deepseek--request-headers ()
  "Build required HTTP headers for the API call.

`Authorization' is assembled from a single canonical source:
`deepseek--api-key-or-error', which has already been normalized,
trimmed, and validated non-empty. Callers will see a user-error
with remediation steps BEFORE this function ever constructs a
`Bearer ' header with an empty key (which previously confused
users because DeepSeek's server error said
  \"auth header format should be Bearer sk-...\"
when the real problem was no key at all)."
  (let ((key (deepseek--api-key-or-error)))
    `(("Content-Type"  . "application/json")
      ;; Defensive: never produce "Bearer " + "" — even if a future
      ;; refactor broke `deepseek--api-key-or-error' validation, we
      ;; would rather fail loudly here than send a malformed header.
      ("Authorization" . ,(progn
                            (cl-assert (> (length key) 12) t
                              "DeepSeek key suspiciously short after normalize")
                            (concat "Bearer " key))))))

(defun deepseek--http-post (url payload callback &optional error-callback)
  "Send a POST to URL with JSON PAYLOAD (alist).
On success CALLBACK receives the parsed JSON object.
On failure ERROR-CALLBACK receives (status err-message).
Both callbacks run in a temporary url-retrieve buffer context.

Debugging: if `deepseek-debug' is non-nil we log (1) the URL + a
SHALLOW summary of the payload (not the full JSON) to the
*deepseek-debug* buffer. The FULL request body is NEVER echoed to
`message' / the minibuffer because the JSON can be tens of KB of
user source code and the previous behaviour of dumping the raw
body made the echo area unusable when completion fired. If you
need to inspect the actual wire body, toggle
`deepseek-debug' + look in *deepseek-debug*."
  (let* ((url-request-method "POST")
         (url-request-extra-headers (deepseek--request-headers))
         (_payload-body (json-encode payload))
         (url-request-data _payload-body)
         (url-show-status nil)
         (timeout deepseek-request-timeout)
         (timer (run-with-timer timeout nil #'deepseek--http-post--abort (current-buffer))))
    ;; Guard: never accidentally message/print the raw body (it's user
    ;; source code and it pollutes the echo area — this is what users saw
    ;; in the scratch screenshot of 2026-08-19 when deepseek-debug and/or
    ;; a url library debug flag were on). We explicitly bind
    ;; `url-show-status' and `url-debug' to nil around the retrieve call
    ;; to be defensive against customizations.
    (let ((url-show-status nil)
          (url-debug nil)
          (message-log-max (when (and (boundp 'message-log-max) deepseek-debug)
                             message-log-max)))
      (deepseek--http-post--log-request url payload)
      (url-retrieve url (deepseek--http-post--make-handler
                          timer callback error-callback))))
  nil)

(defun deepseek--http-post--abort (buf)
  "Cleanup watchdog for a hanging url-retrieve buffer BUF."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (when (fboundp 'url-http-close)
        (url-http-close))
      (kill-buffer))))

;; ------------------------------------------------------------
;;  Streaming (SSE) HTTP POST — token-by-token output
;; ------------------------------------------------------------

(defvar deepseek--stream-process nil
  "Current streaming process, used for abort.")

(defun deepseek--http-post-stream (url payload on-chunk on-done on-error)
  "Send a POST to URL with JSON PAYLAY, streaming response via SSE.

ON-CHUNK is called with each text delta string as it arrives.
ON-DONE is called with the full accumulated text when the stream ends.
ON-ERROR is called with an error message string if something fails.

Uses `url-retrieve' with a process filter that parses SSE
`data:' lines incrementally, so the user sees token-by-token
output in real time instead of waiting for the entire response."
  (let* ((url-request-method "POST")
         (url-request-extra-headers (deepseek--request-headers))
         (url-request-data (json-encode payload))
         (url-show-status nil)
         (url-debug nil)
         (accumulated "")
         (on-chunk-fn on-chunk)
         (on-done-fn on-done)
         (on-error-fn on-error)
         (timer (run-with-timer deepseek-request-timeout nil
                                (lambda ()
                                  (when (and deepseek--stream-process
                                             (process-live-p deepseek--stream-process))
                                    (delete-process deepseek--stream-process)
                                    (funcall on-error-fn "Request timed out"))))))
    (condition-case err
        (let ((proc (url-retrieve url
                                   (lambda (_status)
                                     (when (timerp timer) (cancel-timer timer))
                                     (let ((raw (buffer-substring-no-properties
                                                 (point) (point-max))))
                                       (if (string-match-p "^HTTP/1\.[01] 200" raw)
                                           (funcall on-done-fn accumulated)
                                         (funcall on-error-fn
                                                  (or (and (string-match "HTTP/1\.[01] \\([0-9]+\\) \\(.*\\)" raw)
                                                           (format "HTTP %s: %s"
                                                                   (match-string 1 raw)
                                                                   (match-string 2 raw)))
                                                      "Unknown HTTP error")))))
                                   nil t t)))
          (setq deepseek--stream-process proc)
          (set-process-filter
           proc
           (lambda (_proc data)
             ;; Parse SSE data: lines from the chunk
             (with-temp-buffer
               (insert data)
               (goto-char (point-min))
               (while (re-search-forward "^data: \\(.+\\)$" nil t)
                 (let ((line (match-string 1)))
                   (if (string= line "[DONE]")
                       (progn
                         (when (timerp timer) (cancel-timer))
                         (funcall on-done-fn accumulated))
                     (condition-case nil
                         (let* ((json-object-type 'alist)
                                (json-array-type 'list)
                                (json-key-type 'symbol)
                                (obj (json-read-from-string line))
                                (delta (cdr (assq 'content
                                                  (cdr (assq 'delta
                                                             (car (cdr (assq 'choices obj))))))))
                           (when (and delta (not (string= delta "")))
                             (setq accumulated (concat accumulated delta))
                             (funcall on-chunk-fn delta)))
                       (error nil))))))
             ;; Accept output to keep process alive
             (accept-process-output nil 0.01)))
          proc)
      (error
       (when (timerp timer) (cancel-timer))
       (funcall on-error-fn (format "Stream error: %S" err)))))))

(defun deepseek--http-post--log-request (url payload)
  "When `deepseek-debug' is on, append request info to *deepseek-debug*."
  (when deepseek-debug
    (with-current-buffer (get-buffer-create "*deepseek-debug*")
      (goto-char (point-max))
      (insert "\n---- REQUEST " (format-time-string "%F %T") " ----\n")
      (pp payload (current-buffer))
      (insert "URL: " url "\n"))))

(defun deepseek--http-post--make-handler (timer callback error-callback)
  "Build the url-retrieve callback lambda closing over TIMER, CALLBACK, ERROR-CALLBACK."
  (lambda (status)
    (when (timerp timer) (cancel-timer timer))
    (unwind-protect
        (condition-case err
            (progn
              (goto-char (point-min))
              (when (re-search-forward "^$" nil 'move) (forward-char 1))
              (let* ((raw (buffer-substring-no-properties (point) (point-max)))
                     (json-object-type 'alist)
                     (json-array-type  'list)
                     (json-key-type    'symbol)
                     (resp (condition-case je
                               (json-read-from-string raw)
                             (json-readtable-error
                              (list 'PARSE_ERROR
                                    (format "bad json: %S" je)
                                    'RAW (truncate-string-to-width raw 300))))))
                (deepseek--http-post--log-response raw)
                (cond
                 ((memq (car-safe resp) '(PARSE_ERROR error))
                  (let ((msg (or (cdr (assq 'message (cdr (assq 'error resp))))
                                 (format "Bad response: %S" resp))))
                    (setq deepseek--last-error msg)
                    (if error-callback
                        (funcall error-callback status msg)
                      (message "[DeepSeek] error: %s" msg))))
                 (t
                  (funcall callback resp)))))
          (error
           (when error-callback
             (funcall error-callback status (format "err: %S" err)))))
      (kill-buffer (current-buffer)))))

(defun deepseek--http-post--log-response (raw)
  "When `deepseek-debug' is on, append RAW response text to debug buffer."
  (when deepseek-debug
    (with-current-buffer (get-buffer-create "*deepseek-debug*")
      (goto-char (point-max))
      (insert "\n---- RESPONSE ----\n")
      (insert (truncate-string-to-width raw 3000 nil nil t) "\n"))))

(defun deepseek--first-choice-content (resp)
  "Extract the assistant message text from a chat/completions RESP object."
  (let* ((choices (cdr (assq 'choices resp)))
         (first (if (listp choices) (car choices) nil))
         (msg (cdr (assq 'message first))))
    (cdr (assq 'content msg))))

;; ============================================================
;;  3. Helpers: context builders (mode, region, diagnostics)
;; ============================================================

(defun deepseek--language-name ()
  "Best-effort natural language name for the current `major-mode'."
  (let ((m (symbol-name major-mode)))
    (cond
     ((string-match-p "\\`rust-ts-mode\\|rust-mode" m)  "Rust")
     ((string-match-p "\\`go-ts-mode\\|go-mode"     m)  "Go")
     ((string-match-p "\\`python-ts-mode\\|python-mode" m) "Python")
     ((string-match-p "\\`typescript-ts-mode\\|typescript-mode\\|tsx-ts-mode" m) "TypeScript")
     ((string-match-p "\\`js-ts-mode\\|javascript\\|js2-mode" m) "JavaScript")
     ((string-match-p "\\`c-ts-mode\\|c-mode"       m)  "C")
     ((string-match-p "\\`c\\+\\+-ts-mode\\|c\\+\\+-mode" m) "C++")
     ((string-match-p "\\`java-ts-mode\\|java-mode" m)  "Java")
     ((string-match-p "\\`csharp-ts-mode\\|csharp-mode" m) "C#")
     ((string-match-p "\\`ruby-ts-mode\\|ruby-mode" m)  "Ruby")
     ((string-match-p "\\`php-mode"                  m)  "PHP")
     ((string-match-p "\\`clojure"                   m)  "Clojure")
     ((string-match-p "\\`emacs-lisp\\|elisp"        m)  "Emacs Lisp")
     ((string-match-p "\\`haskell\\|haskell-ts-mode" m) "Haskell")
     ((string-match-p "\\`lua"                       m)  "Lua")
     ((string-match-p "\\`sh-mode\\|bash-ts-mode\\|shell-script" m) "Shell / Bash")
     ((string-match-p "\\`yaml"                      m)  "YAML")
     ((string-match-p "\\`toml"                      m)  "TOML")
     ((string-match-p "\\`json"                      m)  "JSON")
     ((string-match-p "\\`sql"                       m)  "SQL")
     ((string-match-p "\\`html"                      m)  "HTML")
     ((string-match-p "\\`css"                       m)  "CSS")
     ((string-match-p "\\`dockerfile"                m)  "Dockerfile")
     ((string-match-p "\\`terraform\\|hcl"           m)  "Terraform / HCL")
     (t (replace-regexp-in-string
         "\\(?:-ts\\)?-mode\\'" "" m)))))

(defun deepseek--eglot-diagnostics ()
  "Return a short list of diagnostic messages (eglot or flymake) at point.
Result is nil if none available, or a string summary."
  (unless deepseek-include-diagnostics
    (cl-return-from deepseek--eglot-diagnostics nil))
  (let ((items
         (cond
          ((fboundp 'eglot-diagnostics)
           (ignore-errors
             (cl-loop for d in (eglot-diagnostics (current-buffer))
                      collect
                      (let ((msg (or (plist-get d :message)
                                     (cdr (assq :message d))
                                     ""))
                            (ln  (or (and (fboundp 'eglot-diagnostic-line)
                                          (eglot-diagnostic-line d))
                                     (line-number-at-pos))))
                        (format "L%d: %s" ln msg)))))
          ((fboundp 'flymake-diagnostics)
           (ignore-errors
             (cl-loop for d in (flymake-diagnostics (current-buffer))
                      for msg = (flymake-diagnostic-text d)
                      for beg = (flymake-diagnostic-beg d)
                      for ln  = (when beg (line-number-at-pos beg))
                      collect (format "L%s: %s" (or ln "?") msg))))
          (t nil))))
    (when items
      (mapconcat 'identity (cl-subseq items 0 20) "\n"))))

(defun deepseek--buffer-or-region-text ()
  "Return (cons text-before point-before text-after point-after).
If region is active, uses region as the body and its surrounding
prefix/suffix as context."
  (let* ((beg (if (use-region-p) (region-beginning) (point-min)))
         (end (if (use-region-p) (region-end)     (point-max)))
         (body (buffer-substring-no-properties beg end))
         (pre  (buffer-substring-no-properties (point-min) beg))
         (post (buffer-substring-no-properties end (point-max))))
    (list :body body :beg beg :end end :pre pre :post post)))

(defun deepseek--system-prompt-for-code (role)
  "Build a concise system prompt for ROLE (explain/refactor/fix/complete/doc/test/generate).
Includes the current `deepseek--language-name' to guide the model."
  (let ((lang (deepseek--language-name)))
    (cl-case role
      (complete
       (format "You are an expert %s code completion engine.
You must output ONLY the raw completion text — no markdown fences,
no explanations, no leading prose, no trailing commentary.
Do NOT repeat the prefix (context already provided). Prefer
idiomatic, concise, correct %s code." lang lang))
      (explain
       (format "You are a senior %s engineer. Explain the code briefly,
then point out likely issues (if any), then offer 1-2 better
alternatives with reasoning. Keep it under 40 lines. Use
markdown for code snippets." lang))
      (refactor
       (format "You are a senior %s engineer. Refactor the code per the
user's instruction. Output ONLY the resulting code as it should be
inserted into the buffer (no fences, no explanation) unless the
user explicitly asks for commentary. Preserve style and semantics,
fix subtle bugs if obvious." lang))
      (fix
       (format "You are a senior %s engineer debugging user code.
Diagnostics (if any) will be provided. Produce ONLY the corrected
code without fences; if only localized changes are required, emit
the full region with fixes applied. After the code, add a single
line `// fixed: <brief>' style summary (adapt syntax to %s)."
               lang lang))
      (doc
       (format "You are a senior %s engineer. Add docstrings and inline
comments following this language's idiomatic style. Output ONLY
the full code with docstrings added — do not drop any logic.
No fences." lang lang))
      (test
       (format "You are a senior %s engineer. Write unit tests targeting
the function(s) at point. Use the language's most popular testing
framework (e.g. pytest, go test, cargo test, jest, ...).
Output ONLY test code (or a full test file as appropriate), no fences.
Test edge cases, happy path, and error paths." lang))
      (generate
       (format "You are a senior %s engineer. Implement code from the
user's natural language description. Output ONLY the resulting
code, no prose, no fences. Keep style idiomatic." lang))
      (summarize
       (format "Summarize the following %s code / diff in under 15 lines.
List 1) purpose, 2) key components, 3) behavior, 4) caveats.
Use bullet points." lang))
      (optimize
       (format "Optimize the following %s code for performance AND clarity.
Preserve semantics. Output ONLY the optimized code, no fences.
After the code, add one short comment line explaining the change."
               lang lang))
      (chat
       (format "You are DeepSeek-Coder, a helpful AI assistant specialized
in %s and general software engineering. Respond truthfully and
concisely. When showing code, use fenced markdown blocks. Do NOT
make up APIs: if you are unsure, say so." lang))
      (t
       (format "You are a helpful %s coding assistant. Follow the user's
instruction carefully." lang)))))

;; ============================================================
;;  4. Inline completion: custom `completion-at-point' backend
;; ============================================================

(defvar-local deepseek--completion-cache nil
  "Cached (prefix-anchor . candidate) pair to avoid double HTTP.")

(defun deepseek--complete-sync (prefix suffix &optional partial)
  "Call the API for inline completion synchronously (used by capf).
Returns a list of candidate strings (length 1 for now).
PREFIX and SUFFIX are the surrounding context strings.
PARTIAL is the token substring right before point."
  (let* ((trim-prefix (if (> (length prefix) deepseek-completion-prefix-length)
                          (substring prefix (- deepseek-completion-prefix-length))
                        prefix))
         (trim-suffix (if (> (length suffix) deepseek-completion-suffix-length)
                          (substring suffix 0 deepseek-completion-suffix-length)
                        suffix))
         (user-prompt
          (format
           (concat
            "You are a %s code completion engine. Continue the code at <CARET>.\n"
            "Output ONLY the plain completion text starting right at the caret\n"
            "(do not repeat the prefix). No fences, no explanation.\n\n"
            "FILE CONTEXT:\n```%s\n%s<CARET>%s\n```\n\n"
            "Token immediately before <CARET> = \"%s\"\n"
            "Completion to emit:")
           (deepseek--language-name)
           (downcase (deepseek--language-name))
           trim-prefix trim-suffix
           (or partial ""))))
    (let ((resp nil)
          (done nil)
          (msgs (deepseek--make-messages
                 (deepseek--system-prompt-for-code 'complete)
                 user-prompt)))
      (deepseek--http-post
       (deepseek--chat-url)
       (deepseek--request-body msgs deepseek-completion-model nil
                               0.0 deepseek-completion-max-tokens nil)
       (lambda (r) (setq resp r done t))
       (lambda (_st msg) (setq done t deepseek--last-error msg)))
      ;; busy-wait (max timeout; background timer will kill url buffer)
      (with-timeout (deepseek-request-timeout
                     (message "[DeepSeek] completion timed out") nil)
        (while (not done)
          (accept-process-output nil 0.05)))
      (when resp
        (let ((text (deepseek--first-choice-content resp)))
          (when (and text (not (string= text "")))
            (list (string-trim-right text))))))))

;;;###autoload
(defun deepseek-completion-at-point ()
  "`completion-at-point-function' backend for DeepSeek inline completion.
Returns the (start end collection . props) form required by capf.
Only triggers in prog-mode derived buffers; can be called explicitly
with `M-x deepseek-complete' or `C-c a I'."
  (when (and deepseek-api-key
             (apply #'derived-mode-p '(prog-mode text-mode)))
    (when-let* ((bounds (bounds-of-thing-at-point 'symbol))
                (start  (or (car bounds) (point)))
                (end    (or (cdr bounds) (point)))
                (partial (buffer-substring-no-properties start end))
                (prefix  (buffer-substring-no-properties (point-min) end))
                (suffix  (buffer-substring-no-properties (point) (point-max))))
      ;; avoid recursion when we're called from inside corfu
      (when (not (memq this-command '(deepseek-complete deepseek-complete-popup)))
        (let ((cands (deepseek--complete-sync prefix suffix partial)))
          (when cands
            (append (list start end cands)
                    (list :annotation-function
                          (lambda (_s) " [DeepSeek]")
                          :exit-function
                          (lambda (_s status)
                            (when (memq status '(finished exact))
                              (message "[DeepSeek] completion inserted")))))))))))

;;;###autoload
(defun deepseek-complete ()
  "Trigger DeepSeek inline completion at point.
This inserts the top candidate directly without the corfu menu."
  (interactive)
  (let* ((cand-list (deepseek--complete-sync
                     (buffer-substring-no-properties (point-min) (point))
                     (buffer-substring-no-properties (point) (point-max))
                     (or (thing-at-point 'symbol t) "")))
         (best (car-safe cand-list)))
    (if (not best) (message "[DeepSeek] no suggestion")
      (insert best)
      (message "[DeepSeek] inserted %d chars" (length best)))))

;;;###autoload
(defun deepseek-complete-popup ()
  "Force corfu (or company) to show the DeepSeek completion candidate list."
  (interactive)
  (let ((completion-at-point-functions (list #'deepseek-completion-at-point)))
    (cond
     ((fboundp 'corfu-complete) (corfu-complete))
     ((fboundp 'company-complete) (company-complete))
     (t (completion-at-point)))))

;; ============================================================
;;  5. Chat / Explain / Refactor / Fix / Doc / Test / Generate
;; ============================================================

(defun deepseek--call-async (role user-prompt callback
                                  &optional model system-extra history)
  "Async helper that builds messages and fires the HTTP POST.

Synchronously validates the API key *before* doing any I/O, so the
caller (chat-send, refactor, generate, …) always gets a visible
`user-error' if `deepseek-api-key' is nil, instead of a silent
\"thinking…\" message followed by an overwritten/lost async error.

ROLE selects the system prompt template; USER-PROMPT is the user
string; CALLBACK receives the finished assistant text string.
MODEL overrides `deepseek-chat-model' temporarily.
SYSTEM-EXTRA is appended to the base system prompt.
HISTORY is (role . content) list for a continuing session."
  ;; Eager, synchronous validation. This intentionally raises BEFORE any
  ;; (message "[DeepSeek] thinking...") from the caller, otherwise that
  ;; transient message can mask the real problem when the key is missing.
  (deepseek--api-key-or-error)
  (let* ((sys (concat (deepseek--system-prompt-for-code role)
                      (when system-extra (concat "\n\n" system-extra))))
         (msgs (deepseek--make-messages sys user-prompt history)))
    (deepseek--http-post
     (deepseek--chat-url)
     (deepseek--request-body msgs model nil
                             deepseek-temperature deepseek-max-tokens nil)
     (lambda (resp)
       (let ((txt (deepseek--first-choice-content resp)))
         (if txt (funcall callback txt)
           (funcall callback "[DeepSeek returned empty content]"))))
     (lambda (_st msg)
       (message "[DeepSeek] HTTP error: %s" msg)
       (funcall callback (format "[DeepSeek error] %s" msg))))))

;; ============================================================
;;  5a. Chat: multi-session, streaming, separated input
;; ============================================================

(defcustom deepseek-chat-max-context-tokens 16384
  "Max approximate tokens in chat history before trimming oldest messages.
DeepSeek's context window is 64K-128K; 16K leaves headroom for the
system prompt and the current user turn."
  :type 'integer
  :group 'deepseek)

(defcustom deepseek-chat-stream t
  "When non-nil, use streaming (SSE) for chat responses.
Tokens appear incrementally instead of all-at-once."
  :type 'boolean
  :group 'deepseek)

;; ---- Session tracking ----

(defvar deepseek--chat-sessions nil
  "Alist of (session-name . buffer) for all active DeepSeek chat sessions.")

(defvar-local deepseek--chat-history nil
  "Buffer-local history list of (role . content) cons cells for the current session.")

(defvar-local deepseek--chat-input-start nil
  "Buffer-local marker pointing to the start of the user input area.")

(defvar-local deepseek--chat-output-marker nil
  "Buffer-local marker for the start of the assistant streaming output area.")

(defvar-local deepseek--chat-session-name nil
  "Buffer-local name of this chat session.")

(defvar-local deepseek--chat-streaming nil
  "Non-nil when a streaming response is in progress in this buffer.")

;; ---- Keymap ----

(defvar deepseek-chat-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "RET")        'deepseek-chat-send)
    (define-key m (kbd "<return>")   'deepseek-chat-send)
    (define-key m (kbd "M-RET")      'newline)        ; Alt+Enter = newline
    (define-key m (kbd "C-<return>") 'newline)        ; Ctrl+Enter = newline
    (define-key m (kbd "C-c C-c")    'deepseek-chat-send)
    (define-key m (kbd "C-c C-k")    'deepseek-chat-reset)
    (define-key m (kbd "C-c C-q")    'deepseek-chat-abort)
    (define-key m (kbd "C-c C-n")    'deepseek-chat-new)
    (define-key m (kbd "C-c C-s")    'deepseek-chat-switch-session)
    (define-key m (kbd "C-c C-m")    'deepseek-switch-model)
    (define-key m (kbd "C-c C-p")    'deepseek-chat-persist)
    m)
  "Keymap for DeepSeek chat buffers.")

(define-derived-mode deepseek-chat-mode text-mode "DeepSeek Chat"
  "Major mode for interactive streaming chat with the DeepSeek assistant.

\\{deepseek-chat-mode-map}

Buffer layout:
  ── USER ──
  your text here
  ── ASSISTANT ──
  streaming reply...
  ▎  <- input area starts here (type and press RET)

Features:
- Streaming output: tokens appear incrementally (toggle `deepseek-chat-stream')
- Multi-session: each buffer is a separate conversation
- Separated input: type at the bottom, history stays above
- Abort: C-c C-q cancels the current request
- History trimming: old messages auto-pruned to stay under token limit"
  (setq-local deepseek--chat-history nil)
  (setq-local deepseek--chat-input-start (make-marker))
  (setq-local deepseek--chat-output-marker (make-marker))
  (setq-local deepseek--chat-session-name nil)
  (setq-local deepseek--chat-streaming nil)
  (use-local-map deepseek-chat-mode-map)
  (visual-line-mode 1)
  (setq word-wrap t))

;; ---- Helpers ----

(defun deepseek--chat-estimate-tokens (text)
  "Rough token estimate: ~1 token per 4 characters."
  (/ (length text) 4))

(defun deepseek--chat-trim-history ()
  "Trim oldest history entries to stay within token budget."
  (when deepseek--chat-history
    (let ((total (apply #'+ (mapcar (lambda (h) (deepseek--chat-estimate-tokens (cdr h)))
                                     deepseek--chat-history))))
      (while (and (> total deepseek-chat-max-context-tokens)
                  (> (length deepseek--chat-history) 2))
        (let ((old (pop deepseek--chat-history)))
          (setq total (- total (deepseek--chat-estimate-tokens (cdr old)))))
      ;; Keep history in chronological order (newest is at front due to push)
      (setq deepseek--chat-history (nreverse deepseek--chat-history))))))

(defun deepseek--chat-insert-role (role text)
  "Insert ROLE header and TEXT into the chat buffer at point."
  (let ((inhibit-read-only t))
    (insert (propertize (format "── %s ──\n" (upcase role))
                        'face 'font-lock-keyword-face))
    (insert text "\n")))

(defun deepseek--chat-setup-input-area ()
  "Draw the input prompt separator at the bottom of the chat buffer."
  (let ((inhibit-read-only t)
        (buf (current-buffer)))
    (goto-char (point-max))
    (unless (bolp) (insert "\n"))
    (insert (propertize "\n────────────────────\n"
                        'face 'shadow))
    (insert (propertize "▎" 'face 'cursor))
    (set-marker deepseek--chat-input-start (1- (point)))
    (goto-char (point-max))))

(defun deepseek--chat-read-input ()
  "Read and delete the user input from the input area.
Returns the trimmed text string."
  (save-excursion
    (goto-char (marker-position deepseek--chat-input-start))
    (forward-char 1) ; skip the cursor char
    (let* ((start (point))
           (end (point-max))
           (text (string-trim (buffer-substring-no-properties start end))))
      (delete-region start end)
      text)))

;; ---- Session management ----

(defun deepseek--chat-generate-name ()
  "Generate a unique session name like 'session-1', 'session-2', etc."
  (let ((n 1))
    (while (assoc (format "session-%d" n) deepseek--chat-sessions)
      (setq n (1+ n)))
    (format "session-%d" n)))

;;;###autoload
(defun deepseek-chat-new (name)
  "Create a new DeepSeek chat session named NAME (interactively prompts).
Each session is a separate buffer with its own history."
  (interactive
   (list (read-string "Session name: "
                       (deepseek--chat-generate-name))))
  (let* ((buf-name (format "*DeepSeek Chat: %s*" name))
         (buf (get-buffer-create buf-name)))
    (with-current-buffer buf
      (unless (eq major-mode 'deepseek-chat-mode)
        (deepseek-chat-mode))
      (setq-local deepseek--chat-session-name name)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize (format "# DeepSeek Chat — %s\n" name)
                            'face 'outline-1))
        (insert (propertize "RET send · M-RET newline · C-c C-k clear · C-c C-q abort · C-c C-n new · C-c C-s switch\n"
                            'face 'shadow))
        (insert (propertize "────────────────────\n"
                            'face 'shadow))))
    ;; Register session
    (setq deepseek--chat-sessions
          (cons (cons name buf)
                (assq-delete-all name deepseek--chat-sessions)))
    (deepseek--chat-setup-input-area)
    (pop-to-buffer buf)))

;;;###autoload
(defun deepseek-chat-switch-session ()
  "Switch to another active DeepSeek chat session via completing-read."
  (interactive)
  (if (null deepseek--chat-sessions)
      (user-error "No active sessions. Use M-x deepseek-chat-new to create one.")
    (let* ((names (mapcar #'car deepseek--chat-sessions))
           (choice (completing-read "Switch to session: " names nil t)))
      (when choice
        (let ((buf (cdr (assoc choice deepseek--chat-sessions))))
          (when buf
            (pop-to-buffer buf)))))))

(defun deepseek-chat--current-buffer-name ()
  "Return the session name of the current chat buffer, or nil."
  (and (eq major-mode 'deepseek-chat-mode)
       deepseek--chat-session-name))

;; ---- Abort ----

;;;###autoload
(defun deepseek-chat-abort ()
  "Abort the current streaming request in the chat buffer."
  (interactive)
  (if (and deepseek--stream-process
           (process-live-p deepseek--stream-process))
      (progn
        (delete-process deepseek--stream-process)
        (setq deepseek--stream-process nil)
        (setq deepseek--chat-streaming nil)
        (let ((inhibit-read-only t))
          (goto-char (marker-position deepseek--chat-output-marker))
          (insert (propertize "\n[aborted]\n" 'face 'warning)))
        (message "[DeepSeek] request aborted"))
    (message "[DeepSeek] no active request to abort")))

;; ---- Reset ----

;;;###autoload
(defun deepseek-chat-reset ()
  "Clear chat history in the current session buffer."
  (interactive)
  (setq deepseek--chat-history nil)
  (let ((inhibit-read-only t)
        (name deepseek--chat-session-name))
    (erase-buffer)
    (insert (propertize (format "# DeepSeek Chat — %s\n" name)
                        'face 'outline-1))
    (insert (propertize "RET send · M-RET newline · C-c C-k clear · C-c C-q abort · C-c C-n new · C-c C-s switch\n"
                        'face 'shadow))
    (insert (propertize "────────────────────\n"
                        'face 'shadow)))
  (deepseek--chat-setup-input-area)
  (message "[DeepSeek] chat history reset"))

;; ---- Persist to file ----

(defun deepseek-chat-persist (file)
  "Save the current chat buffer to FILE in Markdown format."
  (interactive
   (list (read-file-name "Save chat to: "
                         nil nil nil
                         (format "deepseek-chat-%s.md"
                                 (or deepseek--chat-session-name "session")
                                 (format-time-string "%Y%m%d-%H%M%S")))))
  (let ((content (buffer-substring-no-properties (point-min) (point-max))))
    (with-temp-file file
      (insert content))
    (message "[DeepSeek] chat saved to %s" file)))

;; ---- Send (streaming) ----

;;;###autoload
(defun deepseek-chat-send ()
  "Send the text in the input area to DeepSeek and stream the response.

If a region is active, sends the region instead (useful for sending
selected code snippets as context)."
  (interactive)
  (unless (eq major-mode 'deepseek-chat-mode)
    (user-error "Not in a DeepSeek chat buffer. Run M-x deepseek-chat-new first."))
  (when deepseek--chat-streaming
    (user-error "A response is still streaming. Press C-c C-q to abort first."))
  ;; Get user text: region or input area
  (let* ((region-text (when (use-region-p)
                        (string-trim
                         (buffer-substring-no-properties
                          (region-beginning) (region-end)))))
         (user-text (or region-text (deepseek--chat-read-input))))
    (when (string= user-text "")
      (user-error "Nothing to send — type a message in the input area below"))
    ;; Pre-check API key
    (condition-case err
        (deepseek--api-key-or-error)
      (error (ding) (signal (car err) (cdr err))))
    ;; Move to end of input area, insert USER block before it
    (let ((inhibit-read-only t)
          (input-pos (marker-position deepseek--chat-input-start)))
      ;; Insert user message above the input area
      (goto-char input-pos)
      (unless (bolp) (insert "\n"))
      (insert (propertize "── USER ──\n" 'face 'font-lock-keyword-face))
      (insert user-text "\n\n")
      (insert (propertize "── ASSISTANT ──\n" 'face 'font-lock-keyword-face))
      ;; Set output marker here — streaming text goes after this
      (set-marker deepseek--chat-output-marker (point))
      ;; Move input area down (clear old input, redraw separator)
      (delete-region (point) (point-max))
      (insert (propertize "────────────────────\n"
                          'face 'shadow))
      (insert (propertize "▎" 'face 'cursor))
      (set-marker deepseek--chat-input-start (1- (point)))
      (goto-char (point-max)))
    ;; Update history (trim old messages)
    (push (cons "user" user-text) deepseek--chat-history)
    (deepseek--chat-trim-history)
    ;; Snapshot history BEFORE pushing assistant turn
    (let ((hist-snapshot (copy-tree deepseek--chat-history)))
      ;; Pre-snapshot: history should be in oldest→newest order for the API
      (setq hist-snapshot (nreverse hist-snapshot))
      (setq deepseek--chat-streaming t)
      (message "[DeepSeek] streaming...")
      (if deepseek-chat-stream
          ;; ---- Streaming path ----
          (let* ((sys (deepseek--system-prompt-for-code 'chat))
                 (msgs (deepseek--make-messages sys user-text hist-snapshot)))
            (deepseek--http-post-stream
             (deepseek--chat-url)
             (deepseek--request-body msgs deepseek-chat-model t
                                     deepseek-temperature deepseek-max-tokens nil)
             ;; on-chunk: insert delta at output marker
             (lambda (delta)
               (with-current-buffer (current-buffer)
                 (let ((inhibit-read-only t))
                   (save-excursion
                     (goto-char (marker-position deepseek--chat-output-marker))
                     (insert delta)))))
             ;; on-done: finalize
             (lambda (full-text)
               (with-current-buffer (current-buffer)
                 (let ((inhibit-read-only t))
                   (save-excursion
                     (goto-char (marker-position deepseek--chat-output-marker))
                     (insert "\n"))
                   (setq deepseek--chat-streaming nil))
                 ;; Try markdown rendering on the assistant reply
                 (deepseek--chat-maybe-render-markdown)
                 ;; Push to history
                 (push (cons "assistant" full-text) deepseek--chat-history)
                 (message "[DeepSeek] response complete (%d chars)"
                          (length full-text)))))
             ;; on-error
             (lambda (err-msg)
               (with-current-buffer (current-buffer)
                 (let ((inhibit-read-only t))
                   (save-excursion
                     (goto-char (marker-position deepseek--chat-output-marker))
                     (insert (propertize (format "[error: %s]\n" err-msg)
                                         'face 'error)))
                   (setq deepseek--chat-streaming nil))
                 (message "[DeepSeek] error: %s" err-msg)))))
        ;; ---- Non-streaming fallback path ----
        (deepseek--call-async
         'chat user-text
         (lambda (reply)
           (with-current-buffer (current-buffer)
             (let ((inhibit-read-only t))
               (save-excursion
                 (goto-char (marker-position deepseek--chat-output-marker))
                 (insert reply "\n"))
               (setq deepseek--chat-streaming nil))
             (deepseek--chat-maybe-render-markdown)
             (push (cons "assistant" reply) deepseek--chat-history)
             (message "[DeepSeek] response received")))
         deepseek-chat-model nil hist-snapshot))))

;; ---- Markdown rendering ----

(defun deepseek--chat-maybe-render-markdown ()
  "Render the most recent assistant reply as read-only Markdown.
Uses `gfm-view-mode' if available, otherwise leaves as plain text."
  (condition-case nil
      (when (fboundp 'gfm-view-mode)
        (save-excursion
          (goto-char (marker-position deepseek--chat-output-marker))
          (let ((end (save-excursion
                       (if (re-search-forward "^── ASSISTANT ──" nil t)
                           (match-beginning 0)
                         (point-max)))))
            (narrow-to-region (point) end)
            (gfm-view-mode)
            (widen))))
    (error nil)))

;; ---- Region-based operations ----

(defmacro deepseek--defregion-op (name docstring role prompt-fn &rest keys)
  "Define an interactive NAME command operating on the active region (or whole buffer).
ROLE is the system-prompt template selector. PROMPT-FN receives
the region text and returns the user prompt string.

Supported keyword KEYS:
  :replace t   — when non-nil, the API reply replaces the active region
                 (otherwise output is rendered in *DeepSeek Output*)."
  (declare (indent 2) (doc-string 2))
  (let ((replacep (plist-get keys :replace)))
    `(defun ,name ()
       ,docstring
       (interactive)
       (let* ((ctx (deepseek--buffer-or-region-text))
              (body (plist-get ctx :body))
              (beg (plist-get ctx :beg))
              (end (plist-get ctx :end))
              (diags (deepseek--eglot-diagnostics))
              (extra (when diags (format "Editor diagnostics:\n%s\n" diags)))
              (prompt (funcall ,prompt-fn body)))
         (message "[DeepSeek] calling `%s'..." (quote ,name))
         (deepseek--call-async ',role prompt
           (lambda (reply)
             (let ((clean (if ,replacep (string-trim reply) reply)))
               (if (not ,replacep)
                   (with-current-buffer (get-buffer-create "*DeepSeek Output*")
                     (let ((inhibit-read-only t))
                       (erase-buffer)
                       (insert clean)
                       (setq buffer-read-only t))
                     (goto-char (point-min))
                     (pop-to-buffer (current-buffer))
                     (when (fboundp 'markdown-mode)
                       (markdown-view-mode)))
                 (save-excursion
                   (goto-char beg)
                   (delete-region beg end)
                   (insert clean)
                   (message "[DeepSeek] region replaced")))))
           nil extra)))))

(deepseek--defregion-op deepseek-explain
  "Explain the selected region (or whole buffer) in a *DeepSeek Output* buffer."
  explain
  (lambda (code)
    (format "Explain the following %s code:\n\n```%s\n%s\n```\n"
            (deepseek--language-name) (downcase (deepseek--language-name)) code)))

(deepseek--defregion-op deepseek-summarize
  "Summarize selected code or diff in a *DeepSeek Output* buffer."
  summarize
  (lambda (code)
    (format "Summarize the following text (code or diff):\n\n%s\n" code)))

(deepseek--defregion-op deepseek-refactor
  "Prompt the user for an instruction, then refactor the region in-place."
  refactor
  (lambda (code)
    (let ((ins (read-string "Refactor instruction: ")))
      (format "Refactor the following %s code per this instruction: %s\n\n```%s\n%s\n```\nReturn only the final code."
              (deepseek--language-name) ins
              (downcase (deepseek--language-name)) code)))
  :replace t)

(deepseek--defregion-op deepseek-doc
  "Add docstrings and idiomatic comments to the selected code (replaces region)."
  doc
  (lambda (code)
    (format "Add docstrings / comments to:\n\n```%s\n%s\n```\nReturn only the full final code."
            (downcase (deepseek--language-name)) code))
  :replace t)

(deepseek--defregion-op deepseek-generate-replace
  "Accept natural-language description and REPLACE the selected region with generated code."
  generate
  (lambda (_code)
    (let ((desc (read-string "Generate (replace) description: ")))
      (format "Generate %s code implementing: %s\n\nSurrounding file context language = %s.\nReturn ONLY code, no fences."
              (deepseek--language-name) desc (deepseek--language-name))))
  :replace t)

(deepseek--defregion-op deepseek-optimize
  "Optimize the selected region for performance/clarity (replaces in-place)."
  optimize
  (lambda (code)
    (format "Optimize the following %s code. Keep semantics. Output ONLY code.\n\n```%s\n%s\n```"
            (deepseek--language-name) (downcase (deepseek--language-name)) code))
  :replace t)

;;;###autoload
(defun deepseek-generate ()
  "Prompt for a natural-language description and INSERT generated code at point."
  (interactive)
  (let* ((desc (read-string "Generate code (insert) description: "))
         (ctx (deepseek--buffer-or-region-text))
         (snippet (plist-get ctx :body))
         (prompt (format "Generate %s code implementing: %s\n\nSurrounding context:\n```%s\n%s\n```\nReturn ONLY raw code, no fences."
                         (deepseek--language-name) desc
                         (downcase (deepseek--language-name)) snippet)))
    (message "[DeepSeek] generating...")
    (deepseek--call-async 'generate prompt
      (lambda (reply)
        (save-excursion (insert (string-trim reply)))
        (message "[DeepSeek] inserted generated code")))))

;;;###autoload
(defun deepseek-fix ()
  "Ask DeepSeek to fix all eglot/flymake diagnostics in the selected region / buffer.
If no region is active, uses the whole buffer. Replaces content."
  (interactive)
  (let* ((ctx (deepseek--buffer-or-region-text))
         (body (plist-get ctx :body))
         (beg (plist-get ctx :beg))
         (end (plist-get ctx :end))
         (diags (deepseek--eglot-diagnostics))
         (prompt
          (format "Fix the following %s code.\n%s\n\nFull file / region code:\n```%s\n%s\n```\nReturn ONLY the corrected full region, no fences."
                  (deepseek--language-name)
                  (if diags (concat "Diagnostics:\n" diags "\n")
                    "(No diagnostics reported. Fix obvious bugs and style issues.)")
                  (downcase (deepseek--language-name))
                  body)))
    (message "[DeepSeek] analyzing diagnostics...")
    (deepseek--call-async 'fix prompt
      (lambda (reply)
        (save-excursion
          (delete-region beg end)
          (goto-char beg)
          (insert (string-trim reply))
          (message "[DeepSeek] fixes applied"))))))

;;;###autoload
(defun deepseek-add-tests ()
  "Generate unit tests for the function at point.
Tests are opened in a *DeepSeek Output* buffer so the user can
review and save them to an appropriate file."
  (interactive)
  (let* ((fn-name (or (thing-at-point 'defun t)
                      (thing-at-point 'word t)
                      ""))
         (body (if (use-region-p)
                   (buffer-substring-no-properties (region-beginning) (region-end))
                 (save-excursion
                   (mark-defun)
                   (buffer-substring-no-properties (mark) (point)))))
         (prompt
          (format "Write unit tests for the following %s code / function `%s':\n\n```%s\n%s\n```\nOutput ONLY test code, no fences. Mention filename convention in a header comment."
                  (deepseek--language-name) fn-name
                  (downcase (deepseek--language-name)) body)))
    (message "[DeepSeek] writing tests...")
    (deepseek--call-async 'test prompt
      (lambda (reply)
        (with-current-buffer (get-buffer-create "*DeepSeek Output*")
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert (string-trim reply))
            (setq buffer-read-only t))
          (goto-char (point-min))
          (pop-to-buffer (current-buffer)))))))

;;;###autoload
(defun deepseek-custom-on-region (prompt)
  "Apply a user-supplied PROMPT to the active region (or buffer).
Output (raw) replaces the region."
  (interactive "sCustom prompt: ")
  (let* ((ctx (deepseek--buffer-or-region-text))
         (body (plist-get ctx :body))
         (beg (plist-get ctx :beg))
         (end (plist-get ctx :end))
         (user-p (format "%s\n\n```%s\n%s\n```" prompt
                         (downcase (deepseek--language-name)) body)))
    (message "[DeepSeek] custom...")
    (deepseek--call-async 't user-p
      (lambda (reply)
        (save-excursion
          (delete-region beg end)
          (goto-char beg)
          (insert (string-trim reply))
          (message "[DeepSeek] custom prompt applied"))))))

;; ============================================================
;;  6. Model switcher + customization entry point
;; ============================================================

(defvar deepseek--model-history nil
  "Minibuffer history for `deepseek-switch-model'.")

;;;###autoload
(defun deepseek-switch-model (new-model)
  "Interactively switch both chat and completion model to NEW-MODEL.
With a prefix argument also offers temperature and max-tokens."
  (interactive
   (list (completing-read
          (format "DeepSeek model (current chat=%s): " deepseek-chat-model)
          '("deepseek-chat" "deepseek-reasoner" "deepseek-coder")
          nil t nil 'deepseek--model-history deepseek-chat-model)))
  (setq deepseek-chat-model new-model
        deepseek-completion-model new-model)
  (message "[DeepSeek] model switched to %s" new-model)
  (when current-prefix-arg
    (let* ((tstr (read-string (format "Temperature (current %s): " deepseek-temperature)
                               (format "%s" deepseek-temperature)))
           (mx   (read-number (format "Max tokens (current %s): " deepseek-max-tokens)
                              deepseek-max-tokens)))
      (setq deepseek-temperature (max 0.0 (min 2.0 (string-to-number tstr)))
            deepseek-max-tokens   mx))))

;;;###autoload
(defun deepseek-customize ()
  "Open the `deepseek' customize group."
  (interactive)
  (customize-group 'deepseek t))

;; ============================================================
;;  7. Install + wire required packages (ellama, llm)
;; ============================================================
;;
;; ellama is OPTIONAL here. This module implements its own chat &
;; completion on top of the raw API so that it works out of the
;; box without extra dependencies beyond built-in `url' + `json'.
;;
;; However, for users who prefer the ellama UX, we enable ellama
;; + the `llm' abstract provider when they install it. This keeps
;; two worlds interoperable at zero cost.

(when (maybe-require-package 'llm)
  (with-eval-after-load 'llm
    ;; Provide a DeepSeek provider factory that users can call
    ;; from init-local if they want to build their own llm flows.
    (defun deepseek-make-provider (&rest opts)
      "Return an `llm' provider bound to the DeepSeek OpenAI-compatible endpoint.
Keyword OPTS override: :key, :base-url, :chat-model, :temperature."
      (cl-destructuring-bind
          (&key (key deepseek-api-key)
                (base-url deepseek-base-url)
                (chat-model deepseek-chat-model)
                (temperature deepseek-temperature))
          opts
        (require 'llm-openai)
        (make-llm-openai-compatible
         :key key
         :url (concat (string-trim-right base-url "/") "/chat/completions")
         :default-chat-model chat-model
         :chat-names '("deepseek-chat" "deepseek-reasoner" "deepseek-coder")
         :temperature temperature)))))

(when (maybe-require-package 'ellama)
  (with-eval-after-load 'ellama
    ;; If the user wants ellama's sessions, wire the llm provider:
    (when (fboundp 'deepseek-make-provider)
      (setq ellama-provider (deepseek-make-provider)
            ellama-chat-translation-enabled t)
      (when (fboundp 'ellama-session-auto-save-mode)
        (add-hook 'after-init-hook #'ellama-session-auto-save-mode)))))

;; ============================================================
;;  8. Register capf and keymap
;; ============================================================

(defvar deepseek-command-map
  (let ((m (make-sparse-keymap)))
    ;; Chat
    (define-key m (kbd "c")       'deepseek-chat-new)
    (define-key m (kbd "C")       'deepseek-chat-send)
    (define-key m (kbd "S")       'deepseek-chat-switch-session)
    (define-key m (kbd "a")       'deepseek-chat-abort)
    (define-key m (kbd "p")       'deepseek-chat-persist)
    ;; Completion
    (define-key m (kbd "i")       'deepseek-complete)
    (define-key m (kbd "I")       'deepseek-complete-popup)
    ;; Explain / summarize
    (define-key m (kbd "e")       'deepseek-explain)
    (define-key m (kbd "s")       'deepseek-summarize)
    ;; Refactor
    (define-key m (kbd "r")       'deepseek-refactor)
    (define-key m (kbd "R")       'deepseek-refactor) ; same; user learns either
    ;; Fix + Doc + Test + Generate + Optimize
    (define-key m (kbd "f")       'deepseek-fix)
    (define-key m (kbd "d")       'deepseek-doc)
    (define-key m (kbd "t")       'deepseek-add-tests)
    (define-key m (kbd "g")       'deepseek-generate)
    (define-key m (kbd "G")       'deepseek-generate-replace)
    (define-key m (kbd "o")       'deepseek-optimize)
    ;; Meta
    (define-key m (kbd "m")       'deepseek-switch-model)
    (define-key m (kbd "SPC")     'deepseek-custom-on-region)
    (define-key m (kbd "?")       'deepseek-customize)
    m)
  "Prefix keymap for all DeepSeek / AI commands.")
(fset 'deepseek-command-map deepseek-command-map)

;;;###autoload
(defun deepseek-setup-keys ()
  "Bind `deepseek-keymap-prefix' to the AI command map globally."
  (interactive)
  (global-set-key deepseek-keymap-prefix 'deepseek-command-map))

;; Enable once the library is loaded
(deepseek-setup-keys)

;; Add our capf backend for programming modes (opt-out via custom)
(when deepseek-auto-complete-capf
  (add-hook
   'prog-mode-hook
   (lambda ()
     (add-hook 'completion-at-point-functions
               #'deepseek-completion-at-point -90 t))))

(provide 'init-deepseek)
;;; init-deepseek.el ends here

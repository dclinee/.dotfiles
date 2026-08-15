" ===================================
" 快捷键映射配置 — Spacemacs 风格（助记分层 + Which-Key 友好）
" 顶级分组分配：
"   <SPC> a=Apps  b=Buffers  c=Code   e=Edit    f=Files   g=Git+Goto
"          h=Help  j=Jump     k=Kustom m=Major(,) n=Narrow p=Project
"          P=Plug  q=Quit     r=Reg    s=Search  t=Toggle  T=Tabs
"          v=VBlock w=Windows x=eXtras y=Yank    z=Fold
" 兼容策略：过渡期（默认 4 周）旧键位保留为「双写别名」，前缀 DOTFILES_SPACEMACS_COMPAT=0 可立即移除
" ===================================

" ===== 全局配置 =====
let mapleader      = ' '
let g:mapleader    = ' '
let maplocalleader = ','
let g:maplocalleader = ','

if !exists('g:dotfiles_spacemacs_compat')
  let g:dotfiles_spacemacs_compat = 1   " 1 = 双写兼容 4 周；0 = 纯 Spacemacs
endif

" =====================
"  0. 退出 / 会话（<leader>q 组）
" =====================
nnoremap <silent> <leader>qq :qa<CR>
nnoremap <silent> <leader>qQ :qa!<CR>
nnoremap <silent> <leader>qw :wq<CR>
nnoremap <silent> <leader>qW :wqa<CR>
nnoremap <silent> <leader>qx :x<CR>
nnoremap <silent> <leader>q! :q!<CR>
" 4 周兼容：原 <leader>q / wq / qa / Q
if g:dotfiles_spacemacs_compat
  nnoremap <silent> <leader>q  :q<CR>
  nnoremap <silent> <leader>wq :wq<CR>
  nnoremap <silent> <leader>qa :qa<CR>
  nnoremap <silent> <leader>Q  :q!<CR>
endif

" =====================
"  1. 文件（<leader>f 组）
" =====================
nnoremap <silent> <leader>ff :find <C-z>
nnoremap <silent> <leader>fr :browse oldfiles<CR>
nnoremap <silent> <leader>fs :w<CR>
nnoremap <silent> <leader>fS :wa<CR>
nnoremap <silent> <leader>fo :NERDTreeFind<CR>
nnoremap <silent> <leader>fe :execute 'edit ' . expand('$MYVIMRC')<CR>
nnoremap <silent> <leader>fE :source $MYVIMRC<CR>
nnoremap <silent> <leader>fl :lcd %:p:h<CR>:pwd<CR>
nnoremap <silent> <leader>fL :cd  %:p:h<CR>:pwd<CR>
nnoremap <silent> <leader>fy :let @+ = expand('%:p')<CR>
nnoremap <silent> <leader>fY :let @+ = expand('%:~:.')<CR>
nnoremap <silent> <leader>fD :call delete(expand('%')) \| bdelete<CR>
" 4 周兼容：原 <leader>w = 保存
if g:dotfiles_spacemacs_compat
  nnoremap <silent> <leader>w  :w<CR>
endif

" =====================
"  2. 窗口（<leader>w 组）
" =====================
nnoremap <silent> <leader>wv :vsplit<CR>
nnoremap <silent> <leader>wh :split<CR>
nnoremap <silent> <leader>wc :close<CR>
nnoremap <silent> <leader>wo :only<CR>
nnoremap <silent> <leader>we :wincmd =<CR>
nnoremap <silent> <leader>ws :wincmd x<CR>
nnoremap <silent> <leader>wH :wincmd H<CR>
nnoremap <silent> <leader>wJ :wincmd J<CR>
nnoremap <silent> <leader>wK :wincmd K<CR>
nnoremap <silent> <leader>wL :wincmd L<CR>
nnoremap <silent> <leader>w= :wincmd =<CR>
" 窗口方向切换（与 <C-hjkl> 共存）
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
" 调整窗口大小
nnoremap <C-Up>    :resize +2<CR>
nnoremap <C-Down>  :resize -2<CR>
nnoremap <C-Left>  :vertical resize -2<CR>
nnoremap <C-Right> :vertical resize +2<CR>
" 4 周兼容：原 <leader>sv/sh/sc/so
if g:dotfiles_spacemacs_compat
  nnoremap <silent> <leader>sv :vsplit<CR>
  nnoremap <silent> <leader>sh :split<CR>
  nnoremap <silent> <leader>sc :close<CR>
  nnoremap <silent> <leader>so :only<CR>
endif

" =====================
"  3. 缓冲区（<leader>b 组）
" =====================
nnoremap <silent> <leader>bb :b#<CR>
nnoremap <silent> <leader>bd :bdelete<CR>
nnoremap <silent> <leader>bD :bdelete!<CR>
nnoremap <silent> <leader>bn :bnext<CR>
nnoremap <silent> <leader>bp :bprev<CR>
nnoremap <silent> <leader>bl :ls<CR>

" =====================
"  4. 标签页（<leader>T 组 + <leader><tab> 别名）
" =====================
nnoremap <silent> <leader>Tn    :tabnew<CR>
nnoremap <silent> <leader>Tc    :tabclose<CR>
nnoremap <silent> <leader>To    :tabonly<CR>
nnoremap <silent> <leader>Tl    :tabnext<CR>
nnoremap <silent> <leader>Th    :tabprevious<CR>
nnoremap <silent> <leader><tab><tab> :tabnew<CR>
nnoremap <silent> <leader><tab>n     :tabnext<CR>
nnoremap <silent> <leader><tab>p     :tabprevious<CR>
nnoremap <silent> <leader><tab>c     :tabclose<CR>
nnoremap <silent> <leader><tab>o     :tabonly<CR>
nnoremap <silent> <S-l> :tabnext<CR>
nnoremap <silent> <S-h> :tabprevious<CR>
" 4 周兼容：原 <leader>tn/tc/to/tl/th
if g:dotfiles_spacemacs_compat
  nnoremap <silent> <leader>tn :tabnew<CR>
  nnoremap <silent> <leader>tc :tabclose<CR>
  nnoremap <silent> <leader>to :tabonly<CR>
  nnoremap <silent> <leader>tl :tabnext<CR>
  nnoremap <silent> <leader>th :tabprevious<CR>
endif

" =====================
"  5. 跳转（<leader>j 组）
" =====================
nnoremap <silent> <leader>jj 8j
nnoremap <silent> <leader>jk 8k
nnoremap <silent> <leader>jh ^
nnoremap <silent> <leader>jl $
nnoremap <silent> <leader>jJ }
nnoremap <silent> <leader>jK {
nnoremap <silent> <leader>jm :marks<CR>
nnoremap <silent> <leader>jo :jumps<CR>
" 4 周兼容：原 <leader>j/k/h/l 作为快捷键直移
if g:dotfiles_spacemacs_compat
  nnoremap <silent> <leader>j 8j
  nnoremap <silent> <leader>k 8k
  nnoremap <silent> <leader>h ^
  nnoremap <silent> <leader>l $
endif

" =====================
"  6. 搜索（<leader>s 组）
" =====================
nnoremap <silent> <leader>sb :exec 'noautocmd vimgrep /' . input('Search in buffer: ') . '/j %' \| cwindow<CR>
nnoremap <silent> <leader>sg :exec 'noautocmd vimgrep /' . input('Grep pattern: ') . '/j **/*' \| cwindow<CR>
nnoremap <silent> <leader>s* :noautocmd vimgrep /\<<C-r><C-w>\>/j **/* \| cwindow<CR>
nnoremap <silent> <leader>sS :%s//gc<Left><Left><Left>
nnoremap <silent> <leader>sc :nohlsearch<CR>
nnoremap <silent> <leader>sn :nohlsearch<CR>
" 4 周兼容：原 <leader>/ = 清高亮
if g:dotfiles_spacemacs_compat
  nnoremap <silent> <leader>/ :nohlsearch<CR>
endif

" =====================
"  7. 编辑（<leader>e 组）
" =====================
vnoremap <silent> <leader>ea ggVG
nnoremap <silent> <leader>ea ggVG
nnoremap <silent> <leader>ei gg=G
nnoremap <silent> <leader>ed :%s/\s\+$//e<CR>
nnoremap <silent> <leader>es [s1z=
nnoremap <silent> <leader>eS z=
nnoremap <silent> <leader>eU gUU
nnoremap <silent> <leader>eu guu
nnoremap <silent> <leader>e< <G
nnoremap <silent> <leader>e> >G
nnoremap <silent> <A-j> :m .+1<CR>==
nnoremap <silent> <A-k> :m .-2<CR>==
vnoremap <silent> <A-j> :m '>+1<CR>gv=gv
vnoremap <silent> <A-k> :m '<-2<CR>gv=gv
" 4 周兼容：原 <leader>a = 全选
if g:dotfiles_spacemacs_compat
  vnoremap <silent> <leader>a ggVG
endif

" =====================
"  8. 切换（<leader>t 组）
" =====================
nnoremap <silent> <leader>tn :setlocal number! number? relativenumber!<CR>
nnoremap <silent> <leader>ts :setlocal spell!<CR>
nnoremap <silent> <leader>tw :setlocal wrap!<CR>
nnoremap <silent> <leader>th :set hlsearch!<CR>
nnoremap <silent> <leader>ti :set ignorecase!<CR>
nnoremap <silent> <leader>tp :set paste!<CR>
nnoremap <silent> <leader>tz :set foldenable!<CR>
" 4 周兼容：原 <leader>us/uw/un（LazyVim 旧分组）
if g:dotfiles_spacemacs_compat
  nnoremap <silent> <leader>us :set spell!<CR>
  nnoremap <silent> <leader>uw :set wrap!<CR>
  nnoremap <silent> <leader>un :set number! relativenumber!<CR>
endif

" =====================
"  9. 剪贴板（<leader>y 组）
" =====================
nnoremap <silent> <leader>ys "+y
vnoremap <silent> <leader>ys "+y
nnoremap <silent> <leader>yS gg"+yG
nnoremap <silent> <leader>yy "+yy
nnoremap <silent> <leader>yY "+Y
nnoremap <silent> <leader>y0 "+y0
nnoremap <silent> <leader>y$ "+y$
nnoremap <silent> <leader>yp "+p
vnoremap <silent> <leader>yp "+p
nnoremap <silent> <leader>yP "+P
" 4 周兼容：原 <leader>y / p = 系统复制/粘贴
if g:dotfiles_spacemacs_compat
  nnoremap <silent> <leader>y "+y
  vnoremap <silent> <leader>y "+y
  nnoremap <silent> <leader>Y "+Y
  nnoremap <silent> <leader>p "+p
  vnoremap <silent> <leader>p "+p
endif

" =====================
"  10. 项目（<leader>p 组）
" =====================
nnoremap <silent> <leader>pf :find <C-z>
nnoremap <silent> <leader>pb :ls<CR>:b<Space>
nnoremap <silent> <leader>pc :cd <C-z>
nnoremap <silent> <leader>pC :lcd <C-z>
nnoremap <silent> <leader>pt :NERDTreeToggle<CR>
nnoremap <silent> <leader>p/ :vimgrep /<C-r><C-w>/j **/* \| cwindow<CR>

" =====================
"  11. 插件管理（<leader>P 大写 = Plugins）
" =====================
nnoremap <silent> <leader>Pi :PlugInstall<CR>
nnoremap <silent> <leader>Pu :PlugUpdate<CR>
nnoremap <silent> <leader>Pc :PlugClean<CR>
nnoremap <silent> <leader>Ps :PlugStatus<CR>
nnoremap <silent> <leader>Px :PlugUpgrade<CR>
" 4 周兼容：原 <leader>pi/pu/pc/ps
if g:dotfiles_spacemacs_compat
  nnoremap <silent> <leader>pi :PlugInstall<CR>
  nnoremap <silent> <leader>pu :PlugUpdate<CR>
  nnoremap <silent> <leader>pc :PlugClean<CR>
  nnoremap <silent> <leader>ps :PlugStatus<CR>
endif

" ===================================
"  Coc.nvim LSP 快捷键 — 归入 <leader>c (Code) / <leader>g (Goto)
" ===================================

" 跳转类 → <leader>g (Git+Goto 共享前缀)
nnoremap <silent> <leader>gd <Plug>(coc-definition)
nnoremap <silent> <leader>gD <Plug>(coc-declaration)
nnoremap <silent> <leader>gi <Plug>(coc-implementation)
nnoremap <silent> <leader>gt <Plug>(coc-type-definition)
nnoremap <silent> <leader>gr <Plug>(coc-references)

" Code 类 → <leader>c
nnoremap <silent> K :call CocActionAsync('doHover')<CR>
nnoremap <silent> <leader>cr <Plug>(coc-rename)
nnoremap <silent> <leader>ca <Plug>(coc-codeaction-selected)
nnoremap <silent> <leader>cd :call CocActionAsync('diagnosticList')<CR>
" 诊断跳转：保持与 LazyVim 约定一致的 [d / ]d，同时提供 <leader>c] / c[
nnoremap <silent> <leader>c] <Plug>(coc-diagnostic-next)
nnoremap <silent> <leader>c[ <Plug>(coc-diagnostic-prev)
" 4 周兼容：原 <leader>rn = rename；<leader>[ / ] = 诊断
if g:dotfiles_spacemacs_compat
  nnoremap <silent> <leader>rn <Plug>(coc-rename)
  nnoremap <silent> <leader>]  <Plug>(coc-diagnostic-next)
  nnoremap <silent> <leader>[  <Plug>(coc-diagnostic-prev)
endif

" ===================================
"  Git 类 → <leader>g 组（与 Goto 同前缀，子键分域：gd/gr/gg…）
" ===================================
nnoremap <silent> <leader>gs :Git<CR>
nnoremap <silent> <leader>gb :Git blame<CR>
nnoremap <silent> <leader>gl :Git log --oneline --decorate --graph -20<CR>
nnoremap <silent> <leader>gh :GitGutterLineHighlightsToggle<CR>
nnoremap <silent> <leader>g} :GitGutterNextHunk<CR>
nnoremap <silent> <leader>g{ :GitGutterPrevHunk<CR>

" ===================================
"  补全弹窗交互（Tab/S-Tab 切换 + Enter 确认）— 保持不变
" ===================================
inoremap <expr> <CR>  pumvisible() ? coc#_select_confirm() : "\<CR>"
inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

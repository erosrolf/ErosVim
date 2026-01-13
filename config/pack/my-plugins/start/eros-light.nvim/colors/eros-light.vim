" Vim/Neovim colorscheme: eros-light
" Palette by erosrolf

hi clear
if exists("syntax_on")
  syntax reset
endif

let g:colors_name = "eros-light"
set background=light

if has("termguicolors")
  set termguicolors
endif

" -------------------------
" Palette
" -------------------------
let s:bg       = "#fffafc"
let s:fg       = "#2b2631"
let s:fg2      = "#3c3741"
let s:fg3      = "#4d4952"
let s:fg4      = "#5e5a62"
let s:bg2      = "#ebe6e8"
let s:bg3      = "#d6d2d4"
let s:bg4      = "#c2bec0"

let s:keyword  = "#ab4f8e"
let s:builtin  = "#3e6060"
let s:const    = "#000000"
let s:comment  = "#919191"
let s:func     = "#9c2dd7"
let s:str      = "#077d16"
let s:type     = "#351b83"
let s:var      = "#000000"

let s:error    = "#f50000"
let s:warn     = "#f2bf56"

" -------------------------
" Helper
" -------------------------
function! s:Hi(group, fg, bg, gui) abort
  let l:cmd = 'hi ' . a:group
  if a:fg !=# '' | let l:cmd .= ' guifg=' . a:fg | endif
  if a:bg !=# '' | let l:cmd .= ' guibg=' . a:bg | endif
  if a:gui !=# '' | let l:cmd .= ' gui=' . a:gui | endif
  execute l:cmd
endfunction

" -------------------------
" Core UI
" -------------------------
call s:Hi('Normal',        s:fg,      s:bg,  '')
call s:Hi('NormalNC',      s:fg,      s:bg,  '')
call s:Hi('EndOfBuffer',   s:bg,      s:bg,  '')

call s:Hi('Cursor',        s:bg,      s:fg,  '')
call s:Hi('CursorIM',      s:bg,      s:fg,  '')

call s:Hi('CursorLine',    '',        s:bg2, '')
call s:Hi('CursorColumn',  '',        s:bg2, '')
call s:Hi('ColorColumn',   '',        s:bg2, '')

call s:Hi('LineNr',        s:fg2,     s:bg2, '')
call s:Hi('CursorLineNr',  s:fg,      s:bg2, 'bold')

call s:Hi('SignColumn',    s:comment, s:bg2, '')
call s:Hi('FoldColumn',    s:comment, s:bg2, '')
call s:Hi('Folded',        s:fg4,     s:bg,  '')

" Splits / separators
call s:Hi('WinSeparator',  s:fg3,     s:bg3, '')
call s:Hi('VertSplit',     s:fg3,     s:bg3, '')

" Statusline / tabline
call s:Hi('StatusLine',    s:fg2,     s:bg3, 'bold')
call s:Hi('StatusLineNC',  s:fg3,     s:bg3, '')
call s:Hi('TabLine',       s:fg3,     s:bg3, '')
call s:Hi('TabLineSel',    s:fg,      s:bg2, 'bold')
call s:Hi('TabLineFill',   '',        s:bg3, '')

call s:Hi('MatchParen',    s:warn,    '',    'underline')

" Winbar
call s:Hi('WinBar',     s:fg2, s:bg3, 'bold')
call s:Hi('WinBarNC',   s:fg3, s:bg3, '')
call s:Hi('WinBarFill', '',    s:bg3, '')

" -------------------------
" Popup menu / completion
" -------------------------
call s:Hi('Pmenu',         s:fg,      s:bg2, '')
call s:Hi('PmenuSel',      '',        s:bg3, '')
call s:Hi('PmenuSbar',     '',        s:bg3, '')
call s:Hi('PmenuThumb',    '',        s:fg3, '')

" -------------------------
" Search / selection
" -------------------------
call s:Hi('IncSearch',     s:bg,      s:keyword, '')
call s:Hi('Search',        s:bg,      s:warn,    '')
call s:Hi('Visual',        '',        s:bg3,     '')

" -------------------------
" Floating windows
" -------------------------
call s:Hi('NormalFloat',   s:fg,      s:bg,  '')
call s:Hi('FloatBorder',   s:fg3,     s:bg,  '')
call s:Hi('FloatTitle',    s:fg,      s:bg,  'bold')

" -------------------------
" Messages
" -------------------------
call s:Hi('ErrorMsg',      s:error,   s:bg2, 'bold')
call s:Hi('WarningMsg',    s:fg,      s:warn,'')
call s:Hi('MoreMsg',       s:str,     '',    '')
call s:Hi('ModeMsg',       s:fg2,     '',    '')

" -------------------------
" Basics / syntax
" -------------------------
call s:Hi('Comment',       s:comment, '',    '')
call s:Hi('Constant',      s:const,   '',    '')
call s:Hi('String',        s:str,     '',    '')
call s:Hi('Character',     s:const,   '',    '')
call s:Hi('Number',        s:const,   '',    '')
call s:Hi('Boolean',       s:const,   '',    '')
call s:Hi('Float',         s:const,   '',    '')

call s:Hi('Identifier',    s:type,    '',    'italic')
call s:Hi('Function',      s:func,    '',    '')

call s:Hi('Statement',     s:keyword, '',    '')
call s:Hi('Keyword',       s:keyword, '',    'bold')
call s:Hi('Conditional',   s:keyword, '',    '')
call s:Hi('Repeat',        s:keyword, '',    '')
call s:Hi('Define',        s:keyword, '',    '')
call s:Hi('Label',         s:var,     '',    '')
call s:Hi('Operator',      s:keyword, '',    '')
call s:Hi('PreProc',       s:keyword, '',    '')
call s:Hi('Special',       s:fg,      '',    '')
call s:Hi('Tag',           s:keyword, '',    '')
call s:Hi('Title',         s:fg,      '',    'bold')

call s:Hi('Type',          s:type,    '',    '')
call s:Hi('StorageClass',  s:type,    '',    'italic')
call s:Hi('Underlined',    '',        '',    'underline')

call s:Hi('Directory',     s:const,   '',    '')
call s:Hi('NonText',       s:bg4,     s:bg2, '')
call s:Hi('SpecialKey',    s:fg2,     s:bg2, '')

call s:Hi('Todo',          s:fg2,     '',    'inverse,bold')

" -------------------------
" Diff
" -------------------------
call s:Hi('DiffAdd',       '#000000', '#bef6dc', 'bold')
call s:Hi('DiffDelete',    s:bg2,     '',        '')
call s:Hi('DiffChange',    '#ffffff', '#5b76ef', '')
call s:Hi('DiffText',      '#ffffff', '#ff0000', 'bold')

" -------------------------
" Diagnostics (LSP)
" -------------------------
call s:Hi('DiagnosticError', s:error,   '', '')
call s:Hi('DiagnosticWarn',  s:warn,    '', '')
call s:Hi('DiagnosticInfo',  s:func,    '', '')
call s:Hi('DiagnosticHint',  s:builtin, '', '')

execute 'hi DiagnosticUnderlineError gui=underline guisp=' . s:error
execute 'hi DiagnosticUnderlineWarn  gui=underline guisp=' . s:warn
execute 'hi DiagnosticUnderlineInfo  gui=underline guisp=' . s:func
execute 'hi DiagnosticUnderlineHint  gui=underline guisp=' . s:builtin

hi! link DiagnosticVirtualTextError DiagnosticError
hi! link DiagnosticVirtualTextWarn  DiagnosticWarn
hi! link DiagnosticVirtualTextInfo  DiagnosticInfo
hi! link DiagnosticVirtualTextHint  DiagnosticHint

" -------------------------
" Treesitter (generic)
" -------------------------
hi! link @comment                 Comment
hi! link @string                  String
hi! link @character               Character
hi! link @number                  Number
hi! link @boolean                 Boolean

hi! link @keyword                 Keyword
hi! link @conditional             Conditional
hi! link @repeat                  Repeat
hi! link @operator                Operator

hi! link @function                Function
hi! link @function.call           Function
hi! link @method                  Function
hi! link @method.call             Function
hi! link @constructor             Function

hi! link @type                    Type
hi! link @type.builtin            Type
hi! link @namespace               Type

hi! link @variable                Identifier
hi! link @variable.builtin        Identifier
hi! link @parameter               Identifier
hi! link @property                Identifier
hi! link @field                   Identifier

hi! link @constant                Constant
hi! link @constant.builtin        Constant
hi! link @constant.macro          PreProc
hi! link @macro                   PreProc
hi! link @preproc                 PreProc
hi! link @include                 PreProc

hi! link @punctuation.delimiter   Special
hi! link @punctuation.bracket     Special
hi! link @punctuation.special     Special

hi! link @markup.heading          Title
hi! link @markup.strong           Statement
hi! link @markup.italic           Identifier
hi! link @markup.link             Underlined
hi! link @markup.raw              String

" -------------------------
" LSP semantic tokens
" -------------------------
hi! link @lsp.type.class          Type
hi! link @lsp.type.struct         Type
hi! link @lsp.type.enum           Type
hi! link @lsp.type.interface      Type
hi! link @lsp.type.typeParameter  Type
hi! link @lsp.type.namespace      Type

hi! link @lsp.type.function       Function
hi! link @lsp.type.method         Function
hi! link @lsp.type.property       Identifier
hi! link @lsp.type.variable       Identifier
hi! link @lsp.type.parameter      Identifier

hi! link @lsp.type.enumMember     Constant
hi! link @lsp.type.macro          PreProc
hi! link @lsp.type.keyword        Keyword

" -------------------------
" Terminal palette
" -------------------------
let g:terminal_color_0  = s:bg
let g:terminal_color_1  = s:error
let g:terminal_color_2  = s:keyword
let g:terminal_color_3  = s:bg4
let g:terminal_color_4  = s:func
let g:terminal_color_5  = s:builtin
let g:terminal_color_6  = s:fg3
let g:terminal_color_7  = s:str
let g:terminal_color_8  = s:bg2
let g:terminal_color_9  = s:warn
let g:terminal_color_10 = s:fg2
let g:terminal_color_11 = s:var
let g:terminal_color_12 = s:type
let g:terminal_color_13 = s:const
let g:terminal_color_14 = s:fg4
let g:terminal_color_15 = s:comment

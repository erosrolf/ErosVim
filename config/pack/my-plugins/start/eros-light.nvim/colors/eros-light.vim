" Vim/Neovim colorscheme: erosflight
" High-contrast light theme inspired by JetBrains Rider

hi clear
if exists("syntax_on")
  syntax reset
endif

let g:colors_name = "eros-rider-light"
set background=light

if has("termguicolors")
  set termguicolors
endif

" -------------------------
" Palette
" -------------------------
let s:bg       = "#ffffff"
let s:fg       = "#1e1f22"
let s:fg2      = "#2b2d30"
let s:fg3      = "#4c5058"
let s:fg4      = "#7a7e85"

let s:bg2      = "#f4f4f5"
let s:bg3      = "#ebecf0"
let s:bg4      = "#d8dbe2"

let s:keyword  = "#8f279a"
let s:builtin  = "#2f6fdd"
let s:const    = "#1a56db"
let s:comment  = "#8b8d91"
let s:func     = "#7a3fc7"
let s:str      = "#067d17"
let s:type     = "#0042b6"
let s:var      = "#1e1f22"

let s:error    = "#d1242f"
let s:warn     = "#c27a00"
let s:info     = "#602682"
let s:hint     = "#7a3fc7"

let s:search   = "#7e7941"
let s:visual   = "#e9e0ff"

let s:cursor_bg = "#2f3337"
let s:cursor_fg = "#ffffff"

let s:paren_fg = "#6b7280"
let s:paren_bg = "#eef3ff"

let s:git_add       = "#126b30"
let s:git_delete    = "#d1242f"
let s:git_change    = "#c27a00"
let s:git_untracked = "#8d7ea8"

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
call s:Hi('EndOfBuffer',   s:bg,      s:bg,  '')

call s:Hi('LineNr',       '#3b134d', s:bg2, '')
call s:Hi('LineNrAbove',  '#7f6f87', s:bg2, '')
call s:Hi('LineNrBelow',  '#7f6f87', s:bg2, '')

call s:Hi('Cursor',        s:cursor_fg, s:cursor_bg, '')
call s:Hi('CursorIM',      s:cursor_fg, s:cursor_bg, '')

call s:Hi('CursorLine',    '',        '#f6f7f9', '')
call s:Hi('CursorColumn',  '',        s:bg2, '')
call s:Hi('ColorColumn',   '',        s:bg2, '')

call s:Hi('SignColumn',    s:fg4,     s:bg,  '')
call s:Hi('FoldColumn',    s:fg4,     s:bg2, '')
call s:Hi('Folded',        s:fg3,     s:bg2, '')

call s:Hi('WinSeparator',  s:bg4,     s:bg3, '')
call s:Hi('VertSplit',     s:bg4,     s:bg3, '')

call s:Hi('StatusLine',    s:fg2,     s:bg3, 'bold')
call s:Hi('StatusLineNC',  s:fg3,     s:bg3, '')
call s:Hi('TabLine',       s:fg3,     s:bg3, '')
call s:Hi('TabLineSel',    s:fg,      s:bg2, 'bold')
call s:Hi('TabLineFill',   '',        s:bg3, '')

call s:Hi('MatchParen',    s:paren_fg, s:paren_bg, 'underline')

call s:Hi('WinBar',        s:fg2,     s:bg3, 'bold')
call s:Hi('WinBarNC',      s:fg3,     s:bg3, '')
call s:Hi('WinBarFill',    '',        s:bg3, '')

" -------------------------
" Popup menu / completion
" -------------------------
call s:Hi('Pmenu',         s:fg,      s:bg2, '')
call s:Hi('PmenuSel',      s:fg,      '#d8e7ff', 'bold')
call s:Hi('PmenuSbar',     '',        s:bg3, '')
call s:Hi('PmenuThumb',    '',        s:fg3, '')

" -------------------------
" Search / selection
" -------------------------
call s:Hi('IncSearch',     s:fg,      '#ffd24d', 'bold')
call s:Hi('Search',        s:fg,      s:search,  '')
call s:Hi('Visual',        '',        s:visual,  '')

" -------------------------
" Floating windows
" -------------------------
call s:Hi('NormalFloat',   s:fg,      s:bg,  '')
call s:Hi('FloatBorder',   s:bg4,     s:bg,  '')
call s:Hi('FloatTitle',    s:fg2,     s:bg,  'bold')

" -------------------------
" Messages
" -------------------------
call s:Hi('ErrorMsg',      s:error,   '#fff1f1', 'bold')
call s:Hi('WarningMsg',    s:fg,      '#fff0c2', '')
call s:Hi('MoreMsg',       s:str,     '',    '')
call s:Hi('ModeMsg',       s:fg2,     '',    '')

" -------------------------
" Basics / syntax
" -------------------------
call s:Hi('Comment',       s:comment, '',    'italic')
call s:Hi('Constant',      s:const,   '',    '')
call s:Hi('String',        s:str,     '',    '')
call s:Hi('Character',     s:str,     '',    '')
call s:Hi('Number',        s:const,   '',    '')
call s:Hi('Boolean',       s:keyword, '',    'bold')
call s:Hi('Float',         s:const,   '',    '')

call s:Hi('Identifier',    s:var,     '',    '')
call s:Hi('Function',      s:func,    '',    '')

call s:Hi('Statement',     s:keyword, '',    '')
call s:Hi('Keyword',       s:keyword, '',    'bold')
call s:Hi('Conditional',   s:keyword, '',    'bold')
call s:Hi('Repeat',        s:keyword, '',    'bold')
call s:Hi('Define',        s:keyword, '',    '')
call s:Hi('Label',         s:var,     '',    '')
call s:Hi('Operator',      s:fg2,     '',    '')
call s:Hi('PreProc',       s:keyword, '',    '')
call s:Hi('Special',       s:fg2,     '',    '')
call s:Hi('Tag',           s:keyword, '',    '')
call s:Hi('Title',         s:fg,      '',    'bold')

call s:Hi('Type',          s:type,    '',    '')
call s:Hi('StorageClass',  s:type,    '',    '')
call s:Hi('Underlined',    '',        '',    'underline')

call s:Hi('Directory',     s:info,    '',    '')
call s:Hi('NonText',       s:bg4,     s:bg2, '')
call s:Hi('SpecialKey',    s:fg3,     s:bg2, '')

call s:Hi('Todo',          s:fg,      '#fff0b3', 'bold')

" -------------------------
" Diff
" -------------------------
call s:Hi('DiffAdd',       s:fg,      '#d9f2e3', 'bold')
call s:Hi('DiffDelete',    '#ffd9d9', '',        '')
call s:Hi('DiffChange',    s:fg,      '#fff1bf', '')
call s:Hi('DiffText',      s:fg,      '#cfe3ff', 'bold')

" -------------------------
" Diagnostics (LSP)
" -------------------------
call s:Hi('DiagnosticError', s:error, '', 'bold')
call s:Hi('DiagnosticWarn',  s:warn,  '', 'bold')
call s:Hi('DiagnosticInfo',  s:info,  '', '')
call s:Hi('DiagnosticHint',  s:hint,  '', '')

execute 'hi DiagnosticUnderlineError gui=underline guisp=' . s:error
execute 'hi DiagnosticUnderlineWarn  gui=underline guisp=' . s:warn
execute 'hi DiagnosticUnderlineInfo  gui=underline guisp=' . s:info
execute 'hi DiagnosticUnderlineHint  gui=underline guisp=' . s:hint

hi! link DiagnosticVirtualTextError DiagnosticError
hi! link DiagnosticVirtualTextWarn  DiagnosticWarn
hi! link DiagnosticVirtualTextInfo  DiagnosticInfo
hi! link DiagnosticVirtualTextHint  DiagnosticHint

" -------------------------
" Cursor word / references
" -------------------------
call s:Hi('LspReferenceText',   '', '', 'underline')
call s:Hi('LspReferenceRead',   '', '', 'underline')
call s:Hi('LspReferenceWrite',  '', '', 'underline')

call s:Hi('CursorWord',         '', '', 'underline')
call s:Hi('CursorWord0',        '', '', 'underline')
call s:Hi('CursorWord1',        '', '', 'underline')

call s:Hi('illuminatedWord',       '', '', 'underline')
call s:Hi('illuminatedCurWord',    '', '', 'underline')
call s:Hi('MiniCursorword',        '', '', 'underline')
call s:Hi('MiniCursorwordCurrent', '', '', 'underline')

" Make inline hints as unobtrusive as possible if they are enabled
call s:Hi('LspInlayHint',      '#cfd3da', '', 'italic')
call s:Hi('InlayHint',         '#cfd3da', '', 'italic')

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
hi! link @markup.italic           Comment
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
let g:terminal_color_2  = s:git_add
let g:terminal_color_3  = s:git_change
let g:terminal_color_4  = s:keyword
let g:terminal_color_5  = s:hint
let g:terminal_color_6  = s:builtin
let g:terminal_color_7  = s:fg3
let g:terminal_color_8  = s:bg3
let g:terminal_color_9  = s:error
let g:terminal_color_10 = s:git_add
let g:terminal_color_11 = s:git_change
let g:terminal_color_12 = s:info
let g:terminal_color_13 = s:hint
let g:terminal_color_14 = s:builtin
let g:terminal_color_15 = s:fg

" -------------------------
" GitSigns
" -------------------------
execute 'highlight! GitSignsAdd           guifg=' . s:git_add       . ' guibg=NONE gui=bold'
execute 'highlight! GitSignsChange        guifg=' . s:git_change    . ' guibg=NONE gui=bold'
execute 'highlight! GitSignsDelete        guifg=' . s:git_delete    . ' guibg=NONE gui=bold'
execute 'highlight! GitSignsTopdelete     guifg=' . s:git_delete    . ' guibg=NONE gui=bold'
execute 'highlight! GitSignsChangedelete  guifg=' . s:git_change    . ' guibg=NONE gui=bold'
execute 'highlight! GitSignsUntracked     guifg=' . s:git_untracked . ' guibg=NONE gui=bold'

execute 'highlight! GitSignsAddNr         guifg=' . s:git_add       . ' guibg=NONE gui=bold'
execute 'highlight! GitSignsChangeNr      guifg=' . s:git_change    . ' guibg=NONE gui=bold'
execute 'highlight! GitSignsDeleteNr      guifg=' . s:git_delete    . ' guibg=NONE gui=bold'

execute 'highlight! GitSignsAddLn         guibg=#d9f2e3 gui=NONE'
execute 'highlight! GitSignsChangeLn      guibg=#fff1bf gui=NONE'
execute 'highlight! GitSignsDeleteLn      guibg=#ffd9d9 gui=NONE'

execute 'highlight! GitSignsCurrentLineBlame guifg=' . s:comment . ' gui=italic'

" -------------------------
" MiniDiff
" -------------------------
execute 'highlight! MiniDiffSignAdd    guifg=' . s:git_add    . ' guibg=NONE gui=bold'
execute 'highlight! MiniDiffSignChange guifg=' . s:git_change . ' guibg=NONE gui=bold'
execute 'highlight! MiniDiffSignDelete guifg=' . s:git_delete . ' guibg=NONE gui=bold'

execute 'highlight! MiniDiffOverAdd    guibg=#d9f2e3 gui=NONE'
execute 'highlight! MiniDiffOverChange guibg=#fff1bf gui=NONE'
execute 'highlight! MiniDiffOverDelete guibg=#ffd9d9 gui=NONE'

" -------------------------
" Aerial (outline window)
" -------------------------

" текущая строка в Aerial (раньше была бирюзовой)
call s:Hi('AerialLine', '', '#e9e0ff', '')

" fallback, так как Aerial иногда ссылается на QuickFixLine
call s:Hi('QuickFixLine', '', '#e9e0ff', '')

" вертикальные линии структуры
call s:Hi('AerialGuide', s:fg4, '', '')

" уровни вложенности
hi! link AerialGuide1 AerialGuide
hi! link AerialGuide2 AerialGuide
hi! link AerialGuide3 AerialGuide
hi! link AerialGuide4 AerialGuide
hi! link AerialGuide5 AerialGuide
hi! link AerialGuide6 AerialGuide

" заголовок окна
call s:Hi('AerialTitle', s:keyword, '', 'bold')

" иконки символов
call s:Hi('AerialClassIcon',       s:type,    '', '')
call s:Hi('AerialFunctionIcon',    s:func,    '', '')
call s:Hi('AerialMethodIcon',      s:func,    '', '')
call s:Hi('AerialVariableIcon',    s:var,     '', '')
call s:Hi('AerialNamespaceIcon',   s:type,    '', '')
call s:Hi('AerialStructIcon',      s:type,    '', '')
call s:Hi('AerialInterfaceIcon',   s:type,    '', '')
call s:Hi('AerialEnumIcon',        s:type,    '', '')

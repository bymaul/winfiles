Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -MaximumHistoryCount 100000
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -ShowToolTips

Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Ctrl+z -Function Undo
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
Set-PSReadLineKeyHandler -Key Ctrl+Delete -Function DeleteWord

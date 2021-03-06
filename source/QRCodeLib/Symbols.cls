VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "Symbols"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
Option Explicit

Private m_items  As Collection

Private m_minVersion              As Long
Private m_maxVersion              As Long
Private m_ErrorCorrectionLevel    As ErrorCorrectionLevel
Private m_structuredAppendAllowed As Boolean
Private m_ByteModeCharsetName     As String

Private m_structuredAppendParity As Long

Private m_currSymbol As Symbol

Private m_encNum    As IQRCodeEncoder
Private m_encAlpha  As IQRCodeEncoder
Private m_encByte   As IQRCodeEncoder
Private m_encKanji  As IQRCodeEncoder

Private m_byteModeEncoding As TextEncoding

'------------------------------------------------------------------------------
' (概要)
'  オブジェクトを初期化します。
'------------------------------------------------------------------------------
Friend Sub Initialize(ByVal ecLevel As ErrorCorrectionLevel, _
                      ByVal maxVer As Long, _
                      ByVal allowStructuredAppend As Boolean, _
                      ByVal ByteModeCharsetName As String)
    
    If maxVer < Constants.MIN_VERSION Or _
       maxVer > Constants.MAX_VERSION Then
        Err.Raise 5
    End If

    Set m_items = New Collection
    
    Set m_encNum = QRCodeEncoderFactory.CreateEncoder( _
            EncodingMode.Numeric, ByteModeCharsetName)
    Set m_encAlpha = QRCodeEncoderFactory.CreateEncoder( _
            EncodingMode.ALPHA_NUMERIC, ByteModeCharsetName)
    Set m_encByte = QRCodeEncoderFactory.CreateEncoder( _
            EncodingMode.EIGHT_BIT_BYTE, ByteModeCharsetName)
    Set m_encKanji = QRCodeEncoderFactory.CreateEncoder( _
            EncodingMode.KANJI, ByteModeCharsetName)

    m_minVersion = 1
    m_maxVersion = maxVer
    m_ErrorCorrectionLevel = ecLevel
    m_structuredAppendAllowed = allowStructuredAppend
    m_ByteModeCharsetName = ByteModeCharsetName

    m_structuredAppendParity = 0
    
    Set m_byteModeEncoding = New TextEncoding
    Call m_byteModeEncoding.Init(ByteModeCharsetName)

    Set m_currSymbol = New Symbol
    Call m_currSymbol.Initialize(Me)
    Call m_items.Add(m_currSymbol)

End Sub

'------------------------------------------------------------------------------
' (概要)
'  指定したインデックス番号のシンボルを返します。
'  既定メンバとして [Attribute Item.VB_UserMemId = 0] が指定されています。
'------------------------------------------------------------------------------
Public Property Get Item(ByVal idx As Long) As Symbol
Attribute Item.VB_UserMemId = 0

    Set Item = m_items(idx + 1)

End Property

'------------------------------------------------------------------------------
' (概要)
'  シンボル数を取得します。
'------------------------------------------------------------------------------
Public Property Get Count() As Long
    
    Count = m_items.Count

End Property

'------------------------------------------------------------------------------
' (概要)
'  構造的連接モードの使用可否を表すブール値を取得します。
'------------------------------------------------------------------------------
Friend Property Get StructuredAppendAllowed() As Boolean
    
    StructuredAppendAllowed = m_structuredAppendAllowed

End Property

'------------------------------------------------------------------------------
' (概要)
'  構造的連接のパリティを取得します。
'------------------------------------------------------------------------------
Friend Property Get StructuredAppendParity() As Long
    
    StructuredAppendParity = m_structuredAppendParity

End Property

'------------------------------------------------------------------------------
' (概要)
'  型番の下限を取得または設定します。
'------------------------------------------------------------------------------
Friend Property Get MinVersion() As Long

    MinVersion = m_minVersion
    
End Property
Friend Property Let MinVersion(ByVal Value As Long)

    m_minVersion = Value
    
End Property

'------------------------------------------------------------------------------
' (概要)
'  型番の上限を取得します。
'------------------------------------------------------------------------------
Friend Property Get MaxVersion() As Long

    MaxVersion = m_maxVersion
    
End Property

'------------------------------------------------------------------------------
' (概要)
'  誤り訂正レベルを取得します。
'------------------------------------------------------------------------------
Friend Property Get ErrorCorrectionLevel() As ErrorCorrectionLevel

    ErrorCorrectionLevel = m_ErrorCorrectionLevel

End Property

'------------------------------------------------------------------------------
' (概要)
'  バイトモードの文字コードを取得します。
'------------------------------------------------------------------------------
Friend Property Get ByteModeCharset() As String
    
    ByteModeCharset = m_ByteModeCharsetName

End Property

'------------------------------------------------------------------------------
' (概要)
'  Collectionとして扱うために必要なコードです。
'  [Attribute NewEnum.VB_UserMemId = -4] が指定されています。
'------------------------------------------------------------------------------
Public Property Get NewEnum() As IUnknown
Attribute NewEnum.VB_UserMemId = -4
Attribute NewEnum.VB_MemberFlags = "40"
    
    Set NewEnum = m_items.[_NewEnum]

End Property

'------------------------------------------------------------------------------
' (概要)
'  シンボルを追加します。
'
' (戻り値)
'  追加したシンボルを表すオブジェクト
'------------------------------------------------------------------------------
Private Function Add() As Symbol
    
#If [Debug] Then
    Debug.Assert m_structuredAppendAllowed
    Debug.Assert m_items.Count < 16
#End If

    Set m_currSymbol = New Symbol
    Call m_currSymbol.Initialize(Me)
    Call m_items.Add(m_currSymbol)

    Set Add = m_currSymbol
    
End Function

'------------------------------------------------------------------------------
' (概要)
'  文字列を追加します。
'------------------------------------------------------------------------------
Public Sub AppendString(ByVal s As String)
    
    Dim oldMode As EncodingMode
    Dim newMode As EncodingMode
    Dim i       As Long

    If Len(s) = 0 Then Err.Raise 5
    
    For i = 1 To Len(s)
        oldMode = m_currSymbol.CurrentEncodingMode
    
        Select Case oldMode
            Case EncodingMode.UNKNOWN
                newMode = SelectInitialMode(s, i)
                
            Case EncodingMode.Numeric
                newMode = SelectModeWhileInNumericMode(s, i)
                
            Case EncodingMode.ALPHA_NUMERIC
                newMode = SelectModeWhileInAlphanumericMode(s, i)
                
            Case EncodingMode.EIGHT_BIT_BYTE
                newMode = SelectModeWhileInByteMode(s, i)
                
            Case EncodingMode.KANJI
                newMode = SelectInitialMode(s, i)
                
            Case Else
                Err.Raise 51
            
        End Select
    
        If newMode <> oldMode Then
            If Not m_currSymbol.TrySetEncodingMode(newMode, Mid$(s, i, 1)) Then
                If Not m_structuredAppendAllowed Or m_items.Count = 16 Then
                    Err.Raise 6
                End If

                Call Add
                newMode = SelectInitialMode(s, i)
                Call m_currSymbol.TrySetEncodingMode(newMode, Mid$(s, i, 1))
                
            End If
        End If
    
        If Not m_currSymbol.TryAppend(Mid$(s, i, 1)) Then
            If Not m_structuredAppendAllowed Or m_items.Count = 16 Then
                Err.Raise 6
            End If
            
            Call Add
            newMode = SelectInitialMode(s, i)
            Call m_currSymbol.TrySetEncodingMode(newMode, Mid$(s, i, 1))
            Call m_currSymbol.TryAppend(Mid$(s, i, 1))
            
        End If
    Next
    
End Sub

'------------------------------------------------------------------------------
' (概要)
'  構造的連接のパリティを更新します。
'------------------------------------------------------------------------------
Friend Sub UpdateParity(ByVal c As String)
    
#If [Debug] Then
    Debug.Assert Len(c) = 1
#End If

    Dim charBytes() As Byte
    charBytes = m_byteModeEncoding.GetBytes(c)

    Dim i As Long
    
    For i = 0 To UBound(charBytes)
        m_structuredAppendParity = m_structuredAppendParity Xor charBytes(i)
    Next

End Sub

'------------------------------------------------------------------------------
' (概要)
'  初期モードを決定します。
'
' (パラメータ)
'  s          : 対象文字列
'  startIndex : 評価を開始する位置
'------------------------------------------------------------------------------
Private Function SelectInitialMode( _
    ByRef s As String, ByVal startIndex As Long) As EncodingMode
    
    Dim cnt     As Long
    Dim flg     As Boolean
    Dim flg1    As Boolean
    Dim flg2    As Boolean
    Dim i       As Long
            
    If m_encKanji.IsInSubset(Mid$(s, startIndex, 1)) Then
        SelectInitialMode = EncodingMode.KANJI
        Exit Function

    ElseIf m_encByte.IsInExclusiveSubset(Mid$(s, startIndex, 1)) Then
        SelectInitialMode = EncodingMode.EIGHT_BIT_BYTE
        Exit Function
    
    ElseIf m_encAlpha.IsInExclusiveSubset(Mid$(s, startIndex, 1)) Then
        cnt = 0
        flg = False
        
        For i = startIndex To Len(s)
            If m_encAlpha.IsInExclusiveSubset(Mid$(s, i, 1)) Then
                cnt = cnt + 1
            Else
                Exit For
            End If
        Next

        Select Case m_currSymbol.Version
            Case 1 To 9
                flg = cnt < 6
                
            Case 10 To 26
                flg = cnt < 7
                
            Case 27 To 40
                flg = cnt < 8
                
            Case Else
                Err.Raise 51
            
        End Select
        
        If flg Then
            If (startIndex + cnt) <= Len(s) Then
                If m_encByte.IsInExclusiveSubset(Mid$(s, startIndex + cnt, 1)) Then
                    SelectInitialMode = EncodingMode.EIGHT_BIT_BYTE
                    Exit Function
                Else
                    SelectInitialMode = EncodingMode.ALPHA_NUMERIC
                    Exit Function
                End If
            Else
                SelectInitialMode = EncodingMode.ALPHA_NUMERIC
                Exit Function
            End If
        Else
            SelectInitialMode = EncodingMode.ALPHA_NUMERIC
            Exit Function
        End If

    ElseIf m_encNum.IsInSubset(Mid$(s, startIndex, 1)) Then
        cnt = 0
        flg1 = False
        flg2 = False
        
        For i = startIndex To Len(s)
            If m_encNum.IsInSubset(Mid$(s, i, 1)) Then
                cnt = cnt + 1
            Else
                Exit For
            End If
        Next
        
        Select Case m_currSymbol.Version
            Case 1 To 9
                flg1 = cnt < 4
                flg2 = cnt < 7
            
            Case 10 To 26
                flg1 = cnt < 4
                flg2 = cnt < 8
                
            Case 27 To 40
                flg1 = cnt < 5
                flg2 = cnt < 9
                
            Case Else
                Err.Raise 51
            
        End Select

        If flg1 Then
            If (startIndex + cnt) <= Len(s) Then
                flg1 = m_encByte.IsInExclusiveSubset(Mid$(s, startIndex + cnt, 1))
            Else
                flg1 = False
            End If
        End If

        If flg2 Then
            If (startIndex + cnt) <= Len(s) Then
                flg2 = m_encAlpha.IsInExclusiveSubset(Mid$(s, startIndex + cnt, 1))
            Else
                flg2 = False
            End If
        End If

        If flg1 Then
            SelectInitialMode = EncodingMode.EIGHT_BIT_BYTE
            Exit Function
        ElseIf flg2 Then
            SelectInitialMode = EncodingMode.ALPHA_NUMERIC
            Exit Function
        Else
            SelectInitialMode = EncodingMode.Numeric
            Exit Function
        End If
        
    Else
        Err.Raise 51
        
    End If

End Function

'------------------------------------------------------------------------------
' (概要)
'  数字モードから切り替えるモードを決定します。
'
' (パラメータ)
'  s          : 対象文字列
'  startIndex : 評価を開始する位置
'------------------------------------------------------------------------------
Private Function SelectModeWhileInNumericMode( _
    ByRef s As String, ByVal startIndex As Long) As EncodingMode
    
    If m_encKanji.IsInSubset(Mid$(s, startIndex, 1)) Then
        SelectModeWhileInNumericMode = EncodingMode.KANJI
        Exit Function
        
    ElseIf m_encByte.IsInExclusiveSubset(Mid$(s, startIndex, 1)) Then
        SelectModeWhileInNumericMode = EncodingMode.EIGHT_BIT_BYTE
        Exit Function
    
    ElseIf m_encAlpha.IsInExclusiveSubset(Mid$(s, startIndex, 1)) Then
        SelectModeWhileInNumericMode = EncodingMode.ALPHA_NUMERIC
        Exit Function
        
    End If
    
    SelectModeWhileInNumericMode = EncodingMode.Numeric

End Function

'------------------------------------------------------------------------------
' (概要)
'  英数字モードから切り替えるモードを決定します。
'
' (パラメータ)
'  s          : 対象文字列
'  startIndex : 評価を開始する位置
'------------------------------------------------------------------------------
Private Function SelectModeWhileInAlphanumericMode( _
    ByRef s As String, ByVal startIndex As Long) As EncodingMode
    
    Dim cnt As Long
    Dim flg As Boolean
    Dim i   As Long
    
    If m_encKanji.IsInSubset(Mid$(s, startIndex, 1)) Then
        SelectModeWhileInAlphanumericMode = EncodingMode.KANJI
        Exit Function
    
    ElseIf m_encByte.IsInExclusiveSubset(Mid$(s, startIndex, 1)) Then
        SelectModeWhileInAlphanumericMode = EncodingMode.EIGHT_BIT_BYTE
        Exit Function
        
    End If
    
    cnt = 0
    flg = False

    For i = startIndex To Len(s)
        If Not m_encAlpha.IsInSubset(Mid$(s, i, 1)) Then
            Exit For
        End If
        
        If m_encNum.IsInSubset(Mid$(s, i, 1)) Then
            cnt = cnt + 1
        Else
            flg = True
            Exit For
        End If
    Next
        
    If flg Then
        Select Case m_currSymbol.Version
            Case 1 To 9
                flg = cnt >= 13

            Case 10 To 26
                flg = cnt >= 15
                
            Case 27 To 40
                flg = cnt >= 17
                
            Case Else
                Err.Raise 51
            
        End Select

        If flg Then
            SelectModeWhileInAlphanumericMode = EncodingMode.Numeric
            Exit Function
        End If
    End If

    SelectModeWhileInAlphanumericMode = EncodingMode.ALPHA_NUMERIC

End Function

'------------------------------------------------------------------------------
' (概要)
'  バイトモードから切り替えるモードを決定します。
'
' (パラメータ)
'  s          : 対象文字列
'  startIndex : 評価を開始する位置
'------------------------------------------------------------------------------
Private Function SelectModeWhileInByteMode( _
    ByRef s As String, ByVal startIndex As Long) As EncodingMode
    
    Dim cnt     As Long
    Dim flg     As Boolean
    Dim i       As Long
    
    If m_encKanji.IsInSubset(Mid$(s, startIndex, 1)) Then
        SelectModeWhileInByteMode = EncodingMode.KANJI
        Exit Function
    End If

    For i = startIndex To Len(s)
        If Not m_encByte.IsInSubset(Mid$(s, i, 1)) Then
            Exit For
        End If
    
        If m_encNum.IsInSubset(Mid$(s, i, 1)) Then
            cnt = cnt + 1
            
        ElseIf m_encByte.IsInExclusiveSubset(Mid$(s, i, 1)) Then
            flg = True
            Exit For
            
        Else
            Exit For
            
        End If
    Next

    If flg Then
        Select Case m_currSymbol.Version
            Case 1 To 9
                flg = cnt >= 6
                
            Case 10 To 26
                flg = cnt >= 8
                
            Case 27 To 40
                flg = cnt >= 9
                
            Case Else
                Err.Raise 51
            
        End Select
        
        If flg Then
            SelectModeWhileInByteMode = EncodingMode.Numeric
            Exit Function
        End If
    End If

    cnt = 0
    flg = False

    For i = startIndex To Len(s)
        If Not m_encByte.IsInSubset(Mid$(s, i, 1)) Then
            Exit For
        End If
        
        If m_encAlpha.IsInExclusiveSubset(Mid$(s, i, 1)) Then
            cnt = cnt + 1
            
        ElseIf m_encByte.IsInExclusiveSubset(Mid$(s, i, 1)) Then
            flg = True
            Exit For
            
        Else
            Exit For
            
        End If
        
        i = i + 1
    Next

    If flg Then
        Select Case m_currSymbol.Version
            Case 1 To 9
                flg = cnt >= 11
                
            Case 10 To 26
                flg = cnt >= 15
                
            Case 27 To 40
                flg = cnt >= 16
                
            Case Else
                Err.Raise 51
            
        End Select

        If flg Then
            SelectModeWhileInByteMode = EncodingMode.ALPHA_NUMERIC
            Exit Function
            
        End If
        
    End If

    SelectModeWhileInByteMode = EncodingMode.EIGHT_BIT_BYTE
    
End Function


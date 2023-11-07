$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$csv_src = '.\output\Users.csv'


$csv = import-csv -Delimiter ',' -Path $csv_src

# Find the domain
$ntds_info = $csv | where { $_.Username -eq 'krbtgt' -and $_.Hash.ToUpper() -ne 'AAD3B435B51404EEAAD3B435B51404EE:31D6CFE0D16AE931B73C59D7E0C089C0' }

# If no domain found => STOP
if( $ntds_info -eq $null -or $ntds_info.Count -ne $null -or $ntds_info.Count -gt 1 ){
	Write-Host ("Found {0} domains" -f $ntds_info.Count)
	Write-Error 'Unable to filter on the domain ! Please send an issue to https://github.com/1mm0rt41PC/NtdsAudit'
	Exit 1
}

$domain = $ntds_info[0].Domain

# Filter to keep only the current domain and avoid trusted domains
$csv=$csv | where { $_.Domain -eq $domain } | foreach {
	if( $_.Password.StartsWith('$HEX[') ){
		$p=$_.Password.Substring(5,$_.Password.Length-6);
		$_.Password = for( $i=0; $i -lt $p.Length; $i+=2 ){ $k=[char][byte]("0x"+$p[$i]+$p[$i+1]); $k; }
		$_.Password = $_.Password -join ''
		$_.PasswordLen=$_.Password.Length
	}
	$_
}
$csv | Export-Csv -Delimiter ',' -Path $csv_src -NoTypeInformation

$nbAccount = $csv.Count
$activeAccount = $csv | where {$_.Disabled -eq $false -and $_.Expired -eq $false}
$nbActiveAccount = $activeAccount.Count
$nbDisabledUser = $nbAccount - ($csv | where {$_.Disabled -eq $false}).Count
$nbExpiredUser = $nbAccount -  ($csv | where {$_.Expired -eq $false}).Count

function parseDate($in){
	try {
		return [DateTime]::ParseExact($in, 'yyyy/MM/dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)	
	}catch {}
	try {
		return [DateTime]::ParseExact($in, 'dd.MM.yy HH:mm', [Globalization.CultureInfo]::InvariantCulture)	
	}catch {}
	try {
		return [DateTime]::ParseExact($in, 'dd.MM.yyyy HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)	
	}catch {}
	try {
		return [DateTime]::ParseExact($in, 'dd/MM/yyyy HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)	
	}catch {}
	try {
		return [DateTime]::ParseExact($in, 'yyyy.MM.dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)	
	}catch {}
	try {
		return [DateTime]::ParseExact($in, 'yy.MM.dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)	
	}catch {
		throw "Bad date format" 
	}
}
#
$1YearBefore = (get-date).AddYears(-1);
$Active_users_unused_in_1_year = ($activeAccount | where {(parseDate $_.'Last Logon') -lt $1YearBefore}).Count
#
$90DaysBefore = (get-date).AddDays(-90);
$Active_users_unused_in_90_days = ($activeAccount | where {(parseDate $_.'Last Logon') -lt $90DaysBefore}).Count

$Password_Never_Expires_ACTIVE = ($activeAccount | where {$_.'Password Never Expires' -eq $true}).Count

$Active_users_with_password_unchanged_in_1_year = ($activeAccount | where {(parseDate $_.'Password Last Changed') -lt $1YearBefore}).Count
$Active_users_with_password_unchanged_in_90_days = ($activeAccount | where {(parseDate $_.'Password Last Changed') -lt $90DaysBefore}).Count

$Active_users_with_Administrator_rights = ($activeAccount | where {$_.'Domain Admin' -eq $true -or $_.'Enterprise Admin' -eq $true -or $_.Administrator -eq $true}).Count
$Active_users_with_Domain_Admin_rights = ($activeAccount | where {$_.'Domain Admin' -eq $true}).Count
$Active_users_with_Enterprise_Admin_rights = ($activeAccount | where {$_.'Enterprise Admin' -eq $true}).Count

$Number_of_compromised_accounts = ($csv | where {$_.PasswordFound -eq $true}).Count
$Number_of_compromised_accounts_with_enabled_flag = ($activeAccount | where {$_.PasswordFound -eq $true}).Count

$Number_of_compromised_accounts_with_admin_privilege = ($csv | where {$_.PasswordFound -eq $true -and ($_.'Domain Admin' -eq $true -or $_.'Enterprise Admin' -eq $true -or $_.Administrator -eq $true)}).Count
$Number_of_compromised_accounts_enabled_and_admin = ($activeAccount | where {$_.PasswordFound -eq $true -and ($_.'Domain Admin' -eq $true -or $_.'Enterprise Admin' -eq $true -or $_.Administrator -eq $true)}).Count

$Active_users_which_do_not_require_a_password = ($activeAccount | where {$_.'Password Not Required' -eq $true}).Count


$excel = New-Object -ComObject excel.application
$excel.visible = $True
$workbook = $excel.Workbooks.Open("$(pwd)\Template_PasswordPolicy.xlsx")
$Statistics = $workbook.Worksheets['Statistics']

function percent( $xOf, $total ){
	if( [string]::IsNullOrEmpty($xOf+"") ){
		$xOf = 0;
	}
	return "$xOf of $total ($([math]::Round($xOf*100.0/$total,2))%)";
}

$i = 3
$Statistics.Range("B"+($i++)).Value2 = $nbAccount
$Statistics.Range("B"+($i++)).Value2 = "$(percent $nbActiveAccount $nbAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $nbDisabledUser $nbAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $nbExpiredUser $nbAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Active_users_unused_in_1_year $nbActiveAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Active_users_unused_in_90_days $nbActiveAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Active_users_which_do_not_require_a_password $nbActiveAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Password_Never_Expires_ACTIVE $nbActiveAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Active_users_with_password_unchanged_in_1_year $nbActiveAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Active_users_with_password_unchanged_in_90_days $nbActiveAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Active_users_with_Administrator_rights $nbActiveAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Active_users_with_Domain_Admin_rights $nbActiveAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Active_users_with_Enterprise_Admin_rights $nbActiveAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Number_of_compromised_accounts $nbAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Number_of_compromised_accounts_with_enabled_flag $nbActiveAccount)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Number_of_compromised_accounts_with_admin_privilege ($csv | where {$_.'Domain Admin' -eq $true -or $_.'Enterprise Admin' -eq $true -or $_.Administrator -eq $true}).Count)"
$Statistics.Range("B"+($i++)).Value2 = "$(percent $Number_of_compromised_accounts_enabled_and_admin $Active_users_with_Domain_Admin_rights)"

if( $Statistics.ListObjects("PasswordLenStats").DataBodyRange.Rows.Count -gt 0 ){
	$Statistics.ListObjects("PasswordLenStats").DataBodyRange.Rows.Delete()
}
$i=3
$csv | Group-Object PasswordLen | Sort-Object { [int]$_.Name } | Select-Object Name, Count | where {$_.Name -ne -1} | foreach {
	$Statistics.Range("D"+($i)).Value = ("Password with a length of $($_.Name)")
	$Statistics.Range("E"+($i)).Value2 = $_.Count
	$i++
}


Write-Progress -Activity "Updating >Password reuse<" -PercentComplete 1
$PasswordReuse = $workbook.Worksheets['Password reuse']
$csv = import-csv -Delimiter ',' -Path $csv_src
$csv | ForEach-Object { $tmp=$_.Hash; try{$_.Hash = $_.Hash.Split(":")[1];}catch{$_.Hash=$tmp;} }
$i=2
if( $PasswordReuse.ListObjects("user_PasswordReuse").DataBodyRange.Rows.Count -gt 0 ){
	$PasswordReuse.ListObjects("user_PasswordReuse").DataBodyRange.Rows.Delete()
}
$csv | Group-Object Hash,Password | Sort-Object -Descending Count | Select-Object Name, Count | where { $_.Count -gt 1 } | foreach {
	$tmp = $_.Name -split ", "
	$PasswordReuse.Range("A"+$i).Value = "$($tmp[0])";
	$PasswordReuse.Range("B"+$i).Value = "$($tmp[1])";
	$PasswordReuse.Range("C"+$i).Value2 = $_.Count;
	$i++;
}
Write-Progress -Activity "Updating >Password reuse<" -Completed


$csv = import-csv -Delimiter ',' -Path $csv_src
$UsersDetails = $workbook.Worksheets["User's details"]
$UsersDetails.ListObjects("Users").DataBodyRange.Rows.Delete();
$UsersDetails.Application.ScreenUpdating = $false
$iRow=2
$nbRows = $csv.Count
$csv | Sort-Object @{e={$_.Sid.Substring($_.Sid.LastIndexOf('-')+1) -as [int]}} | foreach {
    Write-Progress -Activity "Updating >User's details<" -PercentComplete ($iRow*100.0/$nbRows)
	$iCol=1
	$row=$_
	$_.psobject.Properties | foreach {
		$tmp = $row."$($_.Name)"
		try {
			$tmp = [DateTime]::ParseExact($tmp, 'dd.MM.yy HH:mm', [Globalization.CultureInfo]::InvariantCulture)	
		}catch {
			try {
				$tmp = [DateTime]::ParseExact($tmp, 'dd/MM/yyyy HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)	
			}catch{
			
			}
		}
		$UsersDetails.Cells.Item($iRow,$iCol).Value = "$tmp";
		$iCol++
	}
	$iRow++;
}
$UsersDetails.Application.ScreenUpdating = $true
Write-Progress -Activity "Updating >User's details<" -Completed

$workbook.SaveAs((pwd).Path+"\output\"+$domain+"_PasswordPolicy.xlsx")
$workbook.Application.Quit();

#Sub Macro1()
#'
#' Macro1 Macro
#'
#
#'
#    ActiveWorkbook.Queries.Add Name:="Users", Formula:= _
#        "let" & Chr(13) & "" & Chr(10) & "    Source = Csv.Document(File.Contents(""C:\Users\1mm0rt41\Tools\binary-NtdsAudit-v2.0.6\output\Users.csv""),[Delimiter="","", Columns=20, Encoding=65001, QuoteStyle=QuoteStyle.None])," & Chr(13) & "" & Chr(10) & "    #""En-têtes promus"" = Table.PromoteHeaders(Source, [PromoteAllScalars=true])," & Chr(13) & "" & Chr(10) & "    #""Type modifié"" = Table.TransformColumnTypes(#""En-têtes promus"",{{""Sid"", type text" & _
#        "}, {""Domain"", type text}, {""Username"", type text}, {""PasswordFound"", type logical}, {""IsAdminWithLowPassword"", type logical}, {""isAdminInAnyGroup"", type logical}, {""Administrator"", type logical}, {""Domain Admin"", type logical}, {""Enterprise Admin"", type logical}, {""Disabled"", type logical}, {""Expired"", type logical}, {""Password Never Expires"", " & _
#        "type logical}, {""Password Not Required"", type logical}, {""Password Last Changed"", type datetime}, {""Last Logon"", type datetime}, {""Hash"", type text}, {""Password"", type text}, {""PasswordLen"", Int64.Type}, {""MemberOf"", type text}, {""Count in group"", Int64.Type}})" & Chr(13) & "" & Chr(10) & "in" & Chr(13) & "" & Chr(10) & "    #""Type modifié"""
#    ActiveWorkbook.Worksheets.Add
#    With ActiveSheet.ListObjects.Add(SourceType:=0, Source:= _
#        "OLEDB;Provider=Microsoft.Mashup.OleDb.1;Data Source=$Workbook$;Location=Users;Extended Properties=""""" _
#        , Destination:=Range("$A$1")).QueryTable
#        .CommandType = xlCmdSql
#        .CommandText = Array("SELECT * FROM [Users]")
#        .RowNumbers = False
#        .FillAdjacentFormulas = False
#        .PreserveFormatting = True
#        .RefreshOnFileOpen = False
#        .BackgroundQuery = True
#        .RefreshStyle = xlInsertDeleteCells
#        .SavePassword = False
#        .SaveData = True
#        .AdjustColumnWidth = True
#        .RefreshPeriod = 0
#        .PreserveColumnInfo = True
#        .ListObject.DisplayName = "Users_2"
#        .Refresh BackgroundQuery:=False
#    End With
#    Application.CommandBars("Queries and Connections").Visible = False
#    Columns("D:I").FormatConditions.Add Type:=xlTextString, String:="VRAI", _
#        TextOperator:=xlContains
#    With Columns("D:I").FormatConditions(1).Font
#        .Bold = True
#        .Italic = False
#        .ThemeColor = xlThemeColorDark1
#        .TintAndShade = 0
#    End With
#    With Selection.FormatConditions(1).Interior
#        .PatternColorIndex = xlAutomatic
#        .Color = 192
#        .TintAndShade = 0
#    End With
#    Selection.FormatConditions(1).StopIfTrue = False
#End Sub
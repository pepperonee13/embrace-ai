$sourcePath = "\\sander\moers\Team_Gruen\CI_Warnings\"
$warningJsonsPath = "./BuildWarningAnalyzer-Vue/public/warningsDB"
$reportPath = "./BuildWarningAnalyzer-Vue/public"

.\Parse-WarningFolder.ps1 -InputRoot $sourcePath -OutputRoot $warningJsonsPath
.\Build-Index.ps1 -InputRoot $warningJsonsPath -OutputRoot $reportPath
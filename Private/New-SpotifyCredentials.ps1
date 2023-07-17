
$location = "$env:temp\musicMachine"

mkdir $location -errorAction Ignore

$clientID = Read-host "Please enter your clientID" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | out-file $location\a1.tfc
$clientSecret = Read-Host "Please enter your client secret" -AsSecureString |  ConvertFrom-SecureString | out-file $location\a2.tfc
$userID = Read-Host "Please enter your user ID" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | out-file $location\a3.tfc

Write-Host "Now I am going to launch a browser window. If you have not already logged into Spotify on this machine then you will need to log in."`n -ForegroundColor Yellow
Write-Host "The browser will redirect to a localhost page to confirm that the credentials are correct - once I'm done then you can close that browser window."`n -ForegroundColor Yellow
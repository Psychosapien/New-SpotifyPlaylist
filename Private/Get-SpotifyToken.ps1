function Get-SpotifyToken {
    [CmdletBinding()]
    param (

    )
    
    begin {
        # Get Initial Token
        $location = "$env:temp\musicMachine"

        $clientId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-Content $location\a1.tfc | ConvertTo-SecureString)))
        $clientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-Content $location\a2.tfc | ConvertTo-SecureString)))

        $url = "https://accounts.spotify.com/api/token"
        $contentType = "application/x-www-form-urlencoded"
        $body = "grant_type=client_credentials&client_id=$($clientId)&client_secret=$($clientSecret)"
        $token = Invoke-WebRequest -Uri $url -Method Post -Body $body -ContentType $contentType
        $headers = @{}
        $headers.Add("Authorization", "Bearer $(($token.Content | ConvertFrom-Json).access_token)")
        
        # Now we make sure the token is authorized to make a playlist
        $redirectUri = "http://localhost:3000"
        $scope = "playlist-modify-private%20ugc-image-upload"
        
        # Step 1: Construct the authorization URL
        $authorizationUrl = "https://accounts.spotify.com/authorize?client_id=$($clientId)&response_type=code&redirect_uri=$redirectUri&scope=$scope"
        
        $redirectUriCheck = "http://localhost:3000/"  # Replace with your redirect URI
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add($redirectUriCheck)
        $listener.Start()

        # Open the page in a browser
        $window = Start-Process -FilePath msedge -ArgumentList "--new-window $authorizationUrl"
        write-host "Opening up a browser window for auth, please don't close it just yet!" -foregroundColor Yellow

        $progressPreference = 'SilentlyContinue'  # Suppresses verbose output from Write-Progress
        
        $seconds = 10
        
        for ($i = 1; $i -le $seconds; $i++) {
            Write-Progress -Activity "Please Wait" -Status "Processing..." -PercentComplete (($i / $seconds) * 100)
            Start-Sleep -Seconds 1
        }
        
        # Clear the progress bar once the loop is finished
        Write-Progress -Activity "Please Wait" -Completed        

        # Wait for the redirect
        $context = $listener.GetContext()

        $request = $context.Request
        $queryParams = $request.Url.Query

        # Extract the redirected URL and close the listener
        $redirectedUrl = $request.Url.AbsoluteUri
        $listener.Stop()
        $listener.Close()

        # Extract the authorization code from the redirected URL
        $authorizationCode = [System.Web.HttpUtility]::ParseQueryString($queryParams)["code"]
        
        write-host "Code aquired, you may now close that browser window" -foregroundColor Green

        # Step 4: Wait for the user to grant permission and obtain the authorization code from the redirect URI
        #$authorizationCode = Read-Host "Please enter code from url because I'm not clever enough to get it myself..."
        
        # Step 5: Exchange the authorization code for an access token and refresh token
        $tokenUrl = "https://accounts.spotify.com/api/token"
        $grantType = "authorization_code"
        
        $tokenParams = @{
            client_id     = $clientId
            client_secret = $clientSecret
            redirect_uri  = $redirectUri
            code          = $authorizationCode
            grant_type    = $grantType
        }
        
        $tokenResponse = Invoke-WebRequest -Uri $tokenUrl -Method Post -Body $tokenParams
        
        # Step 6: Extract the access token from the response
        $accessToken = ($tokenResponse.Content | ConvertFrom-Json).access_token
        
    }
    
    process {
        
    }
    
    end {
        Write-Output $accessToken
    }
}


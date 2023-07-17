function New-SpotifyPlaylist {
    [CmdletBinding()]
    param (
        [string]$playlistName,
        [string]$playlistDescription,
        [switch]$randomCoverImage,
        [string[]]$genres,
        [string[]]$genreSearch,
        [int]$songCount
    )

    begin {

        $ErrorActionPreference = "Stop"

        $location = "$env:appdata\Local\MusicMachine"
        $test1 = Get-ChildItem -Path $location\a1.tfc -ErrorAction Ignore
        $test2 = Get-ChildItem -Path $location\a2.tfc -ErrorAction Ignore
        $test3 = Get-ChildItem -Path $location\a3.tfc -ErrorAction Ignore

        if (!$test1 -or !$test2 -or !$test3) {
            Write-host "We need to set up your login info, please enter the information requested below..." -ForegroundColor Yellow
            Write-host "If you haven't already, please go to https://developer.spotify.com/documentation/web-api and set up an app to retrieve your access tokens." -ForegroundColor Yellow
            Write-host "You can get your User ID by logging into the Spotify website and looking at your profile page." -ForegroundColor Yellow

            .$PSScriptRoot\Private\New-SpotifyCredentials.ps1
        }

        if ($env:SpotifyToken -and $env:SpotifyTokenTime -gt (Get-Date).AddHours(-1)) {
            Write-Host "You already seem to have a valid token, commencing with the script..." -ForegroundColor Green

            $accessToken = $env:SpotifyToken

        } else {
            . $PSScriptRoot\Private\Get-SpotifyToken.ps1

            $accessToken = Get-SpotifyToken
            $timeNow = Get-Date

            $env:SpotifyToken = $accessToken
            $env:SpotifyTokenTime = $timeNow    
        }
    
        $location = "$env:temp\musicMachine"
        $userId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-Content $location\a3.tfc |  ConvertTo-SecureString)))

        if (!$genres) {
            $genres = @()
        }

        $songsUsed = @()

    }

    process {
        # Now for the fun bit - making the playlist
        $url = "https://api.spotify.com/v1/users/$($userId)/playlists"

        $body = "{
                    `"name`": `"$($playlistName)`",
                    `"description`": `"$($playlistDescription)`",
                    `"public`": false
                }"

        $headers = @{
            'Authorization' = "Bearer $accessToken"
            'Content-Type'  = 'application/json'
        }

        $createPlaylist = Invoke-WebRequest -Uri $url -Method Post -Body $body -Headers $headers
        $playlistID = ($createPlaylist.content | ConvertFrom-Json).id

        # List Genres
        $genreList = Get-Content $PSScriptRoot\Public\genreList.txt

        if ($genreSearch) {

            foreach ($genre in $genreSearch -split ",") {

                if (($genreList | Where-Object { $_ -like "*$($genre)*" }).count -ge 2 -and ($genreList | Where-Object { $_ -like "*$($genre)*" }).count -ge 1 ) {
                    if (($genreList | Where-Object { $_ -like "*$($genre)*" })) {

                        $chosenGenre = $genreList | Where-Object { $_ -like "*$($genre)*" } | Out-GridView -Title "Here are the genres I've found, choose which ones you want" -OutputMode Multiple

                        $genres += $chosenGenre    
                    }
                    else {
                        Write-Host "Couldn't find anything matching $($genre)! moving on to the next one"
                    }
                }
                else {
                    $genres += ($genreList | Where-Object { $_ -like "*$($genre)*" })

                    Write-Host "Only found 1 match to the genre $genre - $($genreList | Where-Object { $_ -like "*$($genre)*" }), so I have added that one for you." -ForegroundColor Yellow
                }
            }
        }

        if ($genres.count -lt 1) {

            $chosenGenres = $genreList | Out-GridView -Title "Select wich genre(s) you would like to add" -OutputMode Multiple

            $fixedGenres = @()
            foreach ($genre in $chosenGenres) {
                $fixedGenres += '%22' + [uri]::EscapeDataString($genre) + '%22'
            }
        }
        else {
            $fixedGenres = @()
            foreach ($genre in $genres -split ",") {
                $fixedGenres += '%22' + [uri]::EscapeDataString($genre) + '%22'
            }
        }

        $chosenGenres = $fixedGenres

        for ($i = 0; $i -lt $songCount; $i++) {

            try {

                $offset = Get-Random -minimum 0 -maximum 50
                $updatePlaylist = ""
                $songExists = ""
                $genreExists = ""

                if ($chosenGenres.Count -gt 1) {
                    $chosenGenre = Get-random $chosenGenres
                }
                else {
                    $chosenGenre = $chosenGenres
                }

                $genreFinder = "https://api.spotify.com/v1/search?q=genre%3A$($chosenGenre)&type=track&limit=50&offset=$($offset)"
                $genreExists = ((Invoke-WebRequest -Uri $genreFinder -Headers $headers).Content | ConvertFrom-Json).tracks.items

                if (!$genreExists) {

                    $genreFinder = "https://api.spotify.com/v1/search?q=genre%3A$($chosenGenre)&type=track&limit=50"
                    $genreExists = ((Invoke-WebRequest -Uri $genreFinder -Headers $headers).Content | ConvertFrom-Json).tracks.items

                    if (!$genreExists) {

                        Write-Host "I can't find any songs for the genre $($chosenGenre -replace "%20", " " -replace "%22",'')!" -ForegroundColor Red

                        if ($chosenGenres.Count -ge 2) {
                            $newGenres = @()
                            foreach ($genre in $chosenGenres) {
                                if ($genre -ne $chosenGenre) {
                                    $newGenres += $genre
                                }
                            }

                            $chosenGenres = $newGenres

                            throw "moving on to the next song and removing this genre from the list"
                        }
                        else {
                            Write-Host "Oh snap, there's only 1 genre to search and I can't find anything. I am going to exit now, the playlist will remain in place so you need to delete it mnanually" -ForegroundColor Red
                            throw ""
                        }
                    }
                }

                $url = "https://api.spotify.com/v1/playlists/$playlistID/tracks"
                $songExists = Get-Random $genreExists

                if ($songsUsed -contains $songExists) {
                    do {
                        $songExists = Get-Random $genreExists
                    } until (
                        $songsUsed -notcontains $songExists
                    )
                }
                $body = '{
                            "uris": [
                                "' + $songExists.uri + '"
                            ],
                            "position": 0
                        }'    

                Write-Host "adding $($songExists.name) by $($songExists.album.artists.name) to playlist - Genre is $($chosenGenre -replace "%20", " " -replace "%22", '')" -ForegroundColor Cyan
                $updatePlaylist = Invoke-WebRequest -Uri $url -Method Post -Body $body -Headers $headers -SkipHttpErrorCheck -ErrorAction SilentlyContinue
                
                if ($updatePlaylist.StatusCode -ne "201") {
                    $i--
                }

                $songsUsed += $songExists
            }
            catch {

                if ($chosenGenres.Count -ge 1) {
                    Continue
                }
                else {

                }
            }
        }
    }

    end {

        if ($randomCoverImage) {

            # Get a random image
            Write-host "Generating image, this takes a moment so please be patient...`n" -foregroundcolor yellow
            $Header = @{ Authorization = "563492ad6f917000010000019142f114c9664f5aaf3a03c69726add5" }
            $PageNum = get-random -Minimum 1 -Maximum ((Invoke-WebRequest -Uri "https://api.pexels.com/v1/search?query=nature&orientation=square&per_page=1" -Headers $Header).Content | convertfrom-json).Total_results
            $Url = ((Invoke-WebRequest -Uri "https://api.pexels.com/v1/search?query=nature&orientation=square&per_page=1&page=$($PageNum)" -Headers $Header).Content | Convertfrom-Json).photos.id
            $getImage = Invoke-WebRequest -Uri "https://api.pexels.com/v1/photos/$Url" -Headers $Header
            $ImageURL = ($getImage.Content | ConvertFrom-Json).src.large
            $filename = "$($env:appdata)\temp.jpeg"
            Invoke-WebRequest $ImageURL -OutFile $filename

            # Set vars for uploading to playlist
            $url = "https://api.spotify.com/v1/playlists/$playlistID/images"
            $headers = @{
                'Authorization' = "Bearer $accessToken"
                'Content-Type'  = 'image/jpeg'
            }

            $base64 = [convert]::ToBase64String((Get-Content $filename -AsByteStream))
            $imageUpload = Invoke-WebRequest -Uri $url -Headers $headers -Body $base64 -Method Put
            remove-item $filename
        }
    }
}
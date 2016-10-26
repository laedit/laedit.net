C:\tools\Pretzel\pretzel bake src

if ($lastExitCode -eq 0)
{
    Write-Host "Starting deploy"
    $env:Path += ";C:\\Python35;C:\\Python35\\Scripts"
    $envConf = "{{`"`"default`"`": {{`"`"connection`"`": `"`"ftp://{0}:{1}@laedit.net`"`"}}}}" -f $env:ftp_user, $env:ftp_password
    creep -e $envConf -d "{`"`"source`"`": `"`"hash`"`"}" -b src/_site -y
}

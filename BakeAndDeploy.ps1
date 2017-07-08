C:\ProgramData\chocolatey\bin\pretzel bake src

if ($lastExitCode -ne 0)
{
    exit -1
}
else
{
    Write-Host "Starting deploy"
    $envConf = '{{""default"": {{""connection"": ""ftp://{0}:{1}@laedit.net""}}}}' -f $env:ftp_user, $env:ftp_password
    creep -e $envConf -d '{""source"": ""hash""}' -b src/_site -y

    if ($lastExitCode -ne 0)
    {
        exit -1
    }
}

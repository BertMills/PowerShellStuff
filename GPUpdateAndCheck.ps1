########################
# GPUpdateAndCheck.ps1
# by Bert Mills
# 4/6/2023
# Runs GP Update, ensures policy is successfully applied, and cleans up GroupPolicy folders before trying again if it fails.
# Licensed under MIT license
########################


$gpoutput = & gpupdate /force
if (($gpoutput -match "Computer Policy update has completed successfully") -and ($gpoutput -match "User Policy update has completed successfully")) {
    write-host "Complete"
}
else {
    Write-Host "GPUpdate failed.  Cleaning Group Policy folders."
    Remove-Item -Path $env:SystemRoot\System32\GroupPolicy\Machine -Force
    Remove-Item -Path $env:SystemRoot\System32\GroupPolicy\User -Force
    Write-Host "Rerunning GPUpdate"
    $gpoutput2 = & gpupdate /force
    if (($gpoutput2 -match "Computer Policy update has completed successfully") -and ($gpoutput2 -match "User Policy update has completed successfully")) {
        Write-Host "GPUpdate successful" 
    }
    else {
        Write-Host "GPUpdate failed again.  Try manually running."
    }
}

# Check if OpenSSL is installed
try {
    $opensslVersion = openssl version
    Write-Host "OpenSSL version is $opensslVersion"
    $env:Path += ";C:\Program Files\OpenSSL-Win64\bin"
}
catch {
    Write-Host "OpenSSL is not installed. Installing OpenSSL SLProWeb.com"
    $url = "https://slproweb.com/download/Win64OpenSSL_Light-3_1_2.exe"
    $output = "C:\Users\$env:USERNAME\Downloads\OpenSSL.exe"
    Invoke-WebRequest -Uri $url -OutFile $output
    Start-Process -FilePath $output -ArgumentList "/silent" -Wait
    $env:Path += ";C:\Program Files\OpenSSL-Win64\bin"
}

function CreateCNFTemplate {
    # Specify the file path
    $filePath = Join-Path -Path $PSScriptRoot -ChildPath "cnftemplate.cnf"
    if (Test-Path $filePath -PathType Leaf) {
        #Write-Host "The CNF template file exists."
    }
    else {
        #manually create template
        Add-Content -Path $filePath -Value "[ req ] `ndistinguished_name = req_distinguished_name `nextensions = v3_ca `nreq_extensions = v3_ca `nprompt = no `n[ v3_ca ] `nbasicConstraints = CA:TRUE `n[ req_distinguished_name ] `ncountryName = s1 `nstateOrProvinceName = s2 `norganizationName = s3 `ncommonName = s4"
    }
}

############# create certificate
function CreateCerts {
    $CommonName = Read-Host "Enter Root certificate name, [Root.com]"
    if ($CommonName -match "^\s*$") { $CommonName = "Root.com" }

    $countryName = Read-Host "Enter the Country, [US]"
    if ($countryName -match "^\s*$") { $countryName = "US" }

    $stateOrProvinceName = Read-Host "Enter the State or Providence, [TX]"
    if ($stateOrProvinceName -match "^\s*$") { $stateOrProvinceName = "TX" }

    $organizationName = Read-Host "Enter the Orginization Name, [SelfSigned]"
    if ($organizationName -match "^\s*$") { $organizationName = "SelfSigned" }

    $RootCertPassword = Read-Host "Enter Root Private Key password"
    $RootCertPassword = "pass:" + $RootCertPassword

    $CertDays = Read-Host "Enter days the certificate is valid for [365]"
    if ($CertDays -match "^\s*$") { $CertDays = 365 }

    #create Root.cnf
    $FN = "Root.cnf"
    CreateCNF -s1 $countryName -s2 $stateOrProvinceName -s3 $organizationName -s4 $CommonName -FN $FN

    #creates Root.key private certificate (private key)
    openssl ecparam -out Root.key -name prime256v1 -genkey

    #creates Root.csr certificate signing request (CSR) with the Root.key private certificate
    openssl req -new -sha256 -key Root.key -out Root.csr -config Root.cnf

    #creates Root.cer certificate from Root.csr, Root.key, Root.cnf
    openssl x509 -req -sha256 -days $CertDays -in Root.csr -signkey Root.key -out Root.cer -extfile $FN -extensions v3_ca -passin $RootCertPassword

    #create Leaf.key private certificate (private key)
    openssl ecparam -out Leaf.key -name prime256v1 -genkey

    $CommonName = ""
    $CommonName = Read-Host "Enter Site/Leaf/Server certificate name, Leaf.com"
    if ($CommonName -match "^\s*$") { $CommonName = "Leaf.com" }

    $LeafCertPassword = Read-Host "Enter Leaf Private Key password"
    $LeafCertPassword = "pass:" + $LeafCertPassword

    #create Leaf.cnf
    $FN = "Leaf.cnf"
    CreateCNF -s1 $countryName -s2 $stateOrProvinceName -s3 $organizationName -s4 $CommonName -FN $FN

    #ask for SANs, add the CN/general name to SAN list
    $SAN = Read-Host "Enter the SANs for the certificate, []"
    $SAN = $SAN.ToLower()

    if ($SAN -match "^\s*$") {
        #no SAN entered :(
        $SAN = "DNS:" + $CommonName.ToLower()
    } #could ignore SANs if not entered
    else {
        #add 'DNS:' to the list
        $SAN = ($SAN -split ',') -join ',DNS:'
        $SAN = 'DNS:' + $SAN  # Add 'DNS:' to the beginning
        #Write-Host "Multiple SANS "
    }
    
    $s0 = "DNS:" + $CommonName.ToLower()
    # Check if the common name is in the SAN list
    if ($SAN.contains($s0)) {
        
    }  
    else {
        # Add the common name to the end of the SAN list
        $SAN = $SAN + ",DNS:" + $CommonName.ToLower()
        Write-Host "`nHad to add the common name to the SAN list`n" #$elements
    }

    Write-Host "Subjnect Alternative Name List:`n"$SAN"`n"
    
    #create the V3 extenstion file with SANS
    CreateV3 -s1 $SAN

    #create Leaf.csr certificate signing request (CSR) with the Leaf.key private certificate
    openssl req -new -sha256 -key Leaf.key -out Leaf.csr -config Leaf.cnf

    #create Leaf.cer certificate from Root.cer Root.key, and create a .srl file (serial file)
    $FN = "v3.txt"
    openssl x509 -req -in Leaf.csr -CA Root.cer -CAkey Root.key -CAcreateserial -out Leaf.cer -days 365 -sha256 -extfile $FN -passin $LeafCertPassword

    #export the Leaf as a PFX with the Key and bundled Root.cer and Leaf.cer
    openssl pkcs12 -export -out FullCertChain.pfx -inkey Leaf.key -in Leaf.cer
}

############# modify the CNF files
function CreateCNF {
    param (
        [string]$s1,
        [string]$s2,
        [string]$s3,
        [string]$s4,
        [string]$FN
    )
    CreateCNFTemplate
    #$PSScriptRoot is a built-in variable that represents the directory where the script is located.
    #create a CNF from template cnf file
    $filePath = Join-Path -Path $PSScriptRoot -ChildPath "cnftemplate.cnf"
    $content = Get-Content -Path $filePath

    # Modify the content as needed
    $modifiedContent = $content -replace "s1", $s1
    $modifiedContent = $modifiedContent -replace "s2", $s2
    $modifiedContent = $modifiedContent -replace "s3", $s3
    $modifiedContent = $modifiedContent -replace "s4", $s4
    #Write-Host "filepath "$filepath
    #Write-Host "filename "$FN
    $filePath = Join-Path -Path $PSScriptRoot -ChildPath $FN
    $modifiedContent | Set-Content -Path $filePath

    #remove lines 3 and 4 from the template for the leaf CNF
    if ($FN -eq "Leaf.cnf") {
        $lines = Get-Content -Path $filePath

        # Remove lines at indices 2 and 3 (0-based indices, so lines 3 and 4)
        $lines = $lines | Where-Object { $_ -notin @($lines[2], $lines[3]) }

        # Write the modified content back to the file
        $lines | Set-Content -Path $filePath
    }
}

function PSNativeCert {
    $CommonName = Read-Host "Enter Root certificate name, [Root.com]"
    if ($CommonName -match "^\s*$") { $CommonName = "CN=Root.com" }
    $CommonName = 'CN=' + $CommonName
    # $countryName = Read-Host "Enter the Country, [US]"
    # if ($countryName -match "^\s*$") { $countryName = "US" }

    # $stateOrProvinceName = Read-Host "Enter the State or Providence, [TX]"
    # if ($stateOrProvinceName -match "^\s*$") { $stateOrProvinceName = "TX" }

    # $organizationName = Read-Host "Enter the Orginization Name, [SelfSigned]"
    # if ($organizationName -match "^\s*$") { $organizationName = "SelfSigned" }

    # $RootCertPassword = Read-Host "Enter Root Private Key password"
    # $RootCertPassword = "pass:" + $RootCertPassword

    # $CertDays = Read-Host "Enter days the certificate is valid for [365]"
    #if ($CertDays -match "^\s*$") { $CertDays = 365 }

    $par = [PSCustomObject]@{
        Type              = 'Custom'
        Subject           = $CommonName
        KeySpec           = 'Signature'
        KeyExportPolicy   = 'Exportable'
        KeyUsage          = 'CertSign'
        KeyUsageProperty  = 'Sign'
        KeyLength         = 2048
        HashAlgorithm     = 'sha256'
        NotAfter          = (Get-Date).AddMonths(24)
        CertStoreLocation = 'Cert:\CurrentUser\My'
    }

    $cert = New-SelfSignedCertificate @par

    $CommonName = ""
    $CommonName = Read-Host "Enter Site/Leaf/Server certificate name, Leaf.com"
    if ($CommonName -match "^\s*$") { $CommonName = "CN=Leaf.com" }
    $CommonName = 'CN=' + $CommonName

    #ask for SANs, add the CN/general name to SAN list
    $SAN = Read-Host "Enter the SANs for the certificate, []"
    $SAN = $SAN.ToLower()

    if ($SAN -match "^\s*$") {
        #no SAN entered :(
        $SAN = "DNS:" + $CommonName.ToLower()
    } #could ignore SANs if not entered
    else {
        #add 'DNS:' to the list
        $SAN = ($SAN -split ',') -join ',DNS:'
        $SAN = 'DNS:' + $SAN  # Add 'DNS:' to the beginning
        #Write-Host "Multiple SANS "
    }
    
    $s0 = "DNS:" + $CommonName.ToLower()
    # Check if the common name is in the SAN list
    if ($SAN.contains($s0)) {
        
    }  
    else {
        # Add the common name to the end of the SAN list
        $SAN = $SAN + ",DNS:" + $CommonName.ToLower()
        Write-Host "`nHad to add the common name to the SAN list`n" #$elements
    }

    Write-Host "Subjnect Alternative Name List:`n"$SAN"`n"
    $par = [PSCustomObject]@{
        Type              = 'Custom'
        Subject           = $CommonName
        DnsName           = $SAN
        KeySpec           = 'Signature'
        KeyExportPolicy   = 'Exportable'
        KeyLength         = 2048
        HashAlgorithm     = 'sha256'
        NotAfter          = (Get-Date).AddMonths(18)
        CertStoreLocation = 'Cert:\CurrentUser\My'
        Signer            = $cert
        TextExtension     = @(
            '2.5.29.37={text}1.3.6.1.5.5.7.3.2')
    }
    New-SelfSignedCertificate @par
}

function InstallCert {
    # Specify the path to the PFX file and the password
    $pfxPath = "C:\Path\to\YourCertificate.pfx"
    $pfxPassword = ConvertTo-SecureString -String "YourPfxPassword" -Force -AsPlainText

    # Import the PFX certificate into the LocalMachine certificate store
    Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\LocalMachine\My -Password $pfxPassword

}

function CreateV3 {
    param (
        [string]$s1
    )
    # Specify the file path
    $filePath = Join-Path -Path $PSScriptRoot -ChildPath "v3.txt"

    # Content to be written to the file
    $content = "subjectAltName = " + $s1
    $content | Set-Content -Path $filePath

    #add the last line
    Add-Content -Path $filePath -Value "extendedKeyUsage = serverAuth, clientAuth"
}

function Get-OpenSSL {
    try {	
        # Download and install OpenSSL
        Invoke-WebRequest -Uri "https://slproweb.com/download/Win64OpenSSL_Light-3_1_2.exe" -OutFile "C:\Users\$env:USERNAME\Downloads\OpenSSL.exe"
        Start-Process -FilePath "C:\Users\$env:USERNAME\Downloads\OpenSSL.exe" -Wait
        $env:Path += ";C:\Program Files\OpenSSL-Win64\bin"
    }
    catch {
        Write-Host "Check which link the script is trying to download. Attempting to open the website for you."
        Start-Process https://slproweb.com/products/Win32OpenSSL.html
    }
}

#menu here
function Show-Menu {
    Clear-Host
    Write-Host "================ Self Signed Certificate ================"
    Write-Host "1: Press '1' Create certificate with OpenSSL"
    Write-Host "2: Press '2' View OpenSSL PFX"
    Write-Host "3: Press '3' Install OpenSSL"
    Write-Host "4: Press '4' Open the SLBWebsite for OpenSSL"
    Write-Host "5: Press '5' Create and Install a certificate with PowerShell Commands"
    Write-Host "6: Press '6' Install the OpenSSL PFX in local machine"
    Write-Host "7: Press '7' Requires ADMIN: Set OpenSSL enviroment path permently"
    #Write-Host "8: Press '8' "
    #Write-Host "9: Press '9' "
    #Write-Host "0: Press '0' "
    Write-Host "Q: Press 'Q' to quit."
}

do {
    Show-Menu
    $S = Read-Host "Please make a selection"

    switch ($S) {
        '1' {
            #get the user input
            CreateCerts
            Pause
        }
        '2' {
            #view the pfx
            openssl pkcs12 -in .\FullCertChain.pfx -nodes
            Pause
        }
        '3' {
            Get-OpenSSL
            Pause
        }
        '4' {
            Start-Process https://slproweb.com/products/Win32OpenSSL.html
        }
        '5' {
            PSNativeCert
            Pause
        }
        '6' {
            InstallCert
            Pause
        }
        '7' {
            setx /M PATH "$env:Path;C:\Program Files\OpenSSL-Win64\bin"
            Pause
        }
        'q' {
            try {	
            }
            catch {
                Write-Host "Error"
            }
        }
    }
}
until ($S -eq 'q')
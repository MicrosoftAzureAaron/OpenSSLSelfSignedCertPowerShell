# Check if OpenSSL is installed
if (!(Get-Command openssl -ErrorAction SilentlyContinue)) {
    # Download and install OpenSSL
    Invoke-WebRequest -Uri "https://slproweb.com/download/Win64OpenSSL_Light-3_1_2.exe" -OutFile "C:\OpenSSL.exe"
    Start-Process -FilePath "C:\OpenSSL.exe" -ArgumentList "/SILENT" -Wait
    $env:Path += ";C:\Program Files\OpenSSL-Win64\bin"
}

#todo:
# add variable checking

############# create certificate
function CreateCerts {
    $CN = Read-Host "Enter Root certificate name, [Root.com]"
    if($CN -match "^\s*$") {$CN = "Root.com"}

    $countryName = Read-Host "Enter the Country, [US]"
    if($countryName -match "^\s*$") {$countryName = "US" }

    $stateOrProvinceName = Read-Host "Enter the State or Providence, [TX]"
    if($stateOrProvinceName -match "^\s*$") {$stateOrProvinceName = "TX"}

    $organizationName = Read-Host "Enter the Orginization Name, [SelfSigned]"
    if($organizationName -match "^\s*$") {$organizationName = "SelfSigned"}

    $RootCertPassword = Read-Host "Enter Root Private Key password"
    $RootCertPassword = "pass:" + $RootCertPassword

    $LeafCertPassword = Read-Host "Enter Leaf Private Key password"
    $LeafCertPassword = "pass:" + $LeafCertPassword

    #$CertDays = Read-Host "Enter days the certificate is valid for [365]"

    #create Root.cnf
    $FN = "Root.cnf"
    CreateCNF -s1 $countryName -s2 $stateOrProvinceName -s3 $organizationName -s4 $CN -FN $FN

    #creates Root.key private certificate (private key)
    openssl ecparam -out Root.key -name prime256v1 -genkey

    #creates Root.csr certificate signing request (CSR) with the Root.key private certificate
    openssl req -new -sha256 -key Root.key -out Root.csr -config Root.cnf

    #creates Root.cer certificate from Root.csr, Root.key, Root.cnf
    openssl x509 -req -sha256 -days 365 -in Root.csr -signkey Root.key -out Root.cer -extfile $FN -extensions v3_ca -passin $RootCertPassword

    #create Leaf.key private certificate (private key)
    openssl ecparam -out Leaf.key -name prime256v1 -genkey
    $CN = ""
    $CN = Read-Host "Enter Site/Leaf/Server certificate name, Leaf.com"
    if($CN -match "^\s*$") {$CN = "Leaf.com" }

    #create Leaf.cnf
    $FN = "Leaf.cnf"
    CreateCNF -s1 $countryName -s2 $stateOrProvinceName -s3 $organizationName -s4 $CN -FN $FN

    #create v3.txt\
    $SAN = Read-Host "Enter the SANs for the certificate, [*Leaf.com,*.Leaf.com,www.Leaf.com]"
    if($SAN -match "^\s*$") {$SAN = "*Leaf.com,*.Leaf.com,www.Leaf.com" }
    
    #add 'DNS:' to the list
    $SAN = ($SAN -split ',') -join ',DNS:'

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
    #$PSScriptRoot is a built-in variable that represents the directory where the script is located.
    #create a CNF from template cnf file
    $filePath = Join-Path -Path $PSScriptRoot -ChildPath "cnftemplate.cnf"
    $content = Get-Content -Path $filePath

    # Modify the content as needed
    $modifiedContent = $content -replace "s1", $s1
    $modifiedContent = $modifiedContent -replace "s2", $s2
    $modifiedContent = $modifiedContent -replace "s3", $s3
    $modifiedContent = $modifiedContent -replace "s4", $s4
    #write-host "filepath "$filepath
    #write-host "filename "$FN
    $filePath = Join-Path -Path $PSScriptRoot -ChildPath $FN
    $modifiedContent | Set-Content -Path $filePath
    if ($FN -eq "Leaf.cnf") {
        $lines = Get-Content -Path $filePath

        # Remove lines at indices 2 and 3 (0-based indices, so lines 3 and 4)
        $lines = $lines | Where-Object { $_ -notin @($lines[2], $lines[3]) }

        # Write the modified content back to the file
        $lines | Set-Content -Path $filePath
    }
}

function CreateV3 {
    param (
        [string]$s1
    )
    # Specify the file path
    $filePath = Join-Path -Path $PSScriptRoot -ChildPath "v3.txt"

    # Content to be written to the file
    $content = "subjectAltName = DNS:"+$s1
    $content | Set-Content -Path $filePath

    #add the last line
    Add-Content -Path $filePath -Value "extendedKeyUsage = serverAuth, clientAuth"
}

#menu here
function Show-Menu {
	#Clear-Host
	Write-Host "================ Self Signed Certificate ================"
	Write-Host "1: Press '1' Create Certificate "
	Write-Host "2: Press '2' View Local PFX"
	#Write-Host "3: Press '3' "
	#Write-Host "4: Press '4' "
	#Write-Host "5: Press '5' "
	#Write-Host "6: Press '6' "
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
            Show-Menu
		}
		'2' {
            #view the pfx
            openssl pkcs12 -in .\FullCertChain.pfx -nodes
            Show-Menu
		}
		'3' {

		}
		'4' {

		}
		'5' {

		}
		'6' {

		}
		'9' {

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
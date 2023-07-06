# Check if OpenSSL is installed
if (!(Get-Command openssl -ErrorAction SilentlyContinue)) {
    # Download and install OpenSSL
    Invoke-WebRequest -Uri "https://slproweb.com/download/Win64OpenSSL_Light-3_1_1.exe" -OutFile "C:\OpenSSL.exe"
    Start-Process -FilePath "C:\OpenSSL.exe" -ArgumentList "/SILENT" -Wait
    $env:Path += ";C:\Program Files\OpenSSL-Win64\bin"
}

# Ask user for parameters
$certName = Read-Host "Enter Site/Leaf/Server certificate name, example.com wild card will be included"
# $RootCertPassword = Read-Host "Enter Root Certificate password" -AsSecureString
# $LeafCertPassword = Read-Host "Enter Leaf Certificate password" -AsSecureString
$certDays = 366
$LeafCertPassword = $RootCertPassword = "1234"

# Create Root Certificate and Root Key
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -days $certDays -nodes -keyout SelfSignedRoot.key -out SelfSignedRoot.crt -subj "/CN=SelfSignedRoot.com" -addext "subjectAltName = DNS:SelfSignedRoot.com,DNS:*SelfSignedRoot.com" -passout pass:$RootCertPassword

$txt = "subjectAltName = DNS:"+$certName+",DNS:*"+$certname
$cn = "/CN=*"+$certName
# Create the leaf certifite and key
openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -keyout SelfSignedLeaf.key -out SelfSignedLeaf.csr -subj $cn -addext $txt -passout pass:$LeafCertPassword
openssl x509 -req -in SelfSignedLeaf.csr -CA SelfSignedRoot.crt -CAkey SelfSignedRoot.key -CAcreateserial -out SelfSignedLeaf.crt -days $certDays -passin pass:$IntermediateCertPassword

# Export server certificate and key
openssl pkcs12 -export -out SelfSignedLeaf.pfx -inkey SelfSignedLeaf.key -in SelfSignedLeaf.crt -certfile SelfSignedRoot.crt -passout pass:$LeafCertPassword -passin pass:$LeafCertPassword
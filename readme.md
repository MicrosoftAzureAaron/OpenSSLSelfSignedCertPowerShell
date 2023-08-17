run MakeSS.ps1 
1. install openssl lite for win 64 bit, download link is manually coded in - todo fix this
2. create a self signed certificate chain
   
   1. Root.cnf opensll config file
   2. Root.cer public certificate, 
   3. Root.key private certificate,
   4. Root.csr Certificate Signing Request
   5. Leaf.cnf opensll config file 
   6. Leaf.cer public certificate, 
   7. Leaf.key private certificate,
   8. Leaf.csr Certificate Signing Request
   9. FullCertChain.pfx a bundled PFX with private leaf key certificate, public root certificate, public leaf certificate
   10. Root.SRL root certificate serial
   11. v3.txt OpenSSL extension file
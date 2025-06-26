#!/bin/bash

# Usage: ./recon.sh <domain> [--stealth] [--gf-all] [--notify] [--resume]
domain=$1

if [ -z "$domain" ]; then
  echo "Usage: $0 <domain> [--stealth] [--gf-all] [--notify] [--resume]"
  exit 1
fi

root=$(echo $domain | sed 's/https\?:\/\///;s/\/$//')
output_dir="recon-$root-$(date +%s)"
mkdir -p "$output_dir"
cd "$output_dir"

# Mode flags
is_stealth=false
resume=false
gf_all=false
notify=false

for arg in "$@"; do
  case $arg in
    --stealth) is_stealth=true ;;
    --resume) resume=true ;;
    --gf-all) gf_all=true ;;
    --notify) notify=true ;;
  esac
done

# Progress helpers
step=1
total_steps=10
function progress() {
  echo -e "\n[+] Step $step/$total_steps: $1"
  start_time=$(date +%s)
}
function step_done() {
  end_time=$(date +%s)
  echo "⏱️  Done in $((end_time - start_time))s"
  ((step++))
}

overall_start=$(date +%s)

# 1. Subdomain Enumeration
progress "Enumerating subdomains..."
if [ "$resume" = true ] && [ -s subdomains.txt ]; then
  echo "[*] Skipping subdomain enumeration (resume mode)"
else
  subfinder -d "$root" -silent -all -nW -timeout 10 > subdomains.txt
fi
step_done

# 2. Passive URL Collection
progress "Collecting and filtering URLs (gau, waybackurls)..."
if [ "$resume" = true ] && [ -s gau_filtered.txt ] && [ -s wayback_filtered.txt ]; then
  echo "[*] Skipping URL collection (resume mode)"
else
  if [ "$is_stealth" = true ]; then
    (cat subdomains.txt | gau --threads 3 | grep -vE '\.(css|js|png|jpg|jpeg|gif|woff|ttf|ico|pdf)$' | grep -E '\.(php|asp|aspx|jsp|json|html)|/api|/admin|/login|/upload|/redirect' > gau_filtered.txt &) 
    (cat subdomains.txt | waybackurls | grep -vE '\.(css|js|png|jpg|jpeg|gif|woff|ttf|ico|pdf)$' | grep -E '\.(php|asp|aspx|jsp|json|html)|/api|/admin|/login|/upload|/redirect' > wayback_filtered.txt &)
  else
    (gau "$root" | grep -vE '\.(css|js|png|jpg|jpeg|gif|woff|ttf|ico|pdf)$' > gau_filtered.txt &)
    (waybackurls "$root" | grep -vE '\.(css|js|png|jpg|jpeg|gif|woff|ttf|ico|pdf)$' > wayback_filtered.txt &)
  fi
  wait
fi
step_done

# 3. DNS Resolution
progress "Resolving subdomains..."
if [ "$resume" = true ] && [ -s resolved.txt ]; then
  echo "[*] Skipping DNS resolution (resume mode)"
else
  dnsx -l subdomains.txt -silent -a > resolved.txt
fi
step_done

# 4. Port Scanning (Naabu)
progress "Port scanning with naabu..."
if [ "$resume" = true ] && [ -s ports.txt ]; then
  echo "[*] Skipping port scan (resume mode)"
else
  if [ "$is_stealth" = true ]; then
    naabu -list resolved.txt -top-ports 100 -rate 20 -silent -o ports.txt
  else
    naabu -list resolved.txt -top-ports 1000 -rate 1000 -silent -o ports.txt
  fi
fi
step_done

# 5. Live Host Detection (httpx)
progress "Probing live hosts with httpx..."
if [ "$resume" = true ] && [ -s live_httpx.txt ]; then
  echo "[*] Skipping live probing (resume mode)"
else
  if [ "$is_stealth" = true ]; then
    httpx -l resolved.txt -silent -rate-limit 10 -timeout 10 \
      -random-agent -status-code -title -no-color -o live_httpx.txt
  else
    httpx -l resolved.txt -silent -status-code -title -no-color -o live_httpx.txt
  fi
fi
if [ -s live_httpx.txt ]; then
  cut -d ' ' -f1 live_httpx.txt > live_urls.txt
else
  echo "[!] No live hosts found."
  touch live_urls.txt
fi
step_done

# 6. Technology Fingerprint
progress "Fingerprinting technologies with WhatWeb..."
if [ -s live_urls.txt ]; then
  whatweb --no-errors -i live_urls.txt --log-brief whatweb.txt
else
  echo "[!] No live URLs to fingerprint."
fi
step_done

# 7. Crawling
progress "Crawling with Katana..."
if [ "$resume" = true ] && [ -s katana.txt ]; then
  echo "[*] Skipping crawling (resume mode)"
else
  if [ -s live_urls.txt ]; then
    if [ "$is_stealth" = true ]; then
      katana -list live_urls.txt -silent -concurrency 2 -delay 2 -o katana.txt
    else
      katana -list live_urls.txt -silent -o katana.txt
    fi
  else
    echo "[!] No live URLs to crawl."
    touch katana.txt
  fi
fi
step_done

# 8. Merge and Filter
progress "Merging URLs and filtering interesting ones..."
cat gau_filtered.txt wayback_filtered.txt katana.txt 2>/dev/null | sort -u > merged_urls.txt
grep -Ei '\.php|\.aspx|\.jsp|\.json|\.cgi|api|admin|upload|login|dashboard|redirect' merged_urls.txt > interesting_endpoints.txt
grep "?" merged_urls.txt > urls_with_params.txt
step_done

# 9. gf patterns
progress "Running gf patterns..."
if [ -s urls_with_params.txt ]; then
  if [ "$gf_all" = true ]; then
    for pattern in $(gf -list); do
      cat urls_with_params.txt | gf "$pattern" > "gf_$pattern.txt"
    done
  else
    cat urls_with_params.txt | gf xss > gf_xss.txt
    cat urls_with_params.txt | gf sqli > gf_sqli.txt
    cat urls_with_params.txt | gf ssrf > gf_ssrf.txt
  fi
else
  echo "[!] No URLs with parameters found for gf."
fi
step_done

# 10. Nuclei scanning
progress "Running nuclei scans..."
if [ -s live_urls.txt ]; then
  nuclei -l live_urls.txt -t ~/nuclei-templates/ -silent -o nuclei_findings.txt
else
  echo "[!] No live URLs to scan with nuclei."
  touch nuclei_findings.txt
fi
step_done

# Summary
overall_end=$(date +%s)
echo -e "\n[+] Recon complete in $((overall_end - overall_start)) seconds!"
echo "📁 Output saved in $output_dir"
echo "📄 Subdomains: $(wc -l < subdomains.txt) | Live: $(wc -l < live_urls.txt) | Interesting URLs: $(wc -l < interesting_endpoints.txt) | Nuclei findings: $(wc -l < nuclei_findings.txt)"

if [ "$notify" = true ]; then
  echo -e "\n🔔 Sending recon complete notification..."
  echo "Recon for $root finished in $((overall_end - overall_start))s!"
fi


# 🛡️ recon.sh — Bug Bounty Recon Automation

A fast, flexible recon automation script designed for bug bounty hunters and penetration testers.

> Automatically finds subdomains, URLs, live hosts, open ports, tech stacks, vulnerable patterns, and more.

---

## 🔧 Features

- 🌐 Subdomain enumeration with `subfinder`
- 📦 URL collection via `gau` and `waybackurls`
- 🧠 Technology fingerprinting with `WhatWeb`
- ⚡ Live host detection with `httpx`
- 🛠 Port scanning using `naabu`
- 🐾 Crawling with `katana`
- 🔍 GF pattern matching (XSS, SQLi, SSRF, etc.)
- 🧪 Nuclei vulnerability scanning
- ✅ Resume, stealth, and notify modes
- 📂 Organized output in timestamped folders

---

## ⚙️ Requirements

Make sure these tools are installed:

ubfinder gau waybackurls dnsx naabu httpx whatweb katana gf nuclei


Use the included `setup.sh` to install them all.

---

## 🚀 Usage

```bash
chmod +x recon.sh
./recon.sh example.com --gf-all --notify --resume 


Flags:
--stealth: Run in stealth mode (low rate, less noise)
--gf-all: Run all GF patterns instead of just XSS/SQLi/SSRF
--resume: Skip steps that have already completed
--notify: Print notification after script ends

🧪 Sample Output

subdomains.txt: Subdomain list
live_httpx.txt: Live URLs with status/title
ports.txt: Open ports
nuclei_findings.txt: Vulnerability scan report


🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.




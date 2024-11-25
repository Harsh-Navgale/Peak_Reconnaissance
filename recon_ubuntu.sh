#!/bin/bash

# Usage: ./recon_ubuntu.sh <domain> <task>
# Tasks: enumeration, domain_resolve, port_scan, http_probe, takeover, nuclei, waybackurl

domain=$1
task=$2

# Define paths
# Define the repository directory path
repository_directory="/mnt/f/EthicalHacking/configFiles/resolvers"
resolvers="/mnt/f/EthicalHacking/configFiles/resolvers/resolvers.txt"
output_dir="./results/$domain"
mkdir -p $output_dir

# Function to install missing tools
install_tool() {
    if ! command -v $1 &>/dev/null; then
        echo "[*] $1 is not installed. Installing..."
        case $1 in
            "curl") sudo apt-get install -y curl ;;
            "jq") sudo apt-get install -y jq ;;
            "subfinder") GO111MODULE=on go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest ;;
            "assetfinder") go get -u github.com/tomnomnom/assetfinder ;;
            "massdns") sudo apt-get install -y massdns ;;
            "dnsx") GO111MODULE=on go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest ;;
            "nmap") sudo apt-get install -y nmap ;;
            "httpx") GO111MODULE=on go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest ;;
            "subjack") go install github.com/haccer/subjack@latest ;;
            "nuclei") GO111MODULE=on go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest ;;
            "waybackurls") go install github.com/tomnomnom/waybackurls@latest ;;
            *) echo "Tool $1 not recognized for installation." ;;
        esac
    else
        echo "[*] $1 is already installed."
    fi
}

# Install all required tools
tools=("curl" "jq" "subfinder" "assetfinder" "massdns" "nmap" "httpx" "subjack" "nuclei" "waybackurls")
for tool in "${tools[@]}"; do
    install_tool $tool
done

# Task Functions
enumeration() {
    echo "[*] Starting subdomain enumeration..."
    mkdir -p $output_dir/enumeration
    # CRT.sh lookup
    curl -s "https://crt.sh/?q=$domain&output=json" | jq -r '.[]?.common_name? // empty' | sed 's/\*\.//g' | sort -u > $output_dir/enumeration/crtsh.txt
    # Subfinder
    subfinder -d $domain -silent -o $output_dir/enumeration/subfinder.txt
    # Assetfinder
    assetfinder -subs-only $domain | tee $output_dir/enumeration/assetfinder.txt
    # Combine all results
    cat $output_dir/enumeration/*.txt | sort -u > $output_dir/enumeration/all_subdomains.txt
    echo "[*] Subdomain enumeration completed."
    echo "Task completed. results at: $(pwd)/$domain"
}

domain_resolve() {
    echo "[*] Resolving subdomains..."
    
    resolver_update(){
        # Get the current directory
        current_directory=$(pwd)

        # Change to the repository directory
        cd $repository_directory

        # Update the repository (assuming it's a Git repository)
        git pull origin

        # Change back to the original directory
        cd $current_directory
    }
    resolver_update
    
    mkdir -p $output_dir/resolved
    # MassDNS
    massdns -r $resolvers -t A -o S $output_dir/enumeration/all_subdomains.txt > $output_dir/resolved/massdns.txt
    awk '{print $1}' $output_dir/resolved/massdns.txt | sort -u > $output_dir/resolved/resolved_domains.txt
    echo "[*] Domain resolution completed."
    echo "Task completed. results at: $(pwd)/$domain"
}

port_scan() {
    echo "[*] Starting port scan..."
    mkdir -p $output_dir/ports
    nmap -T3 -vv -iL $output_dir/resolved/resolved_domains.txt --top-ports 100 -n --open -oX $output_dir/ports/nmap.xml
    echo "[*] Port scan completed."
    echo "Task completed. results at: $(pwd)/$domain"
}

http_probe() {
    echo "[*] Probing HTTP services..."
    mkdir -p $output_dir/http_probe
    httpx -l $output_dir/resolved/resolved_domains.txt -silent -o $output_dir/http_probe/http_services.txt
    cat $output_dir/resolved/resolved_domains.txt | httpx --random-agent --status-code --title -server -td -fhr -fc 400,503,429,403,409 -o $domain/recon/httpx_details.txt
    echo "[*] HTTP probing completed."
    echo "Task completed. results at: $(pwd)/$domain"
}

takeover() {
    echo "[*] Checking for subdomain takeovers..."
    mkdir -p $output_dir/takeovers
    subjack -w $output_dir/resolved/resolved_domains.txt -ssl -v > $output_dir/takeovers/subjack_results.txt
    nuclei -l $output_dir/resolved/resolved_domains.txt -t ~/nuclei-templates/http/takeovers/ -o $output_dir/takeovers/nuclei_takeovers.txt
    echo "[*] Subdomain takeover check completed."
    echo "Task completed. results at: $(pwd)/$domain"
}

nuclei_scan() {
    echo "[*] Running Nuclei scans..."
    mkdir -p $output_dir/nuclei
    nuclei -l $output_dir/http_probe/http_services.txt -o $output_dir/nuclei/vulnerabilities.txt
    echo "[*] Nuclei scan completed."
    echo "Task completed. results at: $(pwd)/$domain"
}

waybackurl() {
    echo "[*] Extracting Wayback URLs..."
    mkdir -p $output_dir/wayback
    waybackurls $domain | sort -u > $output_dir/wayback/urls1.txt
    wget "https://web.archive.org/cdx/search/cdx?url=*.$domain/*&output=text&fl=original&collapse=urlkey" -O $output_dir/wayback/urls2.txt
    cat $output_dir/wayback/*.txt | sort -u > $output_dir/wayback/all_urls.txt
    echo "[*] Wayback URL extraction completed."
    echo "Task completed. results at: $(pwd)/$domain"
}

# Main Dispatcher
case $task in
    "enumeration") enumeration ;;
    "domain_resolve") domain_resolve ;;
    "port_scan") port_scan ;;
    "http_probe") http_probe ;;
    "takeover") takeover ;;
    "nuclei") nuclei_scan ;;
    "waybackurl") waybackurl ;;
    *)
        echo "Unknown task: $task"
        exit 1
        ;;
esac

echo "[*] Task $task completed for domain $domain."

package main

import (
	"bufio"
	"encoding/base64"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

const maxConcurrentRequests = 50

var wg sync.WaitGroup
var mu sync.Mutex
var hibpDir = "/opt/hibp"

type AccountInfo struct {
	SID         string
	NTLMHash    string
	Pwned       bool
	Base64Pass  string
	Length      int
	IsPublicLeak bool
	HasBannedWord bool
}

func main() {
	// Vérifier que les arguments nécessaires sont fournis
	if len(os.Args) < 5 {
		fmt.Fprintln(os.Stderr, "\033[41;37m[!]\033[0m Usage: go run your_program.go <secretdumps> <potfile> <bannedWords> <secretdumps-output> [<hipCacheDir>=/opt/hibp]")
		os.Exit(1)
	}

	// Récupérer les noms de fichiers depuis les arguments de la ligne de commande
	secretdumpsFile := os.Args[1]
	potfile := os.Args[2]
	bannedWords := os.Args[3]
	outputFile := os.Args[4]
	if len(os.Args) == 6 {
		hibpDir = os.Args[5]
	}

	// Afficher les fichiers utilisés
	fmt.Println("[*] Argument secretdumpsFile:", secretdumpsFile)
	fmt.Println("[*] Argument potfile:", potfile)
	fmt.Println("[*] Argument bannedWords:", bannedWords)
	fmt.Println("[*] Argument outputFile:", outputFile)
	fmt.Println("[*] Argument hibpDir:", hibpDir)

	// Lire le fichier hashcat.potfile et stocker les correspondances NTLM -> password
	potfileHashes := make(map[string]string)
	potFileHandle, err := os.Open(potfile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Failed to open potfile: %v\n", err)
		os.Exit(1)
	}
	defer potFileHandle.Close()

	fmt.Println("[*] Reading potfile...")
	scanner := bufio.NewScanner(potFileHandle)
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			continue
		}
		// check if nthash size
		if len(parts[0]) != 32 {
			continue
		}
		hash, password := parts[0], parts[1]
		potfileHashes[strings.ToUpper(hash)] = password
	}
	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Error reading potfile: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("[*] Potfile loaded successfully.")

	// load banned words
	bannedWordsList, err := loadBannedWords(bannedWords)
	if err != nil {
		os.Exit(1)
	}

	// Lire le fichier secretdump.txt et analyser les comptes utilisateurs
	secretdumpHandle, err := os.Open(secretdumpsFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Failed to open secretdumps file: %v\n", err)
		os.Exit(1)
	}
	defer secretdumpHandle.Close()

	var accounts []AccountInfo
	fmt.Println("[*] Reading secretdumps file...")
	scanner = bufio.NewScanner(secretdumpHandle)
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.Split(line, ":")
		if len(parts) < 4 {
			continue
		}

		SID := parts[1]
		samAccountName := parts[0]
		ntlmHash := strings.ToUpper(parts[3])

		// Ignorer les _historyXXXX et les comptes avec un $ en fin de nom
		if strings.Contains(samAccountName, "_history") || strings.HasSuffix(samAccountName, "$") {
			continue
		}

		account := AccountInfo{
			SID:      SID,
			NTLMHash: ntlmHash,
			Pwned:    false,
			Length:   -1,
			IsPublicLeak: false,
			HasBannedWord: false,
		}

		// Vérifier si le hash NTLM est dans le fichier potfile
		password, found := potfileHashes[ntlmHash]
		if found {
			account.Pwned = true
			account.Base64Pass = base64.StdEncoding.EncodeToString([]byte(password))
			account.Length = len(password)
		}

		// Vérifier si le mot de passe contient un mot interdit
		account.HasBannedWord = containsBannedWord(password, bannedWordsList)
		if account.IsPublicLeak = true {
			if account.Pwned = false {
				fmt.Println("[*] Password not found by hascat but found a public leak for ", account.SID, " with hash ", account.NTLMHash)
				account.Pwned = true
			}
		}
		
		accounts = append(accounts, account)
	}
	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Error reading secretdumps file: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("[*] Secretdumps file processed successfully.")

	// Utiliser des goroutines pour vérifier les hashes en parallèle
	fmt.Println("[*] Checking hashes for public leaks...")
	checkPublicLeaks(accounts)

	// Créer le fichier CSV de sortie
	outputFileHandle, err := os.Create(outputFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Failed to create output file: %v\n", err)
		os.Exit(1)
	}
	defer outputFileHandle.Close()

	// Écrire l'en-tête du fichier CSV
	header := "sid,nthash,pwned,b64pass,len,isPublicLeak,HasBannedWord\n"
	_, err = outputFileHandle.WriteString(header)
	if err != nil {
		fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Failed to write to output file: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("[*] CSV header written successfully.")

	// Écrire les données des comptes dans le fichier CSV
	for _, account := range accounts {
		line := fmt.Sprintf("%s,%s,%t,%s,%d,%t,%t\n",
			account.SID,
			account.NTLMHash,
			account.Pwned,
			account.Base64Pass,
			account.Length,
			account.IsPublicLeak,
			account.HasBannedWord,
		)
		_, err = outputFileHandle.WriteString(line)
		if err != nil {
			fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Failed to write to output file: %v\n", err)
			os.Exit(1)
		}
	}
	fmt.Println("[*] CSV file written successfully.")
}

func checkPublicLeaks(accounts []AccountInfo) {
	semaphore := make(chan struct{}, maxConcurrentRequests)
	var wg sync.WaitGroup

	for i := range accounts {
		account := &accounts[i]
		if !account.Pwned {
			continue
		}

		semaphore <- struct{}{}
		wg.Add(1)
		go func(a *AccountInfo) {
			defer wg.Done()
			defer func() { <-semaphore }()
			a.IsPublicLeak = checkPwnedPassword(a.NTLMHash)
		}(account)
	}

	wg.Wait()
	fmt.Println("[*] All public leak checks completed.")
}

func checkPwnedPassword(ntlmHash string) bool {
	prefix := ntlmHash[:5]
	suffix := ntlmHash[5:]

	hibpFile := filepath.Join(hibpDir, fmt.Sprintf("%s.txt", prefix))
	
	// Si le fichier existe, vérifier s'il contient le reste du hash
	if _, err := os.Stat(hibpFile); err == nil {
		content, err := ioutil.ReadFile(hibpFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Failed to read %s: %v\n", hibpFile, err)
			return false
		}
		fmt.Printf("[*] Found local HIBP file: %s\n", hibpFile)
		return strings.Contains(string(content), suffix)
	}

	// Sinon, interroger l'API PwnedPasswords
	url := fmt.Sprintf("https://api.pwnedpasswords.com/range/%s?mode=ntlm", prefix)
	fmt.Printf("[*] Querying PwnedPasswords API for prefix: %s\n", prefix)
	resp, err := http.Get(url)
	if err != nil {
		fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Failed to query PwnedPasswords API: %v\n", err)
		return false
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Failed to read response body: %v\n", err)
		return false
	}

	// Enregistrer les résultats dans le fichier pour une future utilisation
	err = ioutil.WriteFile(hibpFile, body, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Failed to write to %s: %v\n", hibpFile, err)
	}
	fmt.Printf("[*] Stored PwnedPasswords results in: %s\n", hibpFile)

	// Vérifier si le suffixe du hash est présent dans le résultat
	return strings.Contains(string(body), suffix)
}

// loadBannedWords lit les mots interdits depuis un fichier et les stocke dans un tableau
func loadBannedWords(filename string) ([]string, error) {
	fmt.Println("[*] Reading banned words from file:", filename)
	file, err := os.Open(filename)
	if err != nil {
		fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Failed to open banned words file: %v\n", err)
		return nil, err
	}
	defer file.Close()

	var bannedWords []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		word := strings.TrimSpace(scanner.Text())
		if word != "" {
			bannedWords = append(bannedWords, strings.ToLower(word))
		}
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "\033[41;37m[!]\033[0m Error reading banned words file: %v\n", err)
		return nil, err
	}

	fmt.Println("[*] Banned words loaded successfully.")
	return bannedWords, nil
}

// containsBannedWord vérifie si un mot de passe contient un mot interdit
func containsBannedWord(password string, bannedWords []string) bool {
	password = strings.ToLower(password)
	for _, word := range bannedWords {
		if strings.Contains(password, word) {
			return true
		}
	}
	return false
}
# Server Update Checker
### Automatic remote update scanner via SSH for Linux servers

![Sysadmin Tool](https://img.shields.io/badge/Sysadmin-Tool-orange)
![Shell Script](https://img.shields.io/badge/Shell-Bash-4EAA25)
![License MIT](https://img.shields.io/badge/License-MIT-blue)
![Platform Linux](https://img.shields.io/badge/Platform-Linux-lightgrey)
![Maintained](https://img.shields.io/badge/Maintained-yes-success)

---

## 🇮🇹 Descrizione (Italiano)

Questo script permette di controllare in modo automatico gli aggiornamenti disponibili su più server Linux tramite SSH.

Identifica automaticamente il gestore pacchetti remoto (APT, DNF, YUM, APK, Zypper, Pacman) e genera un elenco puntato contenente quanti aggiornamenti sono disponibili per ogni server analizzato.

Lo script supporta modalità verbose, dry-run, check della versione su GitHub e può lavorare sia con alias SSH sia con `user@host`.

---

## 🔧 Installazione

### 1) Scarica lo script dal repository GitHub

```bash
curl -O https://raw.githubusercontent.com/RedFoxy/Server-Update-Checker/main/server-update-check.sh
````

oppure:

```bash
wget https://raw.githubusercontent.com/RedFoxy/Server-Update-Checker/main/server-update-check.sh
```

---

### 2) Rendi lo script eseguibile

```bash
chmod +x server-update-check.sh
```

---

### 3) (Opzionale) Installazione globale

```bash
mv server-update-check.sh /usr/local/bin/
```

Così potrai eseguirlo da qualsiasi percorso:

```bash
server-update-check.sh
```

---

## 🧩 Autenticazione SSH: come funziona davvero

Lo script **non gestisce password o porte personalizzate**, e non richiede configurazioni aggiuntive: lascia fare tutto a SSH.

Questo significa che la gestione di:

* Porta
* Chiavi SSH
* User
* IP / Hostname
* Opzioni specifiche
* Alias dei server

va configurata nel file:

```
~/.ssh/config
```

Così puoi definire ogni server una volta sola, rendendo la connessione completamente automatica.

---

## 🛠️ Esempio di configurazione `~/.ssh/config`

```sshconfig
Host server1
    HostName 192.168.1.10
    User myuser
    Port 22
    IdentityFile ~/.ssh/id_ed25519_server1
```

Con ciò puoi collegarti semplicemente con:

```bash
ssh server1
server-update-check.sh server1
```

---

## 🧑‍💻 Uso con `user@host`

Lo script accetta tranquillamente:

```bash
server-update-check.sh admin@192.168.1.10
```

In questo caso:

* SSH proverà chiavi e regole compatibili
* Se non trova chiavi valide → chiederà la password
* Nessun requisito di presenza nell'elenco interno degli host
* Nessun conflitto con configurazioni già presenti

Questa modalità è ideale per controlli spot o server non ancora inclusi nel file di configurazione.

---

## 📂 Host predefiniti nello script

Lo script contiene un elenco di host “regolamentari”, usato quando non specifichi host da riga di comando:

```bash
hosts=(
  server1
  server2
  docker-host
  database01
)
```

Questi nomi **devono corrispondere agli alias** definiti nel file `~/.ssh/config`.

Se passi invece un host dalla CLI (come `user@192.168.1.10`), non serve che sia presente nella lista.

Con `--strict` lo script richiederà che l’host sia incluso nella lista interna.

---

## ▶️ Esempi d’uso (ripristinati come la prima versione)

```bash
./server-update-check.sh                # controlla tutti gli host in silenzio, utile per crontab
./server-update-check.sh -v             # output verboso
./server-update-check.sh host1          # controlla un singolo host
./server-update-check.sh host1 host2    # controlla solo host specifici
./server-update-check.sh -l             # mostra elenco host
./server-update-check.sh -n             # dry-run (nessuna pulizia, nessuna notifica)
./server-update-check.sh -V             # controlla la versione locale rispetto a GitHub:
```

## English Description

This script automatically checks multiple Linux servers over SSH and reports how many package updates are available on each system.

It automatically detects the remote package manager (APT, DNF, YUM, APK, Zypper, Pacman) and produces a clean bullet-list showing how many updates are available on each host.

The script supports verbose mode, dry-run mode, GitHub version checking, and can operate with both SSH aliases and direct `user@host` specifications.

---

## Installation

### 1) Download the script from GitHub

```bash
curl -O https://raw.githubusercontent.com/RedFoxy/Server-Update-Checker/main/server-update-check.sh
````

or:

```bash
wget https://raw.githubusercontent.com/RedFoxy/Server-Update-Checker/main/server-update-check.sh
```

---

### 2) Make the script executable

```bash
chmod +x server-update-check.sh
```

---

### 3) (Optional) Install globally

```bash
mv server-update-check.sh /usr/local/bin/
```

You can then run it from anywhere:

```bash
server-update-check.sh
```

---

## SSH Authentication Model

The script **does not** handle:

* SSH passwords
* non-standard ports
* custom identity files
* special authentication rules

All authentication and connection details are delegated to SSH itself and are configured in:

```
~/.ssh/config
```

This ensures maximum flexibility and security, while avoiding duplicated logic inside the script.

---

## Recommended `~/.ssh/config` setup

You can define per-server settings such as hostname, username, port and SSH keys:

```sshconfig
Host server1
    HostName 192.168.1.10
    User myuser
    Port 22
    IdentityFile ~/.ssh/id_ed25519_server1
```

Once configured, both SSH and the update-check script can connect using the alias:

```bash
ssh server1
server-update-check.sh server1
```

No additional parameters are required.

---

## Using `user@host`

The script also accepts direct SSH targets:

```bash
server-update-check.sh admin@192.168.1.10
```

In this case:

* SSH will try available keys
* If no key matches, SSH may ask for a password
* The host does **not** need to be in the internal host list
* No conflict with existing SSH config entries

This mode is ideal for ad-hoc checks or servers not yet included in the main configuration.

---

## Internal Host List

The script contains an internal list of configured hosts:

```bash
hosts=(
  server1
  server2
  docker-host
  database01
)
```

These entries correspond to the aliases defined in `~/.ssh/config`.

If you specify hosts manually (such as `user@192.168.1.10`), they do **not** need to appear in this list.
With `--strict`, on the other hand, the script will reject unknown hosts.

---

## Notes on Passwords and Automation

The script does **not** implement password-based non-interactive authentication.
For automated or scheduled usage (cron, monitoring), you must configure:

* SSH key authentication
* Proper alias definitions in `~/.ssh/config`

Always test SSH connectivity first:

```bash
ssh server1
```

If this works without password prompts, the script will run smoothly in automated mode.

---

## Usage Examples

Run checks on all configured hosts:

```bash
./server-update-check.sh                # check all hosts
./server-update-check.sh -v             # verbose output
./server-update-check.sh host1          # check a specific host
./server-update-check.sh host1 host2    # check selected hosts
./server-update-check.sh -l             # list configured hosts
./server-update-check.sh -n             # dry-run mode (no clean, no notifications)
./server-update-check.sh -V             # check the local script version against GitHub
```

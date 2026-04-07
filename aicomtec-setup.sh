#!/bin/bash
# ============================================================
# aicomtec-setup.sh
# Setup interattivo Aicomtec Linux
#
# Cosa fa:
#   1) Sposta il pannello Cinnamon in alto (top)
#   2) Installa applicazioni Flatpak e APT con descrizione
#      e conferma interattiva per ognuna
#   3) Scarica e imposta il wallpaper ufficiale Aicomtec
#
# Uso:
#   chmod +x aicomtec-setup.sh
#   ./aicomtec-setup.sh
#
# Repository: github.com/dado70/Mint-dado-Aicomtec
# ============================================================

set -euo pipefail

# ── Colori ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Contatori ─────────────────────────────────────────────────
INSTALLED=0
SKIPPED=0
FAILED=0

# ── Funzioni log ──────────────────────────────────────────────
info()    { echo -e "${BLUE}  ℹ  ${NC}$*"; }
ok()      { echo -e "${GREEN}  ✔  ${NC}$*"; INSTALLED=$((INSTALLED+1)); }
skip()    { echo -e "${YELLOW}  ⊘  ${NC}$*"; SKIPPED=$((SKIPPED+1)); }
fail()    { echo -e "${RED}  ✘  ${NC}$*"; FAILED=$((FAILED+1)); }
warn()    { echo -e "${YELLOW}  ⚠  ${NC}$*"; }
section() { echo -e "\n${BOLD}${CYAN}══  $*  ══${NC}\n"; }
desc()    { echo -e "${DIM}     $*${NC}"; }

# ── Chiedi conferma ───────────────────────────────────────────
# Ritorna 0 (sì) o 1 (no)
ask() {
  local prompt="$1"
  local answer
  echo -en "${BOLD}  ?  ${NC}${prompt} ${DIM}[S/n]${NC} "
  read -r answer
  case "$answer" in
    [Nn]*) return 1 ;;
    *)     return 0 ;;
  esac
}

# ── Verifica se un comando esiste ─────────────────────────────
has() { command -v "$1" &>/dev/null; }

# ── Verifica se un pacchetto apt è installato ─────────────────
apt_installed() { dpkg -s "$1" &>/dev/null 2>&1; }

# ── Verifica se un Flatpak è installato ───────────────────────
flatpak_installed() { flatpak list --app --columns=application 2>/dev/null | grep -q "^$1$"; }

# ── Banner ────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  ╔═══════════════════════════════════════════════════════════╗
  ║                                                           ║
  ║            AICOMTEC LINUX — Setup Interattivo             ║
  ║                                                           ║
  ║   Pannello top · Applicazioni · Wallpaper ufficiale       ║
  ║                                                           ║
  ╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo -e "  Repository: ${CYAN}github.com/dado70/Mint-dado-Aicomtec${NC}"
echo -e "  Per ogni applicazione verrà chiesta conferma."
echo -e "  Premi ${BOLD}INVIO${NC} o ${BOLD}S${NC} per installare, ${BOLD}N${NC} per saltare."
echo ""
read -rp "  Premi INVIO per iniziare..." _

# ═══════════════════════════════════════════════════════════════
# FASE 1 — PANNELLO IN ALTO
# ═══════════════════════════════════════════════════════════════
section "FASE 1 — Pannello Cinnamon in alto"

info "Il pannello verrà spostato dalla posizione attuale verso il top dello schermo."
echo ""

if ask "Spostare il pannello Cinnamon in alto?"; then

  # Cinnamon gestisce i pannelli tramite dconf
  # Il pannello principale è panels-enabled e panels-height
  # La posizione si imposta con panel-edit-mode e lo schema
  # org.cinnamon panels-enabled contiene stringhe tipo "1:0:bottom"
  # formato: "ID:MONITOR:POSIZIONE" dove posizione = top|bottom

  CURRENT_PANELS=$(gsettings get org.cinnamon panels-enabled 2>/dev/null || echo "[]")

  if echo "$CURRENT_PANELS" | grep -q "bottom"; then
    # Sostituisce bottom con top per tutti i pannelli
    NEW_PANELS=$(echo "$CURRENT_PANELS" | sed "s/:bottom/:top/g")
    gsettings set org.cinnamon panels-enabled "$NEW_PANELS"
    ok "Pannello spostato in alto."
    info "Riavvio Cinnamon per applicare..."
    cinnamon --replace &>/dev/null & disown
    sleep 3
  elif echo "$CURRENT_PANELS" | grep -q "top"; then
    warn "Il pannello è già in alto. Nessuna modifica necessaria."
    SKIPPED=$((SKIPPED+1))
  else
    # Fallback: imposta direttamente tramite schema panels
    # Prova con il pannello ID 1 su monitor 0
    gsettings set org.cinnamon panels-enabled "['1:0:top']" 2>/dev/null && \
      ok "Pannello impostato in alto (configurazione default)." || \
      fail "Impossibile spostare il pannello automaticamente."
    info "Se il pannello non si è spostato, fai clic destro sul pannello → Impostazioni → Posizione: In alto."
  fi

else
  skip "Pannello: saltato."
fi

# ═══════════════════════════════════════════════════════════════
# FASE 2 — FLATPAK SETUP
# ═══════════════════════════════════════════════════════════════
section "FASE 2 — Configurazione Flatpak"

if ! has flatpak; then
  info "Flatpak non trovato. Installo..."
  sudo apt install -y flatpak
  sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  ok "Flatpak installato e Flathub configurato."
else
  ok "Flatpak già presente."
  if ! flatpak remotes | grep -q flathub; then
    info "Aggiungo repository Flathub..."
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    ok "Flathub aggiunto."
  fi
fi

# ── Funzione installazione Flatpak ────────────────────────────
install_flatpak() {
  local app_id="$1"
  local app_name="$2"
  local app_desc="$3"

  echo ""
  echo -e "  ${BOLD}${MAGENTA}▶ $app_name${NC} ${DIM}[$app_id]${NC}"
  desc "$app_desc"
  echo ""

  if flatpak_installed "$app_id"; then
    warn "$app_name è già installato. Salto."
    SKIPPED=$((SKIPPED+1))
    return 0
  fi

  if ask "Installare $app_name?"; then
    info "Installazione $app_name in corso..."
    if flatpak install -y flathub "$app_id" 2>&1 | \
        grep -v "^F\[" | grep -v "^$" | sed 's/^/     /'; then
      ok "$app_name installato."
    else
      fail "$app_name — installazione fallita. Riprova manualmente: flatpak install flathub $app_id"
    fi
  else
    skip "$app_name: saltato."
  fi
}

# ═══════════════════════════════════════════════════════════════
# FASE 3 — APPLICAZIONI FLATPAK
# ═══════════════════════════════════════════════════════════════
section "FASE 3 — Applicazioni Flatpak"

info "Verranno proposti i seguenti pacchetti Flatpak da Flathub."
echo ""

install_flatpak \
  "org.gnome.gitlab.somas.Apostrophe" \
  "Apostrophe" \
  "Editor Markdown minimalista e distraction-free. Ideale per scrivere documenti, note e README con anteprima live."

install_flatpak \
  "com.brave.Browser" \
  "Brave Browser" \
  "Browser web basato su Chromium, con blocco pubblicità e tracker integrato. Privacy-first, veloce e compatibile con le estensioni Chrome."

install_flatpak \
  "im.riot.Riot" \
  "Element" \
  "Client di messaggistica sicura basato sul protocollo Matrix. Supporta chat, videochiamate e collaborazione in team in modo decentralizzato."

install_flatpak \
  "org.localsend.localsend_app" \
  "LocalSend" \
  "Condivisione di file in rete locale senza internet, senza account, senza cloud. Funziona tra Linux, Windows, macOS, Android e iOS."

install_flatpak \
  "com.obsproject.Studio" \
  "OBS Studio" \
  "Software professionale per registrazione video e streaming live. Usato da content creator, formatori e team per webinar e screencasting."

install_flatpak \
  "com.github.jeromerobert.pdfarranger" \
  "PDFArranger" \
  "Strumento grafico per riordinare, ruotare, unire e dividere pagine PDF. Semplice e leggero, perfetto per gestire documenti."

install_flatpak \
  "org.telegram.desktop" \
  "Telegram" \
  "App di messaggistica istantanea veloce e sicura. Supporta gruppi, canali, bot e condivisione di file fino a 2 GB."

install_flatpak \
  "com.github.alainm23.planify" \
  "Timecop" \
  "Applicazione per il time tracking e la gestione del tempo. Registra quanto tempo dedichi a ogni progetto o attività."

install_flatpak \
  "com.github.micahflee.torbrowser-launcher" \
  "Tor Browser" \
  "Browser anonimo basato su Firefox che instrada il traffico attraverso la rete Tor. Protegge la privacy e aggira la censura."

install_flatpak \
  "com.rtosta.zapzap" \
  "ZapZap" \
  "Client desktop non ufficiale per WhatsApp. Interfaccia nativa Linux basata su WebApp, con notifiche di sistema integrate."

install_flatpak \
  "com.github.xournalpp.xournalpp" \
  "Xournal++" \
  "Applicazione per prendere appunti scritti a mano, annotare PDF e disegnare con tavoletta grafica o touchscreen."

# ═══════════════════════════════════════════════════════════════
# FASE 4 — APPLICAZIONI APT
# ═══════════════════════════════════════════════════════════════
section "FASE 4 — Applicazioni APT"

info "Verranno proposti i seguenti pacchetti dal repository apt."
echo ""

# ── Funzione installazione APT ────────────────────────────────
install_apt() {
  local pkg="$1"
  local app_name="$2"
  local app_desc="$3"

  echo ""
  echo -e "  ${BOLD}${MAGENTA}▶ $app_name${NC} ${DIM}[$pkg]${NC}"
  desc "$app_desc"
  echo ""

  if apt_installed "$pkg"; then
    warn "$app_name è già installato. Salto."
    SKIPPED=$((SKIPPED+1))
    return 0
  fi

  if ask "Installare $app_name?"; then
    info "Installazione $app_name in corso..."
    if sudo apt install -y "$pkg" 2>&1 | grep -E "^(Setting up|Unpacking|Get:|Err:)" | sed 's/^/     /'; then
      ok "$app_name installato."
    else
      fail "$app_name — installazione fallita. Riprova manualmente: sudo apt install $pkg"
    fi
  else
    skip "$app_name: saltato."
  fi
}

# ── Aggiornamento indice apt ──────────────────────────────────
info "Aggiornamento indice apt..."
sudo apt update -qq
echo ""

install_apt \
  "gimp" \
  "GIMP" \
  "Editor di immagini raster open source, alternativa professionale a Photoshop. Ritocco foto, grafica, elaborazione batch."

install_apt \
  "kazam" \
  "Kazam" \
  "Tool per registrare lo schermo e fare screenshot. Supporta registrazione dell'area, finestra o schermo intero con audio."

install_apt \
  "vlc" \
  "VLC Media Player" \
  "Riproduttore multimediale universale. Supporta praticamente qualsiasi formato video e audio, streaming e DVD."

install_apt \
  "inkscape" \
  "Inkscape" \
  "Editor di grafica vettoriale SVG open source, alternativa a Illustrator. Per loghi, illustrazioni, infografiche e icone."

install_apt \
  "scribus" \
  "Scribus" \
  "Software di desktop publishing open source, alternativa ad Adobe InDesign. Per brochure, riviste, volantini e libri."

install_apt \
  "filezilla" \
  "FileZilla" \
  "Client FTP/SFTP/FTPS grafico per il trasferimento di file su server remoti. Semplice, affidabile e con interfaccia drag-and-drop."

install_apt \
  "chromium-browser" \
  "Chromium" \
  "Browser web open source su cui è basato Google Chrome. Veloce, compatibile con le estensioni Chrome, senza telemetria Google."

install_apt \
  "default-jdk" \
  "OpenJDK" \
  "Java Development Kit open source. Necessario per eseguire applicazioni Java, IDE come IntelliJ o Eclipse, e tool aziendali basati su Java."

# ── Joplin — richiede script ufficiale ───────────────────────
echo ""
echo -e "  ${BOLD}${MAGENTA}▶ Joplin${NC} ${DIM}[installer ufficiale]${NC}"
desc "App open source per note e to-do sincronizzabili. Supporta Markdown, notebook, tag, cifratura end-to-end e sincronizzazione con Nextcloud, Dropbox, OneDrive."
echo ""

JOPLIN_INSTALLED=false
if [ -f "$HOME/.joplin/Joplin.AppImage" ] || flatpak_installed "net.cozic.joplin_desktop" 2>/dev/null; then
  JOPLIN_INSTALLED=true
fi

if $JOPLIN_INSTALLED; then
  warn "Joplin è già installato. Salto."
  SKIPPED=$((SKIPPED+1))
elif ask "Installare Joplin?"; then
  info "Installazione Joplin tramite installer ufficiale..."
  if has wget; then
    wget -O - https://raw.githubusercontent.com/laurent22/joplin/dev/Joplin_install_and_update.sh | bash && \
      ok "Joplin installato in ~/.joplin/" || \
      fail "Installazione Joplin fallita. Riprova: https://joplinapp.org/download/"
  else
    fail "wget non disponibile. Installa Joplin manualmente da https://joplinapp.org/download/"
  fi
else
  skip "Joplin: saltato."
fi

# ═══════════════════════════════════════════════════════════════
# FASE 5 — WALLPAPER UFFICIALE AICOMTEC
# ═══════════════════════════════════════════════════════════════
section "FASE 5 — Wallpaper ufficiale Aicomtec"

WALLPAPER_URL="https://www.scapuzzi.it/cloud/index.php/s/PG4rSpeKWmzYoMM/download"
WALLPAPER_DIR="/usr/share/backgrounds/aicomtec"
WALLPAPER_FILE="$WALLPAPER_DIR/aicomtec-wallpaper.jpg"
WALLPAPER_LOCAL="$HOME/.local/share/backgrounds/aicomtec-wallpaper.jpg"

info "Wallpaper: $WALLPAPER_URL"
echo ""

if ask "Scaricare e impostare il wallpaper ufficiale Aicomtec?"; then

  # Scarica prima in tmp per verificare
  TMP_WALLPAPER="$(mktemp /tmp/aicomtec-wallpaper-XXXXXX)"

  info "Download wallpaper in corso..."
  if wget -q --show-progress -O "$TMP_WALLPAPER" "$WALLPAPER_URL"; then

    # Verifica che sia effettivamente un'immagine
    if file "$TMP_WALLPAPER" | grep -qiE "image|jpeg|png|webp"; then

      # Determina estensione reale
      EXT="jpg"
      if file "$TMP_WALLPAPER" | grep -qi "png"; then EXT="png"; fi
      if file "$TMP_WALLPAPER" | grep -qi "webp"; then EXT="webp"; fi
      WALLPAPER_FILE="$WALLPAPER_DIR/aicomtec-wallpaper.$EXT"
      WALLPAPER_LOCAL="$HOME/.local/share/backgrounds/aicomtec-wallpaper.$EXT"

      # Installa nella cartella di sistema (richiede sudo)
      if ask "Installare il wallpaper per tutti gli utenti? (richiede sudo) [altrimenti solo per utente corrente]"; then
        sudo mkdir -p "$WALLPAPER_DIR"
        sudo cp "$TMP_WALLPAPER" "$WALLPAPER_FILE"
        sudo chmod 644 "$WALLPAPER_FILE"
        ok "Wallpaper installato in: $WALLPAPER_FILE"
        FINAL_WALLPAPER="$WALLPAPER_FILE"
      else
        mkdir -p "$(dirname "$WALLPAPER_LOCAL")"
        cp "$TMP_WALLPAPER" "$WALLPAPER_LOCAL"
        ok "Wallpaper installato in: $WALLPAPER_LOCAL"
        FINAL_WALLPAPER="$WALLPAPER_LOCAL"
      fi

      # Imposta come sfondo desktop via gsettings
      info "Impostazione sfondo desktop..."
      gsettings set org.cinnamon.desktop.background picture-uri \
        "file://$FINAL_WALLPAPER" 2>/dev/null && \
        ok "Sfondo desktop impostato." || \
        warn "gsettings fallito (normale fuori da sessione grafica attiva)."

      gsettings set org.cinnamon.desktop.background picture-options \
        "zoom" 2>/dev/null || true

      # Imposta anche su LightDM se il file è in posizione di sistema
      if [[ "$FINAL_WALLPAPER" == /usr/* ]]; then
        if [ -f /etc/lightdm/lightdm-gtk-greeter.conf ]; then
          info "Aggiornamento sfondo LightDM..."
          sudo sed -i "s|^background=.*|background=$FINAL_WALLPAPER|" \
            /etc/lightdm/lightdm-gtk-greeter.conf 2>/dev/null && \
            ok "Sfondo LightDM aggiornato." || \
            warn "Aggiornamento LightDM fallito — modifica manualmente /etc/lightdm/lightdm-gtk-greeter.conf"
        fi
      fi

    else
      fail "Il file scaricato non sembra un'immagine valida."
      warn "Verifica il link: $WALLPAPER_URL"
    fi

  else
    fail "Download wallpaper fallito."
    warn "Verifica la connessione o scarica manualmente da: $WALLPAPER_URL"
  fi

  rm -f "$TMP_WALLPAPER"

else
  skip "Wallpaper: saltato."
fi

# ═══════════════════════════════════════════════════════════════
# RIEPILOGO FINALE
# ═══════════════════════════════════════════════════════════════
section "Riepilogo"

echo -e "  ${GREEN}${BOLD}Installati:  $INSTALLED${NC}"
echo -e "  ${YELLOW}${BOLD}Saltati:     $SKIPPED${NC}"
echo -e "  ${RED}${BOLD}Falliti:     $FAILED${NC}"
echo ""

if [ "$FAILED" -gt 0 ]; then
  warn "Alcuni pacchetti non sono stati installati correttamente."
  warn "Riesegui lo script o installa manualmente i pacchetti segnalati con ✘"
  echo ""
fi

info "Per rendere effettive tutte le modifiche, riavvia la sessione grafica:"
echo -e "  ${CYAN}cinnamon --replace &${NC}   oppure   ${CYAN}logout e login${NC}"
echo ""

if flatpak list --app 2>/dev/null | grep -q .; then
  info "Le applicazioni Flatpak sono disponibili nel menu applicazioni."
  info "Al primo avvio potrebbero richiedere qualche secondo in più."
fi

echo ""
echo -e "  ${DIM}Aicomtec Linux — github.com/dado70/Mint-dado-Aicomtec${NC}"
echo ""

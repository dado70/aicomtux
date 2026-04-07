Semplice Script bash per personalizzare l'aspetto di Linux Mint 22.3 Cinnamo 64 per l'associazione AICOMTEC https://www.aicomtec.it/

**Usage**
```bash
$ sudo chmod +x aicomtec-setup.sh
$ sudo ./aicomtec-setup.sh
```
Lo script è diviso in 5 fasi, tutte interattive:  

##**Fase 2 — Setup Flatpak**  
installa Flatpak e aggiunge Flathub se non presenti, prima di qualsiasi app.  

##**Fase 3 — App Flatpak**  
per ognuna mostra nome, ID e una riga di descrizione di cosa fa, poi chiede conferma. Verifica anche se è già installata prima di procedere.  

##**Fase 4 — App APT**  
stessa logica. Joplin è un caso speciale — non ha un pacchetto apt ufficiale, viene installato tramite il suo script ufficiale da GitHub come AppImage in `~/.joplin/`.  

##**Fase 5 — Wallpaper**  
scarica da `scapuzzi.it`, verifica che sia un'immagine valida, chiede se installarlo per tutti gli utenti (sistema) o solo per l'utente corrente, imposta lo sfondo via `gsettings` e aggiorna anche `/etc/lightdm/lightdm-gtk-greeter.conf` se il file è in `/usr/share/`.  

##**Fase 1 — Pannello in alto**  
usa `gsettings` su `org.cinnamon panels-enabled` per sostituire `:bottom` con `:top` e riavvia Cinnamon automaticamente con `cinnamon --replace`.  


Al termine mostra un riepilogo con contatori: installati / saltati / falliti.
